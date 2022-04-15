if SERVER then AddCSLuaFile() return end

text_edit_graph = LOCTEXT("dialog_edit_graph", "Edit Graph Parameters")
text_edit_inputs = LOCTEXT("dialog_edit_graph_inputs", "Inputs")
text_edit_outputs = LOCTEXT("dialog_edit_graph_outputs", "Outputs")

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