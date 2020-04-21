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
local currentLocale = "en-us"

-- Covers all gmod supported locales
local locales = {
	{"Bulgarian", "bg"},
	{"Chinese - China", "zh-cn"},
	{"Chinese - Taiwan", "zh-tw"},
	{"Croatian", "hr"},
	{"Czech", "cs"},
	{"Danish", "da"},
	{"Dutch - Netherlands", "nl-nl"},
	{"English - United States", "en-us"},
	{"English - Pirate", "en-pt"},
	{"Estonian", "et"},
	{"Finnish", "fi"},
	{"French - France", "fr-fr"},
	{"German - Germany", "de-de"},
	{"Greek", "el"},
	{"Hebrew", "he"},
	{"Hungarian", "hu"},
	{"Italian - Italy", "it-it"},
	{"Japanese", "ja"},
	{"Korean", "ko"},
	{"Lithuanian", "lt"},
	{"Norwegian - Nynorsk", "no-no"},
	{"Polish", "pl"},
	{"Portuguese - Brazil", "pt-br"},
	{"Portuguese - Portugal", "pt-pt"},
	{"Russian", "ru"},
	{"Slovak", "sk"},
	{"Spanish - Spain (Traditional)", "es-es"},
	{"Swedish - Sweden", "sv-se"},
	{"Thai", "th"},
	{"Turkish", "tr"},
	{"Ukrainian", "uk"},
	{"Vietnamese", "vi"},
}

function GetKnownLocales()

	return locales

end

function GetLocale()

	return currentLocale

end

function SetLocale(l)

	if locale[l] == nil then print("Language not supported: " .. tostring(l)) return end
	if l ~= currentLocale then
		currentLocale = l
		hook.Run("BPLocaleChanged")
	end

end

function GetSupported()

	local t = {}
	for _,v in ipairs(locale) do
		t[#t+1] = v.locale
	end
	return t

end

function AddLocTable(t, makeCurrent)

	if t == nil or t.locale == nil or t.keys == nil then error("Malformed language data") end
	locale[t.locale] = t
	if makeCurrent then SetLocale(t.locale) end

end

function RemoveLocTable(t)

	if t == nil or t.locale == nil then error("Malformed language data") end
	locale[t.locale] = nil
	SetLocale("en-us")

end

function GetData()

	return locale[currentLocale]

end

function GetLocString(key)

	local d = GetData()
	if d then return d.keys[key] or data[key] or key end

	return data[key] or key

end

meta.__call = function(s, ...) return string.format( GetLocString(s.key), ... ) end
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

local function ParseScript(script)

	MsgC(Color(255,180,0), "Parsing: " .. tostring(script) .. "... ")
	local str = file.Read(script, "LUA")
	if str == nil then MsgC(Color(255,100,100), "Failed\n") return end

	for m,d in string.gmatch(str, "LOCTEXT%(?\"([^\"]+)\",+%s*\"([^\"]+)\"") do
		data[m] = d
	end

	MsgC(Color(100,255,100), "Ok\n")

end

local function ProcessScripts(dir)

	local f, d = file.Find(dir .. "/*", "LUA")

	for _, sub in ipairs(d or {}) do
		ProcessScripts(dir .. "/" .. sub)
	end

	for _, file in ipairs(f or {}) do
		ParseScript(dir .. "/" .. file)
	end

end

_G.LOCTEXT = Get

local function UpdateFromGmodLanguage()

	local gmodLocale = GetConVar("gmod_language"):GetString():lower()
	local locale = nil
	for _, loc in ipairs(locales) do
		if loc[2]:find( gmodLocale ) then locale = loc[2]:lower() break end
	end

	if locale == nil then print("Failed to find locale for: '" .. gmodLocale .. "' defaulting to 'en-us'") end

	SetLocale( locale or "en-us" )

end

local NeedsScan = true

function ScanLuaFiles()

	if NeedsScan == false then return end
	ProcessScripts("blueprints")
	NeedsScan = false

end

cvars.RemoveChangeCallback("gmod_language", "localeChangeListener")
cvars.AddChangeCallback("gmod_language", function( convar, oldValue, newValue )

	UpdateFromGmodLanguage()

end, "localeChangeListener")

hook.Add("BPPostInit", "initLocalization", function()
	UpdateFromGmodLanguage()
end)

concommand.Add("bp_scan_localization", function()

	data = {}
	NeedsScan = true
	ScanLuaFiles()

end)