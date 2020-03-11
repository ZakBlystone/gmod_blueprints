AddCSLuaFile()

G_BPClassLoaders = G_BPClassLoaders or {}

module("bpclassloader", package.seeall)

local meta = bpcommon.MetaTable("bpclassloader")

function meta:Init(name, path, refreshHook, meta)

	self.meta = meta
	self.registered = {}
	self.initializing = false
	self.path = path
	self.refreshHook = refreshHook
	self.name = name

	hook.Add("BPPostInit", "BPClassLoader_" .. self.name, function()
		self:LoadClasses()
	end)

	_G["Register" .. name .. "Class"] = function(...) return self:Register(...) end

	return self

end

function meta:Register(name, tab, base)

	if base then base = base:lower() end

	local scriptEnv = getfenv(2)
	local registered = self.registered
	local parentMeta = self.meta

	tab.__index = function(s, k)
		local v = rawget(tab, k) if v then return v end
		local b = base and registered[base] if b then return b.__index(s, k) end
		return parentMeta[k]
	end

	tab.__indexer = setmetatable({}, tab)

	local env = setmetatable({},{
		__index = function(s,k)
			if k == "BaseClass" then
				local b = base and registered[base] if b then return b.__indexer end
				return parentMeta
			end
			return scriptEnv[k]
		end
	})

	for _, func in pairs(tab) do
		if type(func) == "function" then setfenv(func, env) end
	end

	registered[name:lower()] = tab

	if not initializing and self.refreshHook then
		hook.Run(self.refreshHook, name)
	end

	print("Registered [" .. self.name .. "] class: " .. name .. " : " .. tostring(tab))

end

function meta:GetClasses()

	local t = {}
	for k, v in pairs(self.registered) do t[#t+1] = k end
	return t

end

function meta:Get(name)

	return self.registered[name:lower()]

end

function meta:LoadClasses()

	self.initializing = true
	local files, folders = file.Find(self.path .. "*", "LUA")
	for _, v in ipairs(files) do include(self.path .. v) end
	self.initializing = false

end

function meta:Install(classname, parent)

	local class = self:Get(classname)
	if class == nil then error("Failed to get class: " .. classname) end

	setmetatable(parent, class)
	if class.Setup then parent:Setup() end

end

function Get(name, ...)

	G_BPClassLoaders[name] = G_BPClassLoaders[name] or bpcommon.MakeInstance(meta, name, ...)
	return G_BPClassLoaders[name]

end