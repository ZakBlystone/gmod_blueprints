AddCSLuaFile()

module("bpfile", package.seeall)

function Sanitizer( str )

	return str

end

FL_None = 0
FL_Running = 1
FL_AlwaysRun = 2
FL_HasOwner = 4

FT_Unknown = 0
FT_Module = 1

local meta = bpcommon.MetaTable("bpfile")

bpcommon.AddFlagAccessors(meta)

meta.__eq = function(a,b)

	if a.name ~= b.name then return false end
	if a.flags ~= b.flags then return false end
	return true

end

function meta:Init(uid, type)

	self.flags = FL_None
	self.uid = uid or bpcommon.GUID()
	self.type = type or FT_Unknown
	return self

end

function meta:SetOwner( owner )

	self.owner = owner
	if self.owner ~= nil then
		self:SetFlag(FL_HasOwner)
	else
		self:ClearFlag(FL_HasOwner)
	end

end

function meta:GetName()

	return self.name or ""

end

function meta:WriteToStream(stream, mode, version)

	stream:WriteBits(self.flags, 8)
	stream:WriteStr(self.uid)

	if self:HasFlag(FL_HasOwner) then
		self.owner:WriteToStream(stream, mode, version)
	end

end

function meta:ReadFromStream(stream, mode, version)

	self.flags = stream:ReadBits(8)
	self.uid = bpcommon.ReadStr(16)

	if not self:HasFlag( FL_AlwaysRun ) then self:ClearFlag( FL_Running ) end
	if self:HasFlag(FL_HasOwner) then
		self.owner = bpuser.New()
		self.owner:ReadFromStream(stream, mode, version)
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end