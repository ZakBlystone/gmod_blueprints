AddCSLuaFile()

module("bppin", package.seeall)

local pinClasses = bpclassloader.Get("Pin", "blueprints/graph/pintypes/", "BPPinClassRefresh")
local meta = bpcommon.MetaTable("bppin")

meta.__tostring = nil
--[[meta.__tostring = function(self)
	return self:ToString(true, true)
end]]

function meta:Init(dir, name, type, desc)
	self.dir = dir
	self.name = name
	self.type = type
	self.desc = desc
	return self
end

function meta:InitPinClass()

	local pinClass = self.pinClass or self:GetType():GetPinClass()
	if pinClass then pinClasses:Install(pinClass, self) end

end

function meta:SetPinClass(class) self.pinClass = class return self end
function meta:SetLiteral(value) self:GetNode():SetLiteral( self.id, value ) end
function meta:GetLiteral() return self:GetNode():GetLiteral( self.id ) end
function meta:CanHaveLiteral() return self:GetLiteralType() ~= nil end

function meta:SetType(type) self.type = type return self end
function meta:SetDir(dir) self.dir = dir return self end
function meta:SetName(name) self.name = name return self end
function meta:SetDisplayName(name) self.displayName = name return self end
function meta:SetInformedType(type) 

	self.informed = type

	if self.informed ~= nil then
		self:InitPinClass()
	else
		setmetatable(self, meta)
	end

	return self 

end

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

function meta:GetNode()

	return self.node

end

function meta:GetConnectedPins()

	local node = self:GetNode()
	local graph = node.graph
	local nodeID = node.id
	local pinID = self.id
	local out = {}
	local dir = self:GetDir()
	for k, v in graph:Connections() do
		if dir == bpschema.PD_In and (v[3] ~= nodeID or v[4] ~= pinID) then continue end
		if dir == bpschema.PD_Out and (v[1] ~= nodeID or v[2] ~= pinID) then continue end
		out[#out+1] = graph:GetNode( dir == bpschema.PD_In and v[1] or v[3] ):GetPin( dir == bpschema.PD_In and v[2] or v[4] )
	end
	return out

end

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

function meta:Copy(dir)

	local copy = bpcommon.MakeInstance(meta, dir or self.dir, self.name, self.type, self.desc)
	copy.default = self.default
	return copy

end

bpcommon.ForwardMetaCallsVia(meta, "bppintype", "GetType")

function New(...) return bpcommon.MakeInstance(meta, ...) end