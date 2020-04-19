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
NTF_FallThrough = 2048

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
	[PN_Color] = "Color(255,255,255)",
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
	[PN_Ref] = "Ref",
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
	[PN_Enum] = "enum",
}

-- Determines if value is, or can be use like a bppintype
function IsPinType(v)
	return isbppin(v) or isbppintype(v)
end

-- Wrapper for PinValueTypes
function GetPinValueTypeClass(pintype)

	local class = PinValueTypes[ pintype:GetBaseType() ]
	return class

end

-- Helper function for creaing pins
function MakePin(dir, name, pintype, flags, ex, desc)
	local istype = type(pintype) == "table"
	return bppin.New(
		dir,
		name,
		istype and pintype or bppintype.New(pintype, flags, ex),
		desc
	)
end