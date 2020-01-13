AddCSLuaFile()

local NODE = {}

function NODE:Setup()

	self.data.pinCount = self.data.pinCount or 2

end

function NODE:GeneratePins(pins)

	table.insert(pins, bpschema.MakePin(
		bpschema.PD_In,
		"Exec",
		bpschema.PN_Exec
	))

	for i=1, self.data.pinCount do
		table.insert(pins, bpschema.MakePin(
			bpschema.PD_Out,
			"Out_" .. i,
			bpschema.PN_Exec
		):SetDisplayName(tostring(i)))
	end

	table.insert(pins, dataPin)

end

function NODE:GetJumpSymbols()

	local t = {}
	for i=1, self.data.pinCount do
		table.insert(t, tostring(i))
	end
	return t

end

function NODE:GetCode()

	local str = ""

	for i=1, self.data.pinCount do
		str = str .. "pushjmp(^_" .. i .. ") ip = #_" .. i .. " goto jumpto\n"
		str = str .. "::^" .. i .. "::\n"
	end
	str = str .. "goto popcall"

	return str

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

bpnodeclasses.Register("Sequence", NODE)