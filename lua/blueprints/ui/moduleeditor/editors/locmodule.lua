if SERVER then AddCSLuaFile() return end

module("editor_locmodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.CanInstallLocally = true
EDITOR.CanExportLuaScript = true

function EDITOR:Setup()

	local mod = self:GetModule()
	self.values = bpvaluetype.FromValue(mod.data, function() return mod.data end)

	local rank = {
		["locale"] = 1,
		["keys"] = 2,
	}
	function self.values:SortChildren()
		table.sort(self._children, function(a,b)
			if rank[a.k] == rank[b.k] then
				return tostring(a.k) < tostring(b.k)
			end
			return rank[a.k] < rank[b.k]
		end)
		return self
	end

	self.values:SortChildren()
	self.values:Index("locale"):OverrideClass( "enum" ):SetOptions( bplocalization.GetKnownLocales() )

end

function EDITOR:PostInit()

	local inner = self.values:CreateVGUI({ live = true, })

	self:SetContent( inner )

end

function EDITOR:InstallLocally()

	BaseClass.InstallLocally( self )

	bpmodal.Query({
		message = "Editor must restart to see changes, do this now?",
		title = "Install Locally",
		options = {
			{"yes", function() self:Save( function(status) if status == true then bpuieditor.OpenEditor( true ) end end ) end},
			{"no", function() end},
		},
	})

end

function EDITOR:UninstallLocally()

	BaseClass.UninstallLocally( self )

	bpmodal.Query({
		message = "Editor must restart to see changes, do this now?",
		title = "Uninstall Locally",
		options = {
			{"yes", function() self:Save( function(status) if status == true then bpuieditor.OpenEditor( true ) end end ) end},
			{"no", function() end},
		},
	})

end

RegisterModuleEditorClass("locmodule", EDITOR, "basemodule")