AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodeclasses.lua")

module("bpnode", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpnodedef))

bpcommon.CallbackList({
	"NODE_PINS_UPDATED",
})

local meta = {}
meta.__index = meta
meta.__tostring = function(self) return self:ToString() end

function meta:Init(nodeType, x, y, literals)

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

	self.nodeType = bpdefs:Get():RemapNodeType(self.nodeType)

	local ntype = self:GetType()
	if ntype == nil then 
		if self.nodeType ~= "invalid" then print("Node type not found for: " .. self.nodeType) end
		return false
	end

	if ntype.nodeClass then
		local class = bpnodeclasses.Get(ntype.nodeClass)
		if class == nil then error("Failed to get class: " .. ntype.nodeClass) end
		if ntype.nodeClass and class ~= nil then
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
	if not ntype then return self.graph:GetName() .. ":" .. "<unknown>" end
	local str = self.graph:GetName() .. "." .. ntype.name
	if pinID then
		local p = self:GetPin(pinID)
		if getmetatable(p) == nil then error("NO METATABLE ON PIN: " .. str .. "." .. tostring(p[3])) end
		if p then str = str .. "." .. p:ToString(true,true) end
	end
	return str

end

function meta:IsPinConnected( pinID )

	return self.graph:IsPinConnected( self.id, pinID )

end

function meta:UpdatePins()

	self.pinCache = {}
	self:GeneratePins(self.pinCache)
	self:SetLiteralDefaults()
	self:FireListeners(CB_NODE_PINS_UPDATED)

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

	self.graph:PreModifyNode( self, bpgraph.NODE_MODIFY_SIGNATURE )

end

function meta:PostModify()

	self.graph:PostModifyNode( self, bpgraph.NODE_MODIFY_SIGNATURE )

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
		if pins[i]:GetDir() == dir and pins[i]:GetName():lower() == lowerName then return i end
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

	value = tostring(value)
	self.literals[pinID] = value
	self.graph:FireListeners(bpgraph.CB_PIN_EDITLITERAL, self.id, pinID, value)

end

function meta:RemoveInvalidLiterals()

	local pins = self:GetPins()
	for pinID, value in pairs(self.literals) do
		if pins[pinID] == nil or pins[pinID]:IsOut() or pins[pinID]:IsType(PN_Exec) then self.literals[pinID] = nil end
	end

end

function meta:GetType()

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

function meta:GetRole() return self:GetType():GetRole() end
function meta:GetPins() return self.pinCache end
function meta:GetCode() return self:GetType():GetCode() end
function meta:GetJumpSymbols() return self:GetType():GetJumpSymbols() end
function meta:GetLocals() return self:GetType():GetLocals() end
function meta:GetGraphThunk() return self:GetType():GetGraphThunk() end
function meta:GetHook() return self:GetType():GetHook() end
function meta:GetInforms() return self:GetType():GetInforms() end
function meta:GetDescription() return self:GetType():GetDescription() end
function meta:GetFlags() return self:GetType():GetFlags() end
function meta:HasFlag(fl) return bit.band(self:GetFlags(), fl) ~= 0 end
function meta:GetDisplayName() return self:GetType():GetDisplayName() end
function meta:GetRequiredMeta() return self:GetType():GetRequiredMeta() end

function meta:GetGraph() return self.graph end
function meta:GetModule() return self:GetGraph():GetModule() end

function meta:Move(x, y)

	x = math.Round(x / 15) * 15
	y = math.Round(y / 15) * 15

	self.x = x
	self.y = y

	self.graph:FireListeners(bpgraph.CB_NODE_MOVE, self.id, x, y)

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

function New(...)

	return setmetatable({}, meta):Init(...)

end