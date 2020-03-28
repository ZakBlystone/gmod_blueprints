if SERVER then AddCSLuaFile() return end

module("editor_locmodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

function EDITOR:Setup()

	local mod = self:GetModule()
	self.values = bpvaluetype.FromValue(mod.data, function() return mod.data end)

	local rank = {
		["language"] = 1,
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

end

function EDITOR:PopulateMenuBar( t )

	BaseClass.PopulateMenuBar( self, t )

	t[#t+1] = { name = LOCTEXT("loc_install", "Install"), func = function() bplocalization.InstallModule( self:GetModule() ) end, icon = "icon16/disk.png" }
	t[#t+1] = { name = LOCTEXT("loc_reset", "Reset"), func = function() bplocalization.InstallModule( nil ) end, icon = "icon16/disk.png" }


end

function EDITOR:PostInit()

	local inner = self.values:CreateVGUI({ live = true, })

	self:SetContent( inner )

end

RegisterModuleEditorClass("locmodule", EDITOR, "basemodule")