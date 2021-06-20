AddCSLuaFile()

module("bpcompat", package.seeall)

COMPAT_HOOKS = {}
COMPAT_ENV = nil
COMPAT_SCRIPT = nil
COMPAT_PATH = nil
COMPAT_GLOBALS = { 
	package = {
		seeall = function(x)
			local m = getmetatable(x)
			m.__index = COMPAT_ENV
		end,
		preload = {},
		loaders = {},
		loaded = {},
	},
	module = function(x, ...)
		--print("MODULE: " .. tostring(x))
		local mod = setmetatable({}, {
			__index = {},
			__newindex = function(s,k,v)
				rawset(s, k, v)
			end,
		})
		for _, x in ipairs({...}) do
			x(mod)
		end
		setfenv(COMPAT_SCRIPT, mod)
		COMPAT_GLOBALS.package.loaded[x] = mod
	end,
	hook = {
		Add = function(ev, key, func, ...)
			COMPAT_HOOKS[ev] = COMPAT_HOOKS[ev] or {}
			COMPAT_HOOKS[ev][key] = function(...)
				return func(...)
			end
			--print("HOOK: " .. ev)
		end,
		Run = function(ev, ...)
			PrintTable(COMPAT_HOOKS[ev] or {})
			for k,v in pairs(COMPAT_HOOKS[ev] or {}) do
				v(...)
			end
		end,
	},
	AddCSLuaFile = function(x)
		if CLIENT then return end
		local script = (x or COMPAT_PATH)
		if script then 
			AddCSLuaFile(script) 
			print(script)
		end
	end,
	include = function(path)
		path = path:gsub("blueprints/", "blueprints/system/compat16/")
		--print("INCLUDE PATH: " .. tostring(path))
		local script = CompileFile(path)
		local PUSH_STATE = COMPAT_SCRIPT
		local PUSH_PATH = COMPAT_PATH
		COMPAT_PATH = path
		COMPAT_SCRIPT = script
		setfenv(script, COMPAT_ENV)
		script()
		COMPAT_SCRIPT = PUSH_STATE
		COMPAT_PATH = PUSH_PATH
	end,
	file = setmetatable({
		Find = function(path, type)
			if type == "LUA" then
				path = path:gsub("blueprints/", "blueprints/system/compat16/")
			end
			local f,d = file.Find(path, type)
			--print("FIND: " .. path .. " : " .. #f)
			return f,d
		end,
	}, {
		__index = _G.file
	}),
	-- hack to satisfy bptextwrap module being used on clients during pin init
	bptextwrap = {
		New = function()
			local inst = {}
			setmetatable(inst, {
				__index = function() return function() return inst end end,
			})
			return inst
		end
	},
}

local ProtectedGlobals = {
	G_BPMetaRegistry = true,
	G_BPClassLoaders = true,
}

local SafeTables = {
	table = true,
	math = true,
	bit = true,
	debug = true,
	util = true,
	string = true,
	os = true,
	surface = true,
	file = true,
	system = true,
}

COMPAT_ENV = setmetatable({}, {
	__newindex = function(s,k,v) COMPAT_GLOBALS[k] = v end,
	__index = function(s,k) 
		--print("L REG: " .. k) 
		if k == "_G" then return COMPAT_ENV end
		if ProtectedGlobals[k] then return COMPAT_GLOBALS[k] end
		local x = COMPAT_GLOBALS[k] or COMPAT_GLOBALS.package.loaded[k]
		if x then return x end
		if type(_G[k]) == "table" and not SafeTables[k] then return nil end
		return _G[k]
	end, 
})

local function bpinclude(path)
	local script = CompileFile("blueprints/system/compat16/" .. path)
	COMPAT_PATH = "blueprints/system/compat16/" .. path
	COMPAT_SCRIPT = script
	setfenv(script, COMPAT_ENV)
	script()
end

-- CORE
--bpinclude("core/sh_bplocalization.lua")
bpinclude("core/sh_bpcommon.lua")
bpinclude("core/sh_bpclassloader.lua")
bpinclude("core/sh_bpcollection.lua")
bpinclude("core/sh_bpindexer.lua")
bpinclude("core/sh_bpbuffer.lua")
bpinclude("core/sh_bplist.lua")
bpinclude("core/sh_bplistdiff.lua")
bpinclude("core/sh_bpstringtable.lua")
bpinclude("core/sh_bpdata.lua")

-- GRAPH
bpinclude("graph/sh_bpschema.lua")
bpinclude("graph/sh_bppintype.lua")
bpinclude("graph/sh_bppin.lua")
bpinclude("graph/sh_bpcast.lua")
--bpinclude("graph/sh_bpcompiler.lua")
bpinclude("graph/sh_bpnodetype.lua")
bpinclude("graph/sh_bpnodetypegroup.lua")
bpinclude("graph/sh_bpnode.lua")
bpinclude("graph/sh_bpgraph.lua")

-- MODULE
bpinclude("module/sh_bpvariable.lua")
bpinclude("module/sh_bpstruct.lua")
bpinclude("module/sh_bpevent.lua")
bpinclude("module/sh_bpmodule.lua")
--bpinclude("module/sh_bpcompiledmodule.lua")
--bpinclude("module/sh_bpenv.lua")
--bpinclude("module/sh_bpnet.lua")

--PrintTable(COMPAT_GLOBALS)

-- DEFS
bpinclude("defs/sh_bpdefpack.lua")
bpinclude("defs/sh_bpdefs.lua")

print("RUNNING COMPAT INIT HOOK")
COMPAT_ENV.hook.Run("BPPostInit")