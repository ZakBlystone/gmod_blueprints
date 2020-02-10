AddCSLuaFile()

module("bppinclasses", package.seeall, bpcommon.rescope(bpschema))

local pinTypeBasePath = "blueprints/pintypes/"
local registered = {}
local initializing = false

function Register(name, tab)
	print("Registered pin class: " .. name .. " : " .. tostring(tab))
	registered[name:lower()] = tab

	if not initializing then
		hook.Run("BPPinClassRefresh", name)
	end

end

function Get(name)
	return registered[name:lower()]
end

hook.Add("BPPostInit", "loadpinclasses", function()

	initializing = true
	local files, folders = file.Find(pinTypeBasePath .. "*", "LUA")
	for _, v in ipairs(files) do
		include(pinTypeBasePath .. v)
	end
	initializing = false

end)