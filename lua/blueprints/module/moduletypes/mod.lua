AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Mod"
MODULE.Description = "Behaves like a basic Lua script"
MODULE.Icon = "icon16/application.png"

function MODULE:Setup()

	print( "IS MODULE: " .. tostring( isbpmodule(self) ))

end

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

	return self.BaseClass.CanAddNode( self, nodeType )

end

RegisterModuleClass("Mod", MODULE)