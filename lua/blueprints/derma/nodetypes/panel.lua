AddCSLuaFile()

module("dnode_panel", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DPanel"
NODE.Icon = "icon16/application.png"
NODE.Name = LOCTEXT("derma_node_panel","Panel")
NODE.Creatable = true
NODE.CanHaveChildren = true

function NODE:Setup() 

end

function NODE:SetupDefaultLayout()

	self:SetLayout( bplayout.New("Simple") )
	return self

end

function NODE:InitParams( params )

	params.color = Color(255,255,255,255)
	params.drawBackground = true
	params.enabled = true

end

function NODE:ApplyPanelValue( pnl, k, v, oldValue )
	if k == "color" then pnl:SetBackgroundColor(v) end
	if k == "drawBackground" then pnl:SetPaintBackground(v) end
	if k == "enabled" then pnl:SetEnabled(v) end
end

function NODE:CompileInitializers(compiler)

	local params = self.data.params
	compiler.emit( ("self:SetBackgroundColor(Color(%d,%d,%d,%d))"):format(params.color.r, params.color.g, params.color.b, params.color.a) )
	compiler.emit( ("self:SetPaintBackground(\"%s\")"):format(params.drawBackground) )
	compiler.emit( ("self:SetEnabled(%s)"):format(tostring(params.enabled)) )

end

RegisterDermaNodeClass("Panel", NODE)