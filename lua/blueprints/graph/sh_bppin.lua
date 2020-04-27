AddCSLuaFile()

module("bppin", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bppin")
local pinClasses = bpclassloader.Get("Pin", "blueprints/graph/pintypes/", "BPPinClassRefresh", meta)

meta.__tostring = nil

--[[meta.__tostring = function(self)
	return self:ToString(true, true)
end]]

function meta:Init(dir, name, type, desc)
	self.dir = dir
	self.name = name
	self.type = type and type:Copy( self ) or nil
	self.desc = desc
	self.literal = ""
	return self
end

function meta:InitPinClass()

	local pinClass = self.pinClass or self:GetType():GetPinClass()
	if pinClass then pinClasses:Install(pinClass, self) end

end

function meta:SetPinClass(class) self.pinClass = class return self end
function meta:SetLiteral(value)

	local node = self:GetNode()
	local literalType = self:GetLiteralType()
	if literalType == "number" then
		if not tonumber(value) then
			value = 0
		end
	end

	value = tostring(value)
	local prevValue = self.literal
	local changed = value ~= prevValue

	if node and not node.suppressPinEvents and node:GetGraph() then
		node:GetGraph():Broadcast("preModifyLiteral", node.id, self.id, value)
	end

	self.literal = value

	print("SET LITERAL ON PIN: " .. tostring(value) .. " -> " .. self:ToString())

	if node and not node.suppressPinEvents and node:GetGraph() then
		node:GetGraph():Broadcast("postModifyLiteral", node.id, self.id, value)
	end

	if changed and self.OnLiteralChanged then
		self:OnLiteralChanged( prevValue, value )
	end

end
function meta:GetLiteral() return self.literal end
function meta:CanHaveLiteral() return self:GetLiteralType() ~= nil end
function meta:OnRightClick() end

function meta:SetType(type) self.type = type:Copy( self ) return self end
function meta:SetDir(dir) self.dir = dir return self end
function meta:SetName(name) self.name = name return self end
function meta:SetDisplayName(name) self.displayName = name return self end
function meta:SetInformedType(type) 

	self.informed = type

	if self.informed ~= nil then
		self:InitPinClass()
	else
		setmetatable(self, meta)
		self:InitPinClass()
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

function meta:IsIn() return self:GetDir() == PD_In end
function meta:IsOut() return self:GetDir() == PD_Out end
function meta:GetDefault(...)

	return self.default or self:GetType():GetDefault(...)

end

-- Funky colors!
--[[function meta:GetColor()
	return HSVToColor(math.fmod((self:GetBaseType() + CurTime()) * 80, 360), .75, 1)
end]]

function meta:GetNode()

	return self:FindOuter( bpnode_meta )

end

function meta:GetConnectedPins()

	local node = self:GetNode()
	if node == nil then return {} end

	local graph = node:GetGraph()
	if graph == nil then return {} end

	local nodeID = node.id
	local pinID = self.id
	local out = {}
	local dir = self:GetDir()
	for k, v in graph:Connections() do
		if dir == PD_In and (v[3] ~= nodeID or v[4] ~= pinID) then continue end
		if dir == PD_Out and (v[1] ~= nodeID or v[2] ~= pinID) then continue end
		out[#out+1] = graph:GetNode( dir == PD_In and v[1] or v[3] ):GetPin( dir == PD_In and v[2] or v[4] )
	end
	return out

end

function meta:Connect( other )

	local node = self:GetNode()
	local otherNode = other:GetNode()
	local graph = node:GetGraph()

	if graph == nil then print("Cannot connect, not in a graph") return end
	if graph ~= otherNode:GetGraph() then print("Cannot connect across different graphs") return end

	return graph:ConnectNodes( node.id, self.id, otherNode.id, other.id )

end

function meta:SetDefaultLiteral( force )

	if self:CanHaveLiteral() then
		local default = self:GetDefault()
		if force or self:GetLiteral() == nil then
			self:SetLiteral(default)
		end
	end

end

function meta:Serialize(stream)

	self.type = stream:Object(self.type):WithOuter(self)
	self.dir = stream:Bits(self.dir, 8)
	self.name = stream:String(self.name)
	self.desc = stream:String(self.desc)
	self.default = stream:String(self.default)
	self.literal = stream:String(self.literal)

	--print("PIN SERIALIZE [" .. (stream:IsReading() and "READ" or "WRITE") .. "][" .. stream:GetContext() .. "]: " .. self:ToString())

	return self

end

function meta:ToString(printTypeInfo, printDir)
	local str = self:GetName()
	if printDir then str = str .. " (" .. (self:GetDir() == PD_In and "IN" or "OUT") .. ")" end
	if printTypeInfo then str = str .. " [" .. self:GetType():ToString() .. "]" end
	return str
end

function meta:Copy(dir)

	local copy = bpcommon.MakeInstance(meta, dir or self.dir, self.name, self.type, self.desc)
	copy.default = self.default
	copy.literal = self.literal
	return copy

end

function meta:Equals(other)
	return bppintype_meta.__eq( self.type, other.type ) and self.dir == other.dir and self.name == other.name
end

bpcommon.ForwardMetaCallsVia(meta, "bppintype", "GetType")

meta.GetHash = nil

function New(...) return bpcommon.MakeInstance(meta, ...) end