if SERVER then AddCSLuaFile() return end

module("bpuigrapheditmenu", package.seeall, bpcommon.rescope(bpschema))

function EditGraphParams( graph )

	local width = 500

	local window = vgui.Create( "DFrame" )
	window:SetTitle( "Edit Graph Parameters" )
	window:SetDraggable( true )
	window:ShowCloseButton( true )
	window.OnRemove = function(self)
		hook.Remove("BPEditorBecomeActive", tostring(self))
	end

	hook.Add("BPEditorBecomeActive", tostring(window), function()
		if IsValid(window) then window:Remove() end
	end)

	local inputs = bpuivarcreatemenu.VarList( graph, window, graph.inputs, "Inputs" )
	local outputs = bpuivarcreatemenu.VarList( graph, window, graph.outputs, "Outputs" )

	inputs:SetWide( width / 2 - 10 )
	outputs:SetWide( width / 2 - 10 )

	inputs:Dock( LEFT )
	outputs:Dock( RIGHT )

	window:SetSize( 500, 400 )
	window:Center()

	window:MakePopup()

end