AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")

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
for k,v in pairs(files) do
	include(nodeTypeBasePath .. v)
end