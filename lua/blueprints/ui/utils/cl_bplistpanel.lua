if SERVER then AddCSLuaFile() return end

module("bpuilistpanel", package.seeall)

local text_delete_item = LOCTEXT("query_list_delete_item", "Delete %s? This cannot be undone")
local PANEL = {}
GROUPS = setmetatable({}, {__mode = "k"})

function PANEL:Init()

	self:SetKeyboardInputEnabled( true )
	self:SetBackgroundColor( Color(30,30,30) )
	self.selected = bpcommon.Weak()
	self.vitems = setmetatable({}, {__mode = "k"})

end

function PANEL:SetGroup( id )

	if id == nil then
		if self.group then
			table.RemoveByValue(self.group, self)
		end
		return
	end

	GROUPS[id] = GROUPS[id] or {}
	local group = GROUPS[id]
	if not table.HasValue(group, self) then
		group[#group+1] = self
		self.group = group
	end

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
	panel.item = item
	panel:SetTall(20)

	panel.OnKeyCodePressed = function( pnl, code )

		if code == KEY_DELETE then
			rmv:DoClick()
		elseif code == KEY_F2 then
			self:Rename(item)
		end

	end

	panel.OnMousePressed = function( pnl, code )
		if code == MOUSE_LEFT then
			self:Select(item)
			pnl:RequestFocus()
		elseif code == MOUSE_RIGHT then
			self:OpenMenu(item)
		end
	end

	panel.Paint = function( pnl, w, h )

		local col = self:ItemBackgroundColor(item, self.selected() == pnl.item )
		surface.SetDrawColor( col )
		surface.DrawRect(0,0,w,h)

	end

	panel.label = btn

	rmv.DoClick = function( pnl )

		if self.noConfirm then
			self.list:Remove( item )
			return
		end

		bpmodal.Query({
			message = text_delete_item(item:GetName()),
			options = {
				{"yes", function() 
					self.list:Remove( item )
				end},
				{"no", function() end},
			},
		})

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
	self:SetGroup(nil)

end

function PANEL:ItemAdded(id, item)

	local panel = self:CreateItemPanel( id, item )
	if panel == nil then return end

	self:AddItem( panel )
	self:GetParent():InvalidateLayout(true)

	if self.invokeAdd and panel.OnJustAdded then
		panel:OnJustAdded()
	end

	self.vitems[item] = panel

	if self.selectedID == nil then
		self.selectedID = id
		self:OnItemSelected( item )
	end

	self.selectedID = id

end

function PANEL:ItemRenamed(id, item, prev, new)

	if self.vitems[item].label then
		self.vitems[item].label:SetText(new)
	end

end

function PANEL:ItemRemoved(id, item)

	local panel = self.vitems[item]
	if panel ~= nil then
		self:RemoveItem( panel )
		self:GetParent():InvalidateLayout(true)
		self.vitems[item] = nil
	end

	if self:GetSelected() == item then
		self:Select(nil)
	end

end

function PANEL:ClearSelection()

	self.selected:Reset()

end

function PANEL:Select(item)

	if self.group then
		for _,v in ipairs(self.group) do
			if v ~= self and v.selected() ~= nil then 
				v:ClearSelection()
				v:OnItemSelected(nil)
			end
		end
	end

	if self.selected() ~= item then
		self.selected:Set(item)
		self:OnItemSelected( item, false )
	else
		self:OnItemSelected( item, true )
	end

end

function PANEL:GetSelected()

	return self.selected()

end

function PANEL:OnItemSelected( item, reselected )

end

function PANEL:Clear()

	for _, v in pairs(self.vitems) do
		self:RemoveItem( v )
	end
	self.vitems = {}
	self:GetParent():InvalidateLayout(true)

end

function PANEL:ItemBackgroundColor( item, selected )

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

function PANEL:OpenMenu(item )

	--print("OPEN MENU: " .. id)

	self:CloseMenu()

	local t = {}
	t[#t+1] = { name = LOCTEXT("list_rename","Rename"), func = function() self:Rename(item) end }

	self:PopulateMenuItems(t, item)
	self.menu = bpmodal.Menu({
		options = bpcommon.Transform(t, {}, function(v) return { title = v.name, func = v.func } end),
		width = 100,
	})

end

function PANEL:PopulateMenuItems( items, item )

end

function PANEL:HandleAddItem( list )

end

function PANEL:Rename( item )

	for _, v in pairs(self.vitems) do
		if v.item == item then
			v.btn:SetVisible(false)
			v.edit = vgui.Create("DTextEntry", v)
			v.edit:SetText(item:GetName() or "unnamed")
			v.edit:RequestFocus()
			v.edit:SelectAllOnFocus()
			v.edit.OnFocusChanged = function(te, gained)
				if not gained then 
					self.list:Rename( item, te:GetText() )
					v.btn:SetVisible(true)
					te:Remove()
				end
			end
			v.edit.OnEnter = function(te)
				self.list:Rename( item, te:GetText() )
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