if SERVER then AddCSLuaFile() return end

module("bpuicategorylist", package.seeall)

local PANEL = {}

function PANEL:Init()

	self.lblTitle:SetFont("DermaDefaultBold")

end

function PANEL:PerformLayout()

	local titlePush = 0

	if ( IsValid( self.imgIcon ) ) then

		self.imgIcon:SetPos( 5, 5 )
		self.imgIcon:SetSize( 16, 16 )
		titlePush = 16

	end

	self.btnClose:SetPos( self:GetWide() - 31 - 6, 2 )
	self.btnClose:SetSize( 31, 24 )

	self.btnMaxim:SetPos( self:GetWide() - 31 * 2 - 6, 2 )
	self.btnMaxim:SetSize( 31, 24 )

	self.btnMinim:SetPos( self:GetWide() - 31 * 3 - 6, 2 )
	self.btnMinim:SetSize( 31, 24 )

	self.lblTitle:SetPos( 10 + titlePush, 5 )
	self.lblTitle:SetSize( self:GetWide() - 25 - titlePush, 20 )

end

derma.DefineControl( "BPFrame", "", PANEL, "DFrame" )
