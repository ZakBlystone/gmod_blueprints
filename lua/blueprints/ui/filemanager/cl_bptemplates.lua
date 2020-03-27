if SERVER then AddCSLuaFile() return end

module("bptemplates", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local TEMPLATE_SEARCH = "gamemodes/bpdefs/content/templates/*"
local templates = {}

local function EnumerateTemplates( base, output, search )

	local files, folders = file.Find(base, search)
	for _, f in ipairs(files) do output[#output+1] = {base:sub(0,-2) .. f, search} end
	for _, f in ipairs(folders) do EnumerateTemplates( base:sub(0,-2) .. f .. "/*", output, search ) end

end

local function ParseTemplate( filePath, pathType )

	local str = file.Read( filePath, pathType )
	if str == nil then error("Failed to read template: " .. tostring(filePath)) end

	local template = {}

	for _, line in ipairs( string.Explode("\n", str) ) do
		for x,y in string.gmatch(line, "(%w+)%s*:%s*([^%c]+)") do
			template[x] = y
		end
	end

	if not template["type"] then error("Template must contain type keyword") end
	template["type"] = template["type"]:lower()

	return template

end

function LoadTemplates()

	local files = {}
	EnumerateTemplates( TEMPLATE_SEARCH, files, "THIRDPARTY" )

	templates = {}

	for k,v in ipairs(files) do
		xpcall( function()
			local template = ParseTemplate( unpack(v) )
			templates[#templates+1] = template
		end, function(err) print(tostring(err) .. "\n" .. debug.traceback()) end )
	end

end

function Get()

	return templates

end

function GetByType( type )

	local t = {}
	for k,v in ipairs(Get()) do
		if v.type == type then t[#t+1] = v end
	end
	table.sort(t, function(a,b) return a.name < b.name end)
	return t

end

function CreateTemplate( template )

	local mod = bpmodule.New()
	mod:LoadFromText( template.code )
	mod:GenerateNewUID()
	return mod

end

LoadTemplates()