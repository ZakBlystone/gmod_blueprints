AddCSLuaFile()

module("module_sent", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Entity"
MODULE.Description = "A Scripted Entity you can spawn in the world"
MODULE.Icon = "icon16/bricks.png"
MODULE.Creatable = true
MODULE.AdditionalConfig = true

function MODULE:Setup()

	mod_configurable.MODULE.Setup(self)

	self.getSelfNodeType = bpnodetype.New()
	self.getSelfNodeType:SetCodeType(NT_Pure)
	self.getSelfNodeType.GetDisplayName = function() return "Self" end
	self.getSelfNodeType.GetGraphThunk = function() return self end
	self.getSelfNodeType.GetRole = function() return ROLE_Shared end
	self.getSelfNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Self", PN_Ref, PNF_None, "Entity"),
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
	self.getOwnerNodeType:SetCode( "#1 = __self.Owner" )

end

function MODULE:SetupEditValues( values )

	--values:Index("weapon.ViewModel"):OverrideClass( "weaponviewmodel" )
	--values:Index("weapon.WorldModel"):OverrideClass( "weaponworldmodel" )

end

function MODULE:GetDefaultConfigTable()

	return {
		classname = "my_entity",
		entity = {
			Base = "base_anim",
			Type = "anim",
			Author = "",
			Category = "Blueprint",
			Contact = "",
			Purpose = "",
			Instructions = "",
			PrintName = "BP Scripted Entity",
			AutomaticFrameAdvance = false,
			Spawnable = true,
			AdminOnly = false,
		}
	}

end

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	--local _, init = graph:AddNode("WEAPON_Initialize", 120, 100)
	--local _, hold = graph:AddNode("Weapon_SetHoldType", 250, 100)
	--local _, selfNode = graph:AddNode(self.getSelfNodeType, 128,160)

	--init:FindPin( PD_Out, "Exec" ):Connect( hold:FindPin( PD_In, "Exec" ) )
	--hold:FindPin( PD_In, "Name" ):SetLiteral("pistol")
	--hold:FindPin( PD_In, "Weapon" ):Connect( selfNode:FindPin( PD_Out, "Self" ) )

	--local _, primary = graph:AddNode("WEAPON_PrimaryAttack", 120, 300)
	--local _, secondary = graph:AddNode("WEAPON_SecondaryAttack", 120, 500)

end

local allowedHooks = {
	["GM"] = false,
	["ENTITY"] = true,
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

function MODULE:IsConstructable() return false end

function MODULE:AutoFillsPinClass( class )

	if class == "Entity" then return true end
	if class == "PhysObj" then return true end

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	if pass == CP_PREPASS then

		-- All unconnected entity pins point to self
		for k, v in ipairs( compiler.graphs ) do
			for _, node in v:Nodes() do
				for _, pin in node:SidePins(PD_In) do
					if pin:GetBaseType() ~= PN_Ref then continue end
					if pin:GetSubType() == "Entity" and #pin:GetConnectedPins() == 0 then
						pin:SetLiteral("__self")
					end
					if pin:GetSubType() == "PhysObj" and #pin:GetConnectedPins() == 0 then
						pin:SetLiteral("__self:GetPhysicsObject()")
					end
				end
			end
		end

	elseif pass == CP_MODULEMETA then

		local entityTable = edit:Index("entity")
		compiler.emit( "meta = table.Merge( meta, " .. entityTable:ToString() .. " )")

		compiler.emit([[
for k,v in pairs(meta) do
	local _, _, m = k:find("ENTITY_(.+)")
	if m then meta[ m ] = v end
end]])

		compiler.emit("function meta:Initialize()")
		compiler.emit("\tlocal instance = self")
		compiler.emit("\tinstance.delays = {}")
		compiler.emit("\tinstance.__bpm = __bpm")
		compiler.emit("\tinstance.guid = __bpm.hexBytes(string.format(\"%0.32X\", self:EntIndex()))")
		compiler.emitContext( CTX_Vars .. "global", 1 )
		compiler.emit("\tself.bInitialized = true")
		compiler.emit("\tself.lastThink = CurTime()")
		compiler.emit("\tself:netInit()")
		compiler.emit("\tif self.ENTITY_Initialize then self:ENTITY_Initialize() end")
		compiler.emit("end")

		compiler.emit([[
function meta:Think()
	local r = nil
	if CLIENT and not self.bInitialized then self:Initialize() end
	if self.ENTITY_Think then r = self:ENTITY_Think() end
	if self.lastThink then self:update( CurTime() - self.lastThink ) end
	self.lastThink = CurTime()
	return r
end
function meta:OnRemove()
	if not self.bInitialized then return end
	if self.ENTITY_OnRemove then self:ENTITY_OnRemove() end
	self:netShutdown()
end]])

		return true

	elseif pass == CP_MODULEBPM then

		local classname = edit:Index("classname")

		compiler.emit("__bpm.class = " .. classname:ToString())
		compiler.emit([[
__bpm.init = function()
	scripted_ents.Register( meta, __bpm.class )
	if CLIENT and bpsandbox then bpsandbox.RefreshSENTs() end
	if CLIENT then return end
end
__bpm.shutdown = function()
	if CLIENT then return end
	for _, e in ipairs( ents.FindByClass( __bpm.class ) ) do
		if IsValid(e) then 
			e:Remove()
		end
	end
end]])

	end

end

RegisterModuleClass("SENT", MODULE, "Configurable")
