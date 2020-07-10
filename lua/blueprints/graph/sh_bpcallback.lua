AddCSLuaFile()

module("bpcallback", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local meta = bpcommon.MetaTable("bpcallback")

function meta:Init()

	self.name = ""
	self.pins = {}
	return self

end

function meta:AddPin( pin )

	self.pins[#self.pins+1] = pin

end

function meta:GetPins() return self.pins end

function meta:SetName(name) self.name = name end
function meta:GetName() return self.name end

function meta:GraphMatches( graph )

	print("PIN COUNT: " .. #self.pins .. " : " .. tostring(self.name))

	if graph:GetType() ~= GT_Function then return false end

	local inputs, outputs = {}, {}
	for _, pin in ipairs(self.pins) do

		if pin:GetDir() == PD_In then inputs[#inputs+1] = pin end
		if pin:GetDir() == PD_Out then outputs[#outputs+1] = pin end

	end

	for i, pin in graph.inputs:Items() do
		if inputs[i] == nil or not pin:GetType():Equal(inputs[i]) then return false end
	end

	for i, pin in graph.outputs:Items() do
		if outputs[i] == nil or not pin:GetType():Equal(outputs[i]) then return false end
	end

	return true

end

function meta:Serialize(stream)

	self.pins = stream:ObjectArray( self.pins, self )
	self.name = stream:String( self.name )

end

function meta:ToString()

	return self:GetName()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end