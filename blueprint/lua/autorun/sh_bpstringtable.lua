AddCSLuaFile()

include("sh_bpcommon.lua")

module("bpstringtable", package.seeall)

local INVALID_STRING = 0

local meta = {}
meta.__index = meta

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
		table.insert(self.strings, str)
		local id = #self.strings
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
	for i, str in pairs(self.strings) do
		if str:len() >= 256 then
			longLookup[i] = true
			table.insert(longStrings, i)
		end
	end

	stream:WriteInt(count, false)
	stream:WriteInt(#longStrings, false)

	for k, v in pairs(longStrings) do
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

function New(...)
	return setmetatable({}, meta):Init(...)
end