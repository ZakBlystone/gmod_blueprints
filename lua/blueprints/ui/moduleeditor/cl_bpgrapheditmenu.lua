if SERVER then AddCSLuaFile() return end

text_edit_graph = LOCTEXT("dialog_edit_graph", "Edit Graph Parameters")
text_edit_inputs = LOCTEXT("dialog_edit_graph_inputs", "Inputs")
text_edit_outputs = LOCTEXT("dialog_edit_graph_outputs", "Outputs")

var_edit_text = LOCTEXT("editor_graphmodule_edit_var", "Editing Variable")
var_edit_repmode = LOCTEXT("editor_graphmodule_edit_varrepmode", "Network Sync Mode:")

module("bpuigrapheditmenu", package.seeall, bpcommon.rescope(bpschema))

function EditGraphParams( graph )

	local width = 500

	local window = vgui.Create( "DFrame" )
	window:SetTitle( text_edit_graph() )
	window:SetDraggable( true )
	window:ShowCloseButton( true )
	window.OnRemove = function(self)
		hook.Remove("BPEditorBecomeActive", tostring(self))
	end

	hook.Add("BPEditorBecomeActive", tostring(window), function()
		if IsValid(window) then window:Remove() end
	end)

	local inputs = bpuivarcreatemenu.VarList( graph, window, graph.inputs, text_edit_inputs(), "In" )
	local outputs = bpuivarcreatemenu.VarList( graph, window, graph.outputs, text_edit_outputs(), "Out" )

	inputs:SetSize( width, 200 )
	outputs:SetSize( width, 200 )

	inputs:DockMargin(5,5,5,5)
	inputs:Dock( TOP )
	outputs:DockMargin(5,5,5,5)
	outputs:Dock( TOP )

	window:SetSize( 500, 500 )
	window:Center()

	window:MakePopup()

end

local RepModes = {
	REP_None,
	REP_SyncOwner,
	REP_SyncPVS,
	REP_SyncEveryone,
}

function EditVariable( var, parent, mod, vlist )

	--local inner = vgui.Create("DPanel", parent)
	--inner:SetPaintBackground(false)
	--inner:SetWide(300)

	local repmode_opt = {}
	for _, v in ipairs( RepModes ) do
		if mod:IsVariableRepModeAllowed( v ) then
			repmode_opt[#repmode_opt+1] = { v, v, RepModeNames[v], RepModeDesc[v]() }
		end
	end

	local config = {}
	local cat = bpvaluetype.FromValue(config, function() return config end)
	local supports_rep = var:SupportsReplication()

	cat:AddCosmeticChild("Name",
		bpvaluetype.New("string", 
			function() return var:GetName() end,
			function(x) vlist.list:Rename( var, x ) end )
	)

	if supports_rep then
		cat:AddCosmeticChild("Network Sync Mode",
			bpvaluetype.New("enum", 
				function() return var.repmode end,
				function(x) var.repmode = x end )
					:SetOptions(repmode_opt, false)
					:SetFlag( supports_rep and 0 or bpvaluetype.FL_READONLY )
		)
	end

	-- Default value edit
	local value = nil
	local vt = bpvaluetype.FromPinType(
		var:GetType():Copy(mod),
		function() return value end,
		function(newValue) value = newValue end
	)

	if vt ~= nil then
		vt:SetFromString( tostring(var:GetDefault()) )
		vt:BindRaw( "valueChanged", parent, function(old, new, k)
			var:SetDefault( vt:ToString() )
		end )

		cat:AddCosmeticChild("Default Value", vt)
	end

	local default_edit = cat:CreateVGUI({})
	default_edit:SetParent(parent)
	default_edit:Dock(FILL)

end