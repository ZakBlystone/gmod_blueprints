AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")

module("bpnode", package.seeall, bpcommon.rescope(bpcommon, bpschema))

local meta = {}
meta.__index = meta

function meta:Init(nodeType, x, y, literals)

	self.nodeType = nodeType or "invalid"
	self.x = x or 0
	self.y = y or 0
	self.literals = literals or {}
	self.data = {}
	return self

end

function meta:PostInit()

	self.x = math.Round(self.x / 15) * 15
	self.y = math.Round(self.y / 15) * 15

	local ntype = self:GetType()
	if ntype == nil then 
		if self.nodeType ~= "invalid" then print("Node type node found for: " .. self.nodeType) end
		return false 
	end

	local defaults = ntype.defaults or {}

	for pinID, pin in pairs(ntype.pins) do

		local default = defaults[ntype.pinlookup[pinID][2]]

		if pin[1] == PD_In then

			local literal = NodeLiteralTypes[pin[2]]
			if literal then

				if self:GetLiteral(pinID) == nil then
					self:SetLiteral(pinID, default or Defaults[pin[2]])
				end

			end

		end

	end

	return true

end

function meta:ToString(pinID)

	local ntype = self:GetType()
	if not ntype then return self.graph:GetName() .. ":" .. "<unknown>" end
	local str = self.graph:GetName() .. "." .. ntype.name
	if pinID then
		local p = self:GetPin(pinID)
		if p then str = str .. "." .. p[3] .. " : " .. p[2] .. "[" .. tostring(p[5]) .. "]" end
	end
	return str

end

function meta:GetPins()

	return self:GetType().pins

end

function meta:GetPin(pinID)

	return self:GetPins()[pinID]

end

function meta:FindPin(dir, name)

	local pins = self:GetPins()
	for i=1, #pins do
		if pins[i][1] == dir and pins[i][3] == name then return i end
	end
	return nil

end

function meta:GetLiteral(pinID)

	return self.literals[pinID]

end

function meta:SetLiteral(pinID, value)

	value = tostring(value)
	self.literals[pinID] = value
	self.graph:FireListeners(bpgraph.CB_PIN_EDITLITERAL, self.id, pinID, value)

end

function meta:GetType()

	local nodeTypes = self.graph:GetNodeTypes()
	return nodeTypes[ self.nodeType ]

end

function meta:GetTypeName()

	return self.nodeType

end

function meta:GetName()

	return self.name

end

function meta:GetPos()

	return self.x, self.y

end

function meta:GetCode()

	return self:GetType().code

end

function meta:GetMeta()

	return self:GetType().meta

end

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