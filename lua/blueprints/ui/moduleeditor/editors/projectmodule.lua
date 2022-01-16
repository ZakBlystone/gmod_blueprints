if SERVER then AddCSLuaFile() return end

module("editor_projectmodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.CanSave = true
EDITOR.CanSendToServer = true
EDITOR.CanInstallLocally = true
EDITOR.CanExportLuaScript = true

function EDITOR:PopulateMenuBar( t )

	--[[if not self.editingModuleTab then
		t[#t+1] = { name = "New SubModule", func = function() self:NewSubModule() end, icon = "icon16/asterisk_yellow.png" }
	end]]

	BaseClass.PopulateMenuBar(self, t)

	if self.editingModuleTab then
		local editor = self.editingModuleTab.moduleEditor
		editor:PopulateMenuBar( t )
		editor:GetModule():GetMenuItems( t )
	end

end

function EDITOR:Setup()

end

function EDITOR:PostInit()

	local mod = self:GetModule()
	mod:BindRaw("addedAsset", self, function() self:EnumerateAssets() end)
	mod:BindRaw("removedAsset", self, function(asset) 
		self:EnumerateAssets()
		self:CloseModule(asset:GetAsset())
	end)

	self.openModules = {}
	self.tabs = vgui.Create("BPEditorPropertySheet" )
	self.tabs:DockMargin(0, 0, 0, 0)
	self.tabs:Dock( FILL )
	self.tabs:SetPadding( 4 )
	self.tabs:SetEditor( self:GetMainEditor() )
	self.tabs.OnActiveTabChanged = function(pnl, old, new) self:OnTabChanged(old, new) end
	self.tabs:SetSkin("Blueprints")
	self:SetContent( self.tabs )

	self.scroll = vgui.Create( "DScrollPanel" )
	self.scroll:DockMargin(4,4,4,4)
	self.scroll:Dock( FILL )

	self.assets = vgui.Create("DIconLayout", self.scroll)
	self.assets:SetSelectionCanvas( true )
	self.assets:Dock( FILL )
	self.assets.OnChildAdded = function(pnl, child)
		child:SetSelectable( true )
	end

	self.tabs:AddSheet( LOCTEXT("project_assets","Assets"), self.scroll, LOCTEXT("project_assets_desc","Assets in this project"), "icon16/application_double.png" )

	self:EnumerateAssets()

end

function EDITOR:Shutdown()

	local mod = self:GetModule()
	mod:UnbindAll(self)

end

function EDITOR:OnTabChanged( old, new )

	if new.view then
		self.editingModuleTab = new.view
		print("IN SUBMODULE")
	else
		self.editingModuleTab = nil
		print("NOT IN SUBMODULE")
	end

	self:UpdateMenuBar()

end

function EDITOR:CloseModule( mod )

	local uid = mod:GetUID()
	local opened = self.openModules[uid]
	if opened == nil then return end

	self.tabs:CloseTab( opened.Tab )
	opened.Panel:Remove()

	self.openModules[uid] = nil

end

function EDITOR:OpenModule( mod )

	local existing = self.openModules[mod:GetUID()]
	if existing then
		self.tabs:SetActiveTab( existing.Tab )
		return existing
	end

	local title = mod:GetName()
	local view = vgui.Create("BPModuleEditor")
	local sheet = self.tabs:AddSheet( title, view, title, mod.Icon or "icon16/application.png", true )
	view:SetModule( mod )
	view.editor = self
	view.file = file
	view.tab = sheet.Tab

	sheet.Tab.view = view
	sheet.Tab.Close = function()
		self:CloseModule( mod )
	end

	self.openModules[mod:GetUID()] = sheet

	self.tabs:SetActiveTab( sheet.Tab )
	return sheet

end

function EDITOR:ChooseAsset( asset )

	if isbpmodule(asset:GetAsset()) then
		local mod = asset:GetAsset()
		print("OPEN ASSET: " .. tostring(mod:GetName()))
		self:OpenModule( mod, mod:GetName() )
	end

end

function EDITOR:AddAssetTile( name, icon, pnl, func, rightClick )

	if icon and not pnl then
		pnl = vgui.Create("DImage")
		pnl:SetImage(icon)
		pnl:SetSize(64,64)
		icon = nil
	end

	local tile = vgui.Create("BPAssetTile")
	tile.DoClick = func
	tile:SetSize(128,128)
	tile:SetText( name )
	tile:SetInner( pnl )
	tile:SetIcon( icon )
	tile:SetDrawInnerBox( false )

	local detour = tile.OnMousePressed
	tile.OnMousePressed = function( pnl, code )
		if code == MOUSE_LEFT then
			detour(pnl, code)
		elseif code == MOUSE_RIGHT then
			if rightClick then rightClick(pnl) end
		end
	end

	self.assets:Add( tile )
	return tile

end

function EDITOR:AddAsset( asset, icon )

	local pnl = nil
	if isbpmodule(asset:GetAsset()) then
		local mod = asset:GetAsset()
		icon = icon or mod.Icon
	end

	self:AddAssetTile( asset:GetName(), icon, nil,
		function() self:ChooseAsset( asset ) end,
		function(pnl) self:OpenAssetMenu(pnl, asset) end)

end

function EDITOR:OpenAssetMenu(pnl, asset)

	if IsValid(self.cmenu) then self.cmenu:Remove() end

	local options = {}

	options[#options+1] = {
		title = "Rename",
		func = function()
			bpmodal.String({
				title = "Rename",
				message = "Module Name",
				default = asset:GetName(),
				confirm = function( text )
					asset:SetName( text )
					self:EnumerateAssets()
				end,
			})
		end,
	}

	options[#options+1] = {
		title = "Delete",
		func = function()
			bpmodal.Query({
				title = "Delete Asset",
				message = "Delete " .. asset:GetName() .. "? This cannot be undone",
				options = {
					{"yes", function()
						self:GetModule():RemoveAsset( asset )
						self:EnumerateAssets()
					end},
					{"no", function() end},
				},
			})
		end,
	}

	options[#options+1] = {
		title = "Export",
		func = function()
			local mod = asset:GetAsset()
			SetClipboardText(bpmodule.SaveToText(mod))
			bpmodal.Message({
				message = LOCTEXT("module_export_text", "Module copied to clipboard"), 
				title = LOCTEXT("menu_export", "Export"),
			})
		end,
	}

	self.cmenu = bpmodal.Menu({
		options = options,
		width = 100,
	}, pnl)

end

function EDITOR:OpenAddAssetMenu(pnl)

	if IsValid(self.cmenu) then self.cmenu:Remove() end

	self.cmenu = bpmodal.Menu({
		options = {
			{ title = "Import", func = function() 
				self:ImportSubModule()
			end }
		},
		width = 100,
	}, pnl)

end

function EDITOR:ImportSubModule()

	self:GetMainEditor():OpenImport( function(mod)

		if mod:GetType() == "projectmodule" then error("Cannot import project module as sub-module") end
		print("IMPORT MODULE: " .. mod:GetType())

		self:GetModule():AddModule( mod )

	end)

end

function EDITOR:EnumerateAssets()

	self.assets:Clear()

	for _, m in ipairs(self:GetModule():GetAssets()) do self:AddAsset(m) end

	self:AddAssetTile("", "icon16/add.png", nil, 
		function() self:NewSubModule() end,
		function(pnl)
			self:OpenAddAssetMenu(pnl)
		end ):SetColor(Color(255,255,255,150))

end

function EDITOR:NewSubModule()

	self:ModuleDropdown()

end

function EDITOR:AddModule(subModule)

	return self:GetModule():AddModule(subModule)

end

function EDITOR:CreateModule(type)

	local mod = bpmodule.New(type)
	mod:CreateDefaults()
	local newAsset = self:AddModule(mod)
	--self:ChooseAsset( newAsset )

end

function EDITOR:ModuleDropdown()

	if IsValid(self.cmenu) then self.cmenu:Remove() end

	local options = {}

	local loader = bpmodule.GetClassLoader()
	local classes = bpcommon.Transform( loader:GetClasses(), {}, function(k) return {name = k, class = loader:Get(k)} end )

	table.sort( classes, function(a,b) return tostring(a.class.Name) < tostring(b.class.Name) end )

	bpcommon.Transform( classes, options, function(v)
		local cl = v.class
		if not cl.Creatable or cl.Developer or not cl.CanBeSubmodule then return end
		return {
			title = tostring(cl.Name),
			func = function() self:CreateModule( v.name ) end,
			icon = cl.Icon,
			desc = cl.Description,
		}
	end)

	options[#options+1] = {}

	local templateCategories = {}

	bpcommon.Transform( classes, templateCategories, function(v)
		local cl = v.class
		if not cl.Creatable or not cl.CanBeSubmodule then return end

		local templates = bptemplates.GetByType( v.name )
		if #templates == 0 then return end

		local options = bpcommon.Transform( templates, {}, function(v)

			return {
				title = tostring(v.name),
				func = function()
					local mod = bptemplates.CreateTemplate( v )
					self:AddModule(mod)
				end,
				icon = cl.Icon,
				desc = tostring(v.description) .. "\nby " .. tostring(v.author),
			}

		end )

		return {
			title = tostring(cl.Name),
			options = options,
			icon = cl.Icon,
			desc = cl.Description,
		}
	end)

	options[#options+1] = {
		title = LOCTEXT("module_submenu_examples","Examples"),
		options = templateCategories,
		icon = "icon16/book.png",
	}

	options[#options+1] = {}

	local devOptions = bpcommon.Transform( classes, {}, function(v)
		local cl = v.class
		if not cl.Creatable or not cl.Developer or not cl.CanBeSubmodule then return end
		return {
			title = tostring(cl.Name),
			func = function() self:CreateModule( v.name ) end,
			icon = cl.Icon,
			desc = cl.Description,
		}
	end)

	options[#options+1] = {
		title = LOCTEXT("module_submenu_developer","Developer"),
		options = devOptions,
		icon = "icon16/application_osx_terminal.png",
	}

	self.cmenu = bpmodal.Menu({
		options = options,
		width = 100,
	}, self:GetPanel())

end

function EDITOR:HandleError( errorData )

	local found = self:GetModule():FindAssetByUID( errorData.modUID )
	if found then 
		local sheet = self:OpenModule(found)
		if sheet then
			sheet.Panel:HandleError( errorData )
		end
	end

end

RegisterModuleEditorClass("projectmodule", EDITOR, "basemodule")