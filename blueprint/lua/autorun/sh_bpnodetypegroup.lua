AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodetype.lua")

module("bpnodetypegroup", package.seeall, bpcommon.rescope(bpschema))

TYPE_CLASS = 0
TYPE_LIB = 1
TYPE_HOOKS = 2
TYPE_STRUCTS = 3
TYPE_CALLBACKS = 4

local meta = {}
meta.__index = meta
meta.__tostring = function(self) return self:ToString() end

function meta:Init(entryType)

	self.entryType = entryType
	self.name = ""
	self.entries = {}
	self.params = {}
	return self

end

function meta:SetName(name) self.name = name end
function meta:GetName() return self.name end

function meta:SetParam(key, value) self.params[key] = value end
function meta:GetParam(key) return self.params[key] end

function meta:GetEntries() return self.entries end

function meta:Add(entry)

	table.insert(self.entries, entry)

end

function meta:WriteToStream(stream)

	assert(stream:IsUsingStringTable())
	stream:WriteBits(self.entryType, 8)
	stream:WriteStr(self.name)
	bpdata.WriteValue(self.params, stream)

	local count = #self.entries
	stream:WriteInt(count, false)
	for i=1, count do self.entries[i]:WriteToStream(stream) end

end

function meta:ReadFromStream(stream)

	assert(stream:IsUsingStringTable())
	self.entryType = stream:ReadBits(8)
	self.name = stream:ReadStr()
	self.params = bpdata.ReadValue(stream)

	local count = stream:ReadInt(false)
	for i=1, count do table.insert(self.entries, bpnodetype.New():ReadFromStream(stream)) end

end

function meta:ToString()

	return self:GetName() .. " - " .. #self.entries .. " nodes."

end

function New(...)

	return setmetatable({}, meta):Init(...)

end