AddCSLuaFile()

module("bpnodetypegroup", package.seeall, bpcommon.rescope(bpschema))

TYPE_Class = 0
TYPE_Lib = 1
TYPE_Hooks = 2
TYPE_Structs = 3
TYPE_Callbacks = 4

GroupTypeNames = {
	[TYPE_Class] = "Class",
	[TYPE_Lib] = "Lib",
	[TYPE_Hooks] = "Hooks",
	[TYPE_Structs] = "Structs",
	[TYPE_Callbacks] = "Callbacks",
}

local GroupContexts = {
	[TYPE_Class] = bpnodetype.NC_Class,
	[TYPE_Lib] = bpnodetype.NC_Lib,
	[TYPE_Hooks] = bpnodetype.NC_Hook,
}

local meta = bpcommon.MetaTable("bpnodetypegroup")
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

function meta:GetType() return self.entryType end
function meta:GetEntries() return self.entries end

function meta:NewEntry()

	local entry = bpnodetype.New(GroupContexts[self:GetType()]):WithOuter(self)
	return self:AddEntry( entry )

end

function meta:AddEntry(entry)

	self.entries[#self.entries+1] = entry
	return entry

end

function meta:RemoveEntry( entry )

	table.RemoveByValue(self.entries, entry)

end

function meta:WriteToStream(stream)

	assert(stream:IsUsingStringTable())
	stream:WriteBits(self.entryType, 8)
	stream:WriteStr(self.name)
	bpdata.WriteValue(self.params, stream)

	local count = #self.entries
	stream:WriteInt(count, false)
	for i=1, count do self.entries[i]:WriteToStream(stream) end

	return self

end

function meta:ReadFromStream(stream)

	assert(stream:IsUsingStringTable())
	self.entryType = stream:ReadBits(8)
	self.name = stream:ReadStr()
	self.params = bpdata.ReadValue(stream)

	local count = stream:ReadInt(false)

	if self.entryType == TYPE_STRUCTS then -- DEAD CODE???
		for i=1, count do self.entries[#self.entries+1] = bpstruct.New():ReadFromStream(stream) end
	else
		for i=1, count do self:NewEntry():ReadFromStream(stream) end
	end

	return self

end

function meta:ToString()

	return self:GetName() .. "[" .. GroupTypeNames[self:GetType()] .. "] - " .. #self.entries .. " nodes."

end

function New(...) return bpcommon.MakeInstance(meta, ...) end