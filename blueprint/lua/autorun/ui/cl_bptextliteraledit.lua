if SERVER then AddCSLuaFile() return end

include("../sh_bpschema.lua")

module("bptextliteraledit", package.seeall, bpcommon.rescope(bpschema, bpnodedef))

function EditPinLiteral( vpin )

	local node = vpin:GetVNode():GetNode()
	local pinID = vpin:GetPinID()
	local literalType = vpin:GetPin():GetLiteralType()

	local literal = tostring(node:GetLiteral(pinID))

	local width = 500
	local x, y = gui.MouseX(), gui.MouseY()

	local window = vgui.Create( "DFrame" )
	window:SetTitle( vpin:GetPin():GetDisplayName() )
	window:SetDraggable( false )
	window:ShowCloseButton( false )

	window:SetSize( 400, 60 )
	window:SetPos(x - 8, y - 30)
	--window.Paint = function() end

	local text = vgui.Create("DTextEntry", window)
	text:Dock(FILL)
	text:SetText(literal)
	text:RequestFocus()
	text:SelectAllOnFocus()

	if literalType == "number" then
		text:SetNumeric(true)
		window:SetSize( 100, 60 )
	else
		text:SetMultiline(false)
	end

	text.OnFocusChanged = function(self, gained)
		timer.Simple(.1, function()
			if not gained then
				if IsValid(self) then node:SetLiteral( pinID, tostring(self:GetText()) ) end
				if IsValid(window) then window:Close() end
			end
		end)
	end

	window:MakePopup()

end