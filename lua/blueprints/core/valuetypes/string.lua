AddCSLuaFile()

module("value_string", package.seeall)

RULE_NONE = 0
RULE_NOUPPERCASE = 1
RULE_NOSPACES = 2
RULE_NOSPECIAL = 4

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "string" end

function VALUE:Setup()

	self.ruleFlags = 0

end

function VALUE:BrowserClick( panel, textEntry )

end

function VALUE:Validate( v )

	if self.ruleFlags ~= 0 then
		if bit.band(self.ruleFlags, RULE_NOUPPERCASE) ~= 0 then
			v = string.gsub(v, "%u", function(x) return x:lower() end)
		end
		if bit.band(self.ruleFlags, RULE_NOSPACES) ~= 0 then
			v = string.gsub(v, "%s", function(x) return "_" end)
		end
		if bit.band(self.ruleFlags, RULE_NOSPECIAL) ~= 0 then
			v = string.gsub(v, "[^%l%u%d_]", function(x) return "_" end)
		end
	end
	return v

end

function VALUE:SetRuleFlags( ... )

	local flags = 0
	for _, fl in ipairs({...}) do flags = bit.bor(flags, fl) end

	self.ruleFlags = flags

end

function VALUE:CreateTextEntry( info, parent )

	local entry = vgui.Create("DTextEntry", parent)
	entry:SetText( self:Get() )
	entry:SelectAllOnFocus()
	if info.live then entry:SetUpdateOnType(true) end

	if info.onFinished then
		local detour = entry.OnKeyCodeTyped
		entry.OnKeyCodeTyped = function(pnl, code)
			if code == KEY_ENTER then return info.onFinished() end
			detour(pnl, code)
		end
	end
	entry.OnValueChange = function(pnl, value)
		local cp = entry:GetCaretPos()
		self:Set( value )
		entry:SetCaretPos(cp)
		--pnl:SetText( self:ToString() )
		if info.onChanged then info.onChanged() end
	end

	entry:SetEnabled(not self:HasFlag(bpvaluetype.FL_READONLY))

	self:AddListener( function(cb, old, new, key)
		if cb == bpvaluetype.CB_VALUE_CHANGED then
			entry:SetText( new )
		end 
	end )

	return entry

end

function VALUE:CreateVGUI( info )

	if self:HasFlag( bpvaluetype.FL_HINT_BROWSER ) then

		local panel = vgui.Create("DPanel")
		local entry = self:CreateTextEntry(info, panel)
		local button = vgui.Create("DButton", panel)
		button:SetText("...")
		button.DoClick = function() self:BrowserClick( button, entry ) end
		button:SetWide(32)

		entry:Dock( FILL )
		button:Dock( RIGHT )

		return panel

	else

		return self:CreateTextEntry( info )

	end

end

function VALUE:GetDefault() return "" end

function VALUE:ToString()

	return "\"" .. tostring( self:Get() ) .. "\""

end

function VALUE:SetFromString( str )

	self:Set( str:sub(2, -2) )
	return self

end

RegisterValueClass("string", VALUE)