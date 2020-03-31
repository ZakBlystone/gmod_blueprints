AddCSLuaFile()

if SERVER then
	_G.LOCTEXT = function(k) return k end
	return
end

module("bplocalization", package.seeall)

local data = {}
local cache = {}
local meta = {}
local locale = {}
local currentLocale = "en_us"

function SetLocale(l)

	if locale[l] == nil then print("Language not supported: " .. tostring(l)) return end
	currentLocale = l

end

function GetSupported()

	local t = {}
	for _,v in ipairs(locale) do
		t[#t+1] = v.locale
	end
	return t

end

function AddLocTable(t)

	if t == nil or t.locale == nil or t.keys == nil then error("Malformed language data") end
	locale[t.locale] = t

end

function RemoveLocTable(t)

	if t == nil or t.locale == nil then error("Malformed language data") end
	locale[t.locale] = nil

end

function GetData()

	return locale[currentLocale]

end

function GetLocString(key)

	local d = GetData()
	if d then return d.keys[key] or data[key] or key end

	return data[key] or key

end

meta.__tostring = function(s) return GetLocString(s.key) end
meta.__concat = function(s,b) return GetLocString(s.key) .. b end
meta.__lt = function(a,b) return tostring(a) < tostring(b) end
meta.__le = function(a,b) return tostring(a) <= tostring(b) end
meta.__eq = function(a,b) return tostring(a) == tostring(b) end

function Create(key)

	return setmetatable({key = key}, meta)

end

function Get(key)

	cache[key] = cache[key] or Create(key)
	return cache[key]

end

function GetKeys()

	local t = {}
	for k, _ in pairs(data) do
		t[#t+1] = k
	end
	table.sort(t)
	return t

end

function ParseScript(script)

	MsgC(Color(255,180,0), "Parsing: " .. tostring(script) .. "... ")
	local str = file.Read(script, "LUA")
	if str == nil then MsgC(Color(255,100,100), "Failed\n") return end

	for m,d in string.gmatch(str, "LOCTEXT%(?\"([^\"]+)\",+%s*\"([^\"]+)\"") do
		data[m] = d
	end

	MsgC(Color(100,255,100), "Ok\n")

end

function ProcessScripts(dir)

	local f, d = file.Find(dir .. "/*", "LUA")

	for _, sub in ipairs(d or {}) do
		ProcessScripts(dir .. "/" .. sub)
	end

	for _, file in ipairs(f or {}) do
		ParseScript(dir .. "/" .. file)
	end

end

_G.LOCTEXT = Get

if CLIENT then

	hook.Add("BPPostInit", "initLocalization", function()
		ProcessScripts("blueprints")
	end)

	concommand.Add("bp_refresh_localization", function()

		data = {}
		ProcessScripts("blueprints")

	end)

end