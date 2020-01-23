AddCSLuaFile()

module("bpnodeclasses", package.seeall, bpcommon.rescope(bpschema))

local nodeTypeBasePath = "autorun/nodetypes/"
local registered = {}

function Register(name, tab)
	print("Registered class: " .. name .. " : " .. tostring(tab))
	registered[name:lower()] = tab
end

function Get(name)
	return registered[name:lower()]
end

local files, folders = file.Find(nodeTypeBasePath .. "*", "LUA")
for _, v in ipairs(files) do
	include(nodeTypeBasePath .. v)
end