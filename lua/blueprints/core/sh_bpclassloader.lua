AddCSLuaFile()

module("bpclassloader", package.seeall)

local meta = bpcommon.MetaTable("bpclassloader")

function meta:Init(name, path, refreshHook)

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

function meta:Register(name, tab)

	print("Registered [" .. self.name .. "] class: " .. name .. " : " .. tostring(tab))
	self.registered[name:lower()] = tab

	if not initializing and self.refreshHook then
		hook.Run(self.refreshHook, name)
	end

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

	local base = getmetatable(parent)
	local meta = table.Copy(class)
	table.Inherit(meta, base)
	meta.__index = meta
	setmetatable(parent, meta)
	if meta.Setup then parent:Setup() end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end