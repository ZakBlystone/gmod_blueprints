AddCSLuaFile()

local NODE = {}

function NODE:Setup()

	self.data.pinCount = self.data.pinCount or 1

end

function NODE:GeneratePins(pins)

	local anyPin = bppintype.New(bpschema.PN_Any)
	for i=1, self.data.pinCount do
		table.insert(pins, bpschema.MakePin(
			bpschema.PD_In,
			"In_" .. i,
			anyPin
		))
	end

	table.insert(pins, bpschema.MakePin(
		bpschema.PD_Out,
		"Out",
		anyPin:AsTable()
	))

	self.BaseClass.GeneratePins(self, pins)

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

function NODE:GetInforms()

	local informs = {}
	for k,v in pairs(self:GetPins()) do
		if v:IsType(bpschema.PN_Any) then
			table.insert(informs, k)
		end
	end
	return informs

end

function NODE:GetMeta()

	return {hidePinNames = true}

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

bpnodeclasses.Register("MakeArray", NODE)