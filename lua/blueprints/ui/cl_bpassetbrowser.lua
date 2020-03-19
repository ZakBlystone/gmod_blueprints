local meta = bpcommon.MetaTable("bpassetbrowser")
local browserClasses = bpclassloader.Get("AssetBrowser", "blueprints/ui/browsers/", "BPAssetBrowserClassRefresh", meta)

if SERVER then AddCSLuaFile() return end

module("bpuiassetbrowser", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

print("asset browser")

meta.AssetPath = ""
meta.AllowedExtensions = {}
meta.Title = "None"

function meta:Init( type, callback )

	browserClasses:Install( type, self )
	self.callback = callback
	return self

end

function meta:FileExtensionAllowed( fileExt )

	return self.AllowedExtensions[ fileExt ]

end

function meta:RecursiveBuildFolders( node, path, pathType )

	local files, folders = file.Find(path .. "/*", pathType)

	if files == nil then return end
	if #folders == 0 and #files == 0 then return end

	for _, v in ipairs(folders) do
		local folder = self:FolderNode( node, v, v )
		local inner = path .. "/" .. v
		folder.path = inner
		self:RecursiveBuildFolders( folder, inner, pathType )
	end

	for _,v in ipairs(files) do
		if self:FileExtensionAllowed( v:gsub("^[^%.]+","") ) then
			local entry = self:EntryNode( node, v )
			entry.path = path .. "/" .. v
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
	self.search.OnEnter = function( pnl )

		--pnl:GetText()

	end

	self.tree = vgui.Create( "DTree", self.explorer )
	self.tree:Dock( FILL )

	self.split:SetLeft( self.explorer )
	self.split:SetRight( self.scroll )

	self.results:Dock( FILL )

	local structure = { children = {}, numFolders = 0, numFiles = 0, }
	self:BuildRootFolders( structure )
	self:BuildTreeNodes( self.tree:Root(), structure, self.AssetPath )

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
			if v.icon then folder:SetIcon( v.icon ) end
			self:BuildTreeNodes( folder, v, innerPath )
			folder.DoClick = function()
				self:FolderClicked( v, innerPath )
			end
		elseif v.isFolder and v.numFiles > 0 then
			local folder = node:AddNode( v.name, v.icon )
			folder.DoClick = function()
				self:FolderClicked( v, innerPath )
			end
		end

	end

end

function meta:FolderClicked( folder, path )

	self:PopulateFromFolder( folder, path )

end

function meta:FolderNode( node, name, folder, icon, isRootLevel )

	local folder = { parent = node, name = name, file = folder, icon = icon, children = {}, isFolder = true, isRootLevel = isRootLevel, numFolders = 0, numFiles = 0, }
	node.numFolders = node.numFolders + 1
	node.children[#node.children+1] = folder
	return folder

end

function meta:EntryNode( node, file, icon )

	local entry = { parent = node, name = file, file = file, icon = icon, children = {}, isFile = true, numFolders = 0, numFiles = 0, }
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

	local panel = vgui.Create( "DTileLayout", parent )
	panel:SetBaseSize( 64 )
	panel:SetSelectionCanvas( true )

	return panel

end

function meta:PopulateFromFolder( folder, path )

end

function meta:ChooseAsset( path )

	if self.callback then self.callback( true, path ) end
	if IsValid( self.window ) then self.window:Close() end

end

function meta:Open()

	if IsValid(self.window) then return self.window end

	local window = vgui.Create( "DFrame" )
	window:SetSizable( true )
	window:SetPos( 400, 0 )
	window:SetSize( 800, 500 )
	window:SetTitle( "Asset Browser (" .. self.Title .. ")" )
	window:MakePopup()
	window:Center()
	local detour = window.OnRemove
	window.OnRemove = function(pnl)
		if detour then detour(pnl) end
		if self.callback then self.callback( false, "" ) end
	end

	local inner = vgui.Create( "DPanel" )
	inner:SetParent(window)
	inner:Dock(FILL)
	inner.Paint = function() end
	self:CreateLayout( inner )

	self.window = window
	return self.window

end

function New(...)
	return setmetatable({}, meta):Init(...)
end


local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true

end

vgui.Register( "BPAssetBrowser", PANEL, "DPanel" )