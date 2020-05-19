if SERVER then AddCSLuaFile() return end

module("editor_dermalayout", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.HasSideBar = true
EDITOR.HasDetails = true
EDITOR.CanExportLuaScript = true

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

function EDITOR:OpenDetails( node )

	self.detailGUI = node:GetEdit():CreateVGUI({ live = true, })
	self.detailsSlot:SetContents( self.detailGUI )

end

function EDITOR:NodeSelected(node)

	self:OpenDetails(node)

end

function EDITOR:CreatePanel()

	self:DestroyPanel()

	local ok, res = self:GetModule():TryBuild( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
	if ok then
		local ok, lres = res:TryLoad()
		if ok then

			local unit = res:Get()
			self.preview = unit.create()

			if IsValid(self.preview) then
				self.preview:SetPaintedManually(true)
				self.preview:Hide()

				self:GetModule():Root():MapToPreview( self.preview )
			end

		else

			print("Load failure: " .. tostring(lres))

		end
	else

		print("Compile failure: " .. tostring(res))

	end

end

function EDITOR:DestroyPanel()

	if IsValid( self.preview ) then
		self.preview:Remove()
	end

end

function EDITOR:PostInit()

	self:CreatePanel()

	self.vpreview = vgui.Create("BPDPreview")
	self.vpreview:SetPanel( self.preview )
	self:SetContent( self.vpreview )

	self.detailsBar = vgui.Create("BPCategoryList")
	self.detailsSlot = self.detailsBar:Add( "Details" )
	self:SetDetails( self.detailsBar )

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

	self:BuildNodeTree()

end

function EDITOR:RecursiveAddNode(vnode, node)

	local newNode = vnode:AddNode(node:GetName(), node.Icon or "icon16/application.png")
	newNode:SetExpanded(true)
	newNode.node = node
	newNode.DoClick = function()
		self:NodeSelected( node )
	end
	for _, child in ipairs(node:GetChildren()) do
		self:RecursiveAddNode( newNode, child )
	end

end

function EDITOR:BuildNodeTree()

	self.hierarchyTree:Clear()

	local rootNode = self:GetModule():Root()
	local root = self.hierarchyTree:Root()

	if not rootNode then return end

	self:RecursiveAddNode( root, rootNode )

end

RegisterModuleEditorClass("dermalayout", EDITOR, "basemodule")