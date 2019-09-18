AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")

module("bpnodedef", package.seeall, bpcommon.rescope(bpschema))

-- SPECIAL = custom node with any pins you want
-- EVENT = event bound to gmod hook
-- PURE = pure node that doesn't modify state
-- FUNCTION = executable node that does modify state, adds exec pins for execution. 
--            [inputs start at $2, outputs start at #2]

-- pin = { pin direction, pin type, pin name, [pin flags] }
-- # is output pin
-- $ is input pin
-- ^ is jump label
-- ^_ is jump vector
-- #_ is jump vector if exec pin
-- % is node-local variable
-- code = [[]] is lua code to generate
-- jumpSymbols = {} are jump vectors to generate for use in code
-- locals = {} are node-local variables to use in code

NodeTypes = {
	["Think"] = EVENT {
		pins = {
			{ PD_Out, PN_Number, "dt" },
			{ PD_Out, PN_Number, "curTime" },
		},
		code = [[
			#2 = FrameTime() 
			#3 = CurTime()
		]],
	},
	["PlayerTick"] = EVENT {
		pins = {
			{ PD_Out, PN_Player, "player" },
			{ PD_Out, PN_Any, "moveData" },
			{ PD_Out, PN_Number, "dt" },
			{ PD_Out, PN_Number, "curTime" },
		},
		code = [[
			#2 = arg[1] 
			#3 = arg[2] 
			#4 = FrameTime() 
			#5 = CurTime()
		]],
	},
	["PlayerSpawn"] = EVENT {
		pins = {
			{ PD_Out, PN_Player, "player" },
			{ PD_Out, PN_Bool, "transition" },
		},
		code = [[
			#2 = arg[1] 
			#3 = arg[2] 
		]],		
	},
	["PlayerUse"] = EVENT {
		pins = {
			{ PD_Out, PN_Player, "player" },
			{ PD_Out, PN_Entity, "entity" },
		},
		code = [[
			#2 = arg[1] 
			#3 = arg[2] 
		]],		
	},
	["PlayerSay"] = EVENT {
		pins = {
			{ PD_Out, PN_Player, "player" },
			{ PD_Out, PN_String, "text" },
			{ PD_Out, PN_Bool, "teamChat" },
		},
		code = [[
			#2 = arg[1] 
			#3 = arg[2] 
			#4 = arg[3]
		]],		
	},
	["Alive"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_Bool, "isAlive" },
		},
		code = "#1 = Player_.Alive($1)",
	},
	["SetVelocity"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Vector, "velocity" },
		},
		code = "Entity_.SetVelocity($2, $3)",
	},
	["GetVelocity"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_Vector, "velocity" },
		},
		code = "#1 = Entity_.GetVelocity($1)",
	},
	["Crouching"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_Bool, "crouching" },
		},
		code = "#1 = Player_.Crouching($1)",
	},
	["Kill"] = FUNCTION {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_In, PN_Bool, "silent" },
		},
		code = "if $3 then Player_.KillSilent($2) else Player_.Kill($2) end",
	},
	["Remove"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },		
		},
		code = "if not Entity_.IsPlayer($2) then Entity_.Remove($2) end",
	},
	["GetClass"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_String, "classname" },
		},
		code = "#1 = Entity_.GetClass($1)",
	},
	["ChatPrint"] = FUNCTION {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_In, PN_String, "message" },
		},
		code = "Player_.ChatPrint($2, $3)",		
	},
	["ApplyForceCenter"] = FUNCTION {
		pins = {
			{ PD_In, PN_PhysObj, "physObj" },
			{ PD_In, PN_Vector, "force" },
		},
		code = "PhysObj_.ApplyForceCenter($2, $3)",
	},
	["GetRagdollEntity"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_Entity, "ragdoll" },
		},
		code = "#1 = Player_.GetRagdollEntity($1)",
	},
	["GetPhysicsObjectNum"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Number, "id" },
			{ PD_Out, PN_PhysObj, "physObj" },
		},
		code = "#1 = Entity_.GetPhysicsObjectNum($1, $2)",
	},
	["GetPhysicsObject"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_PhysObj, "physObj" },
		},
		code = "#1 = Entity_.GetPhysicsObject($1)",
	},
	["GetAimVector"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_Vector, "aimvector" },
		},
		code = "#1 = Player_.GetAimVector($1)",
	},
	["If"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Bool, "condition" },
			{ PD_Out, PN_Exec, "True" },
			{ PD_Out, PN_Exec, "False" },
		},
		code = "if $2 then #1 end #2",
	},
	["And"] = PURE {
		pins = {
			{ PD_In, PN_Bool, "A" },
			{ PD_In, PN_Bool, "B" },
			{ PD_Out, PN_Bool, "Result" },
		},
		compact = true,
		code = "#1 = $1 and $2"
	},
	["Or"] = PURE {
		pins = {
			{ PD_In, PN_Bool, "A" },
			{ PD_In, PN_Bool, "B" },
			{ PD_Out, PN_Bool, "Result" },
		},
		compact = true,
		code = "#1 = $1 or $2"
	},
	["Not"] = PURE {
		pins = {
			{ PD_In, PN_Bool, "A" },
			{ PD_Out, PN_Bool, "Result" },
		},
		compact = true,
		code = "#1 = not $1"
	},
	["Rand"] = PURE {
		pins = {
			{ PD_In, PN_Number, "Min" },
			{ PD_In, PN_Number, "Max" },
			{ PD_Out, PN_Number, "Result" },
		},
		code = "#1 = math.Rand($1, $2)"
	},
	["ToString"] = PURE {
		pins = {
			{ PD_In, PN_Any, "Any" },
			{ PD_Out, PN_String, "String" },
		},
		code = "#1 = tostring($1)",
		compact = true,
	},
	["Print"] = FUNCTION {
		pins = {
			{ PD_In, PN_String, "String" },
		},
		code = "print($2)",
	},
	["Vector"] = PURE {
		pins = {
			{ PD_In, PN_Number, "x" },
			{ PD_In, PN_Number, "y" },
			{ PD_In, PN_Number, "z" },
			{ PD_Out, PN_Vector, "vector" },
		},
		code = "#1 = Vector($1, $2, $3)",
	},
	--[[["LocalPlayer"] = PURE {
		pins = {
			{ PD_Out, PN_Player, "player" },
		},
		code = "#1 = LocalPlayer()",
	},]]
	["Player"] = PURE {
		pins = {
			{ PD_In, PN_Number, "id" },	
			{ PD_Out, PN_Player, "player" },
		},
		code = "#1 = player.GetAll()[$1]",
	},
	["Number"] = PURE {
		pins = {
			{ PD_In, PN_Number, "num" },
			{ PD_Out, PN_Number, "num" },
		},
		code = "#1 = $1",
	},
	["String"] = PURE {
		pins = {
			{ PD_In, PN_String, "num" },
			{ PD_Out, PN_String, "num" },
		},
		code = "#1 = $1",
	},
	["Sin"] = PURE {
		pins = {
			{ PD_In, PN_Number, "theta" },
			{ PD_Out, PN_Number, "sine" },
		},
		code = "#1 = math.sin($1)",
	},
	["Cos"] = PURE {
		pins = {
			{ PD_In, PN_Number, "theta" },
			{ PD_Out, PN_Number, "cosine" },
		},
		code = "#1 = math.cos($1)",
	},
	["IsValid"] = PURE {
		pins = {
			{ PD_In, PN_Any, "thing" },
			{ PD_Out, PN_Bool, "valid" },
		},
		code = "#1 = IsValid($1)",
	},
	["CurTime"] = PURE {
		pins = {
			{ PD_Out, PN_Number, "curtime" },
		},
		code = "#1 = CurTime()",
	},
	["MultiplyNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		code = "#1 = $1 * $2",
		compact = true,
	},
	["ScaleVector"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "vector" },
			{ PD_In, PN_Number, "scalar" },
			{ PD_Out, PN_Vector, "result" },
		},
		code = "#1 = $1 * $2",
		compact = true,
	},
	["Equal"] = PURE {
		pins = {
			{ PD_In, PN_Any, "vector" },
			{ PD_In, PN_Any, "scalar" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 == $2",
		compact = true,		
	},
	["NotEqual"] = PURE {
		pins = {
			{ PD_In, PN_Any, "vector" },
			{ PD_In, PN_Any, "scalar" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 ~= $2",
		compact = true,		
	},
	["GetPos"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_Vector, "position" },
		},
		code = "#1 = Entity_.GetPos($1)",
	},
	["SetPos"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Vector, "position" },	
		},
		code = "Entity_.SetPos($2, $3)",
	},
	["EntityCreate"] = FUNCTION {
		pins = {
			{ PD_In, PN_String, "classname" },
			{ PD_Out, PN_Entity, "entity" },
		},
		code = "#2 = ents.Create($2)",
	},
	["Spawn"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
		},
		code = "Entity_.Spawn($2)",
	},
	["Fire"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "input" },
			{ PD_In, PN_String, "param" },
			{ PD_In, PN_Number, "delay" },
		},
		code = "Entity_.Fire($2, $3, $4, $5)",
	},
	["SetKeyValue"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "key" },
			{ PD_In, PN_String, "value" },
		},
		code = "Entity_.SetKeyValue($2, $3, $4)",
	},
	["SetParent"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Entity, "parent" },
		},
		code = "Entity_.SetParent($2, $3)",
	},
	["ForEach"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_Out, PN_Exec, "Thru" },
			{ PD_Out, PN_Exec, "Each" },
			{ PD_Out, PN_Any, "key" },
			{ PD_Out, PN_Any, "value" },
		},
		meta = {
			informs = {
				[5] = 2,
				[6] = 2,
			}
		},
		jumpSymbols = {"iter"},
		code = [[
			#3 = nil
			::^iter::
			#3, #4 = next($2, #3)
			if #3 ~= nil then pushjmp(^_iter) ip = #_2 goto jumpto end
			#1
		]],
	},
	["For"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Number, "start" },
			{ PD_In, PN_Number, "end" },
			{ PD_Out, PN_Exec, "Thru" },
			{ PD_Out, PN_Exec, "Each" },
			{ PD_Out, PN_Number, "num" },
		},
		jumpSymbols = {"iter"},
		code = [[
			#3 = $2 - 1
			::^iter::
			if #3 < $3 then #3 = #3 + 1 pushjmp(^_iter) ip = #_2 goto jumpto end
			#1
		]],
	},
	["Delay"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Number, "delay" },
			{ PD_Out, PN_Exec, "Thru" },
		},	
		code = [[
			timer.Simple($2, function() @graph(#_1) end)
			goto popcall
		]],
	},
	["AllPlayers"] = PURE {
		pins = {
			{ PD_Out, PN_Player, "players", PNF_Table },
		},
		code = "#1 = player.GetAll()"
	},
	["AllEntities"] = PURE {
		pins = {
			{ PD_Out, PN_Entity, "entities", PNF_Table },
		},
		code = "#1 = ents.GetAll()"
	},
	["AllEntitiesByClass"] = PURE {
		pins = {
			{ PD_In, PN_String, "classname" },
			{ PD_Out, PN_Entity, "entities", PNF_Table },
		},
		code = "#1 = ents.FindByClass( $1 )"
	}
}
--[[
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Bool, "condition" },
			{ PD_Out, PN_Exec, "True" },
			{ PD_Out, PN_Exec, "False" },
		},
		code = "if $2 then #1 end #2",
]]

--[[local t = {
	["x"] = 1,
	["y"] = 2,
	["z"] = 3,
}

local a, b = next(t, 'x')
print(a, b)]]

for k,v in pairs(NodeTypes) do 
	v.name = k
	v.pinlayout = { inputs = {}, outputs = {} }
	v.pinlookup = {}

	for i, pin in pairs(v.pins) do
		if pin[1] == PD_In then 
			table.insert( v.pinlayout.inputs, i ) v.pinlookup[i] = { v.pinlayout.inputs, #v.pinlayout.inputs, PD_In } 
		elseif pin[1] == PD_Out then 
			table.insert( v.pinlayout.outputs, i ) v.pinlookup[i] = { v.pinlayout.outputs, #v.pinlayout.outputs, PD_Out } 
		end
		pin[4] = pin[4] or PNF_None
		pin.nodeType = v
		pin.id = i
	end

	if v.type == NT_Function and v.code then
		v.code = v.code .. " #1"
	end
end