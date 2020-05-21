AddCSLuaFile()

module("dnode_window", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DFrame"
NODE.RootOnly = true
NODE.Icon = "icon16/application_form.png"
NODE.Name = LOCTEXT"derma_node_window","Window"
NODE.Creatable = true
NODE.CanHaveChildren = true

function NODE:Setup()

end

function NODE:SetupDefaultLayout()

	self:SetLayout( bplayout.New("Simple"):SetParam("padding", 8) )
	return self

end

function NODE:InitParams( params )

	params.width = 400
	params.height = 300
	params.title = "Window"

end

function NODE:ApplyPanelValue( pnl, k, v, oldValue )
	if k == "width" then pnl:SetWide(v) end
	if k == "height" then pnl:SetTall(v) end
	if k == "title" then pnl:SetTitle(v) end
end

function NODE:CompileInitializers(compiler)

	local params = self.data.params
	compiler.emit( ("self:SetSize(%d,%d)"):format(params.width, params.height) )
	compiler.emit( ("self:SetTitle(\"%s\")"):format(params.title) )
	compiler.emit( "self.yoffset=25" )

end

RegisterDermaNodeClass("Window", NODE)