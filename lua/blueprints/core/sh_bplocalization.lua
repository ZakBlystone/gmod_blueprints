AddCSLuaFile()

if SERVER then
	_G.LOCTEXT = function(k) return k end
	return
end

module("bplocalization", package.seeall)

local data = {}
local cache = {}
local meta = {}
local locModule = nil

function InstallModule(mod)

	locModule = mod

end

function GetLocString(key)

	if locModule then
		return locModule:GetLocString(key) or data[key] or key
	end

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

	local str = file.Read(script, "LUA")

	for m,d in string.gmatch(str, "LOCTEXT%(?\"([^\"]+)\",+%s*\"([^\"]+)\"") do
		data[m] = d
	end

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
ProcessScripts("blueprints")

if CLIENT then

	concommand.Add("bp_refresh_localization", function()

		data = {}
		ProcessScripts("blueprints")

	end)

end