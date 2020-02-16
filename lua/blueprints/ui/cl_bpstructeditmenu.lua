if SERVER then AddCSLuaFile() return end

module("bpuistructeditmenu", package.seeall, bpcommon.rescope(bpschema))

local function StructVarList( struct, window, list, name )

	local module = struct.module
	local vlist = vgui.Create( "BPListView", window )
	vlist:SetList( list )
	vlist:SetText( name )
	vlist:SetNoConfirm()
	vlist.HandleAddItem = function(pnl)
		list:Add( MakePin( PD_None, nil, PN_Bool, PNF_None, nil ), name )
	end
	vlist.OpenMenu = function(pnl, id, item)
		window.menu = bpuivarcreatemenu.OpenPinSelectionMenu(module, function(pnl, pinType)
			module:PreModifyNodeType( struct:MakerNodeType() )
			module:PreModifyNodeType( struct:BreakerNodeType() )
			item:SetType( pinType )
			module:PostModifyNodeType( struct:MakerNodeType() )
			module:PostModifyNodeType( struct:BreakerNodeType() )
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

function EditStructParams( struct )

	local width = 500

	local window = vgui.Create( "DFrame" )
	window:SetTitle( "Edit Struct" )
	window:SetDraggable( true )
	window:ShowCloseButton( true )
	window.OnRemove = function(self)
		hook.Remove("BPEditorBecomeActive", tostring(self))
	end

	hook.Add("BPEditorBecomeActive", tostring(window), function()
		if IsValid(window) then window:Remove() end
	end)

	local pins = StructVarList( struct, window, struct.pins, "Pins" )
	pins:Dock( FILL )

	window:SetSize( 500, 400 )
	window:Center()

	window:MakePopup()

end

function EditEventParams( event )

	local width = 500

	local window = vgui.Create( "DFrame" )
	window:SetTitle( "Edit Event" )
	window:SetDraggable( true )
	window:ShowCloseButton( true )
	window.OnRemove = function(self)
		hook.Remove("BPEditorBecomeActive", tostring(self))
	end

	hook.Add("BPEditorBecomeActive", tostring(window), function()
		if IsValid(window) then window:Remove() end
	end)

	window:SetSize( 500, 400 )
	window:Center()

	local param = vgui.Create("DPanel", window)
	param:SetPaintBackground(false)
	param:SetWide(300)

	local label = vgui.Create("DLabel", param)
	label:SetText("Net Mode:")
	label:SizeToContents()
	label:Dock( LEFT )
	local netmode = vgui.Create("DComboBox", param )
	netmode:Dock( FILL )
	netmode:SetSortItems(false)

	for _, v in ipairs( bpevent.NetModes ) do
		netmode:AddChoice( v[1], v[2], bit.band( event:GetFlags(), bpevent.EVF_Mask_Netmode ) == v[2] )
	end

	netmode.OnSelect = function( pnl, index, value, data )
		local flags = bit.band( event:GetFlags(), bpevent.EVF_Mask_Netmode )
		if flags ~= data then
			local keep = bit.band( event:GetFlags(), bit.bnot( bpevent.EVF_Mask_Netmode ) )
			event:PreModify()
			event:SetFlags( bit.bor(keep, data) )
			event:PostModify()
		end
	end

	param:CenterHorizontal()
	param:AlignTop(40)
	param:DockMargin(10,10,10,10)
	param:Dock( TOP )

	local pins = StructVarList( event.module, window, event.pins, "Pins" )
	pins:Dock( FILL )

	window:MakePopup()

end