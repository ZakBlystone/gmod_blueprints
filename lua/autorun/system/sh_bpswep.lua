AddCSLuaFile()

module("bpswep", package.seeall)

local SWEP = {}
SWEP.PrintName		= "Blueprint Scripted Weapon" -- 'Nice' Weapon name (Shown on HUD)
SWEP.Author			= ""
SWEP.Contact		= ""
SWEP.Purpose		= ""
SWEP.Instructions	= "Point away from face"

SWEP.ViewModelFOV	= 62
SWEP.ViewModelFlip	= false
SWEP.ViewModel		= "models/weapons/c_pistol.mdl"
SWEP.WorldModel		= "models/weapons/w_357.mdl"
SWEP.UseHands = true

SWEP.Spawnable		= true
SWEP.AdminOnly		= false

SWEP.Primary = {
	ClipSize		= 8,
	DefaultClip		= 32,
	Automatic		= false,
	Ammo			= "Pistol",
}

SWEP.Secondary = {
	ClipSize		= 18,
	DefaultClip		= 32,
	Automatic		= false,
	Ammo			= "Pistol",
}

--[[---------------------------------------------------------
	Name: SWEP:Initialize()
	Desc: Called when the weapon is first loaded
-----------------------------------------------------------]]
function SWEP:Initialize()

	self:SetHoldType( "pistol" )

	print("Create: " .. self:EntIndex())

end

function SWEP:OnRemove()

	print("Remove: " .. self:EntIndex())

end

function SWEP:Think()

end

--[[---------------------------------------------------------
	Name: SWEP:PrimaryAttack()
	Desc: +attack1 has been pressed
-----------------------------------------------------------]]
function SWEP:PrimaryAttack()

	-- Make sure we can shoot first
	if ( !self:CanPrimaryAttack() ) then return end

	-- Play shoot sound
	self:EmitSound( "Weapon_AR2.Single" )

	-- Shoot 9 bullets, 150 damage, 0.75 aimcone
	self:ShootBullet( 150, 1, 0.01, self.Primary.Ammo )

	-- Remove 1 bullet from our clip
	self:TakePrimaryAmmo( 1 )

	-- Punch the player's view
	self.Owner:ViewPunch( Angle( -1, 0, 0 ) )

end

--[[---------------------------------------------------------
	Name: SWEP:SecondaryAttack()
	Desc: +attack2 has been pressed
-----------------------------------------------------------]]
function SWEP:SecondaryAttack()

	-- Make sure we can shoot first
	if ( !self:CanSecondaryAttack() ) then return end

	-- Play shoot sound
	self:EmitSound("Weapon_Shotgun.Single")

	-- Shoot 9 bullets, 150 damage, 0.75 aimcone
	self:ShootBullet( 150, 9, 0.2, self.Secondary.Ammo )

	-- Remove 1 bullet from our clip
	self:TakeSecondaryAmmo( 1 )

	-- Punch the player's view
	self.Owner:ViewPunch( Angle( -10, 0, 0 ) )

end

--[[---------------------------------------------------------
	Name: SWEP:Reload()
	Desc: Reload is being pressed
-----------------------------------------------------------]]
function SWEP:Reload()
	self:DefaultReload( ACT_VM_RELOAD )
end

--[[---------------------------------------------------------
	Name: SWEP:Think()
	Desc: Called every frame
-----------------------------------------------------------]]


--[[---------------------------------------------------------
	Name: SWEP:Holster( weapon_to_swap_to )
	Desc: Weapon wants to holster
	RetV: Return true to allow the weapon to holster
-----------------------------------------------------------]]
function SWEP:Holster( wep )
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:Deploy()
	Desc: Whip it out
-----------------------------------------------------------]]
function SWEP:Deploy()
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:ShootEffects()
	Desc: A convenience function to create shoot effects
-----------------------------------------------------------]]
function SWEP:ShootEffects()

	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )		-- View model animation
	self.Owner:MuzzleFlash()						-- Crappy muzzle light
	self.Owner:SetAnimation( PLAYER_ATTACK1 )		-- 3rd Person Animation

end

--[[---------------------------------------------------------
	Name: SWEP:ShootBullet()
	Desc: A convenience function to shoot bullets
-----------------------------------------------------------]]
function SWEP:ShootBullet( damage, num_bullets, aimcone, ammo_type, force, tracer )

	local bullet = {}
	bullet.Num		= num_bullets
	bullet.Src		= self.Owner:GetShootPos()			-- Source
	bullet.Dir		= self.Owner:GetAimVector()			-- Dir of bullet
	bullet.Spread	= Vector( aimcone, aimcone, 0 )		-- Aim Cone
	bullet.Tracer	= tracer || 5						-- Show a tracer on every x bullets
	bullet.Force	= force || 1						-- Amount of force to give to phys objects
	bullet.Damage	= damage
	bullet.AmmoType = ammo_type || self.Primary.Ammo

	self.Owner:FireBullets( bullet )

	self:ShootEffects()

end

function SWEP:TakePrimaryAmmo( num )

	-- Doesn't use clips
	if ( self:Clip1() <= 0 ) then

		if ( self:Ammo1() <= 0 ) then return end

		self.Owner:RemoveAmmo( num, self:GetPrimaryAmmoType() )

	return end

	self:SetClip1( self:Clip1() - num )

end

function SWEP:TakeSecondaryAmmo( num )

	-- Doesn't use clips
	if ( self:Clip2() <= 0 ) then

		if ( self:Ammo2() <= 0 ) then return end

		self.Owner:RemoveAmmo( num, self:GetSecondaryAmmoType() )

	return end

	self:SetClip2( self:Clip2() - num )

end

function SWEP:CanPrimaryAttack()

	if ( self:Clip1() <= 0 ) then

		self:EmitSound( "Weapon_Pistol.Empty" )
		self:SetNextPrimaryFire( CurTime() + 0.2 )
		self:Reload()
		return false

	end

	return true

end

function SWEP:CanSecondaryAttack()

	if ( self:Clip2() <= 0 ) then

		self:EmitSound( "Weapon_Pistol.Empty" )
		self:SetNextSecondaryFire( CurTime() + 0.2 )
		return false

	end

	return true

end
function SWEP:OwnerChanged() end
function SWEP:Ammo1() return self.Owner:GetAmmoCount( self:GetPrimaryAmmoType() ) end
function SWEP:Ammo2() return self.Owner:GetAmmoCount( self:GetSecondaryAmmoType() ) end
function SWEP:SetDeploySpeed( speed ) self.m_WeaponDeploySpeed = tonumber( speed ) end
function SWEP:DoImpactEffect( tr, nDamageType ) return false end

weapons.Register( SWEP, "weapon_bp" )

--[[SWEP.PrintName = "Custom Weapon"
SWEP.Author = "zak"
SWEP.Purpose = "This is a custom registered weapon."

SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_smg1.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_smg1.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.AdminOnly = true

game.AddParticles( "particles/hunter_flechette.pcf" )
game.AddParticles( "particles/hunter_projectile.pcf" )

local ShootSound = Sound( "NPC_Hunter.FlechetteShoot" )

function SWEP:Initialize()

	self:SetHoldType( "smg" )

end

function SWEP:Reload() end
function SWEP:CanBePickedUpByNPCs() return true end
function SWEP:PrimaryAttack()

	self:SetNextPrimaryFire( CurTime() + 0.1 )

	self:EmitSound( ShootSound )
	self:ShootEffects( self )

	if ( CLIENT ) then return end

	SuppressHostEvents( NULL ) -- Do not suppress the flechette effects

	local ent = ents.Create( "hunter_flechette" )
	if ( !IsValid( ent ) ) then return end

	local Forward = self.Owner:GetAimVector()

	ent:SetPos( self.Owner:GetShootPos() + Forward * 32 )
	ent:SetAngles( self.Owner:EyeAngles() )
	ent:SetOwner( self.Owner )
	ent:Spawn()
	ent:Activate()

		--2000
	ent:SetVelocity( Forward * 2000 )

end

function SWEP:SecondaryAttack() end
function SWEP:ShouldDropOnDie() return false end
function SWEP:GetNPCRestTimes() return 0.3, 0.6 end
function SWEP:GetNPCBurstSettings() return 1, 6, 0.1 end
function SWEP:GetNPCBulletSpread( proficiency ) return 1 end
]]