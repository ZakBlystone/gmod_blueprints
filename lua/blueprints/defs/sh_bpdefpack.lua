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
		for _, e in ipairs(v:GetEntries()) do
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
	}

	for i=0, PN_Max-1 do
		if blackList[i] then continue end
		types[#types+1] = PinType(i)
	end

	for _, v in pairs(self:GetClasses()) do
		if v:GetParam("pinTypeOverride") then continue end
		types[#types+1] = PinType(PN_Ref, PNF_None, v.name)
	end

	for _, v in pairs(self:GetStructs()) do
		if v:GetPinTypeOverride() then continue end
		types[#types+1] = PinType(PN_Struct, PNF_None, v.name)
	end

	for _,v in ipairs(self.enums) do
		types[#types+1] = PinType(PN_Enum, PNF_None, v.name)
	end

	return types

end

function meta:AddNodeRedirector(oldNode, newNode)

	print("ADD NODE REDIRECT: " .. oldNode .. " -> " .. newNode)
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
		self.nodeGroups[#self.nodeGroups+1] = bpnodetypegroup.New():ReadFromStream(stream)
	end

	for i=1, structCount do
		local struct = bpstruct.New():ReadFromStream(stream)
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