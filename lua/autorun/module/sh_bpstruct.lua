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
				self.module:PreModifyNodeType( self.makerNodeType )
				self.module:PreModifyNodeType( self.breakerNodeType )
			elseif cb == bplist.CB_POSTMODIFY then
				self.module:PostModifyNodeType( self.makerNodeType )
				self.module:PostModifyNodeType( self.breakerNodeType )
			end
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	local pinmeta = bpcommon.FindMetaTable("bppin")

	-- Struct maker node
	self.makerNodeType = bpnodetype.New()
	self.makerNodeType:SetCodeType(NT_Pure)
	self.makerNodeType:SetContext(bpnodetype.NC_Struct)
	self.makerNodeType.GetDisplayName = function() return "Make" .. self:GetName() end
	self.makerNodeType.GetDescription = function() return (self.desc or "Makes a " .. self:GetName() .. " structure") end
	self.makerNodeType.GetCategory = function() return self:GetName() end
	self.makerNodeType.GetFlags = function() return self.custom and NTF_Custom or NTF_None end
	self.makerNodeType.GetRawPins = function()

		local pins = {}

		if self.pinTypeOverride then
			pins[#pins+1] = MakePin(PD_Out, self:GetName(), self.pinTypeOverride, PNF_None)
		else
			pins[#pins+1] = MakePin(PD_Out, self:GetName(), PN_Struct, PNF_None, self:GetName() )
		end

		return bpcommon.Transform(self.pins:GetTable(), pins, pinmeta.Copy, PD_In)

	end

	self.makerNodeType.GetCode = function( ntype )

		local ret, arg = PinRetArg( ntype, function(s,pin)
			local name = pin:GetName()
			return "\n [\"" .. (self.invNameMap[name:lower()] or name) .. "\"] = " .. s
		end)
		local argt = "{ " .. arg .. "\n}"
		local code = ret .. " = "
		if self.metaTable then code = code .. "setmetatable(" end
		code = code .. argt
		if self.metaTable then code = code .. ", " .. self.metaTable .. "_)" end

		return code

	end

	-- Struct breaker node
	self.breakerNodeType = bpnodetype.New()
	self.breakerNodeType:SetCodeType(NT_Pure)
	self.breakerNodeType:SetContext(bpnodetype.NC_Struct)
	self.breakerNodeType:SetCode("")
	self.breakerNodeType.GetDisplayName = function() return "Break" .. self:GetName() end
	self.breakerNodeType.GetDescription = function() return self.desc or "Returns components of a " .. self:GetName() .. " structure" end
	self.breakerNodeType.GetCategory = function() return self:GetName() end
	self.breakerNodeType.GetFlags = function() return self.custom and NTF_Custom or NTF_None end
	self.breakerNodeType.GetRawPins = function()

		local pins = {}

		if self.pinTypeOverride then
			pins[#pins+1] = MakePin(PD_In, self:GetName(), self.pinTypeOverride, PNF_None)
		else
			pins[#pins+1] = MakePin(PD_In, self:GetName(), PN_Struct, PNF_None, self:GetName() )
		end

		return bpcommon.Transform(self.pins:GetTable(), pins, pinmeta.Copy, PD_Out)

	end

	self.breakerNodeType.Compile = function(node, compiler, pass)

		if pass == bpcompiler.CP_PREPASS then

			return true

		elseif pass == bpcompiler.CP_ALLOCVARS then

			compiler:CreatePinVar( node:FindPin(PD_In, self:GetName()) )

			local input = node:FindPin(PD_In, self:GetName())
			for pinID, pin in node:SidePins(PD_Out) do
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

	return self.makerNodeType

end

function meta:BreakerNodeType()

	return self.breakerNodeType

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