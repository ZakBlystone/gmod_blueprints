local meta = bpcommon.MetaTable("bpassetbrowser")
local browserClasses = bpclassloader.Get("AssetBrowser", "blueprints/ui/assetbrowser/browsers/", "BPAssetBrowserClassRefresh", meta)

if SERVER then AddCSLuaFile() return end

G_BPAssetFolderCache = G_BPAssetFolderCache or {}

module("bpuiassetbrowser", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

meta.AssetPath = ""
meta.AllowedExtensions = {}
meta.Title = "None"
meta.MaxSearchResults = 500

function meta:Init( type, callback )

	browserClasses:Install( type, self )
	self.type = type
	self.callback = callback
	self.vgui = {}
	self.pendingCount = 0

	bpcommon.ProfileStart("asset-browser-build")

	local cached = G_BPAssetFolderCache[type]
	if not cached then
		self.rootNode = { file = "", isRoot = true, children = {}, numFolders = 0, numFiles = 0, }
		self.__nodePtr = self.rootNode
		self:BuildRootFolders( self.rootNode )
		G_BPAssetFolderCache[type] = self.rootNode
	else
		self.rootNode = cached
	end

	bpcommon.ProfileEnd()

	return self

end

function meta:FileExtensionAllowed( fileExt )

	return self.AllowedExtensions[ fileExt or "" ]

end

function meta:DoPathFixup( path ) return path end
function meta:RecursiveBuildFolders( node, path, pathType )

	local files, folders = file.Find(path .. "/*", pathType)

	if files == nil then return end
	if #folders == 0 and #files == 0 then return end

	for _, v in ipairs(folders) do
		local folder = self:FolderNode( node, v, v )
		local inner = path .. "/" .. v
		folder.path = self:DoPathFixup(inner)
		folder.pathType = pathType
		self:RecursiveBuildFolders( folder, inner, pathType )
	end

	for _,v in ipairs(files) do
		local ext = v:match("%.%w+")
		if self:FileExtensionAllowed( ext ) then
			local entry = self:EntryNode( node, v )
			entry.path = self:DoPathFixup( path .. "/" .. v )
			entry.pathType = pathType
		end
	end

end

function meta:CreateLayout( parent )

	self.split = vgui.Create( "DHorizontalDivider", parent )
	self.split:Dock( FILL )
	self.split:SetLeftWidth(200)

	self.scroll = vgui.Create( "DScrollPanel", self.split )
	self.results = self:CreateResultsPanel(self.scroll)

	self.explorer = vgui.Create( "DPanel", self.split )
	self.explorer.Paint = function() end

	self.search = vgui.Create( "DTextEntry", self.explorer )
	self.search:Dock( TOP )
	self.search:SelectAllOnFocus()
	self.search:SetTabPosition( 1 )
	self.search:SetUpdateOnType( true )
	self.search.OnValueChange = function( pnl, value )
		self:PopulateSearchTerm( value )
	end

	self.search:RequestFocus()

	self.tree = vgui.Create( "DTree", self.explorer )
	self.tree:Dock( FILL )

	self.split:SetLeft( self.explorer )
	self.split:SetRight( self.scroll )

	self.results:Dock( FILL )

	self:BuildTreeNodes( self.tree:Root(), self.rootNode, self.AssetPath )

	if self.cookie then
		local path = cookie.GetString( self.cookie .. "_path", "" )
		self:ExpandPath( path )
	end

end

function meta:ExpandPath( path )

	local last = nil
	for node in self:PathIterator( path ) do
		local vgui = self.vgui[node]
		if vgui then
			last = vgui
		end
	end
	if last then
		if last:GetParentNode() then
			last:GetParentNode():ExpandTo( true )
		end
		last:GetRoot():SetSelectedItem( last )
		last:DoClick()
	end

end

function meta:GetResultsPanel()

	return self.results

end

function meta:BuildTreeNodes( node, fnode, path )

	for _, v in ipairs(fnode.children) do

		local innerPath = v.isRootLevel and path or path .. "/" .. v.file

		if v.numFolders > 0 then
			local folder = node:AddFolder( v.name, v.file )
			folder:SetFolder( innerPath )
			self.vgui[v] = folder
			if v.icon then folder:SetIcon( v.icon ) end
			self:BuildTreeNodes( folder, v, innerPath )
			folder.DoClick = function()
				self:FolderClicked( v, innerPath )
			end
		elseif v.isFolder and v.numFiles > 0 then
			local folder = node:AddNode( v.name, v.icon )
			self.vgui[v] = folder
			folder.DoClick = function()
				self:FolderClicked( v, innerPath )
			end
		end

	end

end

function meta:Find( node, file )

	for _, ch in ipairs(node.children) do
		if ch.file == file then return ch end
	end

end

function meta:PathIterator( path )

	local node = self.rootNode
	local matchiter = string.gmatch(path, "/([^/]+)")
	return function()
		local x = matchiter()
		if not x then return end
		node = self:Find( node, x )
		return node
	end

end

function meta:FileIterator( node )

	local ptr = node
	return function()
		ptr = ptr.next
		while ptr ~= nil and not ptr.isFile do
			ptr = ptr.next
		end
		return ptr
	end

end

function meta:GetNodePath( node )

	local ptr = node.parent
	local pstr = node.file
	while ptr do
		pstr = ptr.file .. "/" .. pstr
		ptr = ptr.parent
	end
	return pstr

end

function meta:FindIconForNode( node )

	if node.icon then return node.icon end
	local ptr = node.parent
	while ptr do
		if ptr.icon then return ptr.icon end
		ptr = ptr.parent
	end

	return ""

end

function meta:FolderClicked( folder, path )

	self:PopulateFromFolder( folder, path )

	if self.cookie then
		cookie.Set( self.cookie .. "_path", self:GetNodePath( folder ) )
	end

end

function meta:FolderNode( node, name, folder, icon, isRootLevel )

	local folder = { parent = node, name = name, file = folder, icon = icon, children = {}, isFolder = true, isRootLevel = isRootLevel, numFolders = 0, numFiles = 0, }
	self.__nodePtr.next = folder
	self.__nodePtr = folder

	node.numFolders = node.numFolders + 1
	node.children[#node.children+1] = folder
	return folder

end

function meta:EntryNode( node, file, icon )

	local entry = { parent = node, name = file, file = file, icon = icon, children = {}, isFile = true, numFolders = 0, numFiles = 0, }
	self.__nodePtr.next = entry
	self.__nodePtr = entry

	node.numFiles = node.numFiles + 1
	node.children[#node.children+1] = entry
	return entry

end

function meta:BuildRootFolders( node )

	--self:RecursiveBuildFolders( self:FolderNode(node, "ep2"), self.AssetPath, "ep2" )

	local games = engine.GetGames()
	games[#games+1] = { title = "Garry's Mod", folder = "garrysmod", mounted = true, }
	for _, game in ipairs( games ) do

		if not game.mounted then continue end
		local folder = self:FolderNode(node, game.title, game.folder, "games/16/" .. (game.icon or game.folder) .. ".png", true)
		self:RecursiveBuildFolders( folder, self.AssetPath, game.folder )

	end

	local addons = self:FolderNode(node, "Addons", "Addons", nil, true)
	for _, addon in ipairs( engine.GetAddons() ) do

		local folder = self:FolderNode(addons, addon.title, addon.title, "icon16/bricks.png")
		self:RecursiveBuildFolders( folder, self.AssetPath, addon.title )

	end

end

function meta:CreateResultsPanel( parent )

	local panel = vgui.Create( "DIconLayout", parent )
	--panel:SetBaseSize( 64 )
	panel:SetSelectionCanvas( true )
	panel.OnChildAdded = function(pnl, child)
		child:SetSelectable( true )
	end

	return panel

end

function meta:ClearResults()

	local res = self:GetResultsPanel()
	res:Clear()

end

function meta:AddResult( node, pnl )

	local res = self:GetResultsPanel()

	local name = string.GetFileFromFilename( node.path ):gsub("%.%w+", "")
	local tile = vgui.Create("BPAssetTile")
	tile:SetSize(128,128)
	tile:SetText( name )
	tile:SetTooltip( node.path )
	tile.DoClick = function() self:ChooseAsset( node.path ) end
	tile:SetInner( pnl )

	if self:WasSearch() then
		tile:SetIcon( self:FindIconForNode( node ) )
	end

	res:Add( tile )

end

function meta:CreateResultEntry( node ) end
function meta:PopulateFromFolder( folder, path )

	self:ClearResults()

	self.pendingResults = {}
	self.pendingMark = 1
	self.wasSearch = false

	for _, child in ipairs(folder.children) do
		if not child.isFile then continue end
		self.pendingResults[#self.pendingResults+1] = child
	end

	self.pendingCount = #self.pendingResults

end

function meta:SearchRanker( node, query, queryLength )

	local str = node.path
	local len = str:len() - queryLength
	if str == query then return len end
	if str:find(query) == 1 then return len + 100 end
	return len + 1000

end

function meta:WasSearch()

	return self.wasSearch

end

function meta:PopulateSearchTerm( term )

	self:ClearResults()

	self.pendingResults = {}
	self.pendingMark = 1
	self.wasSearch = true

	if term == "" or term:len() < 2 then return end

	term = term:PatternSafe()
	local tl = term:len()

	for node in self:FileIterator( self.rootNode ) do
		if string.find(node.path, term) then
			self.pendingResults[#self.pendingResults+1] = node
		end
	end

	table.sort(self.pendingResults, function(a,b)
		local aRank = self:SearchRanker(a, term, tl)
		local bRank = self:SearchRanker(b, term, tl)
		if aRank == bRank then return a.path < b.path end
		return aRank < bRank
	end)

	self.pendingCount = math.min(#self.pendingResults, self.MaxSearchResults)

end

function meta:Tick()

	if self.pendingResults ~= nil and #self.pendingResults ~= 0 then

		local doUpdate = false
		for i=1, 5 do

			local remain = self.pendingCount - (self.pendingMark-1)
			if remain > 0 then

				local entry = self.pendingResults[self.pendingMark]
				self.pendingMark = self.pendingMark + 1

				local pnl = self:CreateResultEntry( entry )
				self:AddResult( entry, pnl )
				doUpdate = true
			else

				break

			end

		end

		if doUpdate then
			local res = self:GetResultsPanel()
			res.LastW = 0
			res.LastH = 0
			res:InvalidateLayout( true )
		end

	end

end

function meta:ChooseAsset( path )

	if self.callback then self.callback( true, path ) end
	if IsValid( self.window ) then self.window:Close() end

end

function meta:SetCookie( cookie )

	if not cookie then self.cookie = nil return self end
	self.cookie = "bpassetbrowser_" .. self.type .. "_" .. cookie
	return self

end

function meta:Open()

	if IsValid(self.window) then return self.window end

	local w = ScrW() * .8
	local h = ScrH() * .8
	local x = (ScrW() - w)/2
	local y = (ScrH() - h)/2

	local window = vgui.Create( "DFrame" )
	window:SetSizable( true )
	window:SetPos( x, y )
	window:SetSize( w, h )
	window:SetTitle( "Asset Browser (" .. self.Title .. ")" )
	window:MakePopup()
	window:Center()
	window:SetSkin("Blueprints")
	local detour = window.OnRemove
	window.OnRemove = function(pnl)
		hook.Remove("BPEditorBecomeActive", tostring(window))
		if detour then detour(pnl) end
		if self.callback then self.callback( false, "" ) end
	end

	hook.Add("BPEditorBecomeActive", tostring(window), function()
		if IsValid(window) then
			window:Close() 
		end
	end)

	local inner = vgui.Create( "DPanel" )
	inner:SetParent(window)
	inner:Dock(FILL)
	inner.Paint = function() self:Tick() end
	self:CreateLayout( inner )

	self.window = window
	return self.window

end

function New(...)
	return bpcommon.MakeInstance(meta, ...)
end


local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true

end

vgui.Register( "BPAssetBrowser", PANEL, "DPanel" )