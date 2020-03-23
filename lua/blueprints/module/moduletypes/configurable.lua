AddCSLuaFile()

module("mod_configurable", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

MODULE = {}

MODULE.Creatable = false
MODULE.Name = "Configurable"
MODULE.AdditionalConfig = false

function MODULE:Setup()

	BaseClass.Setup(self)

	if self.AdditionalConfig then
		self.config = self.config or self:GetDefaultConfigTable()
	end

end

function MODULE:SetupEditValues( values )

end

function MODULE:GetMenuItems( tab )

	tab[#tab+1] = {
		name = "Set Defaults",
		func = function(...) self:OpenVGUI(...) end,
		color = Color(60,120,200),
	}

end

function MODULE:OpenVGUI( parent )

	bpcommon.ProfileStart("edit defaults")

	local window = vgui.Create( "DFrame" )
	window:SetSizable( true )
	window:SetSize( ScrW()/3, ScrH()/2 )
	window:MakePopup()
	window:SetTitle("Set Defaults")
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

function MODULE:GetConfigEdit( refresh )

	if self.configEdit and not refresh then return self.configEdit end

	local values = bpvaluetype.FromValue(self:GetConfig(), function() return self:GetConfig() end)
	local varDefaults = bpvaluetype.FromValue({}, function() return {} end)

	for _,v in self:Variables() do
		--local b,e = pcall( function()
			local value = nil
			local vt = bpvaluetype.FromPinType(
				v:GetType():Copy(v.module),
				function() return value end,
				function(newValue) value = newValue end
			)

			if vt == nil then continue end
			
			print( v:GetName() .. " = " .. tostring(v:GetDefault()) )

			vt:SetFromString( tostring(v:GetDefault()) )
			vt:AddListener( function(cb, old, new, k)
				if cb ~= bpvaluetype.CB_VALUE_CHANGED then return end
				v:SetDefault( vt:ToString() )
			end )

			varDefaults:AddCosmeticChild( v:GetName(), vt )
		--end)
		--if not b then print("Failed to add pintype: " .. tostring(e)) end
	end

	values:AddCosmeticChild("defaults", varDefaults)
	values:SortChildren()

	self:SetupEditValues( values )

	self.configEdit = values

	return values

end

function MODULE:WriteData( stream, mode, version )

	BaseClass.WriteData( self, stream, mode, version )

	if self.AdditionalConfig then
		bpdata.WriteValue( self:GetConfig(), stream )
	end

end

function MODULE:ReadData( stream, mode, version )

	BaseClass.ReadData( self, stream, mode, version )

	if self.AdditionalConfig then
		local config = bpdata.ReadValue( stream )
		local defaults = self:GetDefaultConfigTable()
		self.config = table.Merge(defaults, config)
	end

end

RegisterModuleClass("Configurable", MODULE, "GraphModule")