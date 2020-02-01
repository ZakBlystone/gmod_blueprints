if SERVER then AddCSLuaFile() return end

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true

end

vgui.Register( "BPAssetBrowser", PANEL, "DPanel" )