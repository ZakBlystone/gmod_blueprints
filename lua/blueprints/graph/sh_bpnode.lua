AddCSLuaFile()

module("bpnode", package.seeall, bpcommon.rescope(bpcommon, bpschema))

bpcommon.CallbackList({
	"NODE_PINS_UPDATED",
})

local DummyNodeType = bpnodetype.New()
DummyNodeType:SetDisplayName("InvalidNode")

local meta = bpcommon.MetaTable("bpnode")
meta.__tostring = function(self) return self:ToString() end

local nodeClasses = bpclassloader.Get("Node", "blueprints/graph/nodetypes/", "BPNodeClassRefresh", meta)

function meta:Init(nodeType, x, y, literals)

	if type(nodeType) == "table" then
		self.nodeTypeObject = nodeType
		self.nodeType = self.nodeTypeObject:GetName()
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

	self.x = math.Round(self.x / 15) * 15
	self.y = math.Round(self.y / 15) * 15

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

	local base = self:GetCodeType() == NT_Function and -1 or 0
	for pinID, pin, pos in self:SidePins(PD_In) do
		if pin:CanHaveLiteral() then
			local default = pin:GetDefault()
			if force or self:GetLiteral(pinID) == nil then
				self:SetLiteral(pinID, default)
			end
		end
	end

end

function meta:ShiftLiterals(d)

	local l = bpcommon.CopyTable(self.literals)
	for pinID, literal in pairs(l) do
		self:SetLiteral(pinID+d, literal)
	end
	self:RemoveInvalidLiterals()

end

function meta:ToString(pinID)

	local ntype = self:GetType()
	local str = nil

	if not ntype then 
		str = "<unknown>"
	else
		str = ntype:GetName() or "unnamed"
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

function meta:UpdatePins()

	self.pinCache = {}
	self:GeneratePins(self.pinCache)

	for k, v in ipairs(self:GetPins()) do
		v:WithOuter( self )
		v.id = k
	end

	for k, v in ipairs(self:GetPins()) do
		v:InitPinClass()
	end

	self:SetLiteralDefaults()
	self:FireListeners(CB_NODE_PINS_UPDATED)

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
	self:FireListeners(CB_NODE_PINS_UPDATED)

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

function meta:Pins(filter)

	filter = filter or filterNoOp
	local pins = self:GetPins()
	local i, j, num = 0, 0, #pins
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
	self.literals[pinID] = value

	if changed and pins[pinID].OnLiteralChanged then
		pins[pinID]:OnLiteralChanged( prevValue, value )
	end
	
	local outerGraph = self:GetGraph()
	if outerGraph == nil then return end
	outerGraph:FireListeners(bpgraph.CB_PIN_EDITLITERAL, self.id, pinID, value)

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

	x = math.Round(x / 15) * 15
	y = math.Round(y / 15) * 15

	self.x = x
	self.y = y

	local outerGraph = self:GetGraph()
	if outerGraph == nil then return px ~= self.x or py ~= self.y end
	outerGraph:FireListeners(bpgraph.CB_NODE_MOVE, self.id, x, y)

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

function meta:WriteToStream(stream, mode, version)

	assert(stream:IsUsingStringTable())

	Profile("write-node", function()

		if version < 4 then
			bpdata.WriteValue( self.nodeType, stream )
			bpdata.WriteValue( self.literals, stream )
		else
			stream:WriteStr( self.nodeType )
			for k,v in pairs(self.literals) do
				stream:WriteBits(k, 16)
				stream:WriteStr(v)
			end
			stream:WriteBits(0, 16)
		end

		bpdata.WriteValue( self.data, stream )
		stream:WriteFloat( self.x )
		stream:WriteFloat( self.y )

	end)

end

function meta:ReadFromStream(stream, mode, version)

	assert(stream:IsUsingStringTable())

	if version < 4 then
		self.nodeType = bpdata.ReadValue(stream)
		self.literals = bpdata.ReadValue(stream)
	else
		self.nodeType = stream:ReadStr()
		self.literals = {}

		local r = stream:ReadBits(16)
		while r ~= 0 do
			self.literals[r] = stream:ReadStr()
			r = stream:ReadBits(16)
		end
	end

	self.data = bpdata.ReadValue(stream)
	self.x = stream:ReadFloat()
	self.y = stream:ReadFloat()

end

bpcommon.ForwardMetaCallsVia(meta, "bpnodetype", "GetType")

function New(...) return bpcommon.MakeInstance(meta, ...) end