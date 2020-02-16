if SERVER then AddCSLuaFile() return end

module("bpuipickmenu", package.seeall, bpcommon.rescope(bpschema, bpnodetype))

local G_PickerMenu = nil
local PANEL = {}

function OrFilter(a,b) return function(n) return a(n) or b(n) end end
function AndFilter(a,b) return function(n) return a(n) and b(n) end end

local function NodeNoAnim(node, expanded)

	if expanded then node:SetExpanded( expanded, true ) end
	node.Expander.DoClick = function() node:SetExpanded( !node.m_bExpanded, true ) end
	return node

end

function PANEL:OnEntrySelected( entry )

end

function PANEL:SortedOptions( filter, res, customSort )

	local options = {}
	local sort = customSort or self.sorter
	for k,v in self.collection:Items() do
		if filter(v) and not self:IsHidden(v) then options[#options+1] = v end
	end
	if sort then table.sort(options, sort) end
	for _, v in ipairs(options) do
		res( v )
	end

end

function PANEL:GetTooltip(entry)

	return tostring(entry)

end

function PANEL:GetDisplayName( entry )

	return tostring(entry)

end

function PANEL:GetIcon( entry )

	return "icon16/bullet_go.png"

end

function PANEL:GetCategory( entry )

	return nil

end

function PANEL:GetSubCategory( entry )

	return nil

end

function PANEL:GetEntryPanel( entry )

	return nil

end

function PANEL:IsHidden( entry )

	return false

end

function PANEL:SetSearchRanker( func )

	self.searchRanker = func
	return self

end

function PANEL:SetSorter( func )

	self.sorter = func
	return self

end

function PANEL:SetBaseFilter( func )

	self.baseFilter = func
	return self

end

function PANEL:SetCollection( collection )

	self.collection = collection
	return self

end

function PANEL:AddPage( name, desc, icon, filter, expanded )

	self.pages[#self.pages + 1] = {
		name = name,
		desc = desc,
		icon = icon,
		filter = filter or function() return true end,
		expanded = expanded,
	}

end

function PANEL:FilterBySubstring( str ) return function(n)
		return string.find( self:GetDisplayName(n):lower(), str, 1, true ) ~= nil
	end 
end

function PANEL:Select( entry )

	self:OnEntrySelected( entry )
	self:Remove()

end

function PANEL:Init()

	--self:SetBackgroundColor( Color(80,80,80) )

	hook.Add("BPEditorBecomeActive", tostring(self), function()
		if IsValid(self) then self:Remove() end
	end)

	self.timers = {}
	self.nextTimer = 0

	local function addTreeNode( p, name, icon, expanded, custom )

		if custom then

			p:CreateChildNodes()

			custom.SetLastChild = custom.SetLastChild or function() end
			custom.FilePopulate = custom.FilePopulate or function() end
			custom:SetParent( p )
			--custom:SetTall( p:GetLineHeight() )
			p:InstallDraggable( custom )
			p.ChildNodes:Add( custom )
			p:InvalidateLayout()
			return custom

		else
			local node = NodeNoAnim(p:AddNode(name, icon), expanded)
			node.Label:SetTextColor(color_white)
			return node
		end

	end

	local function addTreeEntry( p, entry, expanded )

		self.timers[#self.timers+1] = { t = self.nextTimer, f = function()

			local custom = self:GetEntryPanel(entry)
			local node = addTreeNode(p, self:GetDisplayName(entry), self:GetIcon(entry), expanded, custom )
			node.InternalDoClick = function() self:Select(entry) end
			local desc = self:GetTooltip(entry)
			if desc and desc ~= "" then
				if node.SetTooltip then node:SetTooltip(desc) end
			end

		end }
		self.nextTimer = self.nextTimer + 0.001

	end

	local function treeInserter( tree, tc, expanded )

		local function makeCat(p, x, y, z) if x == nil then return p end tc[p] = tc[p] or {} if tc[p][x] then return tc[p][x] end local c = addTreeNode(p, x, y, z or expanded) tc[p][x] = c return c end
		return function( entry )
			local p = tree
			if self:IsHidden( entry ) then return end
			p = makeCat(p, self:GetCategory( entry ))
			p = makeCat(p, self:GetSubCategory( entry ))
			addTreeEntry(p, entry, expanded)
		end

	end

	self.treeInserter = treeInserter

	self.search = vgui.Create("DTextEntry", self)
	self.search:DockMargin(5, 5, 5, 5)
	self.search:Dock( TOP )
	self.search:RequestFocus()
	self.search:SetUpdateOnType(true)
	self.search.OnValueChange = function(te, ...) self:OnSearchTerm(...) end

	self.resultList = vgui.Create("DTree", self )
	self.resultList:DockMargin(5, 0, 5, 5)
	self.resultList:Dock( FILL )
	self.resultList:SetVisible(false)
	self.resultList:SetBackgroundColor(Color(50,50,50))

	self.pages = {}

end

function PANEL:RunTimers()

	local ft = FrameTime()
	for i=1, #self.timers do
		local t = self.timers[i]
		if t.done then continue end
		t.t = t.t - ft
		if t.t <= 0 then
			t.done = true
			t.f()
		end
	end

	for i=#self.timers, 1, -1 do
		if self.timers[i].done then table.remove(self.timers,i) end
	end

end

function PANEL:Think()

	self:RunTimers()

end

function PANEL:Setup()

	if self.collection == nil then return end
	self.baseFilter = self.baseFilter or function() return true end

	if #self.pages > 0 then

		self.tabs = vgui.Create("DPropertySheet", self )
		self.tabs:DockMargin(5, 0, 5, 5)
		self.tabs:Dock( FILL )

		for _,v in ipairs(self.pages) do

			local tree = vgui.Create("DTree")
			tree:SetBackgroundColor(Color(50,50,50))
			self.tabs:AddSheet( v.name, tree, v.icon, false, false, v.desc )
			self:SortedOptions( AndFilter(self.baseFilter, v.filter), self.treeInserter(tree, {}, v.expanded) )

		end

	else

		self.tabs = vgui.Create("DTree", self )
		self.tabs:DockMargin(5, 0, 5, 5)
		self.tabs:Dock( FILL )
		self.tabs:SetBackgroundColor(Color(50,50,50))
		self:SortedOptions( self.baseFilter, self.treeInserter(self.tabs, {}, true) )

	end

end

local function DefaultSearchRanker( entry, query, queryLength, panel )

	local str = panel:GetDisplayName(entry):lower()
	local len = str:len() - queryLength
	if str == query then return len end
	if str:find(query) == 1 then return len + 100 end
	return len + 1000

end

function PANEL:OnSearchTerm( text )

	if self.collection == nil then return end

	if text:len() > 0 then

		self.resultList:SetVisible(true)
		self.tabs:SetVisible(false)

		self.timers = {}
		self.nextTimer = 0

		self.resultList:Clear()


		local search = text:lower()
		local searchLen = search:len()
		local f = self.searchRanker or DefaultSearchRanker
		local function SearchSort(a,b)
			local arank = f(a, search, searchLen, self)
			local brank = f(b, search, searchLen, self)
			if arank == brank then
				if self.sorter then return self.sorter(a, b) end
				return self:GetDisplayName(a) < self:GetDisplayName(b)
			else
				return arank < brank
			end
		end

		self:SortedOptions( AndFilter(self.baseFilter, self:FilterBySubstring( text:lower() ) ), self.treeInserter(self.resultList, {}, true), SearchSort )

	else

		self.resultList:SetVisible(false)
		self.tabs:SetVisible(true)

	end

end

function PANEL:Paint(w,h)

	surface.SetDrawColor( Color(80,80,80) )
	surface.DrawRect(0,0,w,h)

end

function PANEL:OnRemove()

	hook.Remove("BPEditorBecomeActive", tostring(self))

end

vgui.Register( "BPPickMenu", PANEL, "EditablePanel" )

function Create(x, y, w, h)

	if IsValid(G_PickerMenu) then G_PickerMenu:Remove() end

	x = x or gui.MouseX()
	y = y or gui.MouseY()

	local createMenu = vgui.Create("BPPickMenu")

	createMenu:SetWide(w or 400)
	createMenu:SetTall(h or 500)

	if x + createMenu:GetWide() > ScrW() then
		x = ScrW() - createMenu:GetWide()
	end

	if y + createMenu:GetTall() > ScrH() then
		y = ScrH() - createMenu:GetTall()
	end

	createMenu:SizeToContents( true, false )
	createMenu:SetPos(x,y)
	createMenu:SetVisible( true )
	createMenu:MakePopup()

	G_PickerMenu = createMenu

	return createMenu

end