if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpnodetype.lua")

module("bpuicreatemenu", package.seeall, bpcommon.rescope(bpschema, bpnodedef, bpnodetype))


local PANEL = {}

local function DisplayName(nodeType)
	return nodeType:GetDisplayName()
end

local function NodeIcon(nodeType)
	local role = nodeType:GetRole()
	if role == ROLE_Server then return "icon16/bullet_blue.png" end
	if role == ROLE_Client then return "icon16/bullet_orange.png" end
	if role == ROLE_Shared then return "icon16/bullet_purple.png" end
	return "icon16/bullet_white.png"
end

local function SortedFilteredNodeList( graph, filter, res )
	local options = {}
	local types = graph:GetNodeTypes()
	for k,v in pairs(types) do
		if filter(v) and not v.hidden then table.insert(options, k) end
	end
	table.sort(options, function(a,b) return DisplayName(types[a]) < DisplayName(types[b]) end)
	for _, v in pairs(options) do
		res( v, types[v] )
	end
end

local function FilterByType( filterType ) return function(n) 
		return n.type == filterType 
	end 
end

local function FilterByPinType( pinType ) return function(n) 
		for _, pin in pairs(n.pins) do 
			if pin:GetType():Equal(pinType, 0) then return true end 
		end 
		return false 
	end 
end

local function FilterBySubstring( str ) return function(n)
		return string.find( DisplayName(n):lower(), str, 1, true ) ~= nil
	end 
end

local function OrFilter(a,b) return function(n) return a(n) or b(n) end end
local function AndFilter(a,b) return function(n) return a(n) and b(n) end end

local function NodeNoAnim(node, expanded)

	if expanded then node:SetExpanded( expanded, true ) end
	node.Expander.DoClick = function() node:SetExpanded( !node.m_bExpanded, true ) end
	return node

end

function PANEL:OnNodeTypeSelected( nodeType )

end

function PANEL:Init()

	--self:SetBackgroundColor( Color(80,80,80) )
	
	local function inserter( list )
		return function( name, nodeType )
			local c = NodeTypeColors[nodeType:GetType()]
			local cx = Color(c.r/2, c.g/2, c.b/2, 255)
			local item = list:AddItem( nodeType:GetDisplayName() or name )
			item:SetFont("DermaDefaultBold")
			item:SetColor( Color(255,255,255) )
			item.DoClick = function()
				self:OnNodeTypeSelected( nodeType )
				self:Remove()
			end
			item.Paint = function( self, w, h )
				draw.RoundedBox( 0, 0, 0, w, h, cx )
				if ( self.Hovered ) then
					draw.RoundedBox( 0, 0, 0, w, h, Color( 255, 255, 255, 80 ) )
				end
			end
		end
	end

	local function treeItemClick( nodeType )
		self:OnNodeTypeSelected( nodeType )
		self:Remove()
	end

	self.timers = {}
	self.nextTimer = 0

	local function addTreeNode( p, name, icon, expanded )
		local node = NodeNoAnim(p:AddNode(name, icon), expanded)
		node.Label:SetTextColor(color_white)
		return node
	end

	local function addTreeBPNode( p, nodeType, expanded )
		table.insert(self.timers, { t = self.nextTimer, f = function()
			local node = addTreeNode(p, DisplayName(nodeType), NodeIcon(nodeType), expanded)
			node.InternalDoClick = function() treeItemClick(nodeType) end
			local desc = nodeType:GetDescription()
			if desc and desc ~= "" then
				node:SetTooltip(desc)
			end
		end })
		self.nextTimer = self.nextTimer + 0.001
	end

	local function treeInserter( tree, tc, expanded )
		local function makeCat(p, x, y, z) tc[p] = tc[p] or {} if tc[p][x] then return tc[p][x] end local c = addTreeNode(p, x, y, z or expanded) tc[p][x] = c return c end
		return function( name, nodeType )
			local p = tree
			makeCat(p, "Classes", "icon16/bricks.png")
			makeCat(p, "Libs", "icon16/brick.png")
			makeCat(p, "Hooks", "icon16/connect.png")
			makeCat(p, "Structs", "icon16/table.png")
			local context = nodeType:GetContext()
			local category = nodeType:GetCategory()
			if nodeType:HasFlag(NTF_Deprecated) then return end
			if context == NC_Hook then
				p = makeCat(p, "Hooks", "icon16/connect.png")
				if category then p = makeCat(p, category, "icon16/bullet_go.png") end
				addTreeBPNode(p, nodeType, expanded)
			elseif context == NC_Class then
				p = makeCat(p, "Classes", "icon16/bricks.png")
				if category then p = makeCat(p, category, "icon16/bullet_go.png") end
				addTreeBPNode(p, nodeType, expanded)
			elseif context == NC_Lib then
				p = makeCat(p, "Libs", "icon16/brick.png")
				if category then p = makeCat(p, category, "icon16/bullet_go.png") end
				addTreeBPNode(p, nodeType, expanded)
			elseif context == NC_Struct then
				p = makeCat(p, "Structs", "icon16/table.png")
				if category then p = makeCat(p, category, "icon16/bullet_go.png", true) end
				addTreeBPNode(p, nodeType, expanded)
			else
				p = makeCat(p, "Other")
				if category then p = makeCat(p, category, "icon16/bullet_go.png") end
				addTreeBPNode(p, nodeType, expanded)
			end
		end
	end

	self.inserter = inserter
	self.treeInserter = treeInserter

	self.search = vgui.Create("DTextEntry", self)
	self.search:DockMargin(5, 5, 5, 5)
	self.search:Dock( TOP )
	self.search:RequestFocus()
	self.search:SetUpdateOnType(true)
	self.search.OnValueChange = function(te, ...) self:OnSearchTerm(...) end


	self.tabs = vgui.Create("DPropertySheet", self )
	self.tabs:DockMargin(5, 0, 5, 5)
	self.tabs:Dock( FILL )

	self.resultList = vgui.Create("DTree", self )
	self.resultList:DockMargin(5, 0, 5, 5)
	self.resultList:Dock( FILL )
	self.resultList:SetVisible(false)
	self.resultList:SetBackgroundColor(Color(50,50,50))

	self:SetWide(400)
	self:SetTall(500)

	self:SizeToContents( true, false )

