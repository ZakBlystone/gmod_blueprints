if SERVER then AddCSLuaFile() return end

module("bpuigrapheditmenu", package.seeall, bpcommon.rescope(bpschema))

local function GraphVarList( graph, window, list, name )

	local module = graph.module
	local vlist = vgui.Create( "BPListView", window )
	vlist:SetList( list )
	vlist:SetText( name )
	vlist:SetNoConfirm()
	vlist.HandleAddItem = function(pnl)
		local id, item = list:Add( MakePin( PD_None, nil, PN_Bool, PNF_None, nil ), name )
		pnl:Rename(id)
	end
	vlist.OpenMenu = function(pnl, id, item)
		window.menu = bpuivarcreatemenu.OpenPinSelectionMenu(module, function(pnl, pinType)
			graph:PreModify()
			item:SetType( pinType )
			graph:PostModify()
		end)
	end
	vlist.ItemBackgroundColor = function( list, id, item, selected )
		local vcolor = item:GetColor()
		if selected then
			return vcolor
		else
			return Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5)
		end
	end

	return vlist

end

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

	local inputs = GraphVarList( graph, window, graph.inputs, "Inputs" )
	local outputs = GraphVarList( graph, window, graph.outputs, "Outputs" )

	inputs:SetWide( width / 2 - 10 )
	outputs:SetWide( width / 2 - 10 )

	inputs:Dock( LEFT )
	outputs:Dock( RIGHT )

	window:SetSize( 500, 400 )
	window:Center()

	window:MakePopup()

end