AddCSLuaFile()

module("dnode_button", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DButton"
NODE.Icon = "icon16/picture_empty.png"
NODE.Name = LOCTEXT("derma_node_button","Button")
NODE.Creatable = true

function NODE:Setup() 

end

function NODE:InitParams( params )

	params.font = "DermaDefault"
	params.text = "Button"
	params.toggle = false
	params.enabled = true

end

function NODE:GetCallbacks(t) 

	t[#t+1] = {
		func = "DoClick",
		params = {}
	}

	t[#t+1] = {
		func = "DoDoubleClick",
		params = {}
	}

end

function NODE:ApplyPanelValue( pnl, k, v, oldValue )
	if k == "font" then pnl:SetFont(v) end
	if k == "text" then pnl:SetText(v) end
	if k == "toggle" then pnl:SetToggle(v) end
	if k == "enabled" then pnl:SetEnabled(v) end
end

function NODE:CompileInitializers(compiler)

	local params = self.data.params
	compiler.emit( ("self:SetEnabled(%s)"):format(tostring(params.enabled)) )
	compiler.emit( ("self:SetToggle(%s)"):format(tostring(params.toggle)) )
	compiler.emit( ("self:SetText(\"%s\")"):format(params.text) )
	compiler.emit( ("self:SetFont(\"%s\")"):format(params.font) )

end

RegisterDermaNodeClass("Button", NODE)