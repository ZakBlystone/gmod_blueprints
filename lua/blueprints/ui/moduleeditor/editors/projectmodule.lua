if SERVER then AddCSLuaFile() return end

module("editor_projectmodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

function EDITOR:PopulateMenuBar( t )

	t[#t+1] = { name = "New SubModule", func = function() self:NewSubModule() end, icon = "icon16/asterisk_yellow.png" }

	BaseClass.PopulateMenuBar(self, t)

end

function EDITOR:Setup()

end

function EDITOR:PostInit()

	local mod = self:GetModule()
	mod:BindRaw("addedAsset", self, function() self:EnumerateAssets() end)
	mod:BindRaw("removedAsset", self, function() self:EnumerateAssets() end)

	self.assets = vgui.Create("DIconLayout")
	self.assets:SetSelectionCanvas( true )
	self.assets.OnChildAdded = function(pnl, child)
		child:SetSelectable( true )
	end
	self:SetContent( self.assets )
	self:EnumerateAssets()

end

function EDITOR:Shutdown()

	local mod = self:GetModule()
	mod:UnbindAll(self)

end

function EDITOR:ChooseAsset( asset )

	if isbpmodule(asset:GetAsset()) then
		local mod = asset:GetAsset()
		print("OPEN ASSET: " .. tostring(mod:GetName()))
		self:GetMainEditor():OpenModule( mod, mod:GetName() )
	end

end

function EDITOR:AddAsset( asset, icon )

	local pnl = nil
	if isbpmodule(asset:GetAsset()) then
		local mod = asset:GetAsset()
		if mod.Icon then
			pnl = vgui.Create("DImage")
			pnl:SetImage(mod.Icon)
			pnl:SetSize(64,64)
		end
	end

	local tile = vgui.Create("BPAssetTile")
	tile:SetSize(128,128)
	tile:SetText( asset:GetName() )
	tile.DoClick = function() self:ChooseAsset( asset ) end
	tile:SetInner( pnl )
	tile:SetIcon( icon )

	self.assets:Add( tile )

end

function EDITOR:EnumerateAssets()

	self.assets:Clear()

	for _, m in ipairs(self:GetModule():GetAssets()) do self:AddAsset(m) end

end

function EDITOR:NewSubModule()

	self:ModuleDropdown()

end

function EDITOR:AddModule(subModule)

	self:GetModule():AddModule(subModule)

end

function EDITOR:CreateModule(type)

	local mod = bpmodule.New(type)
	mod:CreateDefaults()
	self:AddModule(mod)

end

function EDITOR:ModuleDropdown()

	if IsValid(self.cmenu) then self.cmenu:Remove() end
	self.cmenu = DermaMenu( false, self )

	local loader = bpmodule.GetClassLoader()
	local classes = bpcommon.Transform( loader:GetClasses(), {}, function(k) return {name = k, class = loader:Get(k)} end )

	table.sort( classes, function(a,b) return tostring(a.class.Name) < tostring(b.class.Name) end )

	for _, v in ipairs( classes ) do

		local cl = v.class
		if not cl.Creatable or cl.Developer or not cl.CanBeSubmodule then continue end

		local op = self.cmenu:AddOption( tostring(cl.Name), function() self:CreateModule( v.name ) end)
		if cl.Icon then op:SetIcon( cl.Icon ) end
		if cl.Description then op:SetTooltip( tostring(cl.Description) ) end

	end

	self.cmenu:AddSpacer()
	local templateMenu, op = self.cmenu:AddSubMenu( tostring( LOCTEXT"module_submenu_examples","Examples" ) )
	op:SetIcon( "icon16/book.png" )

	for _, v in ipairs( classes ) do

		local cl = v.class
		if not cl.Creatable or not cl.CanBeSubmodule then continue end

		local templates = bptemplates.GetByType( v.name )
		if #templates > 0 then
			local sub, op = templateMenu:AddSubMenu( tostring(cl.Name) )
			if cl.Icon then op:SetIcon( cl.Icon ) end

			for _, t in ipairs( templates ) do
				local op = sub:AddOption( t.name, function()
					local mod = bptemplates.CreateTemplate( t )
					self:AddModule(mod)
				end )
				if cl.Icon then op:SetIcon( cl.Icon ) end
				op:SetTooltip( tostring(t.description) .. "\nby " .. tostring(t.author) )
			end
		end

	end


	self.cmenu:AddSpacer()
	local developerMenu, op = self.cmenu:AddSubMenu( tostring( LOCTEXT"module_submenu_developer","Developer" ) )
	op:SetIcon( "icon16/application_osx_terminal.png" )

	for _, v in ipairs( classes ) do

		local cl = v.class
		if not cl.Creatable or not cl.Developer or not cl.CanBeSubmodule then continue end

		local op = developerMenu:AddOption( tostring(cl.Name), function() self:CreateModule( v.name ) end)
		if cl.Icon then op:SetIcon( cl.Icon ) end
		if cl.Description then op:SetTooltip( tostring(cl.Description) ) end

	end

	self.cmenu:SetMinimumWidth( 100 )
	self.cmenu:Open( gui.MouseX(), gui.MouseY(), false, self:GetPanel() )

end

RegisterModuleEditorClass("projectmodule", EDITOR, "basemodule")