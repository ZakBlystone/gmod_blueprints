if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpgraph.lua")
include("sh_bpstruct.lua")

module("bpuistructeditmenu", package.seeall, bpcommon.rescope(bpschema, bpnodedef))

local function StructVarList( module, window, list, name )

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

function EditStructParams( struct )

	local width = 500

	local window = vgui.Create( "DFrame" )
	window:SetTitle( "Edit Struct Pins" )
	window:SetDraggable( true )
	window:ShowCloseButton( true )

	local pins = StructVarList( struct.module, window, struct.pins, "Pins" )
	pins:Dock( FILL )

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