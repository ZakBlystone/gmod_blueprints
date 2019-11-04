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
	["Player"] = PURE {
		deprecated = true,
		pins = {
			{ PD_In, PN_Number, "id" },	
			{ PD_Out, PN_Ref, "player", PNF_None, "Player" },
		},
		code = "#1 = player.GetAll()[$1]",
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
		print("NODE REDIRECT: " .. k .. " -> " .. tostring(NodeRedirectors[k]))
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