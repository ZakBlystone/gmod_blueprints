AddCSLuaFile()

module("mod_configurable", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

MODULE = {}

MODULE.Creatable = false
MODULE.Name = "Configurable"

function MODULE:Setup()

	self.config = self.config or self:GetDefaultConfigTable()
	self.editvalues = bpvaluetype.FromValue(self.config, function() return self.config end)

	self:SetupEditValues( self.editvalues )

end

function MODULE:SetupEditValues( values )

end

function MODULE:GetMenuItems( tab )

	tab[#tab+1] = {
		name = "Configure",
		func = function(...) self:OpenVGUI(...) end,
		color = Color(100,100,0),
	}

end

function MODULE:OpenVGUI( parent )

	local window = vgui.Create( "DFrame" )
	window:SetSizable( true )
	window:SetSize( ScrW()/3, ScrH()/2 )
	window:MakePopup()
	window:Center()

	local inner = self:GetConfigEdit():CreateVGUI({})
	inner:SetParent(window)
	inner:Dock(FILL)

end

function MODULE:GetDefaultConfigTable()

	return {}

end

function MODULE:GetConfig()

	return self.config

end

function MODULE:GetConfigEdit()

	return self.editvalues

end

function MODULE:WriteData( stream, mode, version )

	bpdata.WriteValue( self.config or {}, stream )

end

function MODULE:ReadData( stream, mode, version )

	local config = bpdata.ReadValue( stream )
	local defaults = self:GetDefaultConfigTable()
	self.config = table.Merge(defaults, config)

end

RegisterModuleClass("Configurable", MODULE)