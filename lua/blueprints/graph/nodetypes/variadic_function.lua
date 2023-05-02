AddCSLuaFile()

local NODE = {}

function NODE:Setup()

	self.data.extra_pins = self.data.extra_pins or {}

end

function NODE:GeneratePins(pins)

	BaseClass.GeneratePins(self, pins)

	local dataPin = nil
	local dataPinID = nil
	for k,v in ipairs(pins) do
		if v:IsIn() and not v:IsType(bpschema.PN_Exec) then
			dataPin = v
			dataPinID = k
            if self:ShouldStartEmpty() then table.remove(pins, k) end
			break
		end
	end
	if dataPin == nil then print("No data pin") return end

	for k, pintype in ipairs(self.data.extra_pins) do

        print("PINTYPE[" .. k .. "]: " .. pintype)

		pins[#pins+1] = bpschema.MakePin(
			bpschema.PD_In,
			"In_" .. k,
			bppintype.New():FromTypeString(pintype)
		)
	end

end

function NODE:RequestPinType(res)

    local collection = bpcollection.New()
    local filter = self:GetFilter()
    local allowFlagEdit = true

    if #filter > 0 then
        current = filter[1]
        collection:Add( filter )
        allowFlagEdit = false
    else
        self:GetModule():GetAllPinTypes( collection )
    end

    local onSelected = function(pnl, pintype)
        res( pintype )
    end

    bpuivarcreatemenu.OpenPinSelectionMenuEx( collection, onSelected, current, allowFlagEdit )

end

function NODE:GetOptions(tab)

	BaseClass.GetOptions(self, tab)

	tab[#tab+1] = {
		"AddPin",
		function()
            self:RequestPinType( function(pintype)
                if pintype then
                    self:PreModify()
                    self.data.extra_pins[#self.data.extra_pins+1] = pintype:ToTypeString()
                    self:PostModify()
                end
            end)
		end
	}

	if #self.data.extra_pins > 0 then

		tab[#tab+1] = {
			"RemovePin",
			function()
				self:PreModify()
				table.remove(self.data.extra_pins, #self.data.extra_pins)
				self:PostModify()
			end
		}

	end

end

function NODE:GetFilter()

	local str = self:GetType():GetNodeParam("filter") or ""
    local filters = {}
    for x in string.gmatch(str, "{([^}]*)}") do

        filters[#filters+1] = bppintype.New():FromTypeString(x)

    end
    return filters

end

function NODE:ShouldStartEmpty()

    return self:GetType():GetNodeParam("empty") == "true"

end

RegisterNodeClass("VariadicFunction", NODE, "FuncCall")