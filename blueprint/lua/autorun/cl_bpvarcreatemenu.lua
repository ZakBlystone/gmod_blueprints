if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")

module("bpuivarcreatemenu", package.seeall, bpcommon.rescope(bpschema, bpnodedef))


local PANEL = {}

function PANEL:Init()

end

vgui.Register( "BPVarCreateMenu", PANEL, "EditablePanel" )

function RequestVarSpec( callback, parent )

	local Window = vgui.Create( "DFrame" )
	Window:SetTitle( "Create Variable" )
	Window:SetDraggable( true )
	Window:ShowCloseButton( true )

	--Window:SetBackgroundBlur( true )
	--Window:SetDrawOnTop( true )

	local Combo = vgui.Create("DComboBox", Window )
	local TableOption = vgui.Create("DCheckBoxLabel", Window)
	local NameEntry = vgui.Create("DTextEntry", Window )

	local ftime = .1
	local wthink = Window.Think
	Window.Think = function(self)
		wthink(self)
		ftime = ftime - FrameTime()
		if ftime <= 0 and not self:HasAnyFocus() then self:Close() end
	end

	local ButtonPanel = vgui.Create( "DPanel", Window )
	ButtonPanel:SetTall( 30 )
	ButtonPanel:SetPaintBackground( true )

	local function DoClose()
		if IsValid(parent) then parent:Hold() end -- dumb hack
		Window:Close() 
	end

	local Button = vgui.Create( "DButton", ButtonPanel )
	Button:SetText( "OK" )
	Button:SizeToContents()
	Button:SetTall( 20 )
	Button:SetWide( Button:GetWide() + 20 )
	Button:SetPos( 5, 5 )
	Button.DoClick = function()

		local name = NameEntry:GetText()
		local text, type = Combo:GetSelected()
		local flags = 0

		if TableOption:GetChecked() then flags = bit.bor( flags, PNF_Table ) end

		callback( name, type, flags )

		DoClose()
	end

	local ButtonCancel = vgui.Create( "DButton", ButtonPanel )
	ButtonCancel:SetText( "Cancel" )
	ButtonCancel:SizeToContents()
	ButtonCancel:SetTall( 20 )
	ButtonCancel:SetWide( Button:GetWide() + 20 )
	ButtonCancel:SetPos( 5, 5 )
	ButtonCancel.DoClick = function() DoClose() end
	ButtonCancel:MoveRightOf( Button, 5 )

	ButtonPanel:SetWide( Button:GetWide() + 5 + ButtonCancel:GetWide() + 10 )


	Window.HasAnyFocus = function(self)
		return self:HasFocus() or NameEntry:HasFocus() or Button:HasFocus() or ButtonCancel:HasFocus()
	end

	for i=0, PN_Max do
		if i == PN_Any or i == PN_Exec then continue end
		Combo:AddChoice( PinTypeNames[i], i, i == 1 )
		--Combo:AddChoice( "Another Choice", "myData" )
		--Combo:AddChoice( "Default Choice", "myData2", true )
		--Combo:AddChoice( "Icon Choice", "myData3", false, "icon16/star.png" )
	end

	Combo:SetWide( 150 )

	TableOption:SetText("As Table")


	Window:SetSize( 300, 200 )
	Window:Center()

	NameEntry:SetWide(150)
	NameEntry:CenterHorizontal()
	NameEntry:AlignTop(40)

	Combo:CenterHorizontal()
	Combo:AlignTop(60)

	TableOption:CenterHorizontal()
	TableOption:AlignTop(100)

	ButtonPanel:CenterHorizontal()
	ButtonPanel:AlignBottom( 8 )

	Window:MakePopup()
	return Window
	--Window:DoModal()

end