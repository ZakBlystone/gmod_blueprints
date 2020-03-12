AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Mod"
MODULE.Description = "A Basic Script"
MODULE.Icon = "icon16/joystick.png"
MODULE.Creatable = true

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	graph:AddNode("CORE_Init", 120, 100)
	graph:AddNode("GM_Think", 120, 300)
	graph:AddNode("CORE_Shutdown", 120, 500)

end

local allowedHooks = {
	["GM"] = true,
	["CORE"] = true,
}

function MODULE:CanAddNode(nodeType)

	local group = nodeType:GetGroup()
	if group and nodeType:GetContext() == bpnodetype.NC_Hook and not allowedHooks[group:GetName()] then return false end

	return BaseClass:CanAddNode( nodeType )

end

RegisterModuleClass("Mod", MODULE, "Configurable")