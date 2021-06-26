AddCSLuaFile()

module("mod_configurable", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

MODULE = {}


MODULE.Creatable = false
MODULE.AdditionalConfig = false

function MODULE:Setup()

	if self.AdditionalConfig then
		self.config = self.config or self:GetDefaultConfigTable()
	end

end

function MODULE:SetupEditValues( values )

end

function MODULE:OpenVGUI( parent )

	bpcommon.ProfileStart("edit defaults")

	local window = vgui.Create( "DFrame" )
	window:SetSizable( true )
	window:SetSize( ScrW()/3, ScrH()/2 )
	window:MakePopup()
	window:SetTitle(LOCTEXT("menu_setdefaults", "Set Defaults")())
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

	local edit = self:GetConfigEdit( true )

	bpcommon.Profile("create-gui", function()
		local inner = edit:CreateVGUI({ live = true, })
		inner:SetParent(window)
		inner:Dock(FILL)
	end)

	bpcommon.ProfileEnd()

end

function MODULE:GetDefaultConfigTable()

	return {}

end

function MODULE:GetConfig()

	return self.config or {}

end

function MODULE:BuildCosmeticVars( values )

end

function MODULE:GetConfigEdit( refresh )

	if self.configEdit and not refresh then return self.configEdit end

	local values = bpvaluetype.FromValue(self:GetConfig(), function() return self:GetConfig() end)

	self:BuildCosmeticVars( values )

	values:SortChildren()

	self:SetupEditValues( values )

	self.configEdit = values

	return values

end

function MODULE:WriteData( stream, mode, version )

	if self.AdditionalConfig then
		bpdata.WriteValue( self:GetConfig(), stream )
	end

end

function MODULE:ReadData( stream, mode, version )

	if self.AdditionalConfig then
		local config = bpdata.ReadValue( stream )
		local defaults = self:GetDefaultConfigTable()
		self.config = table.Merge(defaults, config)
	end

end

RegisterModuleClass("Configurable", MODULE)