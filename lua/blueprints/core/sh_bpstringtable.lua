AddCSLuaFile()

module("bpstringtable", package.seeall)

INVALID_STRING = 0

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

function meta:Serialize(stream)

	if stream:IsWriting() then

		local longStrings = {}
		local longLookup = {}
		local count = #self.strings
		for i, str in ipairs(self.strings) do
			if str:len() >= 256 then
				longLookup[i] = true
				longStrings[#longStrings+1] = i
			end
		end

		stream:UInt(count)
		stream:UInt(#longStrings)

		for _,v in ipairs(longStrings) do stream:Bits(v, 24) end

		for i=1, count do stream:Bits(self.strings[i]:len(), longLookup[i] and 16 or 8) end
		for i=1, count do stream:String(self.strings[i], true, 0) end

	elseif stream:IsReading() then

		local count = stream:UInt()
		local longCount = stream:UInt()
		local strings = {}

		local longLookup = {}
		for i=1, longCount do
			longLookup[ stream:Bits(nil, 24) ] = true
		end

		for i=1, count do strings[i] = stream:Bits(nil, longLookup[i] and 16 or 8) end
		for i=1, count do strings[i] = stream:String(nil, true, strings[i]) end

		self.strings = strings

	end

	return stream

end


function New(...) return bpcommon.MakeInstance(meta, ...) end