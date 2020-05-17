if SERVER then AddCSLuaFile() return end

module("editor_dermalayout", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.HasSideBar = true

function EDITOR:Setup()

end

function EDITOR:PopulateMenuBar( t )

	BaseClass.PopulateMenuBar(self, t)

	--[[if not self.editingModuleTab then
		t[#t+1] = { name = "New SubModule", func = function() self:NewSubModule() end, icon = "icon16/asterisk_yellow.png" }
	end]]

	--t[#t+1] = { name = "Toggle Design Mode", func = function() self:ToggleDesignMode() end, color = Color(120,60,90) }

end

function EDITOR:ToggleDesignMode()

end

function EDITOR:CreatePanel()

	self.preview = vgui.Create("DFrame")
	self.preview:SetSize(400,300)
	self.preview:SetPaintedManually(true)
	self.preview:Hide()

	local btn = vgui.Create("DButton", self.preview)
	btn:Dock(FILL)

end

function EDITOR:DestroyPanel()

	if IsValid( self.preview ) then
		self.preview:Remove()
	end

end

function EDITOR:PostInit()

	self:CreatePanel()

	self.vpreview = vgui.Create("BPDPreview")
	self.vpreview.Draw2D = function(pnl)
		if IsValid(self.preview) then
			self.preview:PaintAt(0,0)
		end
	end
	self:SetContent( self.vpreview )

end

function EDITOR:Shutdown()

	self:DestroyPanel()

end

function EDITOR:Think()

end

function EDITOR:PopulateSideBar()

	self.hierarchyPanel = vgui.Create("DPanel")
	self.hierarchyPanel:SetSize(100,200)
	self.hierarchyPanel:SetMinimumSize(100,200)
	self.hierarchyPanel:SetBackgroundColor(Color(40,40,40))

	self.hierarchyTree = vgui.Create("DTree", self.hierarchyPanel)
	self.hierarchyTree:Dock( FILL )

	self.hierarchyBar = self:AddSidebarPanel(LOCTEXT("editor_dermalayout_hierarchy","Hierarchy"), self.hierarchyPanel)

	self.callbackList = self:AddSidebarList(LOCTEXT("editor_dermalayout_callbacks","Callbacks"))
	self.callbackList.HandleAddItem = function(pnl, list)

	end

	local root = self.hierarchyTree:Root()
	local win = root:AddNode("Window", "icon16/application_form.png")
	local btn = win:AddNode("Button", "icon16/application.png")
	btn:ExpandTo(true)

end

RegisterModuleEditorClass("dermalayout", EDITOR, "basemodule")