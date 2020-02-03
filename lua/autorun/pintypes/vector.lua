AddCSLuaFile()

local PIN = {}

function PIN:Setup()

	self._vector = Vector(0,0,0)
	self:OnLiteralChanged( nil, self:GetLiteral() )

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
		for x in new:gmatch("[%d%.]+") do
			self._vector[ i ] = tonumber(x)
			i = i + 1
		end
	end

end

function PIN:GetLiteralDisplay()

	return string.format("(%s, %s, %s)", self._vector.x, self._vector.y, self._vector.z)

end

function PIN:OnClicked()

	local pnl = bptextliteraledit.PinLiteralEditWindow( self, "EditablePanel", 300, 60, nil, 0, 0 )
	local entries = {}

	local function close()
		print("Close Parent")
		local window = pnl:GetParent()
		if IsValid(window) then
			window:Close()
		end
	end

	for i=1, 3 do
		local entry = vgui.Create("DTextEntry", pnl)
		local detour = entry.OnKeyCodeTyped
		entry.index = i
		entry:SetText( tostring(self._vector[i]) )
		entry:SetTabPosition( i )
		entry:SelectAllOnFocus()
		entry:SetNumeric(true)
		entry:SetUpdateOnType(true)
		entry.OnKeyCodeTyped = function(pnl, code)
			if code == KEY_ENTER then return close() end
			detour(pnl, code)
		end
		entry.OnValueChange = function(pnl, value)
			self._vector[pnl.index] = tonumber(value)
			self:SetLiteral( string.format("Vector(%s,%s,%s)", self._vector.x, self._vector.y, self._vector.z) )
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

bppinclasses.Register("Vector", PIN)