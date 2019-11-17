AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bppintype.lua")

module("bppin", package.seeall)

local meta = {}
meta.__index = function(self, k)
	if k == 1 then print("Accessed[1], use :GetDir") print(debug.traceback()) return self:GetDir() end
	if k == 2 then print("Accessed[2], use :GetBaseType") print(debug.traceback()) return self:GetType():GetBaseType() end
	if k == 3 then print("Accessed[3], use :GetName") print(debug.traceback()) return self:GetName() end
	if k == 4 then print("Accessed[4], use :GetFlags") print(debug.traceback()) return self:GetType():GetFlags() end
	if k == 5 then print("Accessed[5], use :GetSubType") print(debug.traceback()) return self:GetType():GetSubType() end
	return meta[k]
end

meta.__newindex = function(self, k, v)
	if k == 1 then print("Set[1], use :SetDir") print(debug.traceback()) self:SetDir(v) end
	if k == 2 then error("Tried to set type!!!") end
	if k == 3 then print("Set[3], use :SetName") print(debug.traceback()) self:SetName(v) end
	if k == 4 then error("Tried to set flags!!!") end
	if k == 5 then error("Tried to set subtype!!!") end
	rawset(self, k, v)
end

meta.__tostring = function(self)
	return self:ToString(true, true)
end

function meta:Init(dir, name, type)
	self.dir = dir
	self.name = name
	self.type = type
	return self
end

function meta:SetDir(dir) self.dir = dir return self end
function meta:SetName(name) self.name = name return self end
function meta:SetDisplayName(name) self.displayName = name return self end
function meta:SetInformedType(type) self.informed = type return self end

function meta:GetInformedType() return self.informed end

function meta:GetDir()
	return self.dir
end

function meta:GetType(raw)
	if raw then return self.type end
	return self.informed or self.type
end

function meta:GetName()
	return self.name
end

function meta:GetDisplayName()
	return self.displayName or self:GetName()
end

function meta:IsIn() return self:GetDir() == bpschema.PD_In end
function meta:IsOut() return self:GetDir() == bpschema.PD_Out end
function meta:IsType(...) return self:GetType():IsType(...) end
function meta:GetBaseType(...) return self:GetType():GetBaseType() end
function meta:GetSubType(...) return self:GetType():GetSubType() end
function meta:GetColor(...) return self:GetType():GetColor(...) end
function meta:GetTypeName(...) return self:GetType():GetTypeName(...) end
function meta:GetLiteralType(...) return self:GetType():GetLiteralType(...) end
function meta:GetDefault(...) return self:GetType():GetDefault(...) end
function meta:GetFlags(...) return self:GetType():GetFlags(...) end
function meta:HasFlag(...) return self:GetType():HasFlag(...) end

function meta:ToString(printTypeInfo, printDir)
	local str = self:GetName()
	if printDir then str = str .. " (" .. (self:GetDir() == bpschema.PD_In and "IN" or "OUT") .. ")" end
	if printTypeInfo then str = str .. " [" .. self.type:ToString() .. "]" end
	return str
end

function New(...)
	return setmetatable({}, meta):Init(...)
end