if SERVER then AddCSLuaFile() return end

module("bpuipinlistentry", package.seeall, bpcommon.rescope(bpschema))

local PANEL = {}
local tableIcon = Material("icon16/text_list_bullets.png")
local text_delete_pin = LOCTEXT("query_list_delete_pin", "Delete %s? This cannot be undone")

function PANEL:Init()

	self.AllowAutoRefresh = true

	self:SetMouseInputEnabled( true )
	self:SetKeyboardInputEnabled( true )

	self.typeSelector = vgui.Create("DButton", self)
	self.typeSelector:SetText("")
	function self.typeSelector.DoClick(btn)

		bpuivarcreatemenu.OpenPinSelectionMenu(self.module, function(pnl, pinType)
			self:SetPinType( pinType )
		end, self:GetPinType())

	end
	function self.typeSelector.Paint(btn, w, h) self:PaintSelector(w, h) end

	self.dclickTime = 0

	self.rmv = vgui.Create("DButton", self)
	self.rmv:SetWide(18)
	self.rmv:SetTextColor( Color(255,255,255) )
	self.rmv:SetText("X")
	self.rmv:SetDrawBorder(false)
	self.rmv:SetPaintBackground(false)
	self.rmv:Dock( RIGHT )
	self.rmv.DoClick = function( pnl )

		if self.vlist.noConfirm then
			self.vlist.list:Remove( self.item )
			return
		end

		Derma_Query(text_delete_pin( self:GetPinName() ),
		"",
		LOCTEXT("query_yes", "Yes")(),
		function() 
			self.vlist.list:Remove( self.item )
		end,
		LOCTEXT("query_no", "No")(),
		function() end)

	end

end

function PANEL:OnJustAdded()

	self:EditName()

end

function PANEL:OnRemove()

	self:CloseMenu()

end

function PANEL:OnMousePressed( code )

	if code == MOUSE_LEFT then
		self:RequestFocus()
		self.vlist:Select( self.item )
		if RealTime() - self.dclickTime < 0.5 then
			self:EditName()
		end
		self.dclickTime = RealTime()
	elseif code == MOUSE_RIGHT then
		self.vlist:Select( self.item )
		self:OpenMenu()
	end

end

function PANEL:OnKeyCodePressed( code )

	if code == KEY_DELETE then
		self.rmv:DoClick()
	elseif code == KEY_F2 then
		self:EditName()
	end

end

function PANEL:CloseMenu()

	if IsValid( self.menu ) then self.menu:Remove() end

end

function PANEL:OpenMenu()

	self:CloseMenu()

	self.menu = DermaMenu( false, self )

	self.menu:AddOption( LOCTEXT( "pin_edit_type", "Edit Type" )(), function() self.typeSelector:DoClick() end )
	self.menu:AddOption( LOCTEXT( "pin_edit_rename", "Rename" )(), function() self:EditName() end )
	self.menu:AddOption( LOCTEXT( "pin_edit_delete", "Delete" )(), function() self.rmv:DoClick() end )

	self.menu:SetMinimumWidth( 100 )
	self.menu:Open( gui.MouseX(), gui.MouseY(), false, self )

end

function PANEL:SetPinType( type ) end
function PANEL:SetPinName( name ) end
function PANEL:GetPinType() return bppintype.New( PN_Bool ) end
function PANEL:GetPinName() return "PIN" end

function PANEL:EditName()

	self.edit = vgui.Create("DTextEntry", self)
	self.edit:SetText(self:GetPinName())
	self.edit:RequestFocus()
	self.edit:SelectAllOnFocus()
	self.edit.OnFocusChanged = function(te, gained)
		if not gained then 
			self:SetPinName( te:GetText() )
			te:Remove()
		end
	end
	self.edit.OnEnter = function(te)
		self:SetPinName( te:GetText() )
		te:Remove()
	end

end

function PANEL:Paint(w,h)

	local pinType = self:GetPinType()
	local color = pinType:GetColor()

	if self.vlist:GetSelected() == self.item then
		draw.RoundedBox( 0, 0, 1, w-32, h-2, Color(80,80,80) )
	else
		draw.RoundedBox( 0, 0, 1, w-32, h-2, Color(50,50,50) )
	end
	draw.SimpleTextOutlined( self:GetPinName(), "DermaDefaultBold", 8, h/2, text_col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, color_black )

end

function PANEL:PaintSelector(w,h)

	local pinType = self:GetPinType()
	local color = pinType:GetColor()

	draw.RoundedBoxEx( 6, 0, 0, w, h, color, false, true, false, true )

	if pinType:HasFlag( PNF_Table ) then
		surface.SetDrawColor(color_black)
		surface.SetMaterial(tableIcon)
		surface.DrawTexturedRect(w-h-2,h/2 - 8,16,16)
	end

end

function PANEL:PerformLayout()

	local w,h = self:GetSize()

	self.typeSelector:SetSize(21,18)
	self.typeSelector:SetPos(w - 40,1)

	self:SetTall(20)

end

derma.DefineControl( "BPPinListEntry", "Blueprint pin entry", PANEL, "DPanel" )