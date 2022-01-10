if SERVER then AddCSLuaFile() return end

module("bpmodal", package.seeall)

-- common localization strings for query dialogs
local query_loc = {
	["ok"] = LOCTEXT("query_ok", "Ok"),
	["yes"] = LOCTEXT("query_yes", "Yes"),
	["no"] = LOCTEXT("query_no", "No"),
	["cancel"] = LOCTEXT("query_cancel", "Cancel"),
	["error"] = LOCTEXT("query_error", "Error"),
}

local function GetLoc(x)

	if type(x) == "table" then return tostring(x) end
	local l = query_loc[string.lower(x or "")]
	if l then return l() end
	return x or ""

end

--[[{
	options = {
		{ title = "Test", func = function() end, }
		{ options = {
			title = "Others",
			options = {
				{ title = "Hi", func = function() end, }
			}
		} }
	}
}]]

local function RecursiveConstructMenu(menu, t, depth)

	for k, v in ipairs(t.options) do

		local submenu, op = nil
		if v.options then
			submenu, op = menu:AddSubMenu( GetLoc(v.title), v.func )
			RecursiveConstructMenu( submenu, v, depth + 1 )
		elseif not v.title then
			menu:AddSpacer()
		else
			op = menu:AddOption( GetLoc(v.title), v.func )
		end

		if op then
			if v.icon then op:SetIcon( v.icon ) end
			if v.desc then op:SetTooltip( GetLoc(v.desc) ) end
		end

	end

end

function Menu(t, parent)

	local menu = DermaMenu( false, parent )
	RecursiveConstructMenu( menu, t, 0 )

	if t.width then
		menu:SetMinimumWidth(t.width)
	end

	menu:Open( t.x or gui.MouseX(), t.y or gui.MouseY(), false, parent )
	menu:SetSkin("Blueprints")

	return menu

end

function String(t)

	local pnl = Derma_StringRequest(
		GetLoc(t.title or "Blueprints"), 
		GetLoc(t.message or "Blueprints"), 
		t.default or "", 
		t.confirm or function() end, 
		t.cancel or function() end,
		GetLoc(t.confirmText or "ok"), 
		GetLoc(t.cancelText or "cancel"))

	pnl:SetSkin("Blueprints")
	return pnl

end

function Query(t)

	local pnl = Derma_Query(
		GetLoc(t.message or ""),
		GetLoc(t.title or "Blueprints"),
		t.options[1] and GetLoc(t.options[1][1]) or "Button",
		t.options[1] and t.options[1][2] or nil,
		t.options[2] and GetLoc(t.options[2][1]) or nil,
		t.options[2] and t.options[2][2] or nil,
		t.options[3] and GetLoc(t.options[3][1]) or nil,
		t.options[3] and t.options[3][2] or nil,
		t.options[4] and GetLoc(t.options[4][1]) or nil,
		t.options[4] and t.options[4][2] or nil)

	pnl:SetSkin("Blueprints")
	return pnl

end

function Message(t)

	local pnl = Derma_Message(
		GetLoc(t.message or "Blueprints"),
		GetLoc(t.title or "Blueprints"),
		GetLoc(t.button or "ok"))

	pnl:SetSkin("Blueprints")
	return pnl

end