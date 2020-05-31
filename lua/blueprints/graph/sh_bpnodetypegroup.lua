AddCSLuaFile()

module("bpnodetypegroup", package.seeall, bpcommon.rescope(bpschema))

TYPE_Class = 0
TYPE_Lib = 1
TYPE_Hooks = 2
TYPE_Callbacks = 4

FL_None = 0
FL_NoWikiDoc = 1

GroupTypeNames = {
	[TYPE_Class] = "Class",
	[TYPE_Lib] = "Lib",
	[TYPE_Hooks] = "Hooks",
	[TYPE_Callbacks] = "Callbacks",
}

local GroupContexts = {
	[TYPE_Class] = bpnodetype.NC_Class,
	[TYPE_Lib] = bpnodetype.NC_Lib,
	[TYPE_Hooks] = bpnodetype.NC_Hook,
}

function NodeContextFromGroupType( type )

	return GroupContexts[type]

end

local meta = bpcommon.MetaTable("bpnodetypegroup")

bpcommon.AddFlagAccessors(meta)

function meta:Init(entryType)

	self.flags = FL_None
	self.entryType = entryType
	self.name = ""
	self.entries = bplist.New(bpnodetype_meta):WithOuter(self):Indexed(false):PreserveNames(true)
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

	local entry = bpnodetype.New():WithOuter(self)
	return self:AddEntry( entry )

end

function meta:AddEntry(entry)

	self.entries:Add( entry )
	return entry

end

function meta:RemoveEntry( entry )

	self.entries:RemoveIf( function(e) return e == entry end )

end

function meta:Serialize(stream)

	if stream:GetVersion() > 5 then
		self.flags = stream:Bits(self.flags, 8)
	end

	self.entryType = stream:Bits(self.entryType, 8)
	self.name = stream:String(self.name)
	self.params = stream:Value(self.params)
	self.entries:Serialize(stream)
	return stream

end

function meta:ToString()

	return self:GetName() .. "[" .. GroupTypeNames[self:GetType()] .. "] - " .. self.entries:Size() .. " nodes."

end

function New(...) return bpcommon.MakeInstance(meta, ...) end