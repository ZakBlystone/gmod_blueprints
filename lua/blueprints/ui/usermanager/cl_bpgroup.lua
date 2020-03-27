if SERVER then AddCSLuaFile() return end

module("bpuigroup", package.seeall)

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetBackgroundColor( Color(30,30,30) )

	self.nameLabel = vgui.Create("DLabel", self)
	self.nameLabel:SetFont("DermaDefaultBold")
	self.nameLabel:SetText("GROUPNAME")

end

function PANEL:SetGroup( group )

	self.group = group
	self.nameLabel:SetText(group:GetName())

end

function PANEL:Paint(w, h)

	local r,g,b,a = self.group:GetColor():Unpack()
	draw.RoundedBox(4, 0, 0, w, h, Color(r,g,b,a))
	draw.RoundedBox(4, 1, 1, w-2, h-2, Color(r/2,g/2,b/2,a))

end

function PANEL:GetGroup()

	return self.group

end

function PANEL:PerformLayout()

	self.nameLabel:SetPos(4,0)

end

derma.DefineControl( "BPGroup", "Blueprint group", PANEL, "DPanel" )