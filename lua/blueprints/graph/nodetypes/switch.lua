AddCSLuaFile()

module("node_switch", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup()

	self:AddFlag(NTF_CallStack)
	self:ClearFlag(NTF_FallThrough)

	self.data.cases = self.data.cases or {}

end

function NODE:IsNumeric()

	return self:GetType():GetNodeParam("mode") == "number"

end

function NODE:ValueEntry(res)

	local pnl = nil
	local function commit()
		local value = self:IsNumeric() and tonumber(pnl:GetText()) or pnl:GetText()
		if value then res( value ) end
	end

	pnl = bptextliteraledit.LiteralEditWindow( self:IsNumeric() and "Enter Number" or "Enter String", "DTextEntry", 300, 50, commit, 0, 0 )
	if self:IsNumeric() then pnl:SetNumeric(true) end
	pnl:SetText( "" )
	pnl:SetCaretPos( #pnl:GetText() )
	local detour = pnl.OnKeyCodeTyped
	pnl.OnKeyCodeTyped = function(entry, keyCode)
		if keyCode == KEY_ENTER then
			commit()
			entry:GetParent():Close()
			return
		end
		detour(entry, keyCode)
	end

end

function NODE:PickRemove(res)

	local menu = bpuipickmenu.Create(nil, nil, 300, 200)
	menu:SetCollection( bpcollection.New():Add( self.data.cases ) )
	menu.OnEntrySelected = function(pnl, e) res(e) end
	menu.GetDisplayName = function(pnl, e) return tostring(e) end
	menu.GetTooltip = function(pnl, e) return "Remove '" .. tostring(e) .. "' pin" end
	menu:Setup()

end

function NODE:GetOptions(tab)

	BaseClass.GetOptions(self, tab)

	tab[#tab+1] = {
		"Add Case",
		function()
			self:ValueEntry( function(value)

				if not table.HasValue(self.data.cases, value) then
					self:PreModify()
					self.data.cases[#self.data.cases+1] = value
					self:PostModify()
				end

			end)
		end,
	}

	tab[#tab+1] = {
		"Remove Case",
		function()
			self:PickRemove( function(value)

				for k, v in ipairs(self.data.cases) do
					if v == value then
						self:PreModify()
						table.remove(self.data.cases, k)
						self:PostModify()
						return
					end
				end

			end)
		end,
	}

end

function NODE:GeneratePins(pins)

	pins[#pins+1] = MakePin(
		PD_In,
		"Exec",
		PN_Exec
	)

	pins[#pins+1] = MakePin(
		PD_In,
		"Value",
		self:IsNumeric() and PN_Number or PN_String
	)

	for _, case in ipairs(self.data.cases) do

		local casePin = MakePin(
			PD_Out,
			(self:IsNumeric() and tostring(case) or "\"" .. tostring(case) .. "\""),
			PN_Exec
		)

		pins[#pins+1] = casePin

	end

	pins[#pins+1] = MakePin(
		PD_Out,
		"Default",
		PN_Exec
	)

end

function NODE:GetGraphStatics(compiler, statics)

	statics[#statics+1] = self.lookup.context

end

function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_PREPASS then

		self.lookup = compiler:AllocThunk(bpcompiler.TK_GENERIC)
		self.lut_name = "switch_lut_" .. self.lookup.id

		self.lookup.begin()
		self.lookup.emit("local " .. self.lut_name .. " = {")
		for _, pin, k in self:SidePins(PD_Out) do

			local v = compiler:GetPinVar( pin )
			if pin:GetName() == "Default" then
			else

				self.lookup.emit("\t[" .. pin:GetName() .. "] = " .. v.var .. ",")

			end

		end
		self.lookup.emit("}")
		self.lookup.finish()

		return true

	elseif pass == CP_MAINPASS then

		--compiler.emit("goto popcall")

		local code = compiler:GetPinCode( self:FindPin(PD_In, "Value") )
		local defjump = compiler:GetPinVar( self:FindPin(PD_Out, "Default") ).var 
		local lut = self.lut_name .. "[" .. code .. "]"

		compiler.emit("ip = " .. lut .. " and " .. lut .. " or " .. defjump .. " goto jumpto")

		-- ip = lut[code] and lut[code] or def

		return true

	end

end

RegisterNodeClass("Switch", NODE)