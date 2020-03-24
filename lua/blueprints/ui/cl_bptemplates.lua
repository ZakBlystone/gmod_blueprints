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

	local f = file.Open( filePath, "r", pathType )
	local template = {}

	local x = 1000
	while x > 0 do
		x = x - 1
		local line = f:ReadLine()
		if line == nil then break end
		for x,y in string.gmatch(line, "(.+)%s*:%s*([^%c]+)") do
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
		templates[#templates+1] = ParseTemplate( unpack(v) )
	end

	PrintTable( files )

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