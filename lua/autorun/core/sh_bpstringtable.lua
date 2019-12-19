AddCSLuaFile()

module("bpstringtable", package.seeall)

local INVALID_STRING = 0

local meta = bpcommon.MetaTable("bpstringtable")

function meta:Init()
	self.strings = {}
	self.rstrings = {}
	return self
end

function meta:Add(str)

	if str == nil then return INVALID_STRING end
	local found = self.rstrings[str]
	if found ~= nil then
		return found
	else
		local id = #self.strings+1
		self.strings[id] = str
		self.rstrings[str] = id
		return id
	end

end

function meta:Get(id)

	if id == INVALID_STRING then return nil end
	return self.strings[id]

end

function meta:WriteToStream(stream)

	local longStrings = {}
	local longLookup = {}
	local count = #self.strings
	for i, str in ipairs(self.strings) do
		if str:len() >= 256 then
			longLookup[i] = true
			longStrings[#longStrings+1] = i
		end
	end

	stream:WriteInt(count, false)
	stream:WriteInt(#longStrings, false)

	for _,v in ipairs(longStrings) do
		stream:WriteBits(v, 24)
	end

	for i=1, count do stream:WriteBits(self.strings[i]:len(), longLookup[i] and 16 or 8) end
	for i=1, count do stream:WriteStr(self.strings[i], true) end

end

function meta:ReadFromStream(stream)

	local count = stream:ReadInt(false)
	local longCount = stream:ReadInt(false)
	local strings = {}

	local longLookup = {}
	for i=1, longCount do
		longLookup[ stream:ReadBits(24) ] = true
	end

	for i=1, count do strings[i] = stream:ReadBits(longLookup[i] and 16 or 8) end
	for i=1, count do strings[i] = stream:ReadStr(strings[i], true) end

	self.strings = strings

end

function New(...) return bpcommon.MakeInstance(meta, ...) end