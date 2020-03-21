if SERVER then AddCSLuaFile() return end

module("browser_model", package.seeall, bpcommon.rescope(bpschema))

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetText("ASSET NAME")
	self:SetTextColor(Color(255,255,255))
	self:SetFont("DermaDefaultBold")

end

function PANEL:SetInner( pnl )

	pnl:SetParent(self)
	pnl:SetMouseInputEnabled( false )
	pnl:SetKeyboardInputEnabled( false )
	self.inner = pnl

end

function PANEL:PerformLayout()

	if self.inner then

		local w,h = self:GetSize()
		local iw, ih = self.inner:GetSize()

		self.inner:SetPos((w - iw)/2, ((h-16) - ih)/2)

		local x,y = self.inner:GetPos()
		local bottom = (h - (self.inner:GetTall() + y))

		self:SetTextInset(16,h/2 - math.min(bottom/2,16 ))

	end

end

function PANEL:Paint(w,h)

	local r,g,b,a = 80,80,80,255

	if self.Hovered then
		r = 180
		g = 120
	end

	draw.RoundedBox(4, 0, 0, w, h, Color(r,g,b,a))
	draw.RoundedBox(4, 1, 1, w-2, h-2, Color(r/2,g/2,b/2,a))

	if self.inner then

		local x,y = self.inner:GetPos()
		local iw, ih = self.inner:GetSize()
		draw.RoundedBox(0, x, y, iw, ih, Color(r/3,g/3,b/3,a))

	end

end

derma.DefineControl( "BPTilePanel", "Tile Panel", PANEL, "DButton" )

local BROWSER = {}

BROWSER.Title = "Model"
BROWSER.AssetPath = "models"
BROWSER.AllowedExtensions = {
	[".mdl"] = true,
}

function BROWSER:PopulateFromFolder( folder, path )

	local res = self:GetResultsPanel()

	res:Clear()

	for _, child in ipairs(folder.children) do
		if not child.isFile then continue end

		local mdlName = string.Replace( string.GetFileFromFilename( child.path ), ".mdl", "" )
		local tile = vgui.Create("BPTilePanel")
		tile:SetSize(128,128)
		tile:SetText( mdlName )
		tile:SetTooltip( mdlName )
		tile.DoClick = function( pnl ) self:ChooseAsset( child.path ) end

		local icon = vgui.Create( "ModelImage" )
		icon:SetSize(92,92)
		icon:SetModel( child.path ) --iSkin, BodyGroups
		tile:SetInner( icon )

		res:Add( tile )

	end

	res:InvalidateLayout(true)

end

RegisterAssetBrowserClass("model", BROWSER)