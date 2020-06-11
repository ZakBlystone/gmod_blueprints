AddCSLuaFile()

module("dnode_textentry", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DTextEntry"
NODE.Icon = "icon16/picture_empty.png"
NODE.Name = LOCTEXT("derma_node_textentry","TextEntry")
NODE.Creatable = true

function NODE:Setup() 

end

function NODE:InitParams( params )

	params.font = "DermaDefault"
	params.text = "Text"
	params.enabled = true
	params.multiline = false
	params.numeric = false
	params.updateOnType = false

end

function NODE:GetCallbacks(t) 

	t[#t+1] = {
		func = "OnChange",
		params = {}
	}

	t[#t+1] = {
		func = "OnEnter",
		params = {}
	}

	t[#t+1] = {
		func = "OnGetFocus",
		params = {}
	}

	t[#t+1] = {
		func = "OnKeyCode",
		params = {
			MakePin(PD_In, "keyCode", PN_Enum, PNF_None, "KEY"),
		}
	}

	t[#t+1] = {
		func = "OnValueChange",
		params = {
			MakePin(PD_In, "value", PN_String),
		}
	}

end

function NODE:ApplyPanelValue( pnl, k, v, oldValue )
	if k == "font" then pnl:SetFont(v) end
	if k == "text" then pnl:SetText(v) end
	if k == "enabled" then pnl:SetEnabled(v) end
	if k == "multiline" then pnl:SetMultiline(v) end
	if k == "numeric" then pnl:SetNumeric(v) end
	if k == "updateOnType" then pnl:SetUpdateOnType(v) end
end

function NODE:CompileInitializers(compiler)

	local params = self.data.params
	compiler.emit( ("self:SetEnabled(%s)"):format(tostring(params.enabled)) )
	compiler.emit( ("self:SetText(\"%s\")"):format(params.text) )
	compiler.emit( ("self:SetFont(\"%s\")"):format(params.font) )
	compiler.emit( ("self:SetMultiline(%s)"):format(tostring(params.multiline)) )
	compiler.emit( ("self:SetNumeric(%s)"):format(tostring(params.numeric)) )
	compiler.emit( ("self:SetUpdateOnType(%s)"):format(tostring(params.updateOnType)) )

end

RegisterDermaNodeClass("TextEntry", NODE)