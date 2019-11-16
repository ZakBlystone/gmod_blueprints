AddCSLuaFile()

local NODE = {}

function NODE:Setup()
	self.data.pinCount = self.data.pinCount or 2

	PrintTable(self.literals)
end

function NODE:GeneratePins()
	local pins = table.Copy(self.BaseClass.GeneratePins(self))
	local dataPin = nil
	local dataPinID = nil
	for k,v in pairs(pins) do
		if v[1] == bpschema.PD_Out and v[2] ~= bpschema.PN_Exec then
			dataPin = v
			dataPinID = k
			break
		end
	end
	if dataPin == nil then print("No data pin") return pins end

	-- we need the data pin to be the last pin for backwards compatibility
	table.remove(pins, dataPinID)

	for i=1, self.data.pinCount do
		table.insert(pins, {
			bpschema.PD_In,
			dataPin[2],
			"In_" .. i,
			dataPin[4],
			dataPin[5],
		})
	end

	table.insert(pins, dataPin)

	return pins
end

function NODE:GetOptions(tab)
	self.BaseClass.GetOptions(self, tab)

	table.insert(tab, {
		"AddPin",
		function()
			self.graph:PreModifyNode( self, bpgraph.NODE_MODIFY_SIGNATURE )
			self.data.pinCount = self.data.pinCount + 1
			self:UpdatePins()
			self.graph:PostModifyNode( self, bpgraph.NODE_MODIFY_SIGNATURE )
		end
	})

	if self.data.pinCount > 2 then

		table.insert(tab, {
			"RemovePin",
			function()
				self.graph:PreModifyNode( self, bpgraph.NODE_MODIFY_SIGNATURE )
				self.data.pinCount = self.data.pinCount - 1
				self:UpdatePins()
				self.graph:PostModifyNode( self, bpgraph.NODE_MODIFY_SIGNATURE )
			end
		})

	end
end

function NODE:GetOperator()

	return self:GetType().params["operator"]

end

function NODE:GetCode()

	local str = "#1 ="
	local operator = self:GetOperator()
	for i=1, self.data.pinCount do
		str = str .. " $" .. i
		if i ~= self.data.pinCount then
			str = str .. " " .. operator
		end
	end

	return str

end

bpnodeclasses.Register("VariadicOperator", NODE)