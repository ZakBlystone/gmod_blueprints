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

function meta:NewPin(name, type, default, flags, ex, desc)

	local var = bpvariable.New(type, default, flags, ex)
	return self.pins:Add( var, self.nameMap[name] or name )

end

function meta:SetPinTypeOverride(override)

	self.pinTypeOverride = override

end

function meta:SetName(name)

	self.name = name

end

function meta:GetName()

	return self.name

end

function meta:SetMetaTable(tableName)

	self.metaTable = tableName

end

function meta:GetMetaTable()

	return self.metaTable

end

function meta:RemapName(old, new)

	self.nameMap[old] = new
	self.invNameMap[new] = old

end

function meta:MarkAsCustom()

	self.custom = true
	return self

end

function meta:MakerNodeType()

	local ntype = bpnodetype.New()
	ntype:SetName("Make" .. self:GetName())
	ntype:SetDisplayName("Make" .. self:GetName())
	ntype:SetCodeType(NT_Pure)
	ntype:SetDescription(self.desc or "Makes a " .. self:GetName() .. " structure")
	ntype:SetCategory(self:GetName())
	ntype:SetContext(bpnodetype.NC_Struct)

	if self.custom then ntype:AddFlag(NTF_Custom) end

	if self.pinTypeOverride then
		ntype:AddPin( MakePin(PD_Out, self:GetName(), self.pinTypeOverride, PNF_None) )
	else
		ntype:AddPin(MakePin(
			PD_Out,
			self:GetName(),
			PN_Struct, PNF_None, self:GetName()
		))
	end

	for _, pin in self.pins:Items() do
		ntype:AddPin( pin:CreatePin(PD_In) )
	end

	local ret, arg = PinRetArg( ntype, function(s,pin)
		local name = pin:GetName()
		return "\n [\"" .. (self.invNameMap[name] or name) .. "\"] = " .. s
	end)
	local argt = "{ " .. arg .. "\n}"
	local code = ret .. " = "
	if self.metaTable then code = code .. "setmetatable(" end
	code = code .. argt
	if self.metaTable then code = code .. ", " .. self.metaTable .. "_)" end

	ntype:SetCode(code)

	for _, pin in pairs(ntype:GetPins()) do pin:SetName( bpcommon.Camelize(pin:GetName()) ) end

	return ntype

end

function meta:BreakerNodeType()

	local ntype = bpnodetype.New()
	ntype:SetName("Break" .. self:GetName())
	ntype:SetDisplayName("Break" .. self:GetName())
	ntype:SetCodeType(NT_Pure)
	ntype:SetDescription(self.desc or "Returns components of a " .. self:GetName() .. " structure")
	ntype:SetCategory(self:GetName())
	ntype:SetContext(bpnodetype.NC_Struct)

	if self.custom then ntype:AddFlag(NTF_Custom) end

	if self.pinTypeOverride then
		ntype:AddPin( MakePin(PD_In, self:GetName(), self.pinTypeOverride, PNF_None) )
	else
		ntype:AddPin(MakePin(
			PD_In,
			self:GetName(),
			PN_Struct, PNF_None, self:GetName()
		))
	end

	for _, pin in self.pins:Items() do
		ntype:AddPin( pin:CreatePin(PD_Out) )
	end

	local ret, arg = PinRetArg( ntype, nil, function(s,pin)
		local name = pin:GetName()
		return "\n" .. s .. " = $1[\"" .. (self.invNameMap[name] or name) .. "\"]"
	end, "")
	if ret[1] == '\n' then ret = ret:sub(2,-1) end

	ntype:SetCode(ret)

	for _, pin in pairs(ntype:GetPins()) do pin:SetName( bpcommon.Camelize(pin:GetName()) ) end

	return ntype

end

function meta:PostInit()

end

function meta:WriteToStream(stream, mode, version)

	self.pins:WriteToStream(stream, mode, version)
	bpdata.WriteValue(self.nameMap, stream)
	bpdata.WriteValue(self.invNameMap, stream)
	bpdata.WriteValue(self.metaTable, stream)
	return self

end

function meta:ReadFromStream(stream, mode, version)

	self.pins:ReadFromStream(stream, mode, version)
	self.nameMap = bpdata.ReadValue(stream)
	self.invNameMap = bpdata.ReadValue(stream)
	self.metaTable = bpdata.ReadValue(stream)
	return self

end

function New(...)

	return setmetatable({}, meta):Init(...)

end