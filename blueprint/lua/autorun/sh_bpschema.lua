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
PN_Weapon = 12
PN_Angles = 13
PN_Enum = 14
PN_Ref = 15
PN_Struct = 16
PN_Max = 16

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

GT_Event = 0
GT_Function = 1

MT_Library = 0
MT_Game = 1
MT_Entity = 2
MT_Weapon = 3
MT_NPC = 4

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
	[PN_PhysObj] = "Physics Object",
	[PN_Player] = "Player",
	[PN_Entity] = "Entity",
	[PN_Npc] = "NPC",
	[PN_Vehicle] = "Vehicle",
	[PN_Any] = "Any",
	[PN_String] = "String",
	[PN_Color] = "Color",
	[PN_Weapon] = "Weapon",
	[PN_Angles] = "Angles",
	[PN_Enum] = "Enum",
	[PN_Ref] = "Ref",
	[PN_Struct] = "Struct",
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
	[PN_PhysObj] = Color(80,255,255),
	[PN_Player] = Color(255,100,255),
	[PN_Entity] = Color(80,255,80),
	[PN_Npc] = Color(255,50,50),
	[PN_Vehicle] = Color(50,127,255),
	[PN_Any] = Color(100,100,100),
	[PN_String] = Color(250,170,150),
	[PN_Color] = Color(140,50,200),
	[PN_Weapon] = Color(180,255,100),
	[PN_Angles] = Color(80,150,180),
	[PN_Enum] = Color(0,100,80),
	[PN_Ref] = Color(0,180,255),
	[PN_Struct] = Color(40,80,255),
}

NodePinImplicitConversions = {
	[PN_Entity] = { PN_Player, { PN_Ref, "Entity" } },
	[PN_Player] = { PN_Entity, { PN_Ref, "Player" } },
	[PN_Weapon] = { PN_Entity },
	[PN_Npc] = { PN_Entity },
	[PN_Vehicle] = { PN_Entity },
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
	[PN_Number] = "0",
	[PN_PhysObj] = "nil",
	[PN_Player] = "nil",
	[PN_Entity] = "nil",
	[PN_String] = "",
	[PN_Enum] = "0",
	[PN_Ref] = "nil",
}

function ConfigureNodeType(t)

	if t.type == NT_Function then
		table.insert(t.pins, 1, { PD_Out, PN_Exec, "Thru" })
		table.insert(t.pins, 1, { PD_In, PN_Exec, "Exec" })
	elseif t.type == NT_Event then
		table.insert(t.pins, 1, { PD_Out, PN_Exec, "Exec" })
	end

	t.pinlayout = { inputs = {}, outputs = {} }
	t.pinlookup = {}

	for i, pin in pairs(t.pins) do
		if pin[1] == PD_In then 
			table.insert( t.pinlayout.inputs, i ) t.pinlookup[i] = { t.pinlayout.inputs, #t.pinlayout.inputs, PD_In } 
		elseif pin[1] == PD_Out then 
			table.insert( t.pinlayout.outputs, i ) t.pinlookup[i] = { t.pinlayout.outputs, #t.pinlayout.outputs, PD_Out } 
		end
		pin[4] = pin[4] or PNF_None
		pin.id = i
	end

	if t.type == NT_Function and t.code then
		t.code = t.code .. " #1"
	end
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