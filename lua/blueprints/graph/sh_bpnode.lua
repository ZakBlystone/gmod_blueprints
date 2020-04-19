AddCSLuaFile()

module("bpnode", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local DummyNodeType = bpnodetype.New()
DummyNodeType:SetDisplayName("InvalidNode")

local meta = bpcommon.MetaTable("bpnode")
meta.__tostring = function(self) return self:ToString() end

nodeClasses = bpclassloader.Get("Node", "blueprints/graph/nodetypes/", "BPNodeClassRefresh", meta)

--Common pin filters
PF_NoExec = function( pin ) return not pin:IsType( PN_Exec ) end

function meta:Init(nodeType, x, y, literals)

	if type(nodeType) == "table" then
		self.nodeTypeObject = nodeType
		self.nodeType = self.nodeTypeObject:GetFullName()
	else
		self.nodeType = nodeType or "invalid"
	end

	assert(self.nodeType ~= nil)

	self.x = x or 0
	self.y = y or 0
	self.literals = literals or {}
	self.data = {}

	bpcommon.MakeObservable(self)

	return self

end

function meta:PostInit()

	self.x = math.Round(self.x / 16) * 16
	self.y = math.Round(self.y / 16) * 16

	local ntype = self.nodeTypeObject
	if not self.nodeTypeObject then
		self.nodeType = bpdefs:Get():RemapNodeType(self.nodeType)

		ntype = self:GetType()
		if ntype == nil then 
			if self.nodeType ~= "invalid" then print("Node type not found for: " .. self.nodeType) end
			return false
		end
	end

	local nodeClass = ntype:GetNodeClass()
	if nodeClass then nodeClasses:Install(nodeClass, self) end

	self:UpdatePins()

	return true

end

function meta:SetLiteralDefaults( force )

	local ntype = self:GetType()

	self.suppressPinEvents = true

	local base = self:GetCodeType() == NT_Function and -1 or 0
	for pinID, pin, pos in self:SidePins(PD_In) do
		pin:SetDefaultLiteral( force )
	end

	self.suppressPinEvents = false

end

function meta:ShiftLiterals(d)

	self.suppressPinEvents = true

	local l = bpcommon.CopyTable(self.literals)
	for pinID, literal in pairs(l) do
		self:SetLiteral(pinID+d, literal)
	end
	self:RemoveInvalidLiterals()

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
			if p then str = str .. "." .. p:ToString(true,true) end
		end
	end

	local outerGraph = self:GetGraph()
	if outerGraph then str = outerGraph:GetName() .. ":" .. str end

	return str

end

function meta:IsPinConnected( pinID )

	local outerGraph = self:GetGraph()
	if outerGraph == nil then return false end
	return outerGraph:IsPinConnected( self.id, pinID )

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

	local prev = self.pinCache

	self.pinCache = {}
	self:GeneratePins(self.pinCache)

	for k, v in ipairs(self:GetPins()) do
		v:WithOuter( self )
		v.id = k
	end

	for k, v in ipairs(self:GetPins()) do
		v:InitPinClass()

		if prev ~= nil and prev[k] ~= nil and v:GetLiteral() ~= nil and not prev[k]:Equal(v) then
			v:SetLiteral(nil)
			--print("Force default literal on pin: " .. v:ToString(true) .. " : " .. tostring(v:GetLiteral()) .. "->" .. tostring(v:GetDefault()) )
		end

	end

	self:SetLiteralDefaults()
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

function meta:GetLiteral(pinID)

	return self.literals[pinID]

end

function meta:SetLiteral(pinID, value)

	local pins = self:GetPins()
	if pinID < 1 or pinID > #pins then return end
	if pins[pinID]:IsOut() or pins[pinID]:IsType(PN_Exec) then return end

	local literalType = pins[pinID]:GetLiteralType()
	if literalType == "number" then
		if not tonumber(value) then
			value = 0
		end
	end

	value = tostring(value)
	local prevValue = self.literals[pinID]
	local changed = value ~= prevValue
	local outerGraph = self:GetGraph()

	if not self.suppressPinEvents and outerGraph then
		outerGraph:Broadcast("preModifyLiteral", self.id, pinID, value)
	end

	self.literals[pinID] = value

	if not self.suppressPinEvents and outerGraph then
		outerGraph:Broadcast("postModifyLiteral", self.id, pinID, value)
	end

	if changed and pins[pinID].OnLiteralChanged then
		pins[pinID]:OnLiteralChanged( prevValue, value )
	end

end

function meta:RemoveInvalidLiterals()

	local pins = self:GetPins()
	for pinID, value in ipairs(self.literals) do
		if pins[pinID] == nil or pins[pinID]:IsOut() or pins[pinID]:IsType(PN_Exec) then self.literals[pinID] = nil end
	end

end

function meta:GetType()

	if self.nodeTypeObject then return self.nodeTypeObject end

	local nodeTypes = self:GetGraph():GetNodeTypes()
	local ntype = nodeTypes:Find( self.nodeType )
	if self.nodeType ~= "invalid" and ntype == nil then --[[print("Unable to find node type: " .. tostring(self.nodeType))]] end
	self.nodeTypeObject = ntype

	if ntype == nil then return DummyNodeType end

	return ntype

end

function meta:GetCodeType()

	return self.data.codeTypeOverride or self:GetType():GetCodeType()

end

function meta:GetColor() return NodeTypeColors[ self:GetCodeType() ] end
function meta:GetTypeName() return self.nodeType end
function meta:GetPos() return self.x, self.y end
function meta:RemapPin(name) return self:GetType():RemapPin(name) end

function meta:ConvertType(t)

	self:PreModify()
	self.data.codeTypeOverride = t
	self:PostModify()

	if t == NT_Pure then
		self:ShiftLiterals(-2)
	elseif t == NT_Function then
		self:ShiftLiterals(2)
	end

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
	newNode.literals = bpcommon.CopyTable(self.literals)
	newNode.data = bpcommon.CopyTable(self.data)
	newNode.nodeType = self.nodeType
	newNode.nodeTypeObject = self.nodeTypeObject
	newNode:WithOuter( self:GetOuter() )

	bpcommon.MakeObservable(newNode)
	return newNode

end

function meta:Serialize(stream)

	self.nodeType = stream:String(self.nodeType)
	self.literals = stream:StringArray(self.literals)
	self.x = stream:Float(self.x)
	self.y = stream:Float(self.y)

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