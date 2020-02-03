AddCSLuaFile()

module("bpnodeclasses", package.seeall, bpcommon.rescope(bpschema))

local nodeTypeBasePath = "autorun/nodetypes/"
local registered = {}
local initializing = false

function Register(name, tab)
	print("Registered class: " .. name .. " : " .. tostring(tab))
	registered[name:lower()] = tab

	if not initializing then
		hook.Run("BPNodeClassRefresh", name)
	end

end

function Get(name)
	return registered[name:lower()]
end

hook.Add("BPPostInit", "loadnodeclasses", function()

	initializing = true
	local files, folders = file.Find(nodeTypeBasePath .. "*", "LUA")
	for _, v in ipairs(files) do
		include(nodeTypeBasePath .. v)
	end
	initializing = false

end)