end

function PANEL:RunTimers()

	local ft = FrameTime()
	for i=#self.timers, 1, -1 do
		local t = self.timers[i]
		t.t = t.t - ft
		if t.t <= 0 then
			t.f()
			table.remove(self.timers, i)
		end
	end

end

function PANEL:Think()

	self:RunTimers()

end

function PANEL:Setup( graph, pinFilter )

	self.graph = graph
	self.graph:CacheNodeTypes() -- ensure we have the latest types

	local function makeSearchPage( name, desc, icon, func, autoExpand )
		local tree = vgui.Create("DTree")
		tree:SetBackgroundColor(Color(50,50,50))
		self.tabs:AddSheet( name, tree, icon, false, false, "All nodes" )
		SortedFilteredNodeList( self.graph, func, self.treeInserter(tree, {}, autoExpand) )
	end

	local baseFilter = function() return true end

	if pinFilter then

		local pf = pinFilter

		baseFilter = function(ntype)
			local pin = FindMatchingPin(ntype, pf)
			return pin ~= nil and ntype.pins[pin]:GetDir() ~= pf:GetDir()
		end

	end

	self.baseFilter = baseFilter

	local entityType = bppintype.New(PN_Ref, PNF_None, "Entity")
	local playerType = bppintype.New(PN_Ref, PNF_None, "Player")
	local anyType = bppintype.New(PN_Any, PNF_None)

	makeSearchPage("All", "All nodes", "icon16/book.png", baseFilter, pinFilter ~= nil)
	makeSearchPage("Hooks", "Hook nodes", "icon16/connect.png", AndFilter(baseFilter, FilterByType(NT_Event)), true)
	makeSearchPage("Entity", "Entity nodes", "icon16/bricks.png", AndFilter(baseFilter, FilterByPinType(entityType)), true)
	makeSearchPage("Player", "Player nodes", "icon16/user.png", AndFilter(baseFilter, FilterByPinType(playerType)), true)
	makeSearchPage("Special", "Special nodes", "icon16/plugin.png", OrFilter( FilterByType(NT_Special), FilterByPinType(anyType) ), true)
	makeSearchPage("Custom", "User created nodes", "icon16/wrench.png", AndFilter(baseFilter, function(n) return n.custom == true end), true)

end

function PANEL:OnSearchTerm( text )

	if text:len() > 0 then
		self.resultList:SetVisible(true)
		self.tabs:SetVisible(false)

		self.timers = {}
		self.nextTimer = 0

		self.resultList:Clear()
		SortedFilteredNodeList( self.graph, AndFilter(self.baseFilter, FilterBySubstring( text:lower() ) ), self.treeInserter(self.resultList, {}, true) )
	else
		self.resultList:SetVisible(false)
		self.tabs:SetVisible(true)
	end

end

function PANEL:Paint(w,h)

	surface.SetDrawColor( Color(80,80,80) )
	surface.DrawRect(0,0,w,h)

end

vgui.Register( "BPCreateMenu", PANEL, "EditablePanel" )