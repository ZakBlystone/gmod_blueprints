local meta = bpcommon.MetaTable("bpmoduleeditor")
local editorClasses = bpclassloader.Get("ModuleEditor", "blueprints/ui/moduleeditor/editors/", "BPModuleEditorClassRefresh", meta)

meta.HasSideBar = false

function meta:Init( editUI, module )

	self.editClass = module.EditorClass
	self.editUI = editUI
	self.editor = editUI:GetParent()
	editorClasses:Install( self.editClass, self )
	return self

end

function meta:PostInit() end
function meta:Think() end
function meta:Shutdown() end
function meta:CreateVGUI( parent ) end
function meta:HandleError( errorData ) end
function meta:GetMainEditor() return self:GetPanel().editor end
function meta:GetPanel() return self.editUI end
function meta:GetTab() return self:GetPanel().tab end
function meta:GetModule() return self:GetPanel():GetModule() end
function meta:GetFile() return self:GetModule():FindOuter( bpfile_meta ) end
function meta:SetContent( panel ) self:GetPanel():SetContent( panel ) end
function meta:PopulateMenuBar( menu ) end
function meta:PopulateSideBar() end
function meta:AddSidebarPanel( ... ) return self:GetPanel():AddSidebarPanel(...) end
function meta:AddSidebarList( ... ) return self:GetPanel():AddSidebarList(...) end

local function NewEditor(...)
	return setmetatable({}, meta):Init(...)
end

if SERVER then AddCSLuaFile() return end

module("bpuimoduleeditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}

function PANEL:Init()

	local editor = self:GetParent()

	self.Menu = bpuimenubar.AddTo(self)

	self.callback = function(...)
		self:OnModuleCallback(...)
	end

end

function PANEL:SetContent( panel )

	if IsValid(self.ContentSplit) then

		self.ContentSplit:SetRight( panel )

	else

		panel:SetParent( self.ContentPanel )
		panel:Dock( FILL )

	end

end

function PANEL:CreateContentPanel()

	if IsValid( self.ContentPanel ) then
		self.ContentPanel:Remove()
	end

	self.ContentPanel = vgui.Create("DPanel", self)
	self.ContentPanel:Dock( FILL )
	self.ContentPanel:SetBackgroundColor( Color(50,50,50) )

end

function PANEL:AddSidebarPanel( name, panel )

	local cat = self.SideBar:Add( name or "Unnamed" )
	cat:SetContents( panel )

	return cat

end

function PANEL:AddSidebarList( name )

	local view = vgui.Create("BPListPanel")

	local cat = self:AddSidebarPanel( name, view )
	local add = cat:CreateAddButton()
	add.DoClick = function() view:InvokeAdd() end

	return view

end

function PANEL:Think()

	if self.moduleEditor then
		self.moduleEditor:Think()
	end

end

function PANEL:OnRemove()

	if _G.G_BPError and _G.G_BPError.uid == self.module:GetUID() then
		self.editor:ClearReport()
		_G.G_BPError = nil
	end

	self:SetModule(nil)

end

function PANEL:Refresh()

	self:SetModule( self:GetModule() )

end

function PANEL:MarkAsModified()

	--print("Marking module as modified")

	local file = self:GetModule():FindOuter( bpfile_meta )
	if file and not file:HasFlag( bpfile.FL_HasLocalChanges ) then
		if self.tab then self.tab:SetSuffix("*") end
		bpfilesystem.MarkFileAsChanged( file )
	end

end

function PANEL:SetModule( mod )

	if self.module then
		self.module:UnbindAll( self )
	end

	if self.moduleEditor then
		self.moduleEditor:Shutdown()
	end

	self.module = mod

	if mod == nil then return end
	self.module:Bind("cleared", self, self.Refresh)
	self.module:BindAny(self, self.MarkAsModified)

	self.moduleEditor = NewEditor( self, self.module )

	self.Menu:Clear()
	self:CreateContentPanel()

	if IsValid(self.SideBar) then self.SideBar:Remove() end
	if self.moduleEditor.HasSideBar then

		self.ContentSplit = vgui.Create("DHorizontalDivider", self.ContentPanel)
		self.ContentSplit:Dock( FILL )
		self.ContentSplit:SetBackgroundColor( Color(30,30,30) )
		self.ContentSplit:SetDividerWidth( 3 )

		self.SideBar = vgui.Create("BPCategoryList", self.ContentSplit)
		self.moduleEditor:PopulateSideBar()

		self.SideBar:InvalidateLayout( true )
		self.ContentSplit:SetLeftWidth(150)
		self.ContentSplit:SetLeft(self.SideBar)

	end

	local menu = {}
	self.moduleEditor:PopulateMenuBar( menu )
	self.module:GetMenuItems( menu )

	self.Menu:Add("Refresh", function()

		self:Refresh()

	end, Color(10,100,5), nil)

	for k,v in ipairs(menu) do
		self.Menu:Add(v.name, v.func, v.color, v.icon)
	end

	self.moduleEditor:PostInit()

end

function PANEL:GetModule()

	return self.module

end

function PANEL:HandleError( errorData )

	if self.moduleEditor then
		self.moduleEditor:HandleError( errorData )
	end

end

vgui.Register( "BPModuleEditor", PANEL, "DPanel" )