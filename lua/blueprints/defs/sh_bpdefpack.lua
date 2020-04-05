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
	for k,v in ipairs(self.structs) do

		local maker = v:MakerNodeType()
		local breaker = v:BreakerNodeType()

		local makerName = "Make" .. v:GetName()
		local breakerName = "Break" .. v:GetName()
		tab[makerName] = maker
		tab[breakerName] = breaker

		maker.name = makerName
		breaker.name = breakerName

		self.structLookup[v:GetName()] = v
	end

	for _,v in ipairs(self.enums) do
		self.enumLookup[v.name] = v
	end

	for _,v in ipairs(self.nodeGroups) do
		for _, e in v:GetEntries():Items() do
			tab[e:GetFullName()] = e
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
	for k,v in ipairs(tab) do
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

function meta:GetPinTypes()

	local types = {}

	local blackList = {
		[PN_Exec] = true,
		[PN_Bool] = false,
		[PN_Vector] = false,
		[PN_Number] = false,
		[PN_Any] = true,
		[PN_String] = false,
		[PN_Color] = false,
		[PN_Angles] = false,
		[PN_Enum] = true,
		[PN_Ref] = true,
		[PN_Struct] = true,
		[PN_Func] = true,
		[PN_Dummy] = true,
		[PN_BPRef] = true,
		[PN_BPClass] = true,
		[PN_Asset] = true,
	}

	for i=0, PN_Max-1 do
		if blackList[i] then continue end
		types[#types+1] = bppintype.New(i)
	end

	for _, v in pairs(self:GetClasses()) do
		if v:GetParam("pinTypeOverride") then continue end
		types[#types+1] = bppintype.New(PN_Ref, PNF_None, v.name)
	end

	for _, v in pairs(self:GetStructs()) do
		if v:GetPinTypeOverride() then continue end
		types[#types+1] = bppintype.New(PN_Struct, PNF_None, v.name)
	end

	for _,v in ipairs(self.enums) do
		types[#types+1] = bppintype.New(PN_Enum, PNF_None, v.name)
	end

	types[#types+1] = bppintype.New( PN_Asset, PNF_None, "Material")
	types[#types+1] = bppintype.New( PN_Asset, PNF_None, "Model")
	types[#types+1] = bppintype.New( PN_Asset, PNF_None, "Sound")
	types[#types+1] = bppintype.New( PN_Asset, PNF_None, "Texture")

	return types

end

function meta:AddNodeRedirector(oldNode, newNode)

	--print("ADD NODE REDIRECT: " .. oldNode .. " -> " .. newNode)
	self.redirectors[oldNode] = newNode

end

function meta:AddStruct(struct)

	self.structs[#self.structs+1] = struct

end

function meta:AddNodeGroup(group)

	self.nodeGroups[#self.nodeGroups+1] = group

end

function meta:AddEnum(enum)

	self.enums[#self.enums+1] = enum

end

function meta:RemapNodeType(name)

	return self.redirectors[name] or name

end

function meta:GetNodeTypes()

	return self.nodeTypes

end

function meta:Serialize(stream)

	local groupCount = stream:UInt(#self.nodeGroups)
	local structCount = stream:UInt(#self.structs)

	for i=1, groupCount do
		self.nodeGroups[i] = stream:Object( self.nodeGroups[i] or bpnodetypegroup.New():WithOuter(self), true )
	end

	for i=1, structCount do
		self.structs[i] = stream:Object( self.structs[i] or bpstruct.New():WithOuter(self), true )
		self.structs[i].name = stream:String(self.structs[i].name)
		self.structs[i].pinTypeOverride = stream:Int(self.structs[i].pinTypeOverride or -1)
		if self.structs[i].pinTypeOverride == -1 then self.structs[i].pinTypeOverride = nil end
	end

	self.enums = stream:Value(self.enums)
	self.redirectors = stream:Value(self.redirectors)

	if stream:IsReading() then self:PostInit() end
	return stream

end

function meta:WriteToStream(stream) -- deprecate

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

function meta:ReadFromStream(stream) -- deprecate

	local groupCount = stream:ReadInt(false)
	local structCount = stream:ReadInt(false)

	for i=1, groupCount do
		self.nodeGroups[#self.nodeGroups+1] = bpnodetypegroup.New():WithOuter(self):ReadFromStream(stream)
	end

	for i=1, structCount do
		local struct = bpstruct.New():WithOuter(self):ReadFromStream(stream)
		local structName = stream:ReadStr()
		local pinTypeOverride = stream:ReadInt(true)

		struct:SetName( structName )
		self.structs[#self.structs+1] = struct
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

		for _,v in ipairs(self.nodeGroups) do

			str = str .. "\n\t" .. v:ToString()

		end

	end

	return str

end

function New(...)

	return bpcommon.MakeInstance(meta, ...)

end