AddCSLuaFile()

local NODE = {}

function NODE:Setup()

	self.data.pinCount = self.data.pinCount or 2

end

function NODE:GeneratePins(pins)

	self.BaseClass.GeneratePins(self, pins)

	local dataPin = nil
	local dataPinID = nil
	for k,v in pairs(pins) do
		if v:IsOut() and not v:IsType(bpschema.PN_Exec) then
			dataPin = v
			dataPinID = k
			break
		end
	end
	if dataPin == nil then print("No data pin") return end

	-- we need the data pin to be the last pin for backwards compatibility
	table.remove(pins, dataPinID)

	for i=1, self.data.pinCount do
		table.insert(pins, bpschema.MakePin(
			bpschema.PD_In,
			"In_" .. i,
			dataPin:GetType()
		))
	end

	table.insert(pins, dataPin)

end

function NODE:GetOptions(tab)

	self.BaseClass.GetOptions(self, tab)

	table.insert(tab, {
		"AddPin",
		function()
			self:PreModify()
			self.data.pinCount = self.data.pinCount + 1
			self:PostModify()
		end
	})

	if self.data.pinCount > 2 then

		table.insert(tab, {
			"RemovePin",
			function()
				self:PreModify()
				self.data.pinCount = self.data.pinCount - 1
				self:PostModify()
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