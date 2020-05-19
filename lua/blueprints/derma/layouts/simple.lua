AddCSLuaFile()

-- this just lays things out vertically for now

module("dlayout_simple", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local LAYOUT = {}

function LAYOUT:Setup() end

function LAYOUT:InitParams(params)

	params.padding = 0

end

function LAYOUT:CompileLayout(compiler)

	compiler.emitBlock([[
		local l = self.layout
		local off = self.yoffset or 0
		local y, a = off + l.padding, (self:GetTall() - off - l.padding*2) / #self.ordered
		for _, v in ipairs(self.ordered) do
			local pnl = self.panels[v]
			pnl:SetPos(l.padding, y)
			pnl:SetSize(self:GetWide() - l.padding*2, a)
			y = y + a
		end]])

end

RegisterDermaLayoutClass("Simple", LAYOUT)