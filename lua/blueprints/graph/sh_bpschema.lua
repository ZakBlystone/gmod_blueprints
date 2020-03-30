AddCSLuaFile()

module("bpschema", package.seeall)

-- Pin directions
PD_None = -1
PD_In = 0
PD_Out = 1

-- Pin types
PN_Exec = 0
PN_Bool = 1
PN_Vector = 2
PN_Number = 3
PN_Any = 4
PN_String = 5
PN_Color = 6
PN_Angles = 7
PN_Enum = 8
PN_Ref = 9
PN_Struct = 10
PN_Func = 11
PN_Dummy = 12
PN_BPRef = 13
PN_BPClass = 14
PN_Asset = 15
PN_Max = 16

-- Core node types
NT_Pure = 0
NT_Function = 1
NT_Event = 2
NT_Special = 3
NT_FuncInput = 4
NT_FuncOutput = 5

-- Pin flags
PNF_None = 0
PNF_Table = 1
PNF_Nullable = 2
PNF_Bitfield = 4
PNF_Custom = 8
PNF_All = 15

-- Nodetype flags
NTF_None = 0
NTF_Deprecated = 1
NTF_NotHook = 2
NTF_Latent = 4
NTF_Protected = 8
NTF_Compact = 16
NTF_Custom = 32
NTF_NoDelete = 64
NTF_Collapse = 128
NTF_HidePinNames = 256
NTF_Experimental = 512
NTF_DirectCall = 1024

-- Graph types
GT_Event = 0
GT_Function = 1

-- Node roles
ROLE_Shared = 0
ROLE_Server = 1
ROLE_Client = 2

-- Node header colors
NodeTypeColors = {
	[NT_Pure] = Color(60,150,60),
	[NT_Function] = Color(60,80,150),
	[NT_Event] = Color(150,20,20),
	[NT_Special] = Color(100,100,100),
	[NT_FuncInput] = Color(120,100,250),
	[NT_FuncOutput] = Color(120,100,250),
}

-- Pin type names
PinTypeNames = {
	[PN_Exec] = "Exec",
	[PN_Bool] = "Boolean",
	[PN_Vector] = "Vector",
	[PN_Number] = "Number",
	[PN_Any] = "Any",
	[PN_String] = "String",
	[PN_Color] = "Color",
	[PN_Angles] = "Angles",
	[PN_Enum] = "Enum",
	[PN_Ref] = "Ref",
	[PN_Struct] = "Struct",
	[PN_Func] = "Function",
	[PN_Dummy] = "Dummy",
	[PN_BPRef] = "BPRef",
	[PN_BPClass] = "BPClass",
	[PN_Asset] = "Asset",
}

-- Colors the graph entries in the sidebar
GraphTypeColors = {
	[GT_Event] = Color(120,80,80),
	[GT_Function] = Color(60,80,150),
}

-- Pin colors in the graph editor
NodePinColors = {
	[PN_Exec] = Color(255,255,255),
	[PN_Bool] = Color(255,80,80),
	[PN_Vector] = Color(255,128,10),
	[PN_Number] = Color(80,100,255),
	[PN_Any] = Color(100,100,100),
	[PN_String] = Color(250,170,150),
	[PN_Color] = Color(140,50,200),
	[PN_Angles] = Color(80,150,180),
	[PN_Enum] = Color(0,100,80),
	[PN_Ref] = Color(0,180,255),
	[PN_Struct] = Color(40,80,255),
	[PN_Func] = Color(127,127,127),
	[PN_Dummy] = Color(0,0,0),
	[PN_BPRef] = Color(150,200,100),
	[PN_BPClass] = Color(180,80,255),
	[PN_Asset] = Color(255,210,120),
}

-- Equivalent Lua type for pin
NodeLiteralTypes = {
	[PN_Bool] = "bool",
	[PN_Number] = "number",
	[PN_String] = "string",
	[PN_Enum] = "enum",
	[PN_Asset] = "string",
	--[PN_Vector] = "vector",
}

-- Pin default values when compiled
Defaults = {
	[PN_Bool] = "false",
	[PN_Vector] = "Vector()",
	[PN_Angles] = "Angle()",
	[PN_Color] = "Color()",
	[PN_Number] = "0",
	[PN_String] = "",
	[PN_Enum] = "0",
	[PN_Ref] = "nil",
	[PN_Func] = "nil",
	[PN_BPRef] = "nil",
	[PN_BPClass] = "nil",
	[PN_Asset] = "",
}

-- Pin class to instantiate when pin is created
PinTypeClasses = {
	[PN_Bool] = "Boolean",
	[PN_Number] = "Number",
	[PN_String] = "String",
	[PN_Enum] = "Enum",
	[PN_Vector] = "Vector",
	[PN_Color] = "Color",
	[PN_Angles] = "Angle",
	[PN_Any] = "Wild",
	[PN_BPClass] = "Class",
	[PN_Asset] = "Asset",
}

-- Valuetype class to use for pin
PinValueTypes = {
	[PN_Bool] = "boolean",
	[PN_Number] = "number",
	[PN_String] = "string",
	[PN_Vector] = "vector",
	[PN_Color] = "color",
	[PN_Angles] = "angles",
	[PN_Struct] = "struct",
	[PN_Asset] = "asset",
}

PinType = bppintype.New

-- Determines if value is, or can be use like a bppintype
function IsPinType(v)
	return isbppin(v) or isbppintype(v)
end

-- Wrapper for PinValueTypes
function GetPinValueTypeClass(pintype)

	local class = PinValueTypes[ pintype:GetBaseType() ]
	return class

end

NodePinNetworkThunks = {}

function AddNetworkThunk(pinType, read, write)

	NodePinNetworkThunks[#NodePinNetworkThunks+1] = {
		read = read,
		write = write,
		pinType = pinType,
	}

end

function GetNetworkThunk(pinType, mask)

	mask = mask or 0
	for _, v in ipairs(NodePinNetworkThunks) do
		if v.pinType:Equal(pinType, mask) then return v end
	end
	return nil

end

NodePinImplicitCasts = {}

function AddPinCast(from, to, bidirectional, wrapper, ignoreSub)

	local castInfo = nil
	for _, info in ipairs(NodePinImplicitCasts) do
		if info.from == from then castInfo = info break end
	end
	if castInfo == nil then castInfo = NodePinImplicitCasts[table.insert(NodePinImplicitCasts, { from = from, to = {} })] end

	local function Add( type )
		castInfo.to[#castInfo.to+1] = {
			type = type,
			bidir = bidirectional,
			wrapper = wrapper,
			ignoreSub = ignoreSub,
		}
	end

	if type(to) == "table" and not IsPinType(to) then
		for _, v in ipairs(to) do Add(v) end
	elseif IsPinType(to) then
		Add(to)
	end

end

AddPinCast(PinType(PN_Number), { PinType(PN_Enum) }, true, nil, true )
AddPinCast(PinType(PN_Number), { PinType(PN_String) } )
AddPinCast(PinType(PN_Ref, PNF_None, "Entity"), { 
	PinType(PN_Ref, PNF_None, "Player"),
	PinType(PN_Ref, PNF_None, "Weapon"),
	PinType(PN_Ref, PNF_None, "NPC"),
	PinType(PN_Ref, PNF_None, "Vehicle"),
}, true)
AddPinCast(PinType(PN_String), { PinType(PN_Asset) }, true, nil, true )

AddNetworkThunk(PinType(PN_Bool), "net.ReadBool()", "net.WriteBool(@)")
AddNetworkThunk(PinType(PN_Vector), "net.ReadVector()", "net.WriteVector(@)")
AddNetworkThunk(PinType(PN_Number), "net.ReadFloat()", "net.WriteFloat(@)")
AddNetworkThunk(PinType(PN_String), "net.ReadString()", "net.WriteString(@)")
AddNetworkThunk(PinType(PN_Color), "net.ReadColor()", "net.WriteColor(Color(@.r, @.g, @.b, @.a))") --some functions don't make a proper color table
AddNetworkThunk(PinType(PN_Angles), "net.ReadAngle()", "net.WriteAngle(@)")
AddNetworkThunk(PinType(PN_Enum), "net.ReadUInt(24)", "net.WriteUInt(@, 24)")
AddNetworkThunk(PinType(PN_Ref, PNF_None, "Player"), "net.ReadEntity()", "net.WriteEntity(@)")
AddNetworkThunk(PinType(PN_Ref, PNF_None, "Entity"), "net.ReadEntity()", "net.WriteEntity(@)")
AddNetworkThunk(PinType(PN_Ref, PNF_None, "Weapon"), "net.ReadEntity()", "net.WriteEntity(@)")
AddNetworkThunk(PinType(PN_Ref, PNF_None, "NPC"), "net.ReadEntity()", "net.WriteEntity(@)")
AddNetworkThunk(PinType(PN_Ref, PNF_None, "Vehicle"), "net.ReadEntity()", "net.WriteEntity(@)")
AddNetworkThunk(PinType(PN_Ref, PNF_None, "VMatrix"), "net.ReadMatrix()", "net.WriteMatrix(@)")
--[[
AddPinCast(PinType(PN_Vector), PinType(PN_String), false, "tostring(@)")
AddPinCast(PinType(PN_Bool), PinType(PN_String), false, "tostring(@)")
AddPinCast(PinType(PN_Ref, PNF_None, "Entity"), PinType(PN_String), false, "tostring(@)")
AddPinCast(PinType(PN_Ref, PNF_None, "Weapon"), PinType(PN_String), false, "tostring(@)")
AddPinCast(PinType(PN_Ref, PNF_None, "NPC"), PinType(PN_String), false, "tostring(@)")
AddPinCast(PinType(PN_Ref, PNF_None, "Vehicle"), PinType(PN_String), false, "tostring(@)")
]]

function CanCast(outPinType, inPinType)

	for _, castInfo in ipairs(NodePinImplicitCasts) do
		if castInfo.from:Equal( outPinType, PNF_Table ) then
			for _, entry in ipairs(castInfo.to) do
				if entry.type:Equal( inPinType, PNF_Table, entry.ignoreSub ) then
					return true, entry.wrapper
				end
			end
		elseif castInfo.from:Equal( inPinType, PNF_Table ) then
			for _, entry in ipairs(castInfo.to) do
				if entry.bidir and entry.type:Equal( outPinType, PNF_Table, entry.ignoreSub ) then
					return true, entry.wrapper
				end
			end
		end
	end

	return false

end

function MakePin(dir, name, pintype, flags, ex, desc)
	local istype = type(pintype) == "table"
	return bppin.New(
		dir,
		name,
		istype and pintype or bppintype.New(pintype, flags, ex),
		desc
	)
end

function FindMatchingPin(ntype, pf, module, cache)

	assert(module ~= nil)

	local informs = ntype:GetInforms()
	local ignoreNullable = bit.band( PNF_All, bit.bnot( PNF_Nullable ) )

	local nodeClass = ntype:GetNodeClass()
	if nodeClass ~= nil then
		--local outer = ntype:GetOuter()
		--local outerName = outer and bpcommon.GetMetaTableName( getmetatable(outer) ) or "no-outer"
		--print("FIND MATCHING PIN CLASS " .. nodeClass .. " WITHIN MODULE: " .. module:GetName())
		--print("  NODE TYPE OUTER: " .. outerName)
		--print("  GRAPH THUNK: " .. tostring(ntype:GetGraphThunk()))
		local node = bpnode.New(ntype):WithOuter( module )
		node:PostInit()
		pins = node:GetPins()
	else
		pins = ntype:GetPins()
	end

	if cache and cache[ntype] ~= nil then
		local id = cache[ntype]
		if id == -1 then return end
		return id, pins[id]
	end

	local inType = nil
	local outType = nil
	local fdir = pf:GetDir()

	if fdir == PD_In then inType = pf end
	if fdir == PD_Out then outType = pf end

	for id, pin in ipairs(pins) do

		if pin:GetDir() ~= fdir then

			if fdir == PD_In then outType = pin:GetType() else inType = pin:GetType() end

			local sameType = inType:Equal(outType, 0)
			local sameFlags = inType:GetFlags(ignoreNullable) == outType:GetFlags(ignoreNullable)
			local tableMatch = informs ~= nil and #informs > 0 and pin:HasFlag(PNF_Table) and pf:HasFlag(PNF_Table) and pin:IsType(PN_Any)
			local anyMatch = informs ~= nil and #informs > 0 and not pin:HasFlag(PNF_Table) and not pf:HasFlag(PNF_Table) and pin:GetBaseType() ~= PN_Exec
			local typeFlagTableMatch = ((sameType and sameFlags) or tableMatch or anyMatch)
			local castMatch = sameType
			if not castMatch then

				if cache then
					local outH = outType:GetHash()
					local inH = inType:GetHash()
					cache[outH] = cache[outH] or {}
					if cache[outH][inH] ~= nil then 
						castMatch = cache[outH][inH]
					else
						castMatch = module:CanCast(outType, inType)
						cache[outH][inH] = castMatch
					end
				else
					castMatch = module:CanCast(outType, inType)
				end

			end

			if (ntype:GetName() == "CORE_Pin" or typeFlagTableMatch or castMatch) then
				if cache then cache[ntype] = id end
				return id, pin
			end

		end

	end

	if cache then cache[ntype] = -1 end

end