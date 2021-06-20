AddCSLuaFile()

local NODE = {}

function NODE:Setup()

	self.data.pinCount = self.data.pinCount or 2

end

function NODE:GeneratePins(pins)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_In,
		"Exec",
		bpschema.PN_Exec
	)

	for i=1, self.data.pinCount do
		pins[#pins+1] = bpschema.MakePin(
			bpschema.PD_Out,
			"Out_" .. i,
			bpschema.PN_Exec
		):SetDisplayName(tostring(i))
	end

	pins[#pins+1] = dataPin

end

function NODE:GetJumpSymbols()

	local t = {}
	for i=1, self.data.pinCount do
		t[#t+1] = tostring(i)
	end
	return t

end

function NODE:GetCode()

	local str = ""

	for i=1, self.data.pinCount do
		str = str .. "pushjmp(^_" .. i .. ") ip = #_" .. i .. " goto jumpto ::^" .. i .. "::\n"
	end
	str = str .. "goto popcall"

	return str

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

RegisterNodeClass("Sequence", NODE)