AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bppin.lua")

module("bpschema", package.seeall)

PD_In = 0
PD_Out = 1

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
PN_Max = 12

NT_Pure = 0
NT_Function = 1
NT_Event = 2
NT_Special = 3
NT_FuncInput = 4
NT_FuncOutput = 5

PNF_None = 0
PNF_Table = 1
PNF_Nullable = 2
PNF_Bitfield = 4
PNF_All = 7

NTF_None = 0
NTF_Deprecated = 1
NTF_NotHook = 2
NTF_Latent = 4
NTF_Protected = 8
NTF_Compact = 16
NTF_Returns = 32

GT_Event = 0
GT_Function = 1

MT_Library = 0
MT_Game = 1
MT_Entity = 2
MT_Weapon = 3
MT_NPC = 4

RM_None = 0
RM_Replicated = 1
RM_RepNotify = 2

ROLE_Server = 0
ROLE_Client = 1
ROLE_Shared = 2

NodeTypeColors = {
	[NT_Pure] = Color(60,150,60),
	[NT_Function] = Color(60,80,150),
	[NT_Event] = Color(150,20,20),
	[NT_Special] = Color(100,100,100),
	[NT_FuncInput] = Color(120,100,250),
	[NT_FuncOutput] = Color(120,100,250),
}

GraphTypeNames = {
	[GT_Event] = "EventGraph",
	[GT_Function] = "Function",
}

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
}

GraphTypeColors = {
	[GT_Event] = Color(120,80,80),
	[GT_Function] = Color(60,80,150),
}

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
}

NodePinImplicitConversions = {
	[PN_Enum] = { PN_Number },
	[PN_Number] = { PN_Enum, PN_String },
}

NodeLiteralTypes = {
	[PN_Bool] = "bool",
	[PN_Number] = "number",
	[PN_String] = "string",
	[PN_Enum] = "enum",
}

Defaults = {
	[PN_Bool] = "false",
	[PN_Vector] = "Vector()",
	[PN_Angles] = "Angle()",
	[PN_Number] = "0",
	[PN_String] = "",
	[PN_Enum] = "0",
	[PN_Ref] = "nil",
	[PN_Func] = "nil",
}

function IsPinType(v)
	return type(v) == "table"
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

function ConfigureNodeType(t)

	if t.type == NT_Function then
		table.insert(t.pins, 1, MakePin( PD_Out, "Thru", PN_Exec ))
		table.insert(t.pins, 1, MakePin( PD_In, "Exec", PN_Exec ))
	elseif t.type == NT_Event then
		table.insert(t.pins, 1, MakePin( PD_Out, "Exec", PN_Exec ))
	end

end

function PinRetArg( nodeType, infmt, outfmt, concat )

	concat = concat or ","
	--print(nodeType.name)
	local base = (nodeType.type == NT_Event) and 2 or 1
	local pins = {[PD_In] = {}, [PD_Out] = {}}
	for k,v in pairs(nodeType.pins) do
		local dir = v:GetDir()
		local num = (base+#pins[dir])
		local s = (dir == PD_In and "$" or "#") .. num
		if infmt and dir == PD_In then s = infmt(s, v, num) end
		if outfmt and dir == PD_Out then s = outfmt(s, v, num) end
		table.insert(pins[dir], s)
	end

	local ret = table.concat(pins[PD_Out], concat)
	local arg = table.concat(pins[PD_In], concat)
	return ret, arg, pins

end

function PURE(t) 
	t.pins = t.pins or {}
	t.type = NT_Pure
	ConfigureNodeType(t)
	return t 
end

function FUNCTION(t) 
	t.pins = t.pins or {}
	t.type = NT_Function
	ConfigureNodeType(t)
	return t
end

function EVENT(t)
	t.pins = t.pins or {}
	t.type = NT_Event
	ConfigureNodeType(t)
	return t 
end

function SPECIAL(t)
	t.pins = t.pins or {}
	t.type = NT_Special
	ConfigureNodeType(t)
	return t
end

function FUNC_INPUT(t)
	t.pins = t.pins or {}
	t.type = NT_FuncInput
	t.hidden = true
	ConfigureNodeType(t)
	return t
end

function FUNC_OUTPUT(t)
	t.pins = t.pins or {}
	t.type = NT_FuncOutput
	ConfigureNodeType(t)
	return t
end

function FindMatchingPin(ntype, pf)
	local m = ntype.meta
	local informs = m and m.informs or nil
	local ignoreNullable = bit.band( PNF_All, bit.bnot( PNF_Nullable ) )
	for id, pin in pairs(ntype.pins) do
		local sameType = pin:GetType():Equal(pf:GetType(), 0)
		local sameFlags = pin:GetFlags(ignoreNullable) == pf:GetFlags(ignoreNullable)
		local tableMatch = informs ~= nil and #informs > 0 and pin:HasFlag(PNF_Table) and pf:HasFlag(PNF_Table) and pin:IsType(PN_Any)
		if pin:GetDir() ~= pf:GetDir() and ntype.name == "Pin" or ((sameType and sameFlags) or tableMatch) then return id end
	end
end