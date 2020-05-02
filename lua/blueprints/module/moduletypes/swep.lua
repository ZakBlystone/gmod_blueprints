AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = LOCTEXT"module_swep_name","Weapon"
MODULE.Description = LOCTEXT"module_swep_desc","A Scripted Weapon you can pick up and shoot"
MODULE.Icon = "icon16/gun.png"
MODULE.Creatable = true
MODULE.CanBeSubmodule = true
MODULE.AdditionalConfig = true
MODULE.HasOwner = true
MODULE.SelfPinSubClass = "Weapon"
MODULE.HasUIDClassname = true

function MODULE:Setup()

	BaseClass.Setup(self)

	self:AddAutoFill( self:GetSelfPinType(), "__self" )

end

function MODULE:GetSelfPinType() return bppintype.New( PN_Ref, PNF_None, "Weapon" ) end
function MODULE:GetOwnerPinType() return bppintype.New( PN_Ref, PNF_None, "Entity" ) end

function MODULE:SetupEditValues( values )

	values:Index("weapon.ViewModel"):OverrideClass( "weaponviewmodel" )
	values:Index("weapon.WorldModel"):OverrideClass( "weaponworldmodel" )
	values:Index("classname"):SetRuleFlags( value_string.RULE_NOUPPERCASE, value_string.RULE_NOSPACES, value_string.RULE_NOSPECIAL )

end

function MODULE:GetDefaultConfigTable()

	return {
		classname = bpcommon.GUIDToString(self:GetUID(), true):lower(),
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
			Slot = 0,
			SlotPos = 0,
			Primary = {
				ClipSize = 20,
				DefaultClip = 20,
				Automatic = false,
				Ammo = "Pistol",
			},
			Secondary = {
				ClipSize = 0,
				DefaultClip = 0,
				Automatic = false,
				Ammo = "",
			},
			ViewModel = "models/weapons/c_pistol.mdl",
			WorldModel = "models/weapons/w_pistol.mdl",
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

	--local _, primary = graph:AddNode("WEAPON_PrimaryAttack", 120, 300)
	--local _, secondary = graph:AddNode("WEAPON_SecondaryAttack", 120, 500)
	--local _, canPrimary = graph:AddNode("Weapon_CanPrimaryAttack", 300, 300)
	--local _, cpIf = graph:AddNode("LOGIC_If", 550, 300)
	--local _, cpShootEffects = graph:AddNode("Weapon_ShootEffects", 750, 300)

	--primary:FindPin( PD_Out, "Exec" ):Connect( canPrimary:FindPin( PD_In, "Exec" ) )
	--canPrimary:FindPin( PD_Out, "Thru" ):Connect( cpIf:FindPin( PD_In, "Exec" ) )
	--canPrimary:FindPin( PD_Out, "CanAttack" ):Connect( cpIf:FindPin( PD_In, "Condition" ) )
	--cpIf:FindPin( PD_Out, "True" ):Connect( cpShootEffects:FindPin( PD_In, "Exec" ) )

	--local canPrimaryGraph = graph:AddNode("WEAPON_CanPrimaryAttack", 150, 300)

	init:FindPin( PD_Out, "Exec" ):Connect( hold:FindPin( PD_In, "Exec" ) )
	hold:FindPin( PD_In, "Name" ):SetLiteral("pistol")

	--local _, primary = graph:AddNode("WEAPON_PrimaryAttack", 120, 300)
	--local _, secondary = graph:AddNode("WEAPON_SecondaryAttack", 120, 500)

end

local blacklistHooks = {
	["ENTITY"] = true,
	["EFFECT"] = true,
	["CORE"] = true,
}

function MODULE:CanAddNode(nodeType)

	local group = nodeType:GetGroup()
	if group and nodeType:GetContext() == bpnodetype.NC_Hook and blacklistHooks[group:GetName()] then return false end

	return BaseClass.CanAddNode( self, nodeType )

end

local EntityPin = bppintype.New( PN_Ref, PNF_None, "Entity" )
function MODULE:CanCast( outPinType, inPinType )

	if outPinType:Equal(self:GetModulePinType()) then

		if inPinType:Equal(EntityPin) then return true end

	end

	return BaseClass.CanCast( self, outPinType, inPinType )

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MODULEMETA then

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
		compiler.emit("\tinstance.guid = __hexBytes(string.format(\"%0.32X\", self:EntIndex()))")
		compiler.emitContext( CTX_Vars .. "global", 1 )
		compiler.emit("\tself.bInitialized = true")
		compiler.emit("\tself:netInit()")
		compiler.emit("\tself:hookEvents(true)")
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
	self:hookEvents(false)
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
__bpm.refresh = function()
	for _, e in ipairs( ents.FindByClass( __bpm.class ) ) do
		if IsValid(e) then e.__bpm = __bpm e:hookEvents(true) end
	end
end
__bpm.shutdown = function()
	weapons.Register({ Base = "weapon_base" }, __bpm.class)
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

RegisterModuleClass("SWEP", MODULE, "MetaType")
