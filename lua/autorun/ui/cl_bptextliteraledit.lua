if SERVER then AddCSLuaFile() return end

module("bptextliteraledit", package.seeall, bpcommon.rescope(bpschema))

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

	local detour = text.OnKeyCodeTyped
	text.OnKeyCodeTyped = function(self, keyCode)
		if keyCode == KEY_TAB then

			if ( IsValid( self.Menu ) ) then

				self.HistoryPos = self.HistoryPos + 1
				self:UpdateFromHistory()

			end

			return true
		end
		detour(self, keyCode)
	end

	text.OnFocusChanged = function(self, gained)
		timer.Simple(.1, function()
			if not gained then
				if IsValid(self) then
					local text = self:GetText()
					if text then text = text:gsub("^sound/", "") end --HACK because sound paths don't start with 'sound/'
					node:SetLiteral( pinID, tostring(text) )
				end
				if IsValid(window) then window:Close() end
			end
		end)
	end

	local function matchSubpath(text, fileType)

		local partial = text:gsub("/[%w_]*$","") .. "/"
		local remaining = text:gmatch("/([%w_]*)$")()
		local _, folders = file.Find(partial .. "*", "GAME")
		local files, _ = file.Find(partial .. "*." .. fileType, "GAME")
		local t = {}
		for _, v in ipairs(folders or {}) do
			if not remaining or v:StartWith(remaining) then t[#t+1] = partial .. v end
		end
		for _, v in ipairs(files or {}) do
			if not remaining or v:StartWith(remaining) then t[#t+1] = partial .. v end
		end
		return t

	end

	-- Dumb quick stupid hack to make asset path entry easier
	text.GetAutoComplete = function(pnl, text)

		local _, _, root = text:find("^(%w+)/")
		if root == "models" then
			return matchSubpath(text, "mdl")
		elseif root == "sound" then
			return matchSubpath(text, "wav")
		elseif root == "sounds" then -- because I keep accidentally typing this
			return matchSubpath(text:gsub("^sounds", "sound"), "wav")
		elseif root == "materials" then
			return matchSubpath(text, "vmt")
		end

	end

	text.UpdateFromMenu = function( pnl )

		local pos = pnl.HistoryPos
		local num = pnl.Menu:ChildCount()

		pnl.Menu:ClearHighlights()

		if ( pos < 0 ) then pos = num end
		if ( pos > num ) then pos = 0 end

		local item = pnl.Menu:GetChild( pos )
		if ( !item ) then
			pnl:SetText( "" )
			pnl.HistoryPos = pos
			return
		end

		pnl.Menu:HighlightItem( item )

		local txt = item:GetText()

		pnl:SetText( txt )
		pnl:SetCaretPos( txt:len() )

		pnl:OnTextChanged( true, true )

		pnl.HistoryPos = pos

	end

	text.OnTextChanged = function( pnl, noMenuRemoval, keepAutoComplete )

		pnl.HistoryPos = 0

		if ( pnl:GetUpdateOnType() ) then
			pnl:UpdateConvarValue()
			pnl:OnValueChange( pnl:GetText() )
		end

		if ( IsValid( pnl.Menu ) && !noMenuRemoval ) then
			pnl.Menu:Remove()
		end

		if not keepAutoComplete then
			local tab = pnl:GetAutoComplete( pnl:GetText() )
			if ( tab ) then
				pnl:OpenAutoComplete( tab )
			end
		end

		pnl:OnChange()

	end

	window:MakePopup()

end