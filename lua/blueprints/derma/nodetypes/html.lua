AddCSLuaFile()

module("dnode_panel", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DHTML"
NODE.Icon = "icon16/application_view_tile.png"
NODE.Name = LOCTEXT("derma_node_html","HTML")
NODE.Creatable = true

function NODE:Setup() 

end

function NODE:SetupDefaultLayout()

	return self

end

function NODE:InitParams( params )

	params.html = ""
	params.url = ""

end

function NODE:ApplyPanelValue( pnl, k, v, oldValue )
	if k == "html" then pnl:SetHTML(v) end
	if k == "url" then pnl:OpenURL(v) end
end

function NODE:CompileInitializers(compiler)

	local params = self.data.params
	compiler.emit( ("self:SetHTML(\"%s\")"):format(tostring(params.html)) )

	if params["url"] ~= "" then
		compiler.emit( ("self:OpenURL(\"%s\")"):format(tostring(params.url)) )
	end

end

RegisterDermaNodeClass("HTML", NODE)