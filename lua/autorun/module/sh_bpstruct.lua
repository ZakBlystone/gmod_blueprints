AddCSLuaFile()

module("bpstruct", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpstruct")

function meta:Init()

	self.pins = bplist.New():NamedItems("Pins"):Constructor(bppin.New)
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

function meta:AddPin(pin)

	local name = pin:GetName()
	return self.pins:Add( pin, self.nameMap[name:lower()] or name )

end

function meta:SetPinTypeOverride(override)

	self.pinTypeOverride = override

end

function meta:GetPinTypeOverride()

	return self.pinTypeOverride

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

	self.nameMap[old:lower()] = new
	self.invNameMap[new:lower()] = old

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
		ntype:AddPin( pin:Copy(PD_In) )
	end

	local ret, arg = PinRetArg( ntype, function(s,pin)
		local name = pin:GetName()
		return "\n [\"" .. (self.invNameMap[name:lower()] or name) .. "\"] = " .. s
	end)
	local argt = "{ " .. arg .. "\n}"
	local code = ret .. " = "
	if self.metaTable then code = code .. "setmetatable(" end
	code = code .. argt
	if self.metaTable then code = code .. ", " .. self.metaTable .. "_)" end

	ntype:SetCode(code)

	--for _, pin in pairs(ntype:GetPins()) do pin:SetName( bpcommon.Camelize(pin:GetName()) ) end

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
		ntype:AddPin( pin:Copy(PD_Out) )
	end

	ntype:SetCode("")
	ntype.Compile = function(node, compiler, pass)

		if pass == bpcompiler.CP_PREPASS then

			return true

		elseif pass == bpcompiler.CP_ALLOCVARS then

			print("CREATING PIN ROUTERS ON STRUCT: " .. self:GetName())
			compiler:CreatePinVar( node:FindPin(PD_In, self:GetName()) )

			local input = node:FindPin(PD_In, self:GetName())
			for pinID, pin in node:SidePins(PD_Out) do
				print("+PIN ROUTER: " .. pin:GetName())
				compiler:CreatePinRouter( pin, function(pin)
					local name = pin:GetName()
					return { var = compiler:GetPinCode(input) .. "[\"" .. (self.invNameMap[name:lower()] or name) .. "\"]" }
				end )
			end

			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			if node:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) ) end
			return true

		end

	end

	--for _, pin in pairs(ntype:GetPins()) do pin:SetName( bpcommon.Camelize(pin:GetName()) ) end

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

	local oldPins = nil
	if not version or version >= 4 then
		self.pins:ReadFromStream(stream, mode, version)
	else
		oldPins = bplist.New():NamedItems("Pins"):Constructor(bpvariable.New)
		oldPins:ReadFromStream(stream, mode, version)
	end
	self.nameMap = bpdata.ReadValue(stream)
	self.invNameMap = bpdata.ReadValue(stream)
	self.metaTable = bpdata.ReadValue(stream)

	if oldPins ~= nil then
		for _, v in oldPins:Items() do
			self:AddPin( v:CreatePin(PD_None) )
		end
	end

	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end