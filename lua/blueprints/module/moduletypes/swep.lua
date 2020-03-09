AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Weapon"
MODULE.Description = "A Scripted Weapon you can pick up and shoot"
MODULE.Icon = "icon16/gun.png"
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
	self.getOwnerNodeType:SetCode( "#1 = __self.Owner" )

end

function MODULE:SetupEditValues( values )

	values:Index("weapon.ViewModel"):OverrideClass( "weaponviewmodel" )
	values:Index("weapon.WorldModel"):OverrideClass( "weaponworldmodel" )

end

function MODULE:GetDefaultConfigTable()

	return {
		classname = "my_weapon",
		weapon = {
			Author = "",
			Category = "Blueprint",
			Contact = "",
			Purpose = "",
			Instructions = "",
			UseHands = true,
			PrintName = "BP Scripted Weapon",
			Spawnable = true,
			AdminOnly = false,
			Primary = {
				ClipSize = 50,
				DefaultClip = 20,
				Automatic = true,
				Ammo = "Pistol",
			},
			Secondary = {
				ClipSize = 50,
				DefaultClip = 20,
				Automatic = true,
				Ammo = "Pistol",
			},
			ViewModel = "models/weapons/c_smg1.mdl",
			WorldModel = "models/weapons/w_smg1.mdl",
			ViewModelFlip = false,
			ViewModelFlip1 = false,
			ViewModelFlip2 = false,
			ViewModelFOV = 62,
			AutoSwitchFrom = true,
			AutoSwitchTo = true,
			Weight = 5,
			BobScale = 1.0,
			SwayScale = 1.0,
			BounceWeaponIcon = true,
			DrawWeaponInfoBox = true,
			DrawAmmo = true,
			DrawCrosshair = true,
			m_WeaponDeploySpeed = 1.0,
			m_bPlayPickupSound = true,
			AccurateCrosshair = false,
		}
	}

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
	["GM"] = false,
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

function MODULE:IsConstructable() return false end

function MODULE:AutoFillsPinClass( class )

	if class == "Weapon" then return true end

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	if pass == CP_PREPASS then

		-- All unconnected entity pins point to self
		for k, v in ipairs( compiler.graphs ) do
			for _, node in v:Nodes() do
				for _, pin in node:SidePins(PD_In) do
					if pin:GetBaseType() ~= PN_Ref then continue end
					if pin:GetSubType() == "Weapon" and #pin:GetConnectedPins() == 0 then
						pin:SetLiteral("__self")
					end
				end
			end
		end

	elseif pass == CP_MODULEMETA then

		local weaponTable = edit:Index("weapon")
		compiler.emit( "meta = table.Merge( meta, " .. weaponTable:ToString() .. " )")

		compiler.emit([[
for k,v in pairs(meta) do
	local _, _, m = k:find("WEAPON_(.+)")
	if m then meta[ m ] = v end
end]])

		compiler.emit("function meta:Initialize()")
		compiler.emit("\tlocal instance = self")
		compiler.emit("\tinstance.delays = {}")
		compiler.emit("\tinstance.__bpm = __bpm")
		compiler.emit("\tinstance.guid = __bpm.hexBytes(string.format(\"%0.32X\", self:EntIndex()))")
		compiler.emitContext( CTX_Vars .. "global", 1 )
		compiler.emit("\tself.bInitialized = true")
		compiler.emit("\tself:netInit()")
		compiler.emit("\tif self.WEAPON_Initialize then self:WEAPON_Initialize() end")
		compiler.emit("end")

		compiler.emit([[
function meta:Think()
	if CLIENT and not self.bInitialized then self:Initialize() end
	if self.WEAPON_Think then self:WEAPON_Think() end
	self:update()
end
function meta:OnRemove()
	if not self.bInitialized then return end
	if self.WEAPON_OnRemove then self:WEAPON_OnRemove() end
	self:netShutdown()
end]])

		return true

	elseif pass == CP_MODULEBPM then

		local classname = edit:Index("classname")

		compiler.emit("__bpm.class = " .. classname:ToString())
		compiler.emit([[
__bpm.playerKey = "bpplayerhadweapon_" .. __bpm.class
__bpm.init = function()
	weapons.Register( meta, __bpm.class )
	if CLIENT and bpsandbox then bpsandbox.RefreshSWEPs() end
	if CLIENT then return end
	timer.Simple(.5, function()
	for _, pl in ipairs( player.GetAll() ) do
		if pl[__bpm.playerKey] then
			pl:Give( __bpm.class )
			pl:SelectWeapon( __bpm.class )
			pl[__bpm.playerKey] = false
		end
	end
	end )
end
__bpm.shutdown = function()
	if CLIENT then return end
	for _, e in ipairs( ents.FindByClass( __bpm.class ) ) do
		if IsValid(e) then 
			if IsValid(e.Owner) then
				e.Owner[__bpm.playerKey] = true
				e.Owner:DropWeapon( e )
			end
			e:Remove()
		end
	end
end]])

	end

end

RegisterModuleClass("SWEP", MODULE, "Configurable")
