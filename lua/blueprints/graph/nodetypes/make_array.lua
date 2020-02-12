AddCSLuaFile()

local NODE = {}

function NODE:Setup()

	self.data.pinCount = self.data.pinCount or 1

end

function NODE:GeneratePins(pins)

	local anyPin = bppintype.New(bpschema.PN_Any)
	for i=1, self.data.pinCount do
		pins[#pins+1] = bpschema.MakePin(
			bpschema.PD_In,
			"In_" .. i,
			anyPin
		)
	end

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_Out,
		"Out",
		anyPin:AsTable()
	)

	self.BaseClass.GeneratePins(self, pins)

end

function NODE:GetOptions(tab)

	self.BaseClass.GetOptions(self, tab)

	tab[#tab+1] = {
		"AddPin",
		function()
			self:PreModify()
			self.data.pinCount = self.data.pinCount + 1
			self:PostModify()
		end,
	}

	if self.data.pinCount > 2 then

		tab[#tab+1] = {
			"RemovePin",
			function()
				self:PreModify()
				self.data.pinCount = self.data.pinCount - 1
				self:PostModify()
			end,
		}

	end

end

function NODE:GetInforms()

	local informs = {}
	for k,v in ipairs(self:GetPins()) do
		if v:GetType(true):IsType(bpschema.PN_Any) then
			informs[#informs+1] = k
		end
	end
	return informs

end

function NODE:GetFlags()

	return bit.bor(self.BaseClass.GetFlags(self), bpschema.NTF_HidePinNames)

end

local function sidePinFilter(pin) return not pin:IsType(bpschema.PN_Exec) end
function NODE:GetCode()

	local code = "#1 = {"
	for pinID, pin, pos in self:SidePins(bpschema.PD_In, sidePinFilter) do
		code = code .. "$" .. pos .. ", "
	end
	code = code .. "}"

	return code

end

RegisterNodeClass("MakeArray", NODE)