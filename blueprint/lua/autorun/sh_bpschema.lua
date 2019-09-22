AddCSLuaFile()

include("sh_bpcommon.lua")

module("bpschema", package.seeall)

PD_In = 0
PD_Out = 1

PN_Exec = 0
PN_Bool = 1
PN_Vector = 2
PN_Number = 3
PN_PhysObj = 4
PN_Player = 5
PN_Entity = 6
PN_Npc = 7
PN_Vehicle = 8
PN_Any = 9
PN_String = 10
PN_Color = 11

NT_Pure = 0
NT_Function = 1
NT_Event = 2
NT_Special = 3

PNF_None = 0
PNF_Table = 1
PNF_Nullable = 2

NodeTypeColors = {
	[NT_Pure] = Color(60,150,60),
	[NT_Function] = Color(60,80,150),
	[NT_Event] = Color(150,20,20),
	[NT_Special] = Color(100,100,100),
}

NodePinColors = {
	[PN_Exec] = Color(255,255,255),
	[PN_Bool] = Color(255,80,80),
	[PN_Vector] = Color(255,128,10),
	[PN_Number] = Color(80,100,255),
	[PN_PhysObj] = Color(80,255,255),
	[PN_Player] = Color(255,100,255),
	[PN_Entity] = Color(80,255,80),
	[PN_Npc] = Color(255,50,50),
	[PN_Vehicle] = Color(50,127,255),
	[PN_Any] = Color(100,100,100),
	[PN_String] = Color(255,255,100),
	[PN_Color] = Color(140,50,200),
}

NodePinImplicitConversions = {
	[PN_Entity] = { PN_Player },
	[PN_Player] = { PN_Entity },
	[PN_Npc] = { PN_Entity },
	[PN_Vehicle] = { PN_Entity },
}

NodeLiteralTypes = {
	[PN_Bool] = "bool",
	[PN_Number] = "number",
	[PN_String] = "string",
}

Defaults = {
	[PN_Bool] = "false",
	[PN_Vector] = "Vector()",
	[PN_Number] = "0",
	[PN_PhysObj] = "nil",
	[PN_Player] = "nil",
	[PN_Entity] = "nil",
	[PN_String] = "",
}

function PURE(t) 
	t.pins = t.pins or {}
	t.type = NT_Pure
	return t 
end

function FUNCTION(t) 
	t.pins = t.pins or {}
	t.type = NT_Function
	table.insert(t.pins, 1, { PD_Out, PN_Exec, "Thru" })
	table.insert(t.pins, 1, { PD_In, PN_Exec, "Exec" })
	return t
end

function EVENT(t)
	t.pins = t.pins or {}
	t.type = NT_Event
	table.insert(t.pins, 1, { PD_Out, PN_Exec, "Exec" }) 
	return t 
end

function SPECIAL(t)
	t.pins = t.pins or {}
	t.type = NT_Special
	return t
end