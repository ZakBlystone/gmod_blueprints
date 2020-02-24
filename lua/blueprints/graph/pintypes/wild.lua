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

local function SetAllInforms( fromPin, node, pinType )

	local isInformed = false

	node:GetPin(fromPin):SetInformedType( pinType )

	--[[for k, v in ipairs(node:GetInforms()) do
		if v == fromPin then isInformed = true break end
	end

	if isInformed then
		node.customInformed = pinType ~= nil
		for k, v in ipairs(node:GetInforms()) do
			if v ~= fromPin then
				local pin = node:GetPin(v)
				if pin:GetInformedType() ~= pinType then
					local base = pin:GetType(true)
					pin:SetInformedType( pinType ~= nil and pinType:WithFlags(base:GetFlags()) or pinType )
					pin:SetLiteral( pin:GetDefault() )
				end
			end
		end
	end]]

end

function PIN:UpdateGhost()

	local gt = self:GetGhostTable()
	if not gt or not gt[self.id] then return end

	setmetatable(gt[self.id], bppintype_meta)

	if gt[self.id]:GetBaseType() == PN_Any then

		setmetatable(self, bppin_meta)
		gt[self.id] = nil

		SetAllInforms( self.id, self:GetNode(), nil )

	else

		local pmeta = table.Copy(bppin_meta)

		pmeta.OnRightClick = PIN.OnRightClick
		pmeta.SetGhost = PIN.SetGhost
		pmeta.GetGhostTable = PIN.GetGhostTable
		pmeta.UpdateGhost = PIN.UpdateGhost

		setmetatable(self, pmeta)

		SetAllInforms( self.id, self:GetNode(), gt[self.id] )

	end

end

function PIN:OnRightClick()

	local gt = self:GetGhostTable()
	if self.informed and (not gt or not gt[self.id]) then return end

	-- Doesn't work properly with inform system yet
	for k, v in ipairs(self:GetNode():GetInforms()) do
		if v == self.id then return end
	end

	local node = self:GetNode()
	local mod = node:GetModule()
	bpuivarcreatemenu.OpenPinSelectionMenu( mod, function( pnl, pinType )
		node:PreModify()
		self:SetGhost( pinType )
		self:SetLiteral( self:GetDefault() )
		node:PostModify()
	end, self:GetType(true), false )

end

RegisterPinClass("Wild", PIN)