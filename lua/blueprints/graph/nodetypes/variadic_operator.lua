AddCSLuaFile()

local NODE = {}

function NODE:Setup()

	self.data.pinCount = self.data.pinCount or 2

end

function NODE:GeneratePins(pins)

	BaseClass.GeneratePins(self, pins)

	local dataPin = nil
	local dataPinID = nil
	for k,v in ipairs(pins) do
		if v:IsOut() and not v:IsType(bpschema.PN_Exec) then
			dataPin = v
			dataPinID = k
			break
		end
	end
	if dataPin == nil then print("No data pin") return end

	for i=1, self.data.pinCount do
		pins[#pins+1] = bpschema.MakePin(
			bpschema.PD_In,
			"In_" .. i,
			dataPin:GetType()
		)
	end

end

function NODE:GetOptions(tab)

	BaseClass.GetOptions(self, tab)

	tab[#tab+1] = {
		"AddPin",
		function()
			self:PreModify()
			self.data.pinCount = self.data.pinCount + 1
			self:PostModify()
		end
	}

	if self.data.pinCount > 2 then

		tab[#tab+1] = {
			"RemovePin",
			function()
				self:PreModify()
				self.data.pinCount = self.data.pinCount - 1
				self:PostModify()
			end
		}

	end

end

function NODE:GetOperator()

	return self:GetType():GetNodeParam("operator")

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

RegisterNodeClass("VariadicOperator", NODE)