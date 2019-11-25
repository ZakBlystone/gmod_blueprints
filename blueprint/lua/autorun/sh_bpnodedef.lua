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

--InstallDefs()