AddCSLuaFile()

module("pin_wildcard", package.seeall, bpcommon.rescope(bpschema))

local PIN = {}

function PIN:Setup()

	self:UpdateGhost()

end

function PIN:GetGhostTable( create )

	local node = self:GetNode()
	if create then
		node.data.pinGhosts = node.data.pinGhosts or {}
	end
	return node.data.pinGhosts

end

function PIN:SetGhost( pinType )

	local gt = self:GetGhostTable( true )
	gt[self.id] = pinType
	self:UpdateGhost()

end

function PIN:UpdateGhost()

	local gt = self:GetGhostTable()
	if not gt or not gt[self.id] then return end

	setmetatable(gt[self.id], bppintype_meta)

	if gt[self.id]:GetBaseType() == PN_Any then

		setmetatable(self, bppin_meta)
		gt[self.id] = nil
		self:SetInformedType( nil )

	else

		self.pinClass = nil
		local pmeta = table.Copy(bppin_meta)

		pmeta.OnRightClick = PIN.OnRightClick
		pmeta.SetGhost = PIN.SetGhost
		pmeta.GetGhostTable = PIN.GetGhostTable
		pmeta.UpdateGhost = PIN.UpdateGhost

		setmetatable(self, pmeta)
		self:SetInformedType( gt[self.id] )

	end

end

function PIN:OnRightClick()

	local gt = self:GetGhostTable()
	if self.informed and (not gt or not gt[self.id]) then return end

	local node = self:GetNode()
	local mod = node:GetModule()
	bpuivarcreatemenu.OpenPinSelectionMenu( mod, function( pnl, pinType )
		self:SetGhost( pinType )
		self:SetLiteral( self:GetDefault() )
	end, self:GetType(true), false )

end

RegisterPinClass("Wild", PIN)