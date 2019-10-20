AddCSLuaFile()

include("sh_bpcommon.lua")

module("bpdefs", package.seeall)

local defs = {}
local enums = {}

DEFTYPE_ENUM = 0

local function EnumerateDefs( base, output )

	local files, folders = file.Find(base, "THIRDPARTY")
	for _, f in pairs(files) do table.insert(output, base:sub(0,-2) .. f) end
	for _, f in pairs(folders) do EnumerateDefs( base:sub(0,-2) .. f .. "/*", output ) end

end

function GetEnum( name )

	return enums[name]

end

local function ParseDef( filePath )

	local str = file.Read( filePath, "THIRDPARTY" )
	local lines = string.Explode("\n", str)
	local d = nil
	local br = false
	local def = {}
	for _, l in pairs(lines) do

		local tr = l:Trim()
		local args = string.Explode(",", tr)
		if tr:sub(0, 4) == "ENUM" then
			d = {
				type = DEFTYPE_ENUM,
				enum = args[1]:sub(6,-1),
				desc = table.concat(args, ",", 2):Trim(),
				entries = {},
				lookup = {},
			}
		elseif tr:sub(0,1) == "{" then
			br = true
		elseif tr:sub(0,1) == "}" then
			table.insert(def, d)
			br = false
			d = nil
		elseif br then
			local k = {
				key = args[1]:Trim(),
				desc = table.concat(args, ",", 2):Trim(),
			}
			k.desc = k.desc:len() > 0 and k.desc or nil

			local srch = (k.desc or ""):lower()
			if srch:find("deprecated") ~= nil then k.deprecated = true end
			if srch:find("warning") ~= nil then k.unsafe = true end
			table.insert(d.entries, k)
			d.lookup[k.key] = #d.entries
		end

	end
	return def

end

local function CreateReducedEnumKeys( enum )

	local blacklist = {
		"LAST",
		"FIRST",
		"ALL",
	}

	local blacklisted = {}

	local common = enum.entries[1].key
	for k,v in pairs(enum.entries) do
		for _, b in pairs(blacklist) do
			if v.key:sub(0, b:len()) == b then blacklisted[v.key] = true break end
		end
		if blacklisted[v.key] then continue end

		while common:len() > 0 and v.key:sub(0, common:len()) ~= common do
			common = common:sub(0,-2)
		end
	end

	local commonLen = common:len()
	for k,v in pairs(enum.entries) do
		v.shortkey = blacklisted[v.key] and v.key or v.key:sub(commonLen+1, -1)
	end

end

local foundDefs = {}
EnumerateDefs( "data/bpdefs/*", foundDefs )



for k,v in pairs(foundDefs) do
	if SERVER then resource.AddFile( v ) end
	local parsed = ParseDef(v)
	table.Add(defs, parsed)
end

for k,v in pairs(defs) do
	if v.type == DEFTYPE_ENUM then CreateReducedEnumKeys(v) enums[v.enum] = v end
end

--PrintTable( foundDefs )