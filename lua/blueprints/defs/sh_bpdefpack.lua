AddCSLuaFile()

module("bpdefpack", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpdefpack")

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
	self.callbacks = {}
	return self

end

function meta:CreateEnumBitwiseFunctions( enum, out_nodes )

	local pin_type = bppintype.New(PN_Enum, PNF_Bitfield, enum.name)
	local bit_or = bpnodetype.New():WithOuter(self)
	bit_or:AddFlag(NTF_Compact)
	bit_or:SetContext(bpnodetype.NC_Enum)
	bit_or:SetName(enum.name .. "_BITOR")
	bit_or:SetNodeClass("VariadicOperator")
	bit_or:SetNodeParam("operator", "bit.bor")
	bit_or:SetNodeParam("mode", "function")
	bit_or.GetDisplayName = function() return "|" end
	bit_or.GetDescription = function() return enum.name .. " | " .. enum.name end
	bit_or.GetCategory = function() return enum.name end
	bit_or:AddPin( bppin.New( PD_Out, "Result", pin_type ) )

	local bit_and = bpnodetype.New():WithOuter(self)
	bit_and:AddFlag(NTF_Compact)
	bit_and:SetContext(bpnodetype.NC_Enum)
	bit_and:SetName(enum.name .. "_BITAND")
	bit_and:SetNodeClass("VariadicOperator")
	bit_and:SetNodeParam("operator", "bit.band")
	bit_and:SetNodeParam("mode", "function")
	bit_and:SetNodeParam("test_nonzero", "1")
	bit_and.GetDisplayName = function() return "&" end
	bit_and.GetDescription = function() return enum.name .. " & " .. enum.name end
	bit_and.GetCategory = function() return enum.name end
	bit_and:AddPin( bppin.New( PD_Out, "Result", pin_type ) )
	bit_and:AddPin( MakePin( PD_Out, "NonZero", PN_Bool, PNF_None, nil, "Tests if result is non-zero" ) )

	out_nodes[enum.name .. "_BITOR"] = bit_or
	out_nodes[enum.name .. "_BITAND"] = bit_and

end

function meta:PostInit()

	self.nodeTypes = {}
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

		if v.is_bitfield then
			print("Create bitwise funcs for: " .. v.name)
			self:CreateEnumBitwiseFunctions(v, tab)
		end
	end

	for _,v in ipairs(self.nodeGroups) do
		for _, e in v:GetEntries():Items() do
			tab[e:GetFullName()] = e
		end

		if v:GetType() == bpnodetypegroup.TYPE_Class then
			local exist = self.classes[v:GetName()]
			if exist and exist ~= v then
				for _, entry in v:GetEntries():Items() do
					entry:WithOuter( exist )
					exist:AddEntry( entry )
				end
			else
				self.classes[v:GetName()] = v
			end
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
		print(v:GetFullName())
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

function meta:GetCallbacks()

	return self.callbacks

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

	for _, v in pairs(self:GetCallbacks()) do
		types[#types+1] = bppintype.New(PN_Func, PNF_None, v)
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

function meta:AddCallback(callback)

	self.callbacks[#self.callbacks+1] = callback

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

function meta:LinkPins( pins, lookup )

	for _, pin in ipairs(pins) do

		if pin.type:GetBaseType() == PN_Func then

			local cb = pin.type:GetSubType()
			if type(cb) == "string" then
				pin.type.subtype = bpcommon.Weak( lookup.callbacks[cb] )
			end

		end

	end

end

function meta:LinkObjects()

	local lookup = { callbacks = {} }
	for _, v in ipairs(self.callbacks) do lookup.callbacks[v:GetName()] = v end

	for k,v in ipairs(self.structs) do

		local maker = v:MakerNodeType()
		local breaker = v:BreakerNodeType()

		self:LinkPins(v.pins:GetTable(), lookup)

	end

	for _, v in ipairs(self.nodeGroups) do

		for _, e in v:GetEntries():Items() do

			self:LinkPins(e:GetRawPins(), lookup)

		end

	end

	for _, v in ipairs(self.callbacks) do

		self:LinkPins(v:GetPins(), lookup)

	end

end

function meta:Serialize(stream)

	self.callbacks = stream:ObjectArray(self.callbacks, self)

	local groupCount = stream:UInt(#self.nodeGroups)
	local structCount = stream:UInt(#self.structs)

	for i=1, groupCount do
		self.nodeGroups[i] = stream:Object( self.nodeGroups[i] or bpnodetypegroup.New(), self, true )
	end

	for i=1, structCount do
		-- This is a dumb out-of-bounds hack, fix later
		self.structs[i] = stream:Object( self.structs[i] or bpstruct.New(), self, true )
		self.structs[i].name = stream:String(self.structs[i].name)
		self.structs[i].pinTypeOverride = stream:Int(self.structs[i].pinTypeOverride or -1)
		if self.structs[i].pinTypeOverride == -1 then self.structs[i].pinTypeOverride = nil end
	end

	self.enums = stream:Value(self.enums)
	self.redirectors = stream:StringMap(self.redirectors)

	if stream:IsReading() then self:PostInit() end

	return stream

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