if SERVER then AddCSLuaFile() return end

module("bpuieditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetMouseInputEnabled( true )
	self:SetContentAlignment( 7 )
	self:SetTextInset( 0, 4 )

end

function PANEL:SetLabel( text )

	self.labelText = text
	self:SetText( self.labelText )
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
		self.CloseButton:SetText(" X ")
		self.CloseButton:SizeToContents()
		self.CloseButton.DoClick = function() self:Close() end
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
	Sheet.Tab:SetTooltip( Tooltip )
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

	self.Tabs = vgui.Create("BPEditorPropertySheet", self )
	self.Tabs:DockMargin(0, 0, 0, 5)
	self.Tabs:Dock( FILL )
	self.Tabs:SetPadding( 0 )
	self.Tabs:SetEditor( self )

	self.Status = vgui.Create("DPanel", self)
	self.Status:Dock( BOTTOM )
	self.Status:SetBackgroundColor( Color(50,50,50) )

	self.StatusText = vgui.Create("DLabel", self.Status)
	self.StatusText:SetFont("DermaDefaultBold")
	self.StatusText:Dock( FILL )
	self.StatusText:DockMargin(10, 2, 2, 2)
	self.StatusText:SetText("")

	self.wasActive = false
	self.openModules = {}

	--self.AssetBrowser = vgui.Create("BPAssetBrowser")

	self.UserManager = vgui.Create("BPUserManager")

	self.FileManager = vgui.Create("BPFileManager")
	self.FileManager.editor = self

	--self.Tabs:AddSheet( "Assets", self.AssetBrowser, "Assets", "icon16/zoom.png")
	self.Tabs:AddSheet( "Users", self.UserManager, "Users", "icon16/group.png" )
	self.Tabs:SetActiveTab( self.Tabs:AddSheet( "Files", self.FileManager, "Files", "icon16/folder.png" ).Tab )

	local openCount = cookie.GetNumber("bp_editor_open_count", 0)
	local lastVersion = cookie.GetString("bp_editor_last_version", "")
	if openCount == 0 or lastVersion ~= bpcommon.ENV_VERSION then self:OpenAbout() end

	cookie.Set("bp_editor_open_count", openCount + 1)
	cookie.Set("bp_editor_last_version", bpcommon.ENV_VERSION)

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

function PANEL:OpenImport()

	local import = vgui.Create( "DFrame" )

	local info = vgui.Create("DLabel", import)
	info:SetText("Paste the blueprint below ('bp-xxxxxxxxxxxxxxxxxxxx' codes work too):")
	info:SetPos(0, 30)
	info:SizeToContents()

	local text = vgui.Create("DTextEntry", import)
	text:DockMargin(0, 30, 0, 50)
	text:Dock( FILL )
	text:SetMultiline( true )

	local ok = vgui.Create("DButton", import)

	import:SetTitle("Import Module")
	import:SetSize(ScrW()*.5, ScrH()*.5)
	import:Center()
	import:MakePopup()
	import:DoModal()

	info:CenterHorizontal()

	ok:SetText("Import")
	ok:SetWide(50)
	ok:SetPos(0, import:GetTall() - 40 )
	ok:CenterHorizontal()
	ok.DoClick = function()

		local str = text:GetText()
		if bppaste.IsValidKey( str ) then

			bppaste.Download( str, function(ok, text)

				if ok then self:FinishImport( import, text ) end

			end)

		else

			self:FinishImport( import, str )

		end

	end

	text:RequestFocus()

end

function PANEL:FinishImport( import, text )

	local b,e = pcall( function()

		if import == nil then error("Failed to get import text") end

		local mod = bpmodule.New()
		mod:LoadFromText( text )
		mod:GenerateNewUID()
		self:OpenModule(mod, "unnamed", nil)

		if IsValid(import) then import:Close() end

	end)

	if not b then Derma_Message(e, "Error importing blueprint", "Ok") end

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

	self.BaseClass.Think(self)

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
		Derma_Message( "Wait for definitions to download. If download stalls, run 'bp_request_definitions' in console.", "Failed to open module", "OK" )
		return
	end

	local mod = bpmodule.New()
	local b,e = pcall( function()
		mod:Load(file:GetPath())
		return self:OpenModule( mod, file:GetName(), file )
	end)
	if not b then
		Derma_Message( e, "Failed to open module", "OK" )
	else
		return e
	end

end

function PANEL:CloseFile( file, callback )

	if file == nil then return end

	print("CLOSING FILE: " .. tostring(file:GetName()))

	local opened = self.openModules[file:GetUID()]
	local nop = function() end

	callback = callback or nop

	if opened and file:HasFlag( bpfile.FL_HasLocalChanges ) then 
		self.Tabs:SetActiveTab( opened.Tab )
		Derma_Query("This module has unsaved changes, would you like the save them?", "Close",
		"Yes", function() opened.Panel:Save( function(ok) if ok then self:CloseFileUID( file:GetUID() ) callback() end end ) end,
		"No", function() bpfilesystem.MarkFileAsChanged( file, false ) self:CloseFileUID( file:GetUID() ) callback() end)
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

vgui.Register( "BPEditor", PANEL, "DFrame" )


--if true then return end

local function OpenEditor()

	if IsValid(G_BPEditorInstance) then

		if deleteOnClose:GetBool() then

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
	--mod:CreateTestModule()

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