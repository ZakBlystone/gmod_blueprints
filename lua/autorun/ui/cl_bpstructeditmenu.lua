if SERVER then AddCSLuaFile() return end

module("bpuistructeditmenu", package.seeall, bpcommon.rescope(bpschema))

local function StructVarList( module, window, list, name )

	local vlist = vgui.Create( "BPListView", window )
	vlist:SetList( list )
	vlist:SetText( name )
	vlist:SetNoConfirm()
	vlist.HandleAddItem = function(pnl)
		window.spec = bpuivarcreatemenu.RequestVarSpec( module, function(name, type, flags, ex) 
			list:Add( MakePin(PD_None, nil, type, flags, ex), name )
		end, window )
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

function EditEventParams( event )

	local width = 500

	local window = vgui.Create( "DFrame" )
	window:SetTitle( "Edit Event" )
	window:SetDraggable( true )
	window:ShowCloseButton( true )

	window.OnFocusChanged = function(self, gained)
		timer.Simple(.1, function()
			if not (gained or vgui.FocusedHasParent(window)) then
				if IsValid(self) then self:Close() end
			end
		end)
	end

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