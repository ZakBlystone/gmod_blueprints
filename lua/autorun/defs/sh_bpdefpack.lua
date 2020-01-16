AddCSLuaFile()

module("bpdefpack", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpdefpack")
meta.__tostring = function(self) return self:ToString() end

function meta:Init()

	self.nodeGroups = {}
	self.structs = {}
	self.enums = {}
	self.redirectors = {}
	self.nodeTypes = {}
	self.classes = {}
	self.libs = {}
	self.hooks = {}
	self.structLookup = {}
	self.enumLookup = {}
	return self

end

function meta:PostInit()

	local tab = self.nodeTypes
	for k,v in pairs(self.structs) do
		local breaker = v:BreakerNodeType()
		local maker = v:MakerNodeType()

		tab[maker:GetName()] = maker
		tab[breaker:GetName()] = breaker

		self.structLookup[v:GetName()] = v
	end

	for k,v in pairs(self.enums) do
		self.enumLookup[v.name] = v
	end

	for k,v in pairs(self.nodeGroups) do
		for _, e in pairs(v:GetEntries()) do
			tab[e:GetName()] = e
		end

		if v:GetType() == bpnodetypegroup.TYPE_Class then
			self.classes[v:GetName()] = v
		end

		if v:GetType() == bpnodetypegroup.TYPE_Lib then
			self.libs[v:GetName()] = v
		end

		if v:GetType() == bpnodetypegroup.TYPE_Hooks then
			self.hooks[v:GetName()] = v
		end
	end

	--[[print("Init node types: ")
	for k,v in pairs(tab) do
		print(v:GetName())
	end]]

end

function meta:GetEnum(name)

	if IsPinType(name) then return self.enumLookup[name:GetSubType()] end
	return self.enumLookup[name]

end

function meta:GetClass(name)

	if IsPinType(name) then return self.classes[name:GetSubType()] end
	return self.classes[name]

end

function meta:GetStruct( name )

	if IsPinType(name) then return self.structLookup[name:GetSubType()] end
	return self.structLookup[name]

end

function meta:GetClasses()

	return self.classes

end

function meta:GetLibs()

	return self.libs

end

function meta:GetStructs()

	return self.structLookup

end

function meta:GetHooks()

	return self.hooks

end

function meta:AddNodeRedirector(oldNode, newNode)

	print("ADD NODE REDIRECT: " .. oldNode .. " -> " .. newNode)
	self.redirectors[oldNode] = newNode

end

function meta:AddStruct(struct)

	table.insert(self.structs, struct)

end

function meta:AddNodeGroup(group)

	table.insert(self.nodeGroups, group)

end

function meta:AddEnum(enum)

	table.insert(self.enums, enum)

end

function meta:RemapNodeType(name)

	return self.redirectors[name] or name

end

function meta:GetNodeTypes()

	return self.nodeTypes

end

function meta:WriteToStream(stream)

	assert(stream:IsUsingStringTable())
	stream:WriteInt(#self.nodeGroups, false)
	stream:WriteInt(#self.structs, false)
	for i=1, #self.nodeGroups do self.nodeGroups[i]:WriteToStream(stream) end
	for i=1, #self.structs do
		-- This is a dumb out-of-bounds hack, fix later
		self.structs[i]:WriteToStream(stream)
		stream:WriteStr(self.structs[i]:GetName())
		stream:WriteInt(self.structs[i].pinTypeOverride or -1, true)
	end
	bpdata.WriteValue(self.enums, stream)
	bpdata.WriteValue(self.redirectors, stream)
	return self

end

function meta:ReadFromStream(stream)

	local groupCount = stream:ReadInt(false)
	local structCount = stream:ReadInt(false)

	for i=1, groupCount do
		table.insert(self.nodeGroups, bpnodetypegroup.New():ReadFromStream(stream))
	end

	for i=1, structCount do
		local struct = bpstruct.New():ReadFromStream(stream)
		local structName = stream:ReadStr()
		local pinTypeOverride = stream:ReadInt(true)

		struct:SetName( structName )
		table.insert(self.structs, struct)
		-- This is a dumb out-of-bounds hack, fix later
		if pinTypeOverride ~= -1 then struct.pinTypeOverride = pinTypeOverride end
	end

	self.enums = bpdata.ReadValue(stream)
	self.redirectors = bpdata.ReadValue(stream)

	self:PostInit()
	return self

end

function meta:ToString(inner)

	local str = "Node Groups: " .. #self.nodeGroups .. ", Struct Groups: " .. #self.structs .. ", Enums: " .. #self.enums
	if inner then

		for k,v in pairs(self.nodeGroups) do

			str = str .. "\n\t" .. v:ToString()

		end

	end

	return str

end

function New(...)

	return bpcommon.MakeInstance(meta, ...)

end