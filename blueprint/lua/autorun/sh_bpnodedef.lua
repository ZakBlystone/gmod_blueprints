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
			{ PD_In, PN_Any, "", PNF_None },
			{ PD_Out, PN_Any, "", PNF_None },
		},
		meta = {
			informs = {1,2},
			compact = true,
		},
		code = "#1 = $1",
		collapse = true,
	},
	["EntityFireBullets"] = EVENT {
		deprecated = true,
		pins = {
			{ PD_Out, PN_Ref, "entity", PNF_None, "Entity" },
			{ PD_Out, PN_Ref, "attacker", PNF_None, "Entity" },
			{ PD_Out, PN_Number, "damage", PNF_None },
			{ PD_Out, PN_Number, "count", PNF_None },
			{ PD_Out, PN_Vector, "source", PNF_None },
			{ PD_Out, PN_Vector, "direction", PNF_None },
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