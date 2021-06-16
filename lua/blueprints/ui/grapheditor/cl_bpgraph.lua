if SERVER then AddCSLuaFile() return end

module("bpuigraph", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local PANEL = {}

surface.CreateFont( "GraphTitle", {
	font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
	extended = false,
	size = 52,
	weight = 1200,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

function PANEL:Init()

end

function PANEL:GetGraph()

	return self.graph

end

function PANEL:GetEditor()

	return self.editor

end

function PANEL:SetGraph( graph )

	if self.editor then self.editor:Shutdown() end

	self.graph = graph
	self.editor = bpgrapheditor.New( self )
	self.interface = bpgrapheditorinterface.New( self.editor, self )

	self.editor:CreateAllNodes()
	self:CenterToOrigin()

end

function PANEL:Draw2D()

	if self.interface ~= nil then self.interface:Draw(self:GetSize()) end

end

function PANEL:DrawOverlay()

	if self.interface ~= nil then self.interface:DrawOverlay(self:GetSize()) end

end

function PANEL:EditThink()

	if self.editor then self.editor:Think() end

end

function PANEL:OnRemove()

	if self.editor then self.editor:Shutdown() end

end

function PANEL:LeftMouse(x,y,pressed) return self.editor:LeftMouse(x,y,pressed) end
function PANEL:RightMouse(x,y,pressed) return self.editor:RightMouse(x,y,pressed) end
function PANEL:MiddleMouse(x,y,pressed) return self.editor:MiddleMouse(x,y,pressed) end
--function PANEL:RightClick() self.editor:OpenCreationContext() end
function PANEL:AnyPress() self.editor:CloseCreationContext() end

function PANEL:OnKeyCodePressed( code )

	if self.editor == nil then return end

	self.editor:KeyPress(code)

end

function PANEL:OnKeyCodeReleased( code )

	if self.editor == nil then return end

	self.editor:KeyRelease(code)

end

derma.DefineControl( "BPGraph", "Blueprint graph renderer", PANEL, "BPViewport2D" )
