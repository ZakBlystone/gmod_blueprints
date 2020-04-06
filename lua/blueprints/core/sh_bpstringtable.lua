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

	local lengths = {}
	local strings = self.strings
	local count = stream:UInt(#strings)

	for i=1, count do lengths[i] = stream:Length(strings[i] and #strings[i] or 0) end
	for i=1, count do strings[i] = stream:String(strings[i], true, lengths[i]) end

	return stream

end


function New(...) return bpcommon.MakeInstance(meta, ...) end