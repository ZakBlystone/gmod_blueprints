AddCSLuaFile()

local MODULE = {}

MODULE.Name = "Scripted Weapon"
MODULE.Description = "Behaves like a SWEP"
MODULE.Icon = "icon16/gun.png"

function MODULE:Setup()

end

function MODULE:CreateDefaults()

	--[[local id, graph = self:NewGraph("EventGraph")
	graph:AddNode("CORE_Init", 120, 100)
	graph:AddNode("GM_Think", 120, 300)
	graph:AddNode("CORE_Shutdown", 120, 500)]]

end

RegisterModuleClass("SWEP", MODULE)