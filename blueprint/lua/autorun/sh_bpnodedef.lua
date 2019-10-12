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
-- !node is the node's id
-- !graph is the graph's id
-- @graph is the graph's entry function
-- # is output pin
-- #_ is output exec pin's target jump
-- $ is input pin
-- ^ is jump label
-- ^_ is jump vector
-- #_ is jump vector if exec pin
-- % is node-local variable
-- code = [[]] is lua code to generate
-- jumpSymbols = {} are jump vectors to generate for use in code
-- locals = {} are node-local variables to use in code

NodeTypes = {
	["Init"] = EVENT {
		pins = {},
		code = [[]]
	},
	["Pin"] = PURE {
		pins = { 
			{ PD_In, PN_Any, "" },
			{ PD_Out, PN_Any, "" },
		},
		meta = {
			informs = {1,2}
		},
		code = "#1 = $1",
		compact = true,
	},
	["Think"] = EVENT {
		pins = {
			{ PD_Out, PN_Number, "dt" },
			{ PD_Out, PN_Number, "curTime" },
		},
		hook = "Think",
		code = [[
			#2 = FrameTime() 
			#3 = CurTime()
		]],
	},
	["EntityFireBullets"] = EVENT {
		pins = {
			{ PD_Out, PN_Entity, "entity" },
			{ PD_Out, PN_Entity, "attacker" },
			{ PD_Out, PN_Number, "damage" },
			{ PD_Out, PN_Number, "count" },
			{ PD_Out, PN_Vector, "source" },
			{ PD_Out, PN_Vector, "direction" },
		},
		hook = "EntityFireBullets",
		code = [[
			#2 = arg[1]
			#3 = arg[2].Attacker
			#4 = arg[2].Damage
			#5 = arg[2].Num
			#6 = arg[2].Src
			#7 = arg[2].Dir
		]],
	},
	["EntityEmitSound"] = EVENT {
		pins = {
			{ PD_Out, PN_Entity, "entity" },
			{ PD_Out, PN_String, "soundname" },
			{ PD_Out, PN_String, "originalSound" },
		},
		hook = "EntityEmitSound",
		code = [[
			#2 = arg[1].Entity
			#3 = arg[1].SoundName
			#4 = arg[1].OriginalSoundName
		]],
	},
	["Alive"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_Bool, "isAlive" },
		},
		code = "#1 = Player_.Alive($1)",
	},
	["PlayerGetWeapon"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_In, PN_String, "classname"},
			{ PD_Out, PN_Weapon, "weapon" },
		},
		code = "#1 = Player_.GetWeapon($1, $2)",		
	},
	["PlayerGetActiveWeapon"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_Weapon, "weapon" },
		},
		code = "#1 = Player_.GetActiveWeapon($1)",
	},
	["PlayerName"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_String, "name" },
		},
		code = "#1 = Player_.Nick($1)",
	},
	["FireBullets"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Vector, "spread", PNF_Nullable },
			{ PD_In, PN_Vector, "source" },
			{ PD_In, PN_Vector, "dir" },
			{ PD_In, PN_Number, "num" },
			{ PD_In, PN_Number, "damage" },
		},
		code = "Entity_.FireBullets($2, { Spread = $3, Src = $4, Dir = $5, Num = $6, Damage = $7 })",
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
	["GetGroundEntity"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_Entity, "groundEntity" },
		},
		code = "#1 = Entity_.GetGroundEntity($1)",
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
	["EmitSound"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "target" },
			{ PD_In, PN_String, "sound" },
			{ PD_In, PN_Number, "soundLevel" },
			{ PD_In, PN_Number, "pitch" },
			{ PD_In, PN_Number, "volume" },
		},
		defaults = {
			[4] = 75,
			[5] = 100,
			[6] = 1,
		},
		code = "Entity_.EmitSound( $2, $3, $4, $5, $6 )",
	},
	["TakeDamage"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "target" },
			{ PD_In, PN_Number, "damage" },
			{ PD_In, PN_Entity, "attacker", PNF_Nullable },
			{ PD_In, PN_Entity, "inflictor", PNF_Nullable },
		},
		code = "Entity_.TakeDamage($2, $3, $4, $5)",
	},
	["RemoveAllItems"] = FUNCTION {
		pins = {
			{ PD_In, PN_Player, "player" },
		},
		code = "Player_.RemoveAllItems($2)",
	},
	["RemoveAllAmmo"] = FUNCTION {
		pins = {
			{ PD_In, PN_Player, "player" },
		},
		code = "Player_.RemoveAllAmmo($2)",
	},
	["Remove"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },		
		},
		code = "if not $2:IsPlayer($2) then Entity_.Remove($2) end", -- safe check here
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
	["ChatPrintAll"] = FUNCTION {
		pins = {
			{ PD_In, PN_String, "message" },
		},
		code = "for _, pl in pairs(player.GetAll()) do Player_.ChatPrint(pl, $2) end",
	},
	["Wake"] = FUNCTION {
		pins = {
			{ PD_In, PN_PhysObj, "physObj" },
		},
		code = "PhysObj_.Wake($2)",
	},
	["ApplyForceCenter"] = FUNCTION {
		pins = {
			{ PD_In, PN_PhysObj, "physObj" },
			{ PD_In, PN_Vector, "force" },
		},
		code = "PhysObj_.ApplyForceCenter($2, $3)",
	},
	["ApplyTorqueCenter"] = FUNCTION {
		pins = {
			{ PD_In, PN_PhysObj, "physObj" },
			{ PD_In, PN_Vector, "force" },
		},
		code = "PhysObj_.ApplyTorqueCenter($2, $3)",
	},
	["SetMass"] = FUNCTION {
		pins = {
			{ PD_In, PN_PhysObj, "physObj" },
			{ PD_In, PN_Number, "mass" },
		},
		code = "PhysObj_.SetMass($2, $3)",
	},
	["EnableMotion"] = FUNCTION {
		pins = {
			{ PD_In, PN_PhysObj, "physObj" },
			{ PD_In, PN_Bool, "enabled" },
		},
		code = "PhysObj_.EnableMotion($2, $3)",
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
	["GetShootPos"] = PURE {
		pins = {
			{ PD_In, PN_Player, "player" },
			{ PD_Out, PN_Vector, "pos" },
		},
		code = "#1 = Player_.GetShootPos($1)",
	},
	["CreateRagdoll"] = FUNCTION {
		pins = {
			{ PD_In, PN_Player, "player" },
		},
		code = "Player_.CreateRagdoll($2)",
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
		code = "#1 = math.Rand($1, $2)",
	},
	["RandInt"] = PURE {
		pins = {
			{ PD_In, PN_Number, "Min" },
			{ PD_In, PN_Number, "Max" },
			{ PD_Out, PN_Number, "Result" },
		},
		code = "#1 = math.random($1, $2)",
	},
	["Floor"] = PURE {
		pins = {
			{ PD_In, PN_Number, "in" },
			{ PD_Out, PN_Number, "out" },
		},
		code = "#1 = math.floor($1)",
		compact = true,
	},
	["Ceil"] = PURE {
		pins = {
			{ PD_In, PN_Number, "in" },
			{ PD_Out, PN_Number, "out" },
		},
		code = "#1 = math.ceil($1)",
		compact = true,
	},
	["Round"] = PURE {
		pins = {
			{ PD_In, PN_Number, "in" },
			{ PD_Out, PN_Number, "out" },
		},
		code = "#1 = math.Round($1)",
		compact = true,
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
	["Color"] = PURE {
		pins = {
			{ PD_In, PN_Number, "r" },
			{ PD_In, PN_Number, "g" },
			{ PD_In, PN_Number, "b" },
			{ PD_In, PN_Number, "a" },
			{ PD_Out, PN_Color, "color" },
		},
		code = "#1 = Color($1, $2, $3, $4)",
	},
	["BreakColor"] = PURE {
		pins = {
			{ PD_In, PN_Color, "color" },
			{ PD_Out, PN_Number, "r" },
			{ PD_Out, PN_Number, "g" },
			{ PD_Out, PN_Number, "b" },
			{ PD_Out, PN_Number, "a" },
		},
		code = "#1, #2, #3, #4 = $1.r, $1.g, $1.b, $1.a",
	},
	["Angles"] = PURE {
		pins = {
			{ PD_In, PN_Number, "p" },
			{ PD_In, PN_Number, "y" },
			{ PD_In, PN_Number, "r" },
			{ PD_Out, PN_Angles, "angles" },			
		},
		code = "#1 = Angle($1, $2, $3)",
	},
	["RotateAroundAxis"] = FUNCTION {
		pins = {
			{ PD_In, PN_Angles, "angles" },
			{ PD_In, PN_Vector, "axis" },
			{ PD_In, PN_Number, "rotation" },
		},
		code = "$2:RotateAroundAxis($3, $4)",
		compact = false,
	},
	["VectorToAngle"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "vector" },
			{ PD_Out, PN_Angles, "angles" },
		},
		code = "#1 = $1:Angle()",
		compact = true,
	},
	["AngleVectors"] = PURE {
		pins = {
			{ PD_In, PN_Angles, "angles" },
			{ PD_Out, PN_Vector, "forward" },
			{ PD_Out, PN_Vector, "right" },
			{ PD_Out, PN_Vector, "up" },
		},
		code = "$2 = $1:Forward() $3 = $1:Right() $4 = $1:Up()",
		compact = false,
	},
	["BreakAngles"] = PURE {
		pins = {
			{ PD_In, PN_Angles, "angles" },
			{ PD_Out, PN_Number, "p" },
			{ PD_Out, PN_Number, "y" },
			{ PD_Out, PN_Number, "r" },
		},
		code = "#1, #2, #3 = $1.p, $1.y, $1.r",
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
	["VectorNormalize"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "vector" },
			{ PD_Out, PN_Vector, "normal" },
		},
		code = "#1 = $1:GetNormal()",
		compact = true,
	},
	["BreakVector"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "vector" },
			{ PD_Out, PN_Number, "x" },
			{ PD_Out, PN_Number, "y" },
			{ PD_Out, PN_Number, "z" },
		},
		code = "#1, #2, #3 = $1.x, $1.y, $1.z",
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
	["Entity"] = PURE {
		pins = {
			{ PD_In, PN_Number, "id" },	
			{ PD_Out, PN_Entity, "entity" },
		},
		code = "#1 = Entity($1)",
	},
	["EntIndex"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },	
			{ PD_Out, PN_Number, "id" },
		},
		code = "#1 = Entity_.EntIndex($1)",
	},
	["ToNumber"] = PURE {
		pins = {
			{ PD_In, PN_String, "value" },	
			{ PD_Out, PN_Number, "number" },			
		},
		code = "#1 = tonumber($1) or 0",
	},
	["Number"] = PURE {
		pins = {
			{ PD_In, PN_Number, "num" },
			{ PD_Out, PN_Number, "num" },
		},
		code = "#1 = $1",
	},
	["LessThan"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 < $2",
		compact = true,
	},
	["LessThanEqual"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 <= $2",
		compact = true,
	},
	["GreaterThan"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 > $2",
		compact = true,
	},
	["GreaterThanEqual"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 >= $2",
		compact = true,
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
		code = "#1 = __bpm.genericIsValid($1)",
	},
	["CheckValid"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Any, "thing" },
			{ PD_Out, PN_Exec, "valid" },
			{ PD_Out, PN_Exec, "notvalid" },
		},
		code = "if __bpm.genericIsValid($2) then #1 else #2 end",
	},
	["IsPlayer"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_Bool, "isPlayer" },
		},
		code = "#1 = $1:IsPlayer()", -- not great
	},
	["CurTime"] = PURE {
		pins = {
			{ PD_Out, PN_Number, "curtime" },
		},
		code = "#1 = CurTime()",
		compact = true,
	},
	["FrameTime"] = PURE {
		pins = {
			{ PD_Out, PN_Number, "frametime" },
		},
		code = "#1 = FrameTime()",
		compact = true,
	},
	["DivideNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		code = "#1 = $1 / $2",
		compact = true,
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
	["AddNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		code = "#1 = $1 + $2",
		compact = true,
	},
	["SubNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		code = "#1 = $1 - $2",
		compact = true,
	},
	["AddVector"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "vector" },
			{ PD_In, PN_Vector, "vector" },
			{ PD_Out, PN_Vector, "result" },
		},
		code = "#1 = $1 + $2",
		compact = true,
	},
	["SubVector"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "vector" },
			{ PD_In, PN_Vector, "vector" },
			{ PD_Out, PN_Vector, "result" },
		},
		code = "#1 = $1 - $2",
		compact = true,
	},
	["VectorLength"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "vector" },
			{ PD_Out, PN_Number, "result" },
		},
		code = "#1 = $1:Length()",
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
			{ PD_In, PN_Any, "a" },
			{ PD_In, PN_Any, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		meta = {
			informs = {1, 2}
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
	["WaterLevel"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_Number, "level" },
		},
		code = "#1 = Entity_.WaterLevel($1)",
	},
	["GetAngles"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_Angles, "angles" },
		},
		code = "#1 = Entity_.GetAngles($1)",
	},
	["SetAngles"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Angles, "angles" },	
		},
		code = "Entity_.SetAngles($2, $3)",
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
	["SetOwner"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Entity, "owner", PNF_Nullable },	
		},
		code = "Entity_.SetOwner($2, $3)",
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
	["Activate"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
		},
		code = "Entity_.Activate($2)",
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
	["SetEntityValue"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "key" },
			{ PD_In, PN_Any, "value" },
		},
		code = "if IsValid($2) then $2[\"bp_!graph_\" .. $3] = $4 end",
	},
	["GetEntityValue"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "key" },
			{ PD_Out, PN_Bool, "hasvalue"},
			{ PD_Out, PN_Any, "value" },
		},
		code = "if IsValid($1) then #1 = $1[\"bp_!graph_\" .. $2] ~= nil #2 = $1[\"bp_!graph_\" .. $2] else #1 = false #2 = nil end",
	},
	["ClearEntityValue"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "key" },
		},
		code = "if IsValid($2) then $2[\"bp_!graph_\" .. $3] = nil end",
	},
	["SetKeyValue"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "key" },
			{ PD_In, PN_String, "value" },
		},
		code = "Entity_.SetKeyValue($2, $3, $4)",
	},
	["GetKeyValue"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "key" },
			{ PD_Out, PN_String, "value" },
		},
		code = "#1 = Entity_.GetKeyValues($1)[$2] or \"\"",
	},
	["SetParent"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Entity, "parent" },
		},
		code = "Entity_.SetParent($2, $3)",
	},
	["SetModel"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "model" },
		},
		code = "Entity_.SetModel($2, Model($3))",
	},
	["GetModel"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_String, "model" },
		},
		code = "#1 = Entity_.GetModel($1)",
	},
	["SetColor"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_Color, "color" },
		},
		code = "Entity_.SetColor($2, $3)",
	},
	["GetColor"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_Color, "color" },
		},
		code = "#1 = Entity_.GetColor($1)",		
	},
	["SetName"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_In, PN_String, "name" },
		},
		code = "Entity_.SetName($2, $3)",
	},
	["GetName"] = PURE {
		pins = {
			{ PD_In, PN_Entity, "entity" },
			{ PD_Out, PN_String, "name" },
		},
		code = "#1 = Entity_.GetName($1)",		
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
			informs = {2,6}
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
			__bpm.delay("delay_!graph_!node", $2, function() @graph(#_1) end)
			goto popcall
		]],
	},
	["Debounce"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Number, "delay" },
			{ PD_In, PN_Bool, "alwaysReset"},
			{ PD_Out, PN_Exec, "Thru" },
			{ PD_Out, PN_Exec, "Debounced" },
		},	
		locals = {"debounced"},
		code = [[
			%debounced = __bpm.delayExists("debounce_!graph_!node")
			if %debounced and $3 then __bpm.delay("debounce_!graph_!node", $2, function() end) end
			if %debounced then #2 end
			__bpm.delay("debounce_!graph_!node", $2, function() end)
			#1
		]],
	},
	["Sequence"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_Out, PN_Exec, "1" },
			{ PD_Out, PN_Exec, "2" },
		},
		jumpSymbols = {"a", "b"},
		code = [[
			pushjmp(^_a) ip = #_1 goto jumpto
			::^a::
			pushjmp(^_b) ip = #_2 goto jumpto
			::^b::
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
	},
	["AllEntitiesByName"] = PURE {
		pins = {
			{ PD_In, PN_String, "name" },
			{ PD_Out, PN_Entity, "entities", PNF_Table },
		},
		code = "#1 = ents.FindByName( $1 )"
	},
	["ScreenShake"] = FUNCTION {
		pins = {
			{ PD_In, PN_Vector, "pos" },
			{ PD_In, PN_Number, "amplitude" },
			{ PD_In, PN_Number, "frequency" },
			{ PD_In, PN_Number, "duration" },
			{ PD_In, PN_Number, "radius" },
		},
		code = "util.ScreenShake( $2, $3, $4, $5, $6 )"
	},
	["MakeExplosion"] = FUNCTION {
		pins = {
			{ PD_In, PN_Entity, "owner", PNF_Nullable },
			{ PD_In, PN_Vector, "position" },
			{ PD_In, PN_Number, "damage" }
		},
		locals = {"ent"},
		code = [[
			%ent = ents.Create("env_explosion")
			%ent:SetOwner($2)
			%ent:SetPos($3)
			%ent:Spawn()
			%ent:SetKeyValue("iMagnitude", $4)
			%ent:Fire("Explode")
		]],
	},
	["Concat"] = PURE {
		pins = {
			{ PD_In, PN_String, "a" },
			{ PD_In, PN_String, "b" },
			{ PD_Out, PN_String, "result" },
		},
		compact = false,
		code = "#1 = $1 .. $2"
	},
	["StrLower"] = PURE {
		pins = {
			{ PD_In, PN_String, "str" },
			{ PD_Out, PN_String, "result" },
		},
		compact = false,
		code = "#1 = string.lower($1)",		
	},
	["ContainsString"] = PURE {
		pins = {
			{ PD_In, PN_String, "string" },
			{ PD_In, PN_String, "find" },
			{ PD_Out, PN_Bool, "result" },
		},
		compact = false,
		code = "#1 = string.find($1, $2) ~= nil"
	},
	["StrFind"] = PURE {
		pins = {
			{ PD_In, PN_String, "string" },
			{ PD_In, PN_String, "find" },
			{ PD_Out, PN_Number, "start" },
			{ PD_Out, PN_Number, "end" },
		},
		compact = false,
		locals = {"start", "end"},
		code = "%start, %end = string.find($1, $2) #1 = %start or 0 #2 = %end or 0"
	},
	["StrSub"] = PURE {
		pins = {
			{ PD_In, PN_String, "string" },
			{ PD_In, PN_Number, "start" },
			{ PD_In, PN_Number, "end" },
			{ PD_Out, PN_String, "result" },
		},
		compact = false,
		code = "#1 = string.sub($1, $2, $3) or \"\""
	},
	["StrTrim"] = PURE {
		pins = {
			{ PD_In, PN_String, "string" },
			{ PD_Out, PN_String, "trimmed" },
		},
		compact = false,
		code = "#1 = string.Trim($1)"
	},
	["TableGet"] = PURE {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "key" },
			{ PD_Out, PN_Any, "result" },
		},
		meta = {
			informs = {1,3}
		},
		compact = true,
		code = "#1 = $1[$2]",
	},
	["TableGetOrDefault"] = PURE {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "key" },
			{ PD_In, PN_Any, "default" },
			{ PD_Out, PN_Any, "result" },
		},
		meta = {
			informs = {1,3,4}
		},
		compact = true,
		code = "#1 = $1[$2] or $3",
	},
	["TableGetIndex"] = PURE {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Number, "index" },
			{ PD_Out, PN_Any, "result" },
		},
		meta = {
			informs = {1,3}
		},
		compact = true,
		code = "#1 = $1[$2]",
	},
	["TableGetNum"] = PURE {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_Out, PN_Number, "num" },
		},
		compact = true,
		code = "#1 = #$1",
	},
	["TableInsert"] = FUNCTION {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "value" },
		},
		meta = {
			informs = {3,4}
		},
		compact = true,
		code = "table.insert($2, $3)",
	},
	["TableSet"] = FUNCTION {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "key" },
			{ PD_In, PN_Any, "value", PNF_Nullable },
		},
		meta = {
			informs = {3,5}
		},
		compact = true,
		code = "$2[$3] = $4",
	},
	["TableSetI"] = FUNCTION {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Number, "key" },
			{ PD_In, PN_Any, "value", PNF_Nullable },
		},
		meta = {
			informs = {3,5}
		},
		compact = true,
		code = "$2[$3] = $4",
	},
	["TableHasKey"] = PURE {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "key" },
			{ PD_Out, PN_Bool, "has" },
		},
		compact = true,
		code = "#1 = $1[$2] ~= nil",
	},
	["TableHasValue"] = PURE {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "value" },
			{ PD_Out, PN_Bool, "has" },
		},
		meta = {
			informs = {1,2}
		},
		compact = true,
		code = "#1 = table.HasValue($1, $2)",
	},
	["TableClearKey"] = FUNCTION {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "key" },
		},
		compact = true,
		code = "$2[$3] = nil",
	},
	["TableClear"] = FUNCTION {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
		},
		compact = true,
		code = "$2 = {}",
	},
	["TraceLine"] = FUNCTION {
		pins = {
			{ PD_In, PN_Vector, "start" },
			{ PD_In, PN_Vector, "end" },
			{ PD_In, PN_Entity, "filter", PNF_Nullable },
			{ PD_Out, PN_Bool, "hit" },
			{ PD_Out, PN_Entity, "entity" },
			{ PD_Out, PN_Vector, "pos" },
			{ PD_Out, PN_Vector, "normal" },
			{ PD_Out, PN_Number, "fraction" },
		},
		locals = {"tr"},
		code = [[
			%tr = util.TraceLine({
				start = $2,
				endpos = $3,
				filter = $4,
			})
			#2 = %tr.Hit
			#3 = %tr.Entity
			#4 = %tr.HitPos
			#5 = %tr.HitNormal
			#6 = %tr.Fraction
		]],
	},
	["CheckValue"] = PURE {
		pins = {
			{ PD_In, PN_Any, "value" },
			{ PD_In, PN_Any, "default" },
			{ PD_Out, PN_Any, "out" },
		},
		compact = false,
		meta = {
			informs = {1,2}
		},
		code = [[#1 = (type($1) == type($2)) and $1 or $2]],
	},
}

local allpins = {}
for i=1, PN_Max do
	table.insert(allpins, { PD_In, i, PinTypeNames[i] })
end
for i=1, PN_Max do
	table.insert(allpins, { PD_Out, i, PinTypeNames[i] })
end

NodeTypes["DEBUGALLPINTYPES"] = PURE {
	pins = allpins,
	compact = false,
}

local function AddHook(name, args)

	local pins = {}
	local code = ""
	local ipin = 2
	for k, v in pairs(args) do

		table.insert( pins, { PD_Out, v[2], v[1] })
		code = code .. "#" .. ipin .. " = arg[" .. ipin-1 .. "]\n"

		ipin = ipin + 1

	end

	if code:len() > 0 then
		code = code:sub(0, -2)
	end

	NodeTypes[name] = EVENT {
		pins = pins,
		hook = name,
		code = code,
	}

end


AddHook("OnNPCKilled", { {"npc", PN_Npc}, {"attacker", PN_Entity}, {"inflictor", PN_Entity} })
AddHook("PlayerSpawn", { {"player", PN_Player}, {"transition", PN_Bool} })
AddHook("PlayerSetModel", { {"player", PN_Player} })
AddHook("PlayerUse", { {"player", PN_Player}, {"entity", PN_Entity} })
AddHook("PlayerSay", { {"player", PN_Player}, {"text", PN_String}, {"teamChat", PN_Bool} })
AddHook("PlayerDeath", { {"victim", PN_Player}, {"inflictor", PN_Entity}, {"attacker", PN_Entity} })
AddHook("PlayerDisconnected", { {"player", PN_Player} })
AddHook("PlayerEnteredVehicle", { {"player", PN_Player}, {"vehicle", PN_Vehicle}, {"role", PN_Number} })
AddHook("PlayerLeaveVehicle", { {"player", PN_Player}, {"vehicle", PN_Vehicle} })
AddHook("PlayerFrozeObject", { {"player", PN_Player}, {"entity", PN_Entity}, {"physobj", PN_PhysObj} })
AddHook("PlayerUnfrozeObject", { {"player", PN_Player}, {"entity", PN_Entity}, {"physobj", PN_PhysObj} })
AddHook("PlayerHurt", { {"victim", PN_Player}, {"attacker", PN_Entity}, {"health", PN_Number}, {"damage", PN_Number} })
AddHook("PlayerTick", { {"player", PN_Player}, {"moveData", PN_Any} })
AddHook("GravGunOnDropped", { {"player", PN_Player}, {"entity", PN_Entity} })
AddHook("GravGunOnPickedUp", { {"player", PN_Player}, {"entity", PN_Entity} })
AddHook("PlayerButtonDown", { {"player", PN_Player}, {"button", PN_Number} })
AddHook("PlayerButtonUp", { {"player", PN_Player}, {"button", PN_Number} })
AddHook("KeyPress", { {"player", PN_Player}, {"key", PN_Number} })
AddHook("KeyRelease", { {"player", PN_Player}, {"key", PN_Number} })
AddHook("PlayerSwitchFlashlight", { {"player", PN_Player}, {"enabled", PN_Bool} })
AddHook("EntityTakeDamage", { {"target", PN_Entity}, {"damageInfo", PN_Any} })

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
end