if SERVER then AddCSLuaFile() return end

module("bpuieditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}
local TITLE = "Blueprint Editor"

local deleteOnClose = CreateConVar("bp_delete_editor_on_close", "0", FCVAR_ARCHIVE, "For debugging, re-created editor UI")

LastSavedFile = nil

function PANEL:RunCommand( func, ... )
	self.StatusText:SetTextColor( Color(255,255,255) )
	self.StatusText:SetText("")

	local b = xpcall( func, function( err )
		_G.G_BPError = nil
		self.StatusText:SetTextColor( Color(255,100,100) )
		self.StatusText:SetText( err )
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

	self.Tabs = vgui.Create("DPropertySheet", self )
	self.Tabs:DockMargin(0, 0, 0, 5)
	self.Tabs:Dock( FILL )
	self.Tabs:SetPadding( 0 )

	self.Status = vgui.Create("DPanel", self)
	self.Status:Dock( BOTTOM )
	self.Status:SetBackgroundColor( Color(50,50,50) )

	self.StatusText = vgui.Create("DLabel", self.Status)
	self.StatusText:SetFont("DermaDefaultBold")
	self.StatusText:Dock( FILL )
	self.StatusText:SetText("")

	self.wasActive = false
	self.openModules = {}

	self.UserManager = vgui.Create("BPUserManager")

	self.FileManager = vgui.Create("BPFileManager")
	self.FileManager.editor = self

	self.Tabs:AddSheet( "Users", self.UserManager, nil, false, false, "Users" )
	self.Tabs:SetActiveTab( self.Tabs:AddSheet( "Files", self.FileManager, nil, false, false, "Files" ).Tab )

end

function PANEL:Think()

	self.BaseClass.Think(self)

	if _G.G_BPError ~= nil then
		if self.BpErrorWasNil then
			self.BpErrorWasNil = false
			self.StatusText:SetText( "Blueprint Error: " .. _G.G_BPError.msg .. " [" .. _G.G_BPError.graphID .. "]" )
			self.GraphList:Select(_G.G_BPError.graphID)
		end
	else
		self.BpErrorWasNil = true
	end

	if self:IsActive() then
		if not self.wasActive then
			print("EDITOR BECOME ACTIVE")
			hook.Run("BPEditorBecomeActive")
			self.wasActive = true
		end
	else
		if self.wasActive then
			print("EDITOR BECOME INACTIVE")
			self.wasActive = false
		end
	end


end

function PANEL:OnFocusChanged( gained )

	print("MAIN PANEL FOCUS CHANGE: " .. tostring(gained))

end

function PANEL:OpenModule( mod, name, file )

	local existing = self.openModules[mod:GetUID()]
	if existing then
		self.Tabs:SetActiveTab( existing.Tab )
		return
	end

	local title = "Module: " .. name or bpcommon.GUIDToString( mod:GetUID(), true )
	local view = vgui.Create("BPModuleEditor")
	local sheet = self.Tabs:AddSheet( title, view, nil, false, false, title )
	view:SetModule( mod )
	view.editor = self
	view.file = file

	self.openModules[mod:GetUID()] = sheet

	self.Tabs:SetActiveTab( sheet.Tab )

end

function PANEL:OpenFile( file )

	local mod = bpmodule.New()
	mod:Load(file:GetPath())
	self:OpenModule( mod, file:GetName(), file )

end

function PANEL:CloseFile( file, callback )

	print("CLOSING FILE: " .. tostring(file:GetName()))

	local opened = self.openModules[file:GetUID()]
	local nop = function() end

	callback = callback or nop

	if opened and file:HasFlag( bpfile.FL_HasLocalChanges ) then 
		self.Tabs:SetActiveTab( opened.Tab )
		Derma_Query("This module has unsaved changes, would you like the save them?", "Close",
		"Yes", function() if opened.Panel:Save() then bpfilesystem.MarkFileAsChanged( file, false ) self:CloseFileUID( file:GetUID() ) callback() end end,
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

	if not bpdefs.Ready() then
		print("Wait for definitions to load")
		return
	end

	if IsValid(G_BPEditorInstance) then

		if deleteOnClose:GetBool() then

			if IsValid(G_BPEditorInstance) then G_BPEditorInstance:Remove() end
			G_BPEditorInstance = nil

		else

			G_BPEditorInstance:SetVisible( true )
			return

		end

	end

	--for i=1, 2 do
	local editor = vgui.Create( "BPEditor" )
	editor:SetVisible(true)
	editor:MakePopup()
	--end

	--local mod = bpmodule.New()
	--editor:OpenModule( mod )
	--mod:Load("blueprints/bpm_ded3.txt")
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

concommand.Add("open_blueprint", function()

	OpenEditor()

end)

hook.Add("PlayerBindPress", "catch_f2", function(ply, bind, pressed)

	if bind == "gm_showteam" then
		OpenEditor()
	end

end)
