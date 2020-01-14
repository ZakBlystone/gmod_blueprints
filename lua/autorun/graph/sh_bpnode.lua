AddCSLuaFile()

module("bpnode", package.seeall, bpcommon.rescope(bpcommon, bpschema))

bpcommon.CallbackList({
	"NODE_PINS_UPDATED",
})

local meta = bpcommon.MetaTable("bpnode")
meta.__tostring = function(self) return self:ToString() end

function meta:Init(nodeType, x, y, literals)

	if type(nodeType) == "table" then
		self.nodeTypeObject = nodeType
	end

	self.nodeType = nodeType or "invalid"
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
	if ntype.nodeClass then
		local class = bpnodeclasses.Get(nodeClass)
		if class == nil then error("Failed to get class: " .. nodeClass) end
		if nodeClass and class ~= nil then
			local base = getmetatable(self)
			local meta = table.Copy(class)
			table.Inherit(meta, base)
			meta.__index = meta
			setmetatable(self, meta)
			if meta.Setup then self:Setup() end
		end
	end

	self:UpdatePins()

	return true

end

function meta:SetLiteralDefaults()

	local ntype = self:GetType()

	local base = self:GetCodeType() == NT_Function and -1 or 0
	for pinID, pin, pos in self:SidePins(PD_In) do
		local default = pin:GetDefault()
		local literal = pin:GetLiteralType()
		if literal then
			if self:GetLiteral(pinID) == nil then
				self:SetLiteral(pinID, default)
			end
		end
	end

end

function meta:ShiftLiterals(d)

	local l = table.Copy(self.literals)
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
		str = ntype:GetName()
		if pinID then
			local p = type(pinID) == "table" and pinID or self:GetPin(pinID)
			if getmetatable(p) == nil then error("NO METATABLE ON PIN: " .. str .. "." .. tostring(p[3])) end
			if p then str = str .. "." .. p:ToString(true,true) end
		end
	end

	if self.graph then str = self.graph:GetName() .. ":" .. str end

	return str

end

function meta:IsPinConnected( pinID )

	if self.graph == nil then return false end
	return self.graph:IsPinConnected( self.id, pinID )

end

function meta:UpdatePins()

	self.pinCache = {}
	self:GeneratePins(self.pinCache)
	self:SetLiteralDefaults()
	self:FireListeners(CB_NODE_PINS_UPDATED)

	for k,v in pairs(self:GetPins()) do
		v.node = self
		v.id = k
	end

end

function meta:UpdatePinInforms()

	local informs = self:GetInforms()
	--MsgC(Color(80,255,20), "Update " .. #informs .. " informs...\n")
	for k,v in pairs(informs) do
		local pin = self:GetPin(v)
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

	--print("Cleared informs on node: " .. self:ToString())

	self.informType = nil
	self:UpdatePinInforms()

end

function meta:SetInform(type)

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

	if not self.graph then return end
	self.graph:PreModifyNode( self )

end

function meta:PostModify()

	if not self.graph then return end
	self.graph:PostModifyNode( self )

end

function meta:GeneratePins(pins)

	table.Add(pins, table.Copy(self:GetType():GetPins()))
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
	for k,v in pairs(pins) do 
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
	self.literals[pinID] = value
	
	if self.graph == nil then return end
	self.graph:FireListeners(bpgraph.CB_PIN_EDITLITERAL, self.id, pinID, value)

end

function meta:RemoveInvalidLiterals()

	local pins = self:GetPins()
	for pinID, value in pairs(self.literals) do
		if pins[pinID] == nil or pins[pinID]:IsOut() or pins[pinID]:IsType(PN_Exec) then self.literals[pinID] = nil end
	end

end

function meta:GetType()

	if self.nodeTypeObject then return self.nodeTypeObject end

	local nodeTypes = self.graph:GetNodeTypes()
	local ntype = nodeTypes[ self.nodeType ]
	if self.nodeType ~= "invalid" and ntype == nil then error("Unable to find node type: " .. tostring(self.nodeType)) end
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
			table.insert(tab, {"ConvertToPure", function() self:ConvertType(NT_Pure) end })
		end
	elseif self:GetCodeType() == NT_Pure then
		table.insert(tab, {"ConvertToNonPure", function() self:ConvertType(NT_Function) end })
	end

end

function meta:GetPins() return self.pinCache end
function meta:GetFlags() return self:GetType():GetFlags() end
function meta:HasFlag(fl) return bit.band(self:GetFlags(), fl) ~= 0 end

function meta:GetGraph() return self.graph end
function meta:GetModule() return self:GetGraph():GetModule() end

function meta:Move(x, y)

	local px = self.x
	local py = self.y

	x = math.Round(x / 15) * 15
	y = math.Round(y / 15) * 15

	self.x = x
	self.y = y

	if self.graph == nil then return px ~= self.x or py ~= self.y end
	self.graph:FireListeners(bpgraph.CB_NODE_MOVE, self.id, x, y)

	return px ~= self.x or py ~= self.y

end

function meta:WriteToStream(stream, mode, version)

	Profile("write-node", function()

		bpdata.WriteValue( self.nodeType, stream )
		bpdata.WriteValue( self.literals, stream )
		bpdata.WriteValue( self.data, stream )
		stream:WriteFloat( self.x )
		stream:WriteFloat( self.y )

	end)

end

function meta:ReadFromStream(stream, mode, version)

	self.nodeType = bpdata.ReadValue(stream)
	self.literals = bpdata.ReadValue(stream)
	self.data = bpdata.ReadValue(stream)
	self.x = stream:ReadFloat()
	self.y = stream:ReadFloat()

end

bpcommon.ForwardMetaCallsVia(meta, "bpnodetype", "GetType")

function New(...) return bpcommon.MakeInstance(meta, ...) end