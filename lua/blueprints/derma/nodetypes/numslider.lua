AddCSLuaFile()

module("dnode_slider", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DNumSlider"
NODE.Icon = "icon16/picture_empty.png"
NODE.Name = LOCTEXT("derma_node_slider","NumSlider")
NODE.Creatable = true

function NODE:Setup() 

end

function NODE:InitParams( params )

	params.min = 0
	params.max = 10
	params.decimals = 0
	params.value = 0
	params.enabled = true
	params.convar = ""
	params.label = "Label"

end

function NODE:GetCallbacks(t) 

	t[#t+1] = {
		func = "OnValueChanged",
		params = {
			MakePin(PD_In, "value", PN_Number)
		}
	}

end

function NODE:ApplyPanelValue( pnl, k, v, oldValue )

	if k == "min" then pnl:SetMin(v) end
	if k == "max" then pnl:SetMax(v) end
	if k == "decimals" then pnl:SetDecimals(v) end
	if k == "value" then pnl:SetValue(v) pnl:SetDefaultValue(v) end
	if k == "enabled" then pnl:SetEnabled(v) end
	if k == "convar" then pnl:SetConVar(v) end
	if k == "label" then pnl:SetText(v) end

end

function NODE:CompileInitializers(compiler)

	local params = self.data.params
	compiler.emit( ("self:SetMin(%d)"):format(params.min) )
	compiler.emit( ("self:SetMax(%d)"):format(params.max) )
	compiler.emit( ("self:SetDecimals(%d)"):format(params.decimals) )
	compiler.emit( ("self:SetDefaultValue(%d)"):format(params.value) )
	compiler.emit( ("self:SetValue(%d)"):format(params.value) )
	compiler.emit( ("self:SetEnabled(%s)"):format(tostring(params.enabled)) )
	compiler.emit( ("self:SetConVar(\"%s\")"):format(params.convar) )
	compiler.emit( ("self:SetText(\"%s\")"):format(params.label) )

end

RegisterDermaNodeClass("NumSlider", NODE)