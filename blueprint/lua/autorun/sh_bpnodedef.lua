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

NodePinRedirectors = {}
NodeRedirectors = {}
NodeTypes = {
	["Init"] = EVENT {
		pins = {},
		code = [[]],
		role = ROLE_Shared,
	},
	["Shutdown"] = EVENT {
		pins = {},
		code = [[]],
		role = ROLE_Shared,
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
		collapse = true,
	},
	["EntityFireBullets"] = EVENT {
		deprecated = true,
		pins = {
			{ PD_Out, PN_Ref, "entity", PNF_None, "Entity" },
			{ PD_Out, PN_Ref, "attacker", PNF_None, "Entity" },
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
	["ChatPrintAll"] = FUNCTION {
		pins = {
			{ PD_In, PN_String, "message" },
		},
		code = "for _, pl in pairs(player.GetAll()) do Player_.ChatPrint(pl, $2) end",
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
	["Abs"] = PURE {
		pins = {
			{ PD_In, PN_Number, "in" },
			{ PD_Out, PN_Number, "out" },
		},
		code = "#1 = math.abs($1)",
		compact = true,
	},
	["Sqrt"] = PURE {
		pins = {
			{ PD_In, PN_Number, "in" },
			{ PD_Out, PN_Number, "out" },
		},
		code = "#1 = math.sqrt($1)",
		compact = true,
	},
	["Pow"] = PURE {
		pins = {
			{ PD_In, PN_Number, "in" },
			{ PD_In, PN_Number, "power" },
			{ PD_Out, PN_Number, "out" },
		},
		code = "#1 = math.pow($1, $2)",
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
	["AngleVectors"] = PURE {
		pins = {
			{ PD_In, PN_Angles, "angles" },
			{ PD_Out, PN_Vector, "forward" },
			{ PD_Out, PN_Vector, "right" },
			{ PD_Out, PN_Vector, "up" },
		},
		code = "#1 = $1:Forward() #2 = $1:Right() #3 = $1:Up()",
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
	["Player"] = PURE {
		pins = {
			{ PD_In, PN_Number, "id" },	
			{ PD_Out, PN_Ref, "player", PNF_None, "Player" },
		},
		code = "#1 = player.GetAll()[$1]",
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
	["Boolean"] = PURE {
		pins = {
			{ PD_In, PN_Bool, "bool" },
			{ PD_Out, PN_Bool, "bool" },
		},
		code = "#1 = $1",	
	},
	["Modulo"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Number, "result" },
		},
		code = "#1 = $1 % $2",
		displayName = "%",
		compact = true,
	},
	["LessThan"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 < $2",
		displayName = "<",
		compact = true,
	},
	["LessThanEqual"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 <= $2",
		displayName = "<=",
		compact = true,
	},
	["GreaterThan"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 > $2",
		displayName = ">",
		compact = true,
	},
	["GreaterThanEqual"] = PURE {
		pins = {
			{ PD_In, PN_Number, "a" },
			{ PD_In, PN_Number, "b" },
			{ PD_Out, PN_Bool, "result" },
		},
		code = "#1 = $1 >= $2",
		displayName = ">=",
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
	["Clamp"] = PURE {
		pins = {
			{ PD_In, PN_Number, "value" },
			{ PD_In, PN_Number, "min" },
			{ PD_In, PN_Number, "max" },
			{ PD_Out, PN_Number, "result" },
		},
		code = "#1 = math.Clamp($1, $2, $3)",
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
	["CurTime"] = PURE {
		pins = {
			{ PD_Out, PN_Number, "curtime" },
		},
		code = "#1 = CurTime()",
		compact = true,
	},
	["DivideNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		displayName = "/",
		code = "#1 = $1 / $2",
		compact = true,
	},
	["MultiplyNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		displayName = "*",
		code = "#1 = $1 * $2",
		compact = true,
	},
	["AddNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		displayName = "+",
		code = "#1 = $1 + $2",
		compact = true,
	},
	["SubNumber"] = PURE {
		pins = {
			{ PD_In, PN_Number, "A" },
			{ PD_In, PN_Number, "B" },
			{ PD_Out, PN_Number, "result" },
		},
		displayName = "-",
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
	["VectorMA"] = PURE {
		pins = {
			{ PD_In, PN_Vector, "base" },
			{ PD_In, PN_Vector, "dir" },
			{ PD_In, PN_Number, "scalar" },
			{ PD_Out, PN_Vector, "result" },
		},
		code = "#1 = $1 + ($2 * $3)",
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
			{ PD_In, PN_Any, "a", PNF_Nullable },
			{ PD_In, PN_Any, "b", PNF_Nullable },
			{ PD_Out, PN_Bool, "result" },
		},
		meta = {
			informs = {1, 2}
		},
		displayName = "==",
		code = "#1 = $1 == $2",
		compact = true,		
	},
	["NotEqual"] = PURE {
		pins = {
			{ PD_In, PN_Any, "a", PNF_Nullable },
			{ PD_In, PN_Any, "b", PNF_Nullable },
			{ PD_Out, PN_Bool, "result" },
		},
		meta = {
			informs = {1, 2}
		},
		displayName = "!=",
		code = "#1 = $1 ~= $2",
		compact = true,
	},
	["SetEntityValue"] = FUNCTION {
		pins = {
			{ PD_In, PN_Ref, "entity", PNF_None, "Entity" },
			{ PD_In, PN_String, "key" },
			{ PD_In, PN_Any, "value" },
		},
		code = "if IsValid($2) then $2[\"bp_!graph_\" .. $3] = $4 end",
	},
	["GetEntityValue"] = PURE {
		pins = {
			{ PD_In, PN_Ref, "entity", PNF_None, "Entity" },
			{ PD_In, PN_String, "key" },
			{ PD_Out, PN_Bool, "hasvalue"},
			{ PD_Out, PN_Any, "value" },
		},
		code = "if IsValid($1) then #1 = $1[\"bp_!graph_\" .. $2] ~= nil #2 = $1[\"bp_!graph_\" .. $2] else #1 = false #2 = nil end",
	},
	["ClearEntityValue"] = FUNCTION {
		pins = {
			{ PD_In, PN_Ref, "entity", PNF_None, "Entity" },
			{ PD_In, PN_String, "key" },
		},
		code = "if IsValid($2) then $2[\"bp_!graph_\" .. $3] = nil end",
	},
	["GetKeyValue"] = PURE {
		pins = {
			{ PD_In, PN_Ref, "entity", PNF_None, "Entity" },
			{ PD_In, PN_String, "key" },
			{ PD_Out, PN_String, "value" },
		},
		code = "#1 = Entity_.GetKeyValues($1)[$2] or \"\"",
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
	["DelayBoxed"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Number, "delay" },
			{ PD_In, PN_Any, "value" },
			{ PD_Out, PN_Exec, "Thru" },
			{ PD_Out, PN_Any, "value" },
		},
		meta = {
			informs = {3,5}
		},
		latent = true,
		code = [[
			#2 = $3
			__bpm.delay("delay_!graph_!node", $2, function() @graph(#_1) end)
			goto popcall
		]],
	},
	["Delay"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_In, PN_Number, "delay" },
			{ PD_Out, PN_Exec, "Thru" },
		},
		latent = true,
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
		latent = true,
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
	["FindPlayerByName"] = PURE {
		pins = {
			{ PD_In, PN_String, "name" },
			{ PD_Out, PN_Ref, "player", PNF_None, "Player" },
			{ PD_Out, PN_Bool, "found" },
		},
		code = "#2 = false for _, pl in pairs(player.GetAll()) do if pl:Nick():find( $1 ) ~= nil then #1 = pl #2 = true end end"
	},
	["MakeExplosion"] = FUNCTION {
		pins = {
			{ PD_In, PN_Ref, "owner", PNF_Nullable, "Entity" },
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
	["StrLen"] = PURE {
		pins = {
			{ PD_In, PN_String, "string" },
			{ PD_Out, PN_Number, "length" },
		},
		compact = false,
		code = "#1 = string.len($1)"
	},
	["TableRandom"] = PURE {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_Out, PN_Any, "result" },
		},
		meta = {
			informs = {1,2}
		},
		compact = true,
		code = "#1 = $1[ math.random(1, #$1) ]",
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
	["TableRemove"] = FUNCTION {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Number, "index" },
		},
		compact = true,
		code = "table.remove($2, $3)",
	},
	["TableRemoveValue"] = FUNCTION {
		pins = {
			{ PD_In, PN_Any, "table", PNF_Table },
			{ PD_In, PN_Any, "value" },
		},
		meta = {
			informs = {3,4}
		},
		compact = true,
		code = "table.RemoveByValue($2, $3)",
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
	["Client"] = SPECIAL {
		pins = {
			{ PD_Out, PN_Bool, "IsClient" },
		},
		compact = true,
		code = [[#1 = CLIENT]],
	},
	["Server"] = SPECIAL {
		pins = {
			{ PD_Out, PN_Bool, "IsServer" },
		},
		compact = true,
		code = [[#1 = SERVER]],
	},
	["ClientOnly"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_Out, PN_Exec, "Thru" },
		},
		compact = false,
		code = [[if CLIENT then #1 else goto popcall end]],
	},
	["ServerOnly"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_Out, PN_Exec, "Thru" },
		},
		compact = false,
		code = [[if SERVER then #1 else goto popcall end]],
	},
	["Role"] = SPECIAL {
		pins = {
			{ PD_In, PN_Exec, "Exec" },
			{ PD_Out, PN_Exec, "Server" },
			{ PD_Out, PN_Exec, "Client" },
		},
		compact = false,
		code = [[if SERVER then #1 else #2 end]],
	},
}

for k,v in pairs(NodeTypes) do
	if type(v) == "string" then
		local nodeRedirect = nil
		local pinRedirects = {}
		local args = string.Explode(",", v)
		for _, arg in pairs(args) do
			nodeRedirect = nodeRedirect or arg
			for a,b in arg:gmatch("([%w_]+)=([%w_]+)") do
				pinRedirects[a] = b
			end
		end

		NodeRedirectors[k] = nodeRedirect:gsub("[:.]", "_")
		NodePinRedirectors[k] = pinRedirects
		NodePinRedirectors[NodeRedirectors[k]] = pinRedirects
		NodeTypes[k] = nil
	end
end

for k,v in pairs(NodeTypes) do 
	v.name = k
end

function InstallDefs()
	if bpdefs == nil then return end

	print("Installing defs")
	for k,v in pairs(bpdefs.GetLibs()) do
		bpdefs.CreateLibNodes(v, NodeTypes)
	end

	for k,v in pairs(bpdefs.GetClasses()) do
		bpdefs.CreateLibNodes(v, NodeTypes)
	end

	for k,v in pairs(bpdefs.GetStructs()) do
		bpdefs.CreateStructNodes(v, NodeTypes)
	end

	for k,v in pairs(bpdefs.GetHookSets()) do
		bpdefs.CreateHooksetNodes(v, NodeTypes)
	end
	print("Done.")
end

InstallDefs()