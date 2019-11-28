AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bppintype.lua")

module("bppin", package.seeall)

local meta = bpcommon.MetaTable("bppin")

meta.__tostring = function(self)
	return self:ToString(true, true)
end

function meta:Init(dir, name, type, desc)
	self.dir = dir
	self.name = name
	self.type = type
	self.desc = desc
	return self
end

function meta:SetDir(dir) self.dir = dir return self end
function meta:SetName(name) self.name = name return self end
function meta:SetDisplayName(name) self.displayName = name return self end
function meta:SetInformedType(type) self.informed = type return self end
function meta:SetDefault(def) self.default = def return self end
function meta:GetDescription() return self.desc or self:GetDisplayName() end

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
function meta:GetDefault(...) return self.default or self:GetType():GetDefault(...) end

-- Funky colors!
--[[function meta:GetColor()
	return HSVToColor(math.fmod((self:GetBaseType() + CurTime()) * 80, 360), .75, 1)
end]]

function meta:WriteToStream(stream)

	assert(stream:IsUsingStringTable())
	self.type:WriteToStream(stream)
	stream:WriteBits(self.dir, 8)
	stream:WriteStr(self.name)
	stream:WriteStr(self.desc)
	stream:WriteStr(self.default)
	return self

end

function meta:ReadFromStream(stream)

	assert(stream:IsUsingStringTable())
	self.type = bppintype.New():ReadFromStream(stream)
	self.dir = stream:ReadBits(8)
	self.name = stream:ReadStr()
	self.desc = stream:ReadStr()
	self.default = stream:ReadStr()
	return self

end

function meta:ToString(printTypeInfo, printDir)
	local str = self:GetName()
	if printDir then str = str .. " (" .. (self:GetDir() == bpschema.PD_In and "IN" or "OUT") .. ")" end
	if printTypeInfo then str = str .. " [" .. self:GetType():ToString() .. "]" end
	return str
end

bpcommon.ForwardMetaCallsVia(meta, "bppintype", "GetType")

function New(...) return bpcommon.MakeInstance(meta, ...) end