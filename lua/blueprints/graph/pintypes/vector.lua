AddCSLuaFile()

local PIN = {}

function PIN:Setup()

	self._vector = Vector(0,0,0)
	self._prec = {1,1,1}
	self:OnLiteralChanged( nil, self:GetLiteral() )

end

function PIN:NumToStr( i )

	if self._prec[i] == 0 then return string.format("%d", self._vector[i]) end
	return string.format("%0." .. self._prec[i] .. "f", self._vector[i])

end

function PIN:StrToNum( x, i )

	local _,_,dec = x:find("%-*%d*%.(%d+)")
	dec = dec and (#dec) or 0
	self._prec[i] = dec
	self._vector[i] = tonumber(x)

end

function PIN:CanHaveLiteral()

	return true

end

function PIN:GetDefault()

	return "Vector(0,0,0)"

end

function PIN:OnLiteralChanged( old, new )

	if new then
		local i = 1
		for x in new:gmatch("%-*[%d%.]+") do
			self:StrToNum( x, i )
			i = i + 1
		end
	end

end

function PIN:GetLiteralDisplay()

	return string.format("%s, %s, %s",
	self:NumToStr(1),
	self:NumToStr(2),
	self:NumToStr(3))

end

function PIN:OnClicked()

	local pnl = bptextliteraledit.PinLiteralEditWindow( self, "EditablePanel", 300, 60, nil, 0, 0 )
	local entries = {}

	local function close()
		--print("Close Parent")
		local window = pnl:GetParent()
		if IsValid(window) then
			window:Close()
		end
	end

	for i=1, 3 do
		local entry = vgui.Create("DTextEntry", pnl)
		local detour = entry.OnKeyCodeTyped
		entry.index = i
		entry:SetText( self:NumToStr(i) )
		entry:SetTabPosition( i )
		entry:SelectAllOnFocus()
		entry:SetNumeric(true)
		entry:SetUpdateOnType(true)
		entry.OnKeyCodeTyped = function(pnl, code)
			if code == KEY_ENTER then return close() end
			detour(pnl, code)
		end
		entry.OnValueChange = function(pnl, value)
			self:StrToNum( value, pnl.index )
			self:SetLiteral( string.format("Vector(%s,%s,%s)",
				self:NumToStr(1),
				self:NumToStr(2),
				self:NumToStr(3) ))
		end
		entries[i] = entry
	end

	pnl.PerformLayout = function(pnl)

		local w,h = pnl:GetSize()

		for i=1, #entries do
			local entry = entries[i]
			entry:SetPos((i-1) * 100,0)
			entry:SetSize(w/3, h)
		end

	end


end

RegisterPinClass("Vector", PIN)