AddCSLuaFile()

module("dnode_label", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DLabel"
NODE.Icon = "icon16/picture_empty.png"
NODE.Name = LOCTEXT("derma_node_label","Label")
NODE.Creatable = true

function NODE:Setup() 

end

function NODE:InitParams( params )

	params.font = "DermaDefault"
	params.text = "Label"
	params.textColor = Color(255,255,255,255)

end

function NODE:GetCallbacks(t)

end

function NODE:ApplyPanelValue( pnl, k, v, oldValue )
	if k == "font" then pnl:SetFont(v) end
	if k == "text" then pnl:SetText(v) end
	if k == "textColor" then pnl:SetTextColor(v) end
end

function NODE:CompileInitializers(compiler)

	local params = self.data.params
	compiler.emit( ("self:SetEnabled(%s)"):format(tostring(params.enabled)) )
	compiler.emit( ("self:SetToggle(%s)"):format(tostring(params.toggle)) )
	compiler.emit( ("self:SetTextColor(Color(%d,%d,%d,%d))"):format(params.textColor.r, params.textColor.g, params.textColor.b, params.textColor.a) )

end

RegisterDermaNodeClass("Label", NODE)