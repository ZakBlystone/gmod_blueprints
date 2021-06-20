AddCSLuaFile()

-- Can't rescope bpschema, because it's not loaded yet
module("bppintype", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bppintype")
meta.__tostring = function(self)
	return self:ToString()
end

function meta:Init(type, flags, subtype)
	self.basetype = type
	self.flags = flags or PNF_None
	self.subtype = subtype

	local hashStr = string.format("%0.2d_%0.2x_%s", self.basetype or -1, self.flags, tostring(self.subtype) )
	self.hash = util.CRC( hashStr )

	return self
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

function meta:GetBaseType() return self.basetype end
function meta:GetSubType() return self.subtype end
function meta:GetFlags(mask) return bit.band(self.flags, mask or PNF_All) end
function meta:GetColor() return NodePinColors[ self:GetBaseType() ] or Color(0,0,0,255) end
function meta:GetTypeName() return PinTypeNames[ self:GetBaseType() ] or "UNKNOWN" end
function meta:GetLiteralType() return NodeLiteralTypes[ self:GetBaseType() ] end
function meta:GetDefault()

	if self:HasFlag(PNF_Table) then return (not self:HasFlag(PNF_Nullable)) and "{}" end
	if self:GetBaseType() == PN_Enum and bpdefs and bpdefs.Ready() then
		local enum = bpdefs.Get():GetEnum( self )
		if enum and enum.entries[1] then return enum.entries[1].key end
	end
	return Defaults[ self:GetBaseType() ]

end

function meta:GetDisplayName()

	if self:IsType(PN_BPRef) then
		local mod = self:FindOuter( bpmodule_meta )
		if mod then return mod:GetName() end
		local sub = self:GetSubType()
		return sub and bpcommon.GUIDToString(self:GetSubType(), true) or "unknown blueprint"
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
	if self:GetSubType() ~= other:GetSubType() and not ignoreSubType then return false end
	return true
end

meta.__eq = function(a, b)
	return a.basetype == b.basetype and a.flags == b.flags and a.subtype == b.subtype
end

meta.__lt = function(a, b)
	if a.basetype ~= b.basetype then return a.basetype < b.basetype end
	if a.subtype ~= b.subtype then return a.subtype < b.subtype end
	return false
end

meta.__le = function(a, b)
	if a.basetype ~= b.basetype then return a.basetype <= b.basetype end
	if a.subtype ~= b.subtype then return a.subtype <= b.subtype end
	return true
end

function meta:WriteToStream(stream)

	assert(stream:IsUsingStringTable())
	stream:WriteBits(self.basetype, 8)
	stream:WriteBits(self.flags, 8)
	stream:WriteStr(self.subtype)
	return self

end

function meta:ReadFromStream(stream)

	assert(stream:IsUsingStringTable())
	self.basetype = stream:ReadBits(8)
	self.flags = stream:ReadBits(8)
	self.subtype = stream:ReadStr()
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end