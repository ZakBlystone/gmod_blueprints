if SERVER then AddCSLuaFile() return end

module("bpuigrapheditmenu", package.seeall, bpcommon.rescope(bpschema))

local function GraphVarList( module, window, list, name )

	local vlist = vgui.Create( "BPListView", window )
	vlist:SetList( list )
	vlist:SetText( name )
	vlist:SetNoConfirm()
	vlist.HandleAddItem = function(pnl)
		window.spec = bpuivarcreatemenu.RequestVarSpec( module, function(name, type, flags, ex) 
			list:Add( bpvariable.New( type, nil, flags, ex ), name )
		end, window )
	end
	vlist.ItemBackgroundColor = function( list, id, item, selected )
		local vcolor = bpschema.NodePinColors[item.type]
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

	local inputs = GraphVarList( graph.module, window, graph.inputs, "Inputs" )
	local outputs = GraphVarList( graph.module, window, graph.outputs, "Outputs" )

	inputs:SetWide( width / 2 - 10 )
	outputs:SetWide( width / 2 - 10 )

	inputs:Dock( LEFT )
	outputs:Dock( RIGHT )

	window.OnFocusChanged = function(self, gained)
		timer.Simple(.1, function()
			if not (gained or vgui.FocusedHasParent(window)) then
				self:Close()
			end
		end)
	end

	window:SetSize( 500, 400 )
	window:Center()

	window:MakePopup()

end