if SERVER then AddCSLuaFile() return end

module("bpuieditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}
local TITLE = "Blueprint Editor"

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

	self.FileManager = vgui.Create("BPFileManager")
	self.FileManager.editor = self

	self.Tabs:AddSheet( "Files", self.FileManager, nil, false, false, "Files" )

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

function PANEL:OpenModule( mod )

	local title = bpcommon.GUIDToString( mod:GetUID(), true )
	local view = vgui.Create("BPModuleEditor")
	local sheet = self.Tabs:AddSheet( title, view, nil, false, false, title )
	view:SetModule( mod )
	view.editor = self

	self.openModules[mod:GetUID()] = sheet

	self.Tabs:SetActiveTab( sheet.Tab )

end

function PANEL:CloseModule( mod )

	local opened = self.openModules[mod:GetUID()]

	self.Tabs:CloseTab( opened.Tab )
	opened.Panel:Remove()

end

vgui.Register( "BPEditor", PANEL, "DFrame" )


--if true then return end

local function OpenEditor()

	if not bpdefs.Ready() then
		print("Wait for definitions to load")
		return
	end

	if G_BPEditorInstance then

		if IsValid(G_BPEditorInstance) then G_BPEditorInstance:Remove() end
		G_BPEditorInstance = nil

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

concommand.Add("open_blueprint", function()

	OpenEditor()

end)

hook.Add("PlayerBindPress", "catch_f2", function(ply, bind, pressed)

	if bind == "gm_showteam" then
		OpenEditor()
	end

end)