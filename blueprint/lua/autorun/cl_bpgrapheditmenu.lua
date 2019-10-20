if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpgraph.lua")

module("bpuigrapheditmenu", package.seeall, bpcommon.rescope(bpschema, bpnodedef))

local function GraphVarList( window, list, name )

	local vlist = vgui.Create( "BPListView", window )
	vlist:SetList( list )
	vlist:SetText( name )
	vlist:SetNoConfirm()
	vlist.HandleAddItem = function(pnl)
		window.spec = bpuivarcreatemenu.RequestVarSpec( function(name, type, flags) 
			list:Add( bpvariable.New( type, nil, flags ), name )
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

	local inputs = GraphVarList( window, graph.inputs, "Inputs" )
	local outputs = GraphVarList( window, graph.outputs, "Outputs" )

	inputs:SetWide( width / 2 - 10 )
	outputs:SetWide( width / 2 - 10 )

	inputs:Dock( LEFT )
	outputs:Dock( RIGHT )

	window.HasAnyFocus = function(self)
		return self:HasFocus() or (IsValid(window.spec) and window.spec:HasAnyFocus())
	end


	local ftime = .1
	local wthink = window.Think
	window.Hold = function() ftime = .1 end
	window.Think = function(self)
		wthink(self)
		ftime = ftime - FrameTime()
		if ftime <= 0 and not self:HasAnyFocus() then self:Close() end
	end

	window:SetSize( 500, 400 )
	window:Center()

	window:MakePopup()

end