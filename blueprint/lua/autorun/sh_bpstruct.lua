AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpvariable.lua")

module("bpstruct", package.seeall, bpcommon.rescope(bpschema))

local meta = {}
meta.__index = meta

function meta:Init()

	self.pins = bplist.New():NamedItems("Pins"):Constructor(bpvariable.New)
	self.nameMap = {}
	self.invNameMap = {}
	self.pins:AddListener(function(cb, action, id, var)

		if self.module then
			if cb == bplist.CB_PREMODIFY then
				self.module:PreModifyNodeType( "__Make" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
				self.module:PreModifyNodeType( "__Break" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			elseif cb == bplist.CB_POSTMODIFY then
				self.module:PostModifyNodeType( "__Make" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
				self.module:PostModifyNodeType( "__Break" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			end
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	return self

end

function meta:NewPin(name, type, default, flags, ex)

	local var = bpvariable.New(type, default, flags, ex)
	return self.pins:Add( var, self.nameMap[name] or name )

end

function meta:GetName()

	return self.name

end

function meta:SetMetaTable(tableName)

	self.metaTable = tableName

end

function meta:RemapName(old, new)

	self.nameMap[old] = new
	self.invNameMap[new] = old

end

function meta:MarkAsCustom()

	self.custom = true
	return self

end

function meta:MakerNodeType( pinTypeOverride )

	local ntype = { pins = {} }
	ntype.name = "Make" .. self:GetName()
	ntype.displayName = ntype.name
	ntype.type = NT_Pure
	ntype.desc = self.desc or "Makes a " .. self:GetName() .. " structure"
	ntype.code = ""
	ntype.defaults = {}
	ntype.category = self:GetName()
	ntype.isStruct = true
	ntype.custom = self.custom
	ntype.meta = {}

	if pinTypeOverride then 
		table.insert(ntype.pins, {PD_Out, pinTypeOverride, self:GetName(), PNF_None})
	else
		table.insert(ntype.pins, {
			PD_Out,
			PN_Struct,
			self:GetName(),
			PNF_None,
			self:GetName(),
		})
	end

	for _, pin in self.pins:Items() do

		table.insert(ntype.pins, pin:CreatePin(PD_In))
		ntype.defaults[#ntype.pins - 1] = pin:GetDefaultValue()

	end

	local ret, arg = PinRetArg( ntype, function(s,pin)
		return "\n [\"" .. (self.invNameMap[pin[3]] or pin[3]) .. "\"] = " .. s
	end)
	local argt = "{ " .. arg .. "\n}"
	ntype.code = ret .. " = "
	if self.metaTable then ntype.code = ntype.code .. "setmetatable(" end
	ntype.code = ntype.code .. argt
	if self.metaTable then ntype.code = ntype.code .. ", " .. self.metaTable .. "_)" end

	for _, pin in pairs(ntype.pins) do pin[3] = bpcommon.Camelize(pin[3]) end

	ConfigureNodeType(ntype)
	return ntype

end

function meta:BreakerNodeType( pinTypeOverride )

	local ntype = { pins = {} }
	ntype.name = "Break" .. self:GetName()
	ntype.displayName = ntype.name
	ntype.type = NT_Pure
	ntype.desc = self.desc or "Returns components of a " .. self:GetName() .. " structure"
	ntype.code = ""
	ntype.defaults = {}
	ntype.category = self:GetName()
	ntype.isStruct = true
	ntype.custom = self.custom
	ntype.meta = {}

	if pinTypeOverride then 
		table.insert(ntype.pins, {PD_In, pinTypeOverride, self:GetName(), PNF_None})
	else
		table.insert(ntype.pins, {
			PD_In,
			PN_Struct,
			self:GetName(),
			PNF_None,
			self:GetName(),
		})
	end

	for _, pin in self.pins:Items() do

		table.insert(ntype.pins, pin:CreatePin(PD_Out))
		ntype.defaults[#ntype.pins - 1] = pin:GetDefaultValue()

	end

	local ret, arg = PinRetArg( ntype, nil, function(s,pin)
		return "\n" .. s .. " = $1[\"" .. (self.invNameMap[pin[3]] or pin[3]) .. "\"]"
	end, "")
	if ret[1] == '\n' then ret = ret:sub(2,-1) end
	ntype.code = ret

	for _, pin in pairs(ntype.pins) do pin[3] = bpcommon.Camelize(pin[3]) end

	ConfigureNodeType(ntype)
	return ntype

end

function meta:PostInit()

end

function meta:WriteToStream(stream, mode, version)

	self.pins:WriteToStream(stream, mode, version)
	bpdata.WriteValue(self.nameMap, stream)
	bpdata.WriteValue(self.invNameMap, stream)
	bpdata.WriteValue(self.metaTable, stream)

end

function meta:ReadFromStream(stream, mode, version)

	self.pins:ReadFromStream(stream, mode, version)
	self.nameMap = bpdata.ReadValue(stream)
	self.invNameMap = bpdata.ReadValue(stream)
	self.metaTable = bpdata.ReadValue(stream)

end

function New(...)

	return setmetatable({}, meta):Init(...)

end