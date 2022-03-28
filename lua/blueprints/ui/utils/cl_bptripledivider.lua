if SERVER then AddCSLuaFile() return end

module("bpuitripledivider", package.seeall)

DRAG_NONE = 0
DRAG_LEFT = 1
DRAG_RIGHT = 2

local PANEL = {}

AccessorFunc( PANEL, "m_iDragMode",			"DragMode" )

function PANEL:Init()

	self:SetCursor( "sizewe" )
	--self:SetPaintBackground( false )

end

function PANEL:OnMousePressed( mcode )

	if ( mcode == MOUSE_LEFT ) then
		self:GetParent():StartGrab( self:GetDragMode() )
	end

end

derma.DefineControl( "BPTripleDividerBar", "", PANEL, "DPanel" )


local PANEL = {}

AccessorFunc( PANEL, "m_pLeft",				"Left" )
AccessorFunc( PANEL, "m_pRight",			"Right" )
AccessorFunc( PANEL, "m_pMiddle",			"Middle" )
AccessorFunc( PANEL, "m_iDividerWidth",		"DividerWidth" )
AccessorFunc( PANEL, "m_iLeftWidth",		"LeftWidth" )
AccessorFunc( PANEL, "m_iRightWidth",		"RightWidth" )
AccessorFunc( PANEL, "m_iDragging",			"Dragging" )

AccessorFunc( PANEL, "m_iLeftWidthMin",		"LeftMin" )
AccessorFunc( PANEL, "m_iRightWidthMin",	"RightMin" )

AccessorFunc( PANEL, "m_iHoldPos",			"HoldPos" )

function PANEL:Init()

	self:SetDividerWidth( 8 )
	self:SetLeftWidth( 100 )
	self:SetRightWidth( 100 )

	self:SetLeftMin( 50 )
	self:SetRightMin( 50 )

	self:SetPaintBackground( false )

	self.m_LeftDragBar = vgui.Create( "BPTripleDividerBar", self )
	self.m_LeftDragBar:SetDragMode( DRAG_LEFT )

	self.m_RightDragBar = vgui.Create( "BPTripleDividerBar", self )
	self.m_RightDragBar:SetDragMode( DRAG_RIGHT )

end

function PANEL:SetLeft( pnl )

	self.m_pLeft = pnl

	if ( IsValid( self.m_pLeft ) ) then
		self.m_pLeft:SetParent( self )
	end

end

function PANEL:SetMiddle( Middle )

	self.m_pMiddle = Middle

	if ( IsValid( self.m_pMiddle ) ) then
		self.m_pMiddle:SetParent( self )
	end

end

function PANEL:SetRight( pnl )

	self.m_pRight = pnl

	if ( IsValid( self.m_pRight ) ) then
		self.m_pRight:SetParent( self )
	end

end

function PANEL:GetRealLeftWidth()

	if not IsValid(self.m_pLeft) then return 0 end
	return self:GetLeftWidth()

end

function PANEL:GetRealRightWidth()

	if not IsValid(self.m_pRight) then return 0 end
	return self:GetRightWidth()

end

function PANEL:PerformLayout()

	self.m_LeftDragBar:SetPos( self:GetRealLeftWidth(), 0 )
	self.m_LeftDragBar:SetSize( self:GetDividerWidth(), self:GetTall() )
	self.m_LeftDragBar:SetZPos( -1 )

	self.m_RightDragBar:SetPos( self:GetWide() - self:GetRealRightWidth(), 0 )
	self.m_RightDragBar:SetSize( self:GetDividerWidth(), self:GetTall() )
	self.m_RightDragBar:SetZPos( -1 )

	if ( IsValid( self.m_pLeft ) ) then

		self.m_pLeft:StretchToParent( 0, 0, nil, 0 )
		self.m_pLeft:SetWide( self:GetRealLeftWidth() )
		self.m_pLeft:InvalidateLayout()

	end

	if ( IsValid( self.m_pMiddle ) ) then

		self.m_pMiddle:StretchToParent( self:GetRealLeftWidth() + self.m_LeftDragBar:GetWide(), 0, self:GetRealRightWidth(), 0 )
		self.m_pMiddle:InvalidateLayout()

	end

	if ( IsValid( self.m_pRight ) ) then

		self.m_pRight:StretchToParent( self:GetWide() - self:GetRealRightWidth() + (self.m_LeftDragBar:GetWide()), 0, 0, 0 )
		self.m_pRight:InvalidateLayout()

	end

end

function PANEL:OnCursorMoved( x, y )

	local mode = self:GetDragging()
	if mode == DRAG_NONE then return end

	if mode == DRAG_LEFT then

		local oldLeftWidth = self:GetLeftWidth()
		x = math.Clamp( x - self:GetHoldPos(), self:GetLeftMin(), self:GetWide() - self:GetRightMin() - self:GetDividerWidth() )
		self:SetLeftWidth( x )
		if oldLeftWidth ~= x then self:InvalidateLayout() end

	elseif mode == DRAG_RIGHT then

		local oldRightWidth = self:GetRightWidth()
		x = math.Clamp( x - self:GetHoldPos(), self:GetLeftMin(), self:GetWide() - self:GetRightMin() - self:GetDividerWidth() )
		self:SetRightWidth( self:GetWide() - x )
		if oldRightWidth ~= x then self:InvalidateLayout() end

	end

end

function PANEL:StartGrab( mode )

	self:SetCursor( "sizewe" )

	if mode == DRAG_LEFT then

		local x, y = self.m_LeftDragBar:CursorPos()
		self:SetHoldPos( x )

	elseif mode == DRAG_RIGHT then

		local x, y = self.m_RightDragBar:CursorPos()
		self:SetHoldPos( x )

	else

		error("Invalid grab mode: " .. tostring(mode))

	end

	self:SetDragging( mode )
	self:MouseCapture( true )

end

function PANEL:OnMouseReleased( mcode )

	if ( mcode == MOUSE_LEFT ) then
		self:SetCursor( "none" )
		self:SetDragging( DRAG_NONE )
		self:MouseCapture( false )
		self:SetCookie( "LeftWidth", self:GetLeftWidth() )
	end

end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )

	local ctrl = vgui.Create( ClassName )
	ctrl:SetSize( 512, 256 )
	ctrl:SetLeft( vgui.Create( "DButton" ) )
	ctrl:SetMiddle( vgui.Create( "DButton" ) )
	ctrl:SetRight( vgui.Create( "DButton" ) )

	PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )

end

derma.DefineControl( "BPTripleDivider", "", PANEL, "DPanel" )
