AddCSLuaFile()

module("bpnode", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local DummyNodeType = bpnodetype.New()
DummyNodeType:SetDisplayName("InvalidNode")

local meta = bpcommon.MetaTable("bpnode")

nodeClasses = bpclassloader.Get("Node", "blueprints/graph/nodetypes/", "BPNodeClassRefresh", meta)

--Common pin filters
PF_NoExec = function( pin ) return not pin:IsType( PN_Exec ) end

function meta:Init(nodeType, x, y)

	self.nodeType = Weak(nodeType or DummyNodeType)
	self.x = x or 0
	self.y = y or 0
	self.data = {}

	bpcommon.MakeObservable(self)

	return self

end

function meta:PostInit()

	if self.initialized then return true end

	self.x = math.Round(self.x / 16) * 16
	self.y = math.Round(self.y / 16) * 16

	local ntype = self.nodeType()
	if ntype == nil then
		--print("Node without valid nodetype, replacing with dummy!")
		ntype = DummyNodeType
		self.nodeType:Set( ntype )

		for _, pin in ipairs(self.pinCache or {}) do
			--print(" PIN WAS: " .. pin:ToStringEx(true, true))
		end
	end

	local nodeClass = ntype:GetNodeClass()
	if nodeClass then nodeClasses:Install(nodeClass, self) end

	self:UpdatePins()

	self.initialized = true
	return true

end

function meta:SetLiteralDefaults( force )

	self.suppressPinEvents = true

	local base = self:GetCodeType() == NT_Function and -1 or 0
	for pinID, pin, pos in self:SidePins(PD_In) do
		pin:SetDefaultLiteral( force )
	end

	self.suppressPinEvents = false

end

function meta:ToString(pinID)

	local ntype = self:GetType()
	local str = nil

	if not ntype then 
		str = "<unknown>"
	else
		str = ntype:GetFullName() or "unnamed"
		if pinID then
			local p = type(pinID) == "table" and pinID or self:GetPin(pinID)
			if getmetatable(p) == nil then error("NO METATABLE ON PIN: " .. str .. "." .. tostring(p[3])) end
			if p then str = str .. "." .. p:ToStringEx(true,true) end
		end
	end

	local outerGraph = self:GetGraph()
	if outerGraph then str = outerGraph:GetName() .. ":" .. str end

	return str

end

function meta:IsPinConnected( pinID )

	local pins = self:GetPins()
	if pin[pinID] and #pin[pinID]:GetConnections() > 0 then return true end
	return false

end

function meta:WillExecute()

	local codeType = self:GetCodeType()
	if codeType == NT_Event then return true
	elseif codeType == NT_Pure then

		for _, pin in self:SidePins( PD_Out ) do
			if #pin:GetConnectedPins() > 0 then return true end
		end

	else

		for _, pin in self:SidePins( PD_In ) do
			if pin:IsType(PN_Exec) and #pin:GetConnectedPins() > 0 then return true end
		end

	end
	return false

end

function meta:UpdatePins()

	--print("UPDATING PINS[" .. self:ToString() .. "]...")

	local newPins = nil

	-- This will do for now
	if self.nodeType() ~= DummyNodeType then
		newPins = {}
		self:GeneratePins(newPins)
	else
		newPins = self.pinCache
	end

	local current = self.pinCache
	local function findExisting( p )
		if not current then return end
		for _,v in ipairs( current ) do
			if v:Equals(p) then return v end
		end
		print(" No Match for: " .. tostring(p:ToString(true, true)))
	end

	--print(" SEARCH CACHE: " .. (current and #current or "nil"))

	self.suppressPinEvents = true
	self.pinCache = {}
	for k, v in ipairs(newPins) do
		local p = findExisting(v)
		if not p then 
			--print(" CREATE NEW: " .. v:GetName() .. " ... init literal" )
			v:WithOuter( self )
			v.id = k
			v:InitPinClass()
			v:SetLiteral( v:GetDefault() )
			self.pinCache[k] = v
		else
			p:WithOuter( self )
			p.id = k
			p:InitPinClass()
			self.pinCache[k] = p
			--print(" LOAD FROM CACHE: " .. p:GetName() )
		end
	end

	self.suppressPinEvents = false

	--self:SetLiteralDefaults()
	self:Broadcast("pinsUpdated")

end

function meta:UpdatePinInforms()

	local informs = self:GetInforms()
	--MsgC(Color(80,255,20), "Update " .. #informs .. " informs...\n")
	for _, v in ipairs(informs) do
		local pin = self:GetPin(v)
		if pin == nil then continue end
		--MsgC(Color(80,255,20), "\tModify " .. pin:ToString(true,true) .. " -> ")
		if self.informType == nil then
			pin:SetInformedType(self.informType)
		else
			local base = pin:GetType(true)
			pin:SetInformedType( self.informType:WithFlags(base:GetFlags()) )
		end
		--MsgC(Color(80,255,20), pin:ToString(true,true) .. "\n")
	end
	self:SetLiteralDefaults()
	self:Broadcast("pinsUpdated")

end

function meta:ClearInforms()

	if self.informType == nil then return end

	--print("Cleared informs on node: " .. self:ToString())

	self.informType = nil
	self:UpdatePinInforms()

end

function meta:SetInform(type)

	if self.informType == nil and type == nil then return end
	if self.informType ~= nil and self.informType:Equal(type) then return end

	--print("Set informs on node: " .. self:ToString() .. " : " .. type:ToString())

	self.informType = type
	self:UpdatePinInforms()

end

function meta:HasInformPins()

	return #self:GetInforms() > 0

end

function meta:IsInformPin(pinID)

	local informs = self:GetInforms()
	if informs == nil then return false end
	return table.HasValue(informs, pinID)

end

function meta:PreModify()

	local outerGraph = self:GetGraph()
	if not outerGraph then return end
	outerGraph:PreModifyNode( self )

end

function meta:PostModify()

	local outerGraph = self:GetGraph()
	if not outerGraph then return end
	outerGraph:PostModifyNode( self )

end

function meta:GeneratePins(pins)

	table.Add(pins, bpcommon.CopyTable(self:GetType():GetPins()))
	if pins[1] == nil then return end
	if self.data.codeTypeOverride == NT_Pure and pins[1]:IsType(PN_Exec) then
		table.remove(pins, 1)
		table.remove(pins, 1)
	elseif self.data.codeTypeOverride == NT_Function and not pins[1]:IsType(PN_Exec) then
		table.insert(pins, 1, MakePin( PD_Out, "Thru", PN_Exec ))
		table.insert(pins, 1, MakePin( PD_In, "Exec", PN_Exec ))
	end

end

function meta:GetNumSidePins(dir)

	local pins = self:GetPins()
	local i = 0
	for _, v in ipairs(pins) do 
		if v:GetDir() == dir then i = i + 1 end 
	end
	return i

end

local filterNoOp = function() return true end
function meta:SidePins(dir, filter)

	filter = filter or filterNoOp
	local pins = self:GetPins()
	local i, j, num = 0, 0, #pins
	return function()
		i = i + 1
		while i <= num and (pins[i]:GetDir() ~= dir or not filter(pins[i])) do i = i + 1 end
		if i <= num then
			j = j + 1
			return i, pins[i], j
		end
	end

end

function meta:Pins(filter, reverse)

	filter = filter or filterNoOp
	local pins = self:GetPins()

	local i, j, num = 0, 0, #pins
	if reverse then
		i = num + 1
		return function()
			i = i - 1
			while i >= 1 and not filter(pins[i]) do i = i - 1 end
			if i >= 1 then
				j = j + 1
				return i, pins[i], j
			end
		end
	end
	return function()
		i = i + 1
		while i <= num and not filter(pins[i]) do i = i + 1 end
		if i <= num then
			j = j + 1
			return i, pins[i], j
		end
	end

end

function meta:GetPin(pinID)

	return self:GetPins()[pinID]

end

function meta:FindPin(dir, name)

	local lowerName = name:lower()
	local pins = self:GetPins()
	for i=1, #pins do
		if pins[i]:GetDir() == dir and pins[i]:GetName():lower() == lowerName then return pins[i] end
	end
	return nil

end

function meta:BreakAllLinks()

	for _, pin in ipairs(self:GetPins()) do
		pin:BreakAllLinks()
	end

end

function meta:GetLiteral(pinID)

	local pins = self:GetPins()
	return pins[pinID] ~= nil and pins[pinID]:GetLiteral() or ""

end

function meta:SetLiteral(pinID, value)

	local pins = self:GetPins()
	if pinID < 1 or pinID > #pins then return end
	if pins[pinID]:IsOut() or pins[pinID]:IsType(PN_Exec) then return end

	pins[pinID]:SetLiteral( value )

end

function meta:GetType()

	return self.nodeType()

end

function meta:GetCodeType()

	return self.data.codeTypeOverride or self:GetType():GetCodeType()

end

function meta:GetColor() return NodeTypeColors[ self:GetCodeType() ] end
function meta:GetTypeName() return self.nodeType:IsValid() and self.nodeType():GetFullName() or "unknown" end
function meta:GetPos() return self.x, self.y end
function meta:RemapPin(name) return self:GetType():RemapPin(name) end

function meta:ConvertType(t)

	self:PreModify()
	self.data.codeTypeOverride = t
	self:PostModify()

end

function meta:GetOptions(tab)

	if self:GetCodeType() == NT_Function then
		local canConvert = false
		for id, pin in self:SidePins(PD_Out) do
			if not pin:IsType(PN_Exec) then canConvert = true end
		end
		if canConvert then
			tab[#tab+1] = {"ConvertToPure", function() self:ConvertType(NT_Pure) end }
		end
	elseif self:GetCodeType() == NT_Pure then
		tab[#tab+1] = {"ConvertToNonPure", function() self:ConvertType(NT_Function) end }
	end

end

function meta:GetPins() return self.pinCache or {} end
function meta:GetFlags() return self:GetType():GetFlags() end
function meta:HasFlag(fl) return bit.band(self:GetFlags(), fl) ~= 0 end

function meta:GetGraph() return self:FindOuter( bpgraph_meta ) end
function meta:GetModule() return self:FindOuter( bpmodule_meta ) end

function meta:Move(x, y)

	local px = self.x
	local py = self.y

	x = math.Round(x / 16) * 16
	y = math.Round(y / 16) * 16

	self.x = x
	self.y = y

	local outerGraph = self:GetGraph()
	if outerGraph == nil then return px ~= self.x or py ~= self.y end
	outerGraph:Broadcast("nodeMoved", self.id, x, y)

	return px ~= self.x or py ~= self.y

end

function meta:Copy()

	local newNode = setmetatable({}, meta)
	newNode.x = self.x
	newNode.y = self.y
	newNode.data = bpcommon.CopyTable(self.data)
	newNode.nodeType = Weak(self.nodeType())
	newNode.pinCache = {}
	newNode:WithOuter( self:GetOuter() )

	for _, v in ipairs(self.pinCache or {}) do
		newNode.pinCache[#newNode.pinCache+1] = v:Copy():WithOuter(self)
	end

	bpcommon.MakeObservable(newNode)
	return newNode

end

function meta:Serialize(stream)

	--print("NODE SERIALIZE [" .. (stream:IsReading() and "READ" or "WRITE") .. "][" .. stream:GetContext() .. "]")

	self.nodeType = stream:Object(self.nodeType)
	self.x = stream:Float(self.x)
	self.y = stream:Float(self.y)

	--print("PINS:")
	self.pinCache = stream:ObjectArray( self.pinCache or {}, self )

	--[[for _,v in ipairs(self.pinCache) do
		print(" " .. v:ToString(true, true))
	end]]

	--print("NODE DONE")

	return stream

end

function meta:Compile(compiler, pass)

	if pass == CP_METAPASS then

		local rm = self:GetRequiredMeta()
		if rm == nil then return end

		for _, m in ipairs(rm) do print("REQUIRE: " .. m) compiler:AddRequiredMetaTable( m ) end

	end

end

bpcommon.ForwardMetaCallsVia(meta, "bpnodetype", "GetType")

function New(...) return bpcommon.MakeInstance(meta, ...) end