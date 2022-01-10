AddCSLuaFile()

module("bppin", package.seeall, bpcommon.rescope(bpcommon, bpschema))

local meta = bpcommon.MetaTable("bppin")
local pinClasses = bpclassloader.Get("Pin", "blueprints/graph/pintypes/", "BPPinClassRefresh", meta)

function meta:Init(dir, name, type, desc)
	self.dir = dir
	self.name = name
	self.type = type and type:Copy( self ) or nil
	self.desc = desc
	self.literal = nil
	self.connections = {}
	return self
end

function meta:InitPinClass()

	local pinClass = self.pinClass or self:GetType():GetPinClass()
	if pinClass then 
		pinClasses:Install(pinClass, self)
		self.literal = self.literal or self:GetDefault()
	end

end

function meta:PostLoad()

	self:RemoveInvalidConnections()
	self:MakeConnectionsBiDirectional()

end

function meta:PostNodePinsCreated()

end

function meta:MakeConnectionsBiDirectional()

	for _, v in pairs(self.connections) do
		if not v():IsConnectedTo(self) then
			local conn = v():GetConnections()
			conn[#conn+1] = Weak( self )
			--print("RECONNECT: " .. tostring(self) .. " <- " .. tostring(v()))
		end
	end

end

function meta:RemoveInvalidConnections()

	for i=#self.connections, 1, -1 do
		if not self.connections[i]:IsValid() then
			print("Remove invalid pin connection[" .. tostring(self) .. "]: " .. i)
			table.remove(self.connections, i)
		end
	end

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

	if not self:HasObjectLiteral() then value = tostring(value) end
	local prevValue = self.literal
	local changed = value ~= prevValue

	if node and not node.suppressPinEvents and node:GetGraph() then
		node:GetGraph():Broadcast("preModifyLiteral", node, self.id, value)
	end

	self.literal = value

	--print("SET LITERAL ON PIN: " .. tostring(value) .. " -> " .. self:ToString())

	if node and not node.suppressPinEvents and node:GetGraph() then
		node:GetGraph():Broadcast("postModifyLiteral", node, self.id, value)
	end

	if changed and self.OnLiteralChanged then
		self:OnLiteralChanged( prevValue, value )
	end

end
function meta:GetLiteral() return self.literal end
function meta:CanHaveLiteral() return self:GetLiteralType() ~= nil end
function meta:AlwaysAutoFill() return false end
function meta:ShouldBeHidden() return false end
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

function meta:GetColor()

	if self:HasFlag(PNF_Server) then return Color( 80, 200, 255 ) end
	if self:HasFlag(PNF_Client) then return Color( 255, 180, 80 ) end

	return self:GetType():GetColor()

end

function meta:GetNode()

	return self:FindOuter( bpnode_meta )

end

function meta:GetConnectedPins(out)

	out = out or {}
	for _, pin in pairs(self:GetConnections()) do
		if pin() ~= nil then out[#out+1] = pin() end
	end
	return out

end

function meta:Connect( other )

	return self:MakeLink( other )

end

function meta:SetDefaultLiteral( force )

	if self:CanHaveLiteral() then
		local default = self:GetDefault()
		if force or self:GetLiteral() == nil then
			self:SetLiteral(default)
		end
	end

end

function meta:GetConnections()

	return self.connections

end

function meta:IsConnectedTo( other )

	for _, pin in ipairs(self:GetConnections()) do
		if pin() == other then return true end
	end
	return false

end

function meta:CanConnect( other, autoConform )

	if self:GetDir() == other:GetDir() then return false, "Can't connect " .. (self:IsOut() and "m/m" or "f/f") .. " pins" end
	if not self:IsOut() then return other:CanConnect(self, autoConform) end

	local conn = self:GetConnections()
	local node = self:GetNode()
	local otherNode = other:GetNode()

	if node == nil or otherNode == nil then return false, "Can't connect pins without nodes" end

	if self:HasFlag(PNF_Server) and other:HasFlag(PNF_Client) then return false, "Can't connect server pin to client pin" end
	if self:HasFlag(PNF_Client) and other:HasFlag(PNF_Server) then return false, "Can't connect client pin to server pin" end

	if self:IsConnectedTo( other ) then return false, "Already connected: " .. tostring(self) .. " --> " .. tostring(other) end
	if self:IsType(PN_Exec) and #conn > 0 then 

		if not autoConform then
			return false, "Only one connection outgoing for exec pins" 
		else
			self:BreakAllLinks()
		end

	end
	if not other:IsType(PN_Exec) and #other:GetConnections() > 0 then

		if not autoConform then
			return false, "Only one connection for inputs" 
		else
			other:BreakAllLinks()
		end

	end

	if node:GetTypeName() == "CORE_Pin" and self:IsType(PN_Any) then return true end
	if otherNode:GetTypeName() == "CORE_Pin" and other:IsType(PN_Any) then return true end

	if self:HasFlag(PNF_Table) ~= other:HasFlag(PNF_Table) then return false, "Can't connect table to non-table pin" end

	if not self:GetType():Equal(other:GetType(), 0) then

		if self:IsType(PN_Any) and not other:IsType(PN_Exec) then return true end
		if other:IsType(PN_Any) and not self:IsType(PN_Exec) then return true end

		if bpcast.CanCast( self:GetType(), other:GetType() ) then
			return true
		else
			return false, "No explicit conversion between " .. tostring(self) .. " --> " .. tostring(other)
		end

	end

	local subA = self:GetSubType()
	local subB = other:GetSubType()
	local cantConnectSubtypes = false
	if type(subA) == "table" and type(subB) == "table" then
		if getmetatable(subA) ~= getmetatable(subB) then 
			cantConnectSubtypes = true
		elseif getmetatable(subA).Equals ~= nil then
			cantConnectSubtypes = not subA:Equals(subB)
		else
			cantConnectSubtypes = subA ~= subB
		end
	else
		cantConnectSubtypes = subA ~= subB
	end

	if cantConnectSubtypes then
		return false, "Can't connect " .. tostring(self) .. " --> " .. tostring(other)
	end

	return true

end

function meta:MakeLink( other, force )

	assert( isbppin(other), "Expected pin, got: " .. tostring(other) )

	if self:GetDir() == other:GetDir() then return self:CanConnect(other, true) end
	if not self:IsOut() then return other:MakeLink(self, force) end

	if not force then
		local allowed, msg = self:CanConnect(other, true)
		if not allowed then print(msg) return false end
	end

	local conn = self:GetConnections()
	conn[#conn+1] = Weak( other )
	local otherConn = other:GetConnections()
	otherConn[#otherConn+1] = Weak( self )

	local graph = self:FindOuter( bpgraph_meta )
	if graph and not graph.suppressPinEvents then
		graph:WalkInforms()
		graph:Broadcast("connectionAdded", self, other)
	end

end

function meta:BreakLink( other )

	assert( isbppin(other), "Expected pin, got: " .. tostring(other) )

	local graph = self:FindOuter( bpgraph_meta )
	local conn = self:GetConnections()
	for i, c in ipairs(conn) do
		if c() == other then
			table.remove(conn, i)

			for j, o in ipairs(other:GetConnections()) do
				if o() == self then
					table.remove(other:GetConnections(), j)
				end
			end

			if graph and not graph.suppressPinEvents then
				graph:WalkInforms()
				graph:Broadcast("connectionRemoved", self, c())
			end
			return true
		end
	end

	return false

end

function meta:BreakAllLinks()

	local conn = self:GetConnections()
	for i=#conn, 1, -1 do

		if conn[i]:IsValid() then
			self:BreakLink( conn[i]() )
		else
			table.remove(conn, i)
		end

	end

end

function meta:Serialize(stream)

	self.name = stream:String(self.name)

	--print(" PIN SERIALIZE [" .. (stream:IsReading() and "READ" or "WRITE") .. "][" .. stream:GetContext() .. "]: " .. tostring(self))

	self.type = stream:Object(self.type, self)
	self.dir = stream:Bits(self.dir, 8)
	
	if stream:GetContext() == "defs" or stream:GetVersion() < 5 then
		self.desc = stream:String(self.desc)
	elseif stream:IsReading() then
		self.desc = ""
	end

	self.default = stream:String(self.default)

	if stream:GetVersion() >= 8 then

		local objectLiteral = stream:Bool( self:HasObjectLiteral() )

		if objectLiteral then
			if type(self.literal) == "string" then self.literal = nil end
			self.literal = stream:Object(self.literal)
		else
			self.literal = stream:String(self.literal)
		end

	else
		self.literal = stream:String(self.literal)
	end

	if self.dir == PD_Out or stream:GetVersion() < 5 then
		self.connections = stream:ObjectArray(self.connections)
	elseif stream:IsReading() then
		self.connections = {}
	end

	for _, conn in ipairs(self.connections) do

		if conn:IsValid() then

			assert( isbppin(conn()), "Expected pin, got: " .. tostring( conn() ) )

		end

	end

	--print(" PIN DONE")

	return self

end

function meta:ToString()
	local node = self:GetNode()
	if not node then return "[nodeless]" .. self:ToStringEx(true, true) end
	return self:GetNode():ToString(self)
end

function meta:ToStringEx(printTypeInfo, printDir)
	local str = self:GetName() or "unnamed"
	if printDir then str = str .. " (" .. (self:GetDir() == PD_In and "IN" or "OUT") .. ")" end
	if printTypeInfo then str = str .. " [" .. tostring(self:GetType()) .. "]" end
	return str
end

function meta:Copy(dir)

	local copy = bpcommon.MakeInstance(meta, dir or self.dir, self.name, self.type, self.desc)
	copy.default = self.default
	copy.literal = self.literal
	copy.displayName = self.displayName
	return copy

end

function meta:Equals(other)
	return bppintype_meta.__eq( self.type, other.type ) and self.dir == other.dir and self.name == other.name
end

bpcommon.ForwardMetaCallsVia(meta, "bppintype", "GetType")

meta.GetHash = nil

function New(...) return bpcommon.MakeInstance(meta, ...) end