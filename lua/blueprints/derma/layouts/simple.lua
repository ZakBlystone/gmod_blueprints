AddCSLuaFile()

-- this just lays things out vertically for now

module("dlayout_simple", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local LAYOUT = {}
LAYOUT.Name = LOCTEXT"derma_layout_simple","Simple"
LAYOUT.Creatable = true

function LAYOUT:Setup() end

function LAYOUT:InitParams(params)

	params.padding = 0
	params.horizontal = false

end

function LAYOUT:CompileLayout(compiler)

	compiler.emitBlock([[
		local l = self.layout
		local off = self.yoffset or 0
		local w, h = self:GetSize() h = h - off
		if l.horizontal then
			local x, a = l.padding, (w - l.padding*2) / #self.ordered
			for _, v in ipairs(self.ordered) do
				local pnl = self.panels[v]
				pnl:SetPos(x, l.padding + off)
				pnl:SetSize(a, h - l.padding*2)
				x = x + a
			end
		else
			local y, a = off + l.padding, (h - l.padding*2) / #self.ordered
			for _, v in ipairs(self.ordered) do
				local pnl = self.panels[v]
				pnl:SetPos(l.padding, y)
				pnl:SetSize(w - l.padding*2, a)
				y = y + a
			end
		end]])

end

RegisterDermaLayoutClass("Simple", LAYOUT)