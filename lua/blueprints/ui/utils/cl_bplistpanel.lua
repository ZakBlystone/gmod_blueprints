if SERVER then AddCSLuaFile() return end

module("bpuilistpanel", package.seeall)

local PANEL = {}

function PANEL:Init()

	self:SetKeyboardInputEnabled( true )
	self:SetBackgroundColor( Color(30,30,30) )
	self.selectedID = nil
	self.vitems = {}

end

function PANEL:Paint()

end

function PANEL:CreateItemPanel( id, item )

	local panel = vgui.Create("DPanel")
	panel:SetMouseInputEnabled( true )
	panel:SetKeyboardInputEnabled( true )

	local icon = self:ItemIcon( id, item )

	local btn = vgui.Create("DLabel", panel)
	btn:SetTextColor( Color(255,255,255) )
	btn:SetFont("DermaDefaultBold")
	btn:SetText( item:GetName() or "unnamed" )
	btn:DockMargin( 8,0,2,0 )
	btn:Dock( FILL )

	if icon ~= nil then
	
		local img = vgui.Create("DImage", panel)
		img:SetImage( icon )
		img:SetSize(10,16)
		img:DockMargin( 4,6,0,6 )
		img:Dock( LEFT )

	end

	local rmv = vgui.Create("DButton", panel)
	rmv:SetWide(18)
	rmv:SetTextColor( Color(255,255,255) )
	rmv:SetText("X")
	rmv:SetDrawBorder(false)
	rmv:SetPaintBackground(false)
	rmv:Dock( RIGHT )

	panel.btn = btn
	panel.id = id
	panel:SetTall(20)

	panel.OnKeyCodePressed = function( pnl, code )

		if code == KEY_DELETE then
			rmv:DoClick()
		elseif code == KEY_F2 then
			self:Rename(id)
		end

	end

	panel.OnMousePressed = function( pnl, code )
		if code == MOUSE_LEFT then
			self:Select(id)
			pnl:RequestFocus()
		elseif code == MOUSE_RIGHT then
			self:OpenMenu(id, item)
		end
	end

	panel.Paint = function( pnl, w, h )

		local col = self:ItemBackgroundColor(id, item, self.selectedID == id)
		surface.SetDrawColor( col )
		surface.DrawRect(0,0,w,h)

	end

	panel.label = btn

	rmv.DoClick = function( pnl )

		if self.noConfirm then
			self.list:Remove( id )
			return
		end

		Derma_Query("Delete " .. item:GetName() .. "? This cannot be undone",
		"",
		"Yes",
		function() 
			self.list:Remove( id )
		end,
		"No",
		function() end)

	end

	return panel

end

function PANEL:SetNoConfirm()

	self.noConfirm = true
	return self

end

function PANEL:SetList( list )

	if self.list then self.list:UnbindAll(self) end

	self:Clear()

	if list == nil then return end

	self.list = list
	self.list:Bind("added", self, self.ItemAdded)
	self.list:Bind("removed", self, self.ItemRemoved)
	self.list:Bind("renamed", self, self.ItemRenamed)
	self.list:Bind("cleared", self, self.Clear)

	for id, item in self.list:Items() do
		self:ItemAdded(id, item)
	end

end

function PANEL:OnRemove()

	if self.list then self.list:UnbindAll(self) end

end

function PANEL:ItemAdded(id, item)

	local panel = self:CreateItemPanel( id, item )
	if panel == nil then return end

	self:AddItem( panel )
	self:GetParent():InvalidateLayout(true)

	if self.invokeAdd and panel.OnJustAdded then
		panel:OnJustAdded()
	end

	self.vitems[id] = panel

	if self.selectedID == nil then
		self.selectedID = id
		self:OnItemSelected( id, item )
	end

	self.selectedID = id

end

function PANEL:ItemRenamed(id, prev, new)

	if self.vitems[id].label then
		self.vitems[id].label:SetText(new)
	end

end

function PANEL:ItemRemoved(id, item)

	local panel = self.vitems[id]
	if panel ~= nil then
		self:RemoveItem( panel )
		self:GetParent():InvalidateLayout(true)
		self.vitems[id] = nil
	end

	if self:GetSelectedID() == id then
		self:Select(nil)
	end

end

function PANEL:ClearSelection()

	self.selectedID = nil

end

function PANEL:Select(id)

	if self.selectedID ~= id or self.alwaysSelect then
		self.selectedID = id
		self:OnItemSelected( id, id and self.list:Get(id) or nil )
	end

end

function PANEL:GetSelectedID()

	return self.selectedID

end

function PANEL:OnItemSelected( id, item )

end

function PANEL:Clear()

	for _, v in pairs(self.vitems) do
		self:RemoveItem( v )
	end
	self.vitems = {}
	self:GetParent():InvalidateLayout(true)

end

function PANEL:ItemBackgroundColor( id, item, selected )

	return selected and Color(80,80,80,255) or Color(50,50,50,255)

end

function PANEL:ItemIcon( id, item )

	return nil

end

function PANEL:CloseMenu()

	if IsValid( self.menu ) then
		self.menu:Remove()
	end

end

function PANEL:OpenMenu( id )

	--print("OPEN MENU: " .. id)

	self:CloseMenu()

	self.menu = DermaMenu( false, self )

	local t = {}
	t[#t+1] = { name = "Rename", func = function() self:Rename(id) end }

	self:PopulateMenuItems(t, id)
	for _, v in ipairs(t) do
		self.menu:AddOption( tostring(v.name), v.func )
	end

	self.menu:SetMinimumWidth( 100 )
	self.menu:Open( gui.MouseX(), gui.MouseY(), false, self )

end

function PANEL:PopulateMenuItems( items, id )

end

function PANEL:HandleAddItem( list )

end

function PANEL:Rename( id )

	local item = self.list:Get(id)

	for _, v in pairs(self.vitems) do
		if v.id == id then
			v.btn:SetVisible(false)
			v.edit = vgui.Create("DTextEntry", v)
			v.edit:SetText(item:GetName() or "unnamed")
			v.edit:RequestFocus()
			v.edit:SelectAllOnFocus()
			v.edit.OnFocusChanged = function(te, gained)
				if not gained then 
					self.list:Rename( id, te:GetText() )
					v.btn:SetVisible(true)
					te:Remove()
				end
			end
			v.edit.OnEnter = function(te)
				self.list:Rename( id, te:GetText() )
				v.btn:SetVisible(true)
				te:Remove()
			end
		end
	end

end

function PANEL:InvokeAdd()

	self.invokeAdd = true
	self:HandleAddItem(self.list)
	self.invokeAdd = false

end

vgui.Register( "BPListPanel", PANEL, "DPanelList" )