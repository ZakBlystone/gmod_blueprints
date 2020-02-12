AddCSLuaFile()

local MODULE = {}

MODULE.Name = "Mod"
MODULE.Description = "Behaves like a basic Lua script"
MODULE.Icon = "icon16/application.png"

function MODULE:Setup()

end

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	graph:AddNode("CORE_Init", 120, 100)
	graph:AddNode("GM_Think", 120, 300)
	graph:AddNode("CORE_Shutdown", 120, 500)

end

RegisterModuleClass("Mod", MODULE)