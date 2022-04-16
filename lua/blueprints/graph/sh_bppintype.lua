AddCSLuaFile()

-- Can't rescope bpschema, because it's not loaded yet
module("bppintype", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bppintype")

meta.__eq = function(a, b)
	return a.basetype == b.basetype and a.flags == b.flags and a:GetSubType() == b:GetSubType()
end

meta.__lt = function(a, b)
	if a.basetype ~= b.basetype then return a.basetype < b.basetype end
	if a:GetSubType() ~= b:GetSubType() then return a:GetSubType() < b:GetSubType() end
	return false
end

meta.__le = function(a, b)
	if a.basetype ~= b.basetype then return a.basetype <= b.basetype end
	if a:GetSubType() ~= b:GetSubType() then return a:GetSubType() <= b:GetSubType() end
	return true
end

function meta:Init(basetype, flags, subtype)

	if type(subtype) == "table" then
		subtype = bpcommon.Weak(subtype)
	end

	self.basetype = basetype
	self.flags = flags or PNF_None
	self.subtype = subtype
	self:UpdateHash()

	return self
end

function meta:UpdateHash()
	local hashStr = string.format("%0.2d_%0.2x_%s", self.basetype or -1, self.flags, tostring(self.subtype) )
	self.hash = util.CRC( hashStr )
end

function meta:GetHash()
	return self.hash
end

function meta:AsTable()
	return New(self:GetBaseType(), bit.bor(self:GetFlags(), PNF_Table), self:GetSubType())
end

function meta:AsSingle()
	return New(self:GetBaseType(), bit.band(self:GetFlags(), bit.bnot(PNF_Table)), self:GetSubType())
end

function meta:WithFlags(flags)
	return New(self:GetBaseType(), flags, self:GetSubType())
end

function meta:Copy( outer )
	return New(self:GetBaseType(), self:GetFlags(), self:GetSubType()):WithOuter( outer or self:GetOuter() )
end

function meta:HasObjectLiteral()

	return self:GetBaseType() == PN_Func

end

function meta:GetBaseType() return self.basetype end
function meta:GetSubType() return type(self.subtype) == "table" and self.subtype() or self.subtype end
function meta:GetFlags(mask) return bit.band(self.flags, mask or PNF_All) end
function meta:GetColor() return NodePinColors[ self:GetBaseType() ] or Color(0,0,0,255) end
function meta:GetTypeName() return PinTypeNames[ self:GetBaseType() ] or "UNKNOWN" end
function meta:GetLiteralType() return NodeLiteralTypes[ self:GetBaseType() ] end
function meta:GetDefault()

	if self:HasObjectLiteral() then return nil end
	if self:HasFlag(PNF_Table) then return (not self:HasFlag(PNF_Nullable)) and "__emptyTable()" or nil end
	if self:GetBaseType() == PN_Enum and bpdefs and bpdefs.Ready() then
		local enum = bpdefs.Get():GetEnum( self )
		if enum and enum.entries[1] then return enum.entries[1].key end
	end
	return Defaults[ self:GetBaseType() ]

end

function meta:GetSubTypeString()

	local t = self:GetSubType()
	if type(t) == "table" then return t.GetName and t:GetName() or tostring(t) end
	if type(t) == "string" then return t end
	return "nil"

end

function meta:CanCastTo( inPinType )

	if self:IsType(PN_Any) and not inPinType:IsType(PN_Exec) then return true end
	if inPinType:IsType(PN_Any) and not self:IsType(PN_Exec) then return true end

	if self:IsType(PN_BPRef) and self:GetSubType() ~= nil then
		return self:GetSubType():CanCast( self, inPinType )
	end

	if self:IsType(PN_BPClass) and inPinType:IsType(PN_BPClass) then

		--[[local inSub = inPinType:GetSubType()
		local outSub = self:GetSubType()
		if not bpcommon.IsGUID( inSub ) and bpcommon.IsGUID( outSub )then

			local mod = self:ResolveModuleUID( outSub )
			return mod:GetType() == inSub

		end]]
		return false

	end

end

function meta:GetDisplayName()

	if self:IsType(PN_BPRef) then
		return "M_" .. self:GetSubTypeString()
	end

	if self:IsType(PN_Func) then
		return "CB_" .. self:GetSubTypeString()
	end

	if self:IsType(PN_BPClass) then
		local sub = self:GetSubType()
		local cl = bpmodule.GetClassLoader():Get( sub )
		if cl then return "Class[" .. sub .. "]" end
		return sub and bpcommon.GUIDToString(sub, true) or "unknown blueprint"
	end

	if self:IsType(PN_Asset) then
		return self:GetSubType()
	end

	if self:IsType(PN_Ref) or self:IsType(PN_Enum) or self:IsType(PN_Struct) then
		return self:GetSubType()
	else
		return self:GetTypeName()
	end

end

function meta:FindStruct()

	local res = nil
	bpcommon.Profile("bppintype-get-struct", function()

		--local struct = self:FindOuter(bpstruct_meta)
		--if struct then return struct end

		local mod = self:FindOuter(bpmodule_meta)
		if mod and self:HasFlag(PNF_Custom) and mod.structs then
			for id, v in mod:Structs() do
				if v.name == self:GetSubType() then res = v break end
			end
		end

		if not res then
			res = bpdefs.Get():GetStruct( self:GetSubType() )
		end

	end)

	return res

end

function meta:GetPinClass() return PinTypeClasses[ self:GetBaseType() ] end
function meta:ToString()
	local str = self:GetDisplayName() --self:GetTypeName()
	--if self:GetSubType() ~= nil then str = str .. ", " .. self:GetSubType() end
	if self:HasFlag(PNF_Table) then str = str .. " -table" end
	if self:HasFlag(PNF_Nullable) then str = str .. " -null" end
	if self:HasFlag(PNF_Bitfield) then str = str .. " -bitfield" end
	return str
end

function meta:IsType(base, sub)
	return self:GetBaseType() == base and (sub == nil and true or self:GetSubType() == sub)
end

function meta:HasFlag(fl)
	return bit.band(self:GetFlags(), fl) ~= 0
end

function meta:Equal(other, flagMask, ignoreSubType)
	flagMask = flagMask or PNF_All
	if other == nil then return false end
	if self:GetBaseType() ~= other:GetBaseType() then return false end
	if bit.band( self:GetFlags(), flagMask ) ~= bit.band( other:GetFlags(), flagMask ) then return false end

	if self:GetBaseType() == PN_Func then
		local a = self:GetSubType()
		local b = other:GetSubType()
		return (a and b and a.GetName and b.GetName and a:GetName() == b:GetName()) or (a == nil and b == nil)
	end

	if self:GetSubType() ~= other:GetSubType() and not ignoreSubType then return false end
	return true
end

function meta:Serialize(stream)

	self.basetype = stream:Bits(self.basetype, 8)
	self.flags = stream:Bits(self.flags, 8)

	if self.basetype == PN_BPRef or self.basetype == PN_Func then

		if stream:IsWriting() then
			assert( type(self.subtype) ~= "string", "Was string on pintype: " .. tostring(self) )
		end

		self.subtype = stream:Object(self.subtype)
		print("SERIALIZE SUBTYPE: " .. self:GetSubTypeString())
	else
		self.subtype = stream:String(self.subtype)
	end

	if stream:IsReading() then self:UpdateHash() end

	--print("PINTYPE SERIALIZE [" .. (stream:IsReading() and "READ" or "WRITE") .. "][" .. stream:GetContext() .. "]: " .. self:ToString())

	return stream

end

function New(...) return bpcommon.MakeInstance(meta, ...) end