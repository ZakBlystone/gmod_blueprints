if SERVER then AddCSLuaFile() return end

module("bpuieditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local text_unsaved_changes = LOCTEXT("query_unsaved_changes", "This module has unsaved changes, would you like the save them?")
local text_wait_for_defs = LOCTEXT("editor_wait_for_defs", "Wait for definitions to download. If download stalls, run 'bp_request_definitions' in console.")
local text_failed_to_open = LOCTEXT("editor_failed_to_open", "Failed to open module")
local text_failed_to_convert = LOCTEXT("editor_failed_to_convert", "Error converting legacy blueprint")
local text_blueprint_paste_hint = LOCTEXT("editor_blueprint_paste", "Paste the blueprint below ('bp-xxxxxxxxxxxxxxxxxxxx' codes work too):")
local text_import_module = LOCTEXT("editor_import_module", "Import Module")
local text_import = LOCTEXT("editor_import", "Import")
local text_legacy_convert = LOCTEXT("editor_legacy_convert", "Convert Legacy Blueprint")

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetMouseInputEnabled( true )
	self:SetContentAlignment( 7 )
	self:SetTextInset( 0, 4 )
	self:SetSkin("Blueprints")

end

function PANEL:SetLabel( text )

	self.labelText = text
	self:SetText( tostring(self.labelText) )
	self:InvalidateLayout()
	self:GetParent():InvalidateLayout()
	self:GetParent():GetParent():InvalidateLayout()

end

function PANEL:Setup( label, pPropertySheet, pPanel, strMaterial, closeButton )

	self:SetLabel( label )
	self:SetPropertySheet( pPropertySheet )
	self:SetPanel( pPanel )

	if ( strMaterial ) then

		self.Image = vgui.Create( "DImage", self )
		self.Image:SetImage( strMaterial )
		self.Image:SizeToContents()
		self:InvalidateLayout()

	end

	if closeButton then

		self.CloseButton = vgui.Create( "DButton", self )
		self.CloseButton:SetText("")
		self.CloseButton:SetSize( 21, 24 )
		self.CloseButton.DoClick = function() self:Close() end
		self.CloseButton.Paint = function( panel, w, h ) derma.SkinHook( "Paint", "TabCloseButton", panel, w, h ) end
		self:InvalidateLayout()

	end

end

function PANEL:SetSuffix( str )

	self:SetText( self.labelText .. str )
	self:InvalidateLayout()
	self:GetParent():InvalidateLayout()
	self:GetParent():GetParent():InvalidateLayout()

end

function PANEL:Close()

end

function PANEL:PerformLayout()

	self:ApplySchemeSettings()

	if self.CloseButton then

		self.CloseButton:SetPos( self:GetWide() - self.CloseButton:GetWide() - 6, 0 )

	end

	if ( !self.Image ) then return end

	self.Image:SetPos( 7, 3 )

	if ( !self:IsActive() ) then
		self.Image:SetImageColor( Color( 255, 255, 255, 155 ) )
	else
		self.Image:SetImageColor( Color( 255, 255, 255, 255 ) )
	end

end

function PANEL:ApplySchemeSettings()

	local ExtraInset = 10
	local ExtraWide = 0

	if ( self.Image ) then
		ExtraInset = ExtraInset + self.Image:GetWide()
	end

	if self.CloseButton then
		ExtraWide = ExtraWide + self.CloseButton:GetWide()
	end

	self:SetTextInset( ExtraInset, 4 )
	local w, h = self:GetContentSize()
	h = self:GetTabHeight()

	self:SetSize( w + 10 + ExtraWide, h )

	DLabel.ApplySchemeSettings( self )

end


derma.DefineControl( "BPEditorTab", "Blueprint editor tab", PANEL, "DTab" )

local PANEL = {}

AccessorFunc( PANEL, "m_Editor", "Editor" )

function PANEL:AddSheet( label, panel, Tooltip, material, closeButton )

	if ( !IsValid( panel ) ) then
		ErrorNoHalt( "DPropertySheet:AddSheet tried to add invalid panel!" )
		debug.Trace()
		return
	end

	local Sheet = {}

	Sheet.Name = label

	Sheet.Tab = vgui.Create( "BPEditorTab", self )
	Sheet.Tab:SetTooltip( tostring(Tooltip) )
	Sheet.Tab:Setup( label, self, panel, material, closeButton )

	Sheet.Panel = panel
	Sheet.Panel.NoStretchX = NoStretchX
	Sheet.Panel.NoStretchY = NoStretchY
	Sheet.Panel:SetPos( self:GetPadding(), 20 + self:GetPadding() )
	Sheet.Panel:SetVisible( false )

	panel:SetParent( self )

	table.insert( self.Items, Sheet )

	if ( !self:GetActiveTab() ) then
		self:SetActiveTab( Sheet.Tab )
		Sheet.Panel:SetVisible( true )
	end

	self.tabScroller:AddPanel( Sheet.Tab )

	return Sheet

end

function PANEL:CloseTab( tab, bRemovePanelToo )

	for k, v in pairs( self.Items ) do

		if ( v.Tab != tab ) then continue end

		table.remove( self.Items, k )

	end

	for k, v in pairs( self.tabScroller.Panels ) do

		if ( v != tab ) then continue end

		table.remove( self.tabScroller.Panels, k )

	end

	self.tabScroller:InvalidateLayout( true )

	if ( tab == self:GetActiveTab() ) then
		self:SetActiveTab( self.Items[ #self.Items ].Tab )
		--self.m_pActiveTab = self.Items[ #self.Items ].Tab
	end

	local pnl = tab:GetPanel()

	if ( bRemovePanelToo ) then
		pnl:Remove()
	end

	tab:Remove()

	self:InvalidateLayout( true )

	return pnl

end

derma.DefineControl( "BPEditorPropertySheet", "Blueprint editor property sheet", PANEL, "DPropertySheet" )

local PANEL = {}
local TITLE = "Blueprint Editor v" .. bpcommon.ENV_VERSION

local deleteOnClose = CreateConVar("bp_delete_editor_on_close", "0", FCVAR_ARCHIVE, "For debugging, re-created editor UI")

LastSavedFile = nil

function PANEL:RunCommand( func, ... )
	self:ClearReport()

	local b = xpcall( func, function( err )
		_G.G_BPError = nil
		self:Report( err, 1 )
		print( err )
		print( debug.traceback() )
	end, self, ... )
end

function PANEL:Init()

	local w = ScrW() * .8
	local h = ScrH() * .8
	local x = (ScrW() - w)/2
	local y = (ScrH() - h)/2

	self.fullScreen = false
	self.btnMaxim:SetDisabled(false)
	self.btnMaxim.DoClick = function ( button )
		self.fullScreen = not self.fullScreen
		if self.fullScreen then
			self.px, self.py = self:GetPos()
			self.pw, self.ph = self:GetSize()
			self:SetPos(0,0)
			self:SetSize(ScrW(), ScrH())
			self:SetDraggable(false)
			self:SetSizable(false)
		else
			self:SetPos(self.px,self.py)
			self:SetSize(self.pw,self.ph)
			self:SetDraggable(true)
			self:SetSizable(true)
		end
	end

	self:SetPos(x, y)
	self:SetSize(w, h)

	self:SetMouseInputEnabled( true )
	self:SetTitle( TITLE )
	self:SetDraggable(true)
	self:SetSizable(true)
	self:ShowCloseButton(true)
	self:SetDeleteOnClose(false)

	self.btnMinim:SetVisible(false)

	self.Tabs = vgui.Create("BPEditorPropertySheet", self )
	self.Tabs:DockMargin(2, 2, 2, 5)
	self.Tabs:Dock( FILL )
	self.Tabs:SetPadding( 0 )
	self.Tabs:SetEditor( self )

	self.Status = vgui.Create("DPanel", self)
	self.Status:DockMargin(2, 2, 2, 2)
	self.Status:Dock( BOTTOM )

	self.StatusText = vgui.Create("DLabel", self.Status)
	self.StatusText:SetFont("DermaDefaultBold")
	self.StatusText:Dock( FILL )
	self.StatusText:DockMargin(8, 4, 4, 4)
	self.StatusText:SetText("OK")

	self.wasActive = false
	self.openModules = {}

	--self.AssetBrowser = vgui.Create("BPAssetBrowser")

	self.UserManager = vgui.Create("BPUserManager")

	self.FileManager = vgui.Create("BPFileManager")
	self.FileManager.editor = self

	--self.Tabs:AddSheet( "Assets", self.AssetBrowser, "Assets", "icon16/zoom.png")
	self.Tabs:AddSheet( LOCTEXT("file_users","Users"), self.UserManager, LOCTEXT("file_users_desc","Users"), "icon16/group.png" )
	self.Tabs:SetActiveTab( self.Tabs:AddSheet( LOCTEXT("file_files","Files"), self.FileManager, LOCTEXT("file_files_desc","Files"), "icon16/folder.png" ).Tab )

	local openCount = cookie.GetNumber("bp_editor_open_count", 0)
	local lastVersion = cookie.GetString("bp_editor_last_version", "")
	if openCount == 0 or lastVersion ~= bpcommon.ENV_VERSION then self:OpenAbout() end

	cookie.Set("bp_editor_open_count", openCount + 1)
	cookie.Set("bp_editor_last_version", bpcommon.ENV_VERSION)

	self:SetSkin("Blueprints")

end

function PANEL:OpenHelp()

	local outer = vgui.Create("DPanel")

	local html = vgui.Create("DHTML", outer)
	html:OpenURL("samuelmaddock.github.io/gm-mediaplayer/gmblueprints/docs.html")
	html:Dock( FILL )

	local sheet = self.Tabs:AddSheet( "Help", outer, "Help", "icon16/zoom.png", true)
	sheet.Tab.Close = function()
		self.Tabs:CloseTab( sheet.Tab )
		sheet.Panel:Remove()
	end

	outer:DockMargin(5, 0, 5, 5)
	outer:Dock( FILL )

	self.Tabs:SetActiveTab( sheet.Tab )

end

function PANEL:OpenAbout()

	local about = vgui.Create( "DFrame" )
	about:SetSkin("Blueprints")

	local html = vgui.Create("DHTML", about)
	html:OpenURL("samuelmaddock.github.io/gm-mediaplayer/gmblueprints/about.html")
	html:DockMargin(0, 0, 0, 50)
	html:Dock( FILL )

	local ok = vgui.Create("DButton", about)

	about:ShowCloseButton(false)
	about:SetTitle("About")
	about:SetSize(ScrW()*.7, ScrH()*.7)
	about:Center()
	about:MakePopup()
	about:DoModal()

	ok:SetText("Ok")
	ok:SetWide(50)
	ok:SetPos(0, about:GetTall() - 40 )
	ok:CenterHorizontal()
	ok.DoClick = function() if IsValid(about) then about:Close() end end

end

function PANEL:OpenSettings()

	local window = vgui.Create( "BPFrame" )
	window:SetSkin("Blueprints")
	window:SetSizable( true )
	window:SetSize( ScrW()/3, ScrH()/2 )
	window:MakePopup()
	window:SetTitle(LOCTEXT("menu_editorsettings", "Editor Settings")())
	window:Center()
	local detour = window.OnRemove
	window.OnRemove = function(pnl)
		hook.Remove("BPEditorBecomeActive", tostring(window))
		if detour then detour(pnl) end
	end

	hook.Add("BPEditorBecomeActive", tostring(window), function()
		if IsValid(window) then
			window:Close() 
		end
	end)

	local function makeCvar(v)
		local convar = GetConVar(v)
		print(v .. " : " .. convar:GetFloat())
		return bpvaluetype.New("Number", 
			function() return convar:GetFloat() end,
			function(v) convar:SetFloat(v) end)
		:SetMin(convar:GetMin())
		:SetMax(convar:GetMax())
		:SetPrecision(1)
		:Set(convar:GetFloat())
	end

	local edit = bpvaluetype.FromValue({
		["color scheme"] = {
			["hue"] = makeCvar("bp_editor_ui_hue"),
			["saturation"] = makeCvar("bp_editor_ui_sat"),
			["value"] = makeCvar("bp_editor_ui_val"),
		}
	})

	bpcommon.Profile("create-gui", function()
		local inner = edit:CreateVGUI({ live = true, })
		inner:SetParent(window)
		inner:Dock(FILL)
	end)

end

function PANEL:OpenImport( finishFunc )

	local import = vgui.Create( "DFrame" )

	local info = vgui.Create("DLabel", import)
	info:SetText(text_blueprint_paste_hint())
	info:SetPos(0, 30)
	info:SizeToContents()

	local text = vgui.Create("DTextEntry", import)
	text:DockMargin(0, 30, 0, 50)
	text:Dock( FILL )
	text:SetMultiline( true )

	local ok = vgui.Create("DButton", import)

	import:SetTitle(text_import_module())
	import:SetSize(ScrW()*.5, ScrH()*.5)
	import:Center()
	import:MakePopup()
	import:DoModal()

	info:CenterHorizontal()

	ok:SetText(text_import())
	ok:SetWide(50)
	ok:SetPos(0, import:GetTall() - 40 )
	ok:CenterHorizontal()
	ok.DoClick = function()

		local str = text:GetText()
		if bppaste.IsValidKey( str ) then

			bppaste.Download( str, function(ok, text)

				if ok then self:FinishImport( import, text, finishFunc ) end

			end)

		else

			self:FinishImport( import, str, finishFunc )

		end

	end

	text:RequestFocus()

end

function PANEL:OpenLegacyImporter()

	local selected = nil
	local import = vgui.Create( "DFrame" )

	local info = vgui.Create("DLabel", import)
	info:SetText(text_blueprint_paste_hint())
	info:SetPos(0, 30)
	info:SizeToContents()

	local ok = vgui.Create("DButton", import)
	ok:SetEnabled(false)

	local browser = vgui.Create( "DFileBrowser", import )
	browser:DockMargin(0, 30, 0, 50)
	browser:Dock( FILL )
	browser:SetPath( "DATA" )
	browser:SetBaseFolder( "blueprints" )
	browser:SetCurrentFolder( "client" )
	browser:SetOpen( true, true )

	browser.OnDoubleClick = function(b, path)
		self:FinishLegacyImport( import, path )
	end

	browser.OnSelect = function(b, path)
		ok:SetEnabled(true)
		selected = path
	end


	import:SetTitle(text_legacy_convert())
	import:SetSize(ScrW()*.5, ScrH()*.5)
	import:Center()
	import:MakePopup()
	import:DoModal()

	info:CenterHorizontal()

	ok:SetText(text_import())
	ok:SetWide(50)
	ok:SetPos(0, import:GetTall() - 40 )
	ok:CenterHorizontal()
	ok.DoClick = function()
		if selected then self:FinishLegacyImport( import, selected ) end
	end

end

function PANEL:FinishLegacyImport( panel, path )

	if IsValid(panel) then panel:Close() end
	local b,e = xpcall( 
		function()
			local mod = bplegacy.ConvertModule16( path )
			return self:OpenModule(mod, "unnamed", nil)
		end, 
		function(err)
			bpmodal.Message({
				message = tostring(err) .. "\n" .. debug.traceback(), 
				title = text_failed_to_convert()
			})
		end)
	if not b then
		
	else
		return e
	end

end

function PANEL:FinishImport( import, text, finishFunc )

	local b,e = pcall( function()

		if import == nil then error("Failed to get import text") end

		local mod = bpmodule.LoadFromText( text )
		mod:GenerateNewUID()

		if finishFunc then
			finishFunc(mod)
		else
			self:OpenModule(mod, "unnamed", nil)
		end

		if IsValid(import) then import:Close() end

	end)

	if not b then bpmodal.Message({
		message = e, 
		title = "Error importing blueprint"
	}) end

end

function PANEL:ClearReport()

	self.StatusText:SetText("")
	self.StatusText:SetTextColor(Color(255,255,255))

end

function PANEL:Report( text, type )

	self.StatusText:SetText( text )
	if type == 1 then
		self.StatusText:SetTextColor(Color(255,100,100))
	else
		self.StatusText:SetTextColor(Color(255,255,255))
	end

end

function PANEL:Think()

	BPFrame.Think(self)

	if _G.G_BPError ~= nil then
		if self.BpErrorWasNil then
			self.BpErrorWasNil = false
			self:Report( "Blueprint Error: " .. _G.G_BPError.msg, 1 )

			local localFile = bpfilesystem.GetLocalFiles()[ _G.G_BPError.uid ]
			if localFile then
				local sheet = self:OpenFile( localFile )
				if sheet and sheet.Panel then
					sheet.Panel:HandleError( _G.G_BPError )
				end
			end
		end
	else
		self.BpErrorWasNil = true
	end

	if self:IsActive() then
		if not self.wasActive then
			--print("EDITOR BECOME ACTIVE")
			hook.Run("BPEditorBecomeActive")
			self.wasActive = true
		end
	else
		if self.wasActive then
			--print("EDITOR BECOME INACTIVE")
			self.wasActive = false
		end
	end


end

function PANEL:OnFocusChanged( gained )

	--print("MAIN PANEL FOCUS CHANGE: " .. tostring(gained))

end

function PANEL:OpenModule( mod, name, file )

	local existing = self.openModules[mod:GetUID()]
	if existing then
		self.Tabs:SetActiveTab( existing.Tab )
		return existing
	end

	local title = name or bpcommon.GUIDToString( mod:GetUID(), true )
	local view = vgui.Create("BPModuleEditor")
	local sheet = self.Tabs:AddSheet( title, view, title, mod.Icon or "icon16/application.png", true )
	view:SetModule( mod )
	view.editor = self
	view.file = file
	view.tab = sheet.Tab

	sheet.Tab.Close = function()
		if file then
			self:CloseFile( file )
		else
			self:CloseModule( mod )
		end
	end

	self.openModules[mod:GetUID()] = sheet

	self.Tabs:SetActiveTab( sheet.Tab )
	return sheet

end

function PANEL:OpenFile( file )

	local opened = self.openModules[ file:GetUID() ]
	if opened then
		self.Tabs:SetActiveTab( opened.Tab )
		return opened
	end

	if not bpdefs.Ready() then
		bpmodal.Message({
			message = text_wait_for_defs, 
			title = text_failed_to_open, 
		})
		return
	end

	local b,e = xpcall( 
		function()
			local mod = bpmodule.Load(file:GetPath()):WithOuter(file)
			return self:OpenModule( mod, file:GetName(), file )
		end, 
		function(err)
			bpmodal.Message({
				message = tostring(err) .. "\n" .. debug.traceback(), 
				title = text_failed_to_open,
			})
		end)
	if not b then
		
	else
		return e
	end

end

function PANEL:CloseFile( file, callback )

	if file == nil then return end

	--print("CLOSING FILE: " .. tostring(file:GetName()))

	local opened = self.openModules[file:GetUID()]
	local nop = function() end

	callback = callback or nop

	if opened and file:HasFlag( bpfile.FL_HasLocalChanges ) then 
		self.Tabs:SetActiveTab( opened.Tab )

		bpmodal.Query({
			message = text_unsaved_changes,
			title = LOCTEXT("query_close_file", "Close"),
			options = {
				{ "yes", function() opened.Panel:Save( function(ok) if ok then self:CloseFileUID( file:GetUID() ) callback() end end ) end },
				{ "no", function() bpfilesystem.MarkFileAsChanged( file, false ) self:CloseFileUID( file:GetUID() ) callback() end },
			},
		})
		return
	end

	if file then self:CloseFileUID( file:GetUID() ) callback() end

end

function PANEL:CloseFileUID( uid )

	local opened = self.openModules[uid]
	if opened == nil then return end

	self.Tabs:CloseTab( opened.Tab )
	opened.Panel:Remove()

	self.openModules[uid] = nil

end

function PANEL:CloseModule( mod )

	self:CloseFileUID( mod:GetUID() )

end

vgui.Register( "BPEditor", PANEL, "BPFrame" )


--if true then return end

function OpenEditor( forceRefresh )

	if IsValid(G_BPEditorInstance) then

		if deleteOnClose:GetBool() or forceRefresh then

			if IsValid(G_BPEditorInstance) then G_BPEditorInstance:Remove() end
			G_BPEditorInstance = nil

		else

			G_BPEditorInstance:SetVisible( true )
			return

		end

	end

	if not bpdefs.Ready() then
		LocalPlayer():ConCommand("bp_request_definitions")
	end

	--for i=1, 2 do
	local editor = vgui.Create( "BPEditor" )
	editor:SetVisible(true)
	editor:MakePopup()
	--end

	--local mod = bpmodule.New()
	--editor:OpenModule( mod )
	--editor:SetModule(mod)

	--bpnet.DownloadServerModule( mod )
	--graph:CreateTestGraph()
	--graph:RemoveNode( graph.nodes[1] )

	G_BPEditorInstance = editor

end

concommand.Add("bp_editorpanic", function()

	print("Tearing down editor")
	if IsValid(G_BPEditorInstance) then G_BPEditorInstance:Remove() end
	G_BPEditorInstance = nil

end)

concommand.Add("bp_open_editor", function()

	OpenEditor()

end)

--[[hook.Add("PlayerBindPress", "catch_f2", function(ply, bind, pressed)

	if bind == "gm_showteam" then
		OpenEditor()
	end

end)]]

list.Set(
	"DesktopWindows",
	"BlueprintEditor",
	{
		title = "Blueprint Editor",
		icon = "icon64/blueprints.png",
		width = 100,
		height = 100,
		onewindow = true,
		init = function(icn, pnl)
			pnl:Remove()
			OpenEditor()
		end
	}
)