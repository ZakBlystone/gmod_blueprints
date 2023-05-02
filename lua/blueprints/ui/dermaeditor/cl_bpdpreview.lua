if SERVER then AddCSLuaFile() return end

module("bpuidpreview", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local PANEL = {}

local ZoomLevels = {
	{2.0, "2x"},
	{1.5, "1.5x"},
	{1.0, "1:1"},
	{0.75, "0.75x"},
	{0.5, "0.5x"},
}

function PANEL:Init()

	self:InitRenderer()

end

function PANEL:GetDefaultZoomLevel() return 3 end
function PANEL:GetZoomLevels() return ZoomLevels end

function PANEL:DrawSelectionBox(pnl)

	local px, py = pnl:GetPos()
	local lx, ly = self:LocalToScreen(-px, -py)

	local bx, by = -lx, -ly
	local bw, bh = pnl:GetSize()

	surface.SetDrawColor(100,255,100,80)
	surface.DrawRect(bx, by, 2, bh)
	surface.DrawRect(bx, by, bw, 2)
	surface.DrawRect(bx+bw-2, by, 2, bh)
	surface.DrawRect(bx, by+bh-2, bw, 2)

	draw.SimpleText( pnl:GetClassName(), "DermaDefault", bx, by )

end

function PANEL:DrawSelectionBoxAll(pnl)

	self:DrawSelectionBox(pnl)
	for _, ch in pairs(pnl:GetChildren()) do
		self:DrawSelectionBoxAll(ch)
	end

end

function PANEL:Draw2D()

	if IsValid(self.preview) then
		self.preview:PaintAt(0,0)
		--self:DrawSelectionBoxAll(self.preview)
	end

end

function PANEL:SetPanel(pnl)

	self.preview = pnl

end

derma.DefineControl( "BPDPreview", "Blueprint derma preview renderer", PANEL, "BPViewport2D" )
