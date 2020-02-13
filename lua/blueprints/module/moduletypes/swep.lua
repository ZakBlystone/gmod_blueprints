AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Scripted Weapon"
MODULE.Description = "Behaves like a SWEP"
MODULE.Icon = "icon16/gun.png"

function MODULE:Setup()

	self.getSelfNodeType = bpnodetype.New()
	self.getSelfNodeType:SetCodeType(NT_Pure)
	self.getSelfNodeType.GetDisplayName = function() return "Self" end
	self.getSelfNodeType.GetGraphThunk = function() return self end
	self.getSelfNodeType.GetRole = function() return ROLE_Shared end
	self.getSelfNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Self", PN_Ref, PNF_None, "Weapon"),
		}
	end
	self.getSelfNodeType:SetCode( "#1 = __self" )

	self.getOwnerNodeType = bpnodetype.New()
	self.getOwnerNodeType:SetCodeType(NT_Pure)
	self.getOwnerNodeType.GetDisplayName = function() return "Owner" end
	self.getOwnerNodeType.GetGraphThunk = function() return self end
	self.getOwnerNodeType.GetRole = function() return ROLE_Shared end
	self.getOwnerNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Owner", PN_Ref, PNF_None, "Entity"),
		}
	end
	self.getSelfNodeType:SetCode( "#1 = __self.Owner" )

end

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	local _, init = graph:AddNode("WEAPON_Initialize", 120, 100)
	local _, hold = graph:AddNode("Weapon_SetHoldType", 250, 100)

	init:FindPin( PD_Out, "Exec" ):Connect( hold:FindPin( PD_In, "Exec" ) )
	hold:FindPin( PD_In, "Name" ):SetLiteral("pistol")

	--local _, primary = graph:AddNode("WEAPON_PrimaryAttack", 120, 300)
	--local _, secondary = graph:AddNode("WEAPON_SecondaryAttack", 120, 500)

end

local allowedHooks = {
	["GM"] = true,
	["WEAPON"] = true,
}

function MODULE:CanAddNode(nodeType)

	local group = nodeType:GetGroup()
	if group and nodeType:GetContext() == bpnodetype.NC_Hook and not allowedHooks[group:GetName()] then return false end

	return self.BaseClass.CanAddNode( self, nodeType )

end

function MODULE:GetNodeTypes( graph, collection )

	self.BaseClass.GetNodeTypes( self, graph, collection )

	local types = {}

	collection:Add( types )

	types["__Self"] = self.getSelfNodeType
	types["__Owner"] = self.getOwnerNodeType

	for k,v in pairs(types) do v.name = k end

end

RegisterModuleClass("SWEP", MODULE)