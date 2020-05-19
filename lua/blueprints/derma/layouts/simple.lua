AddCSLuaFile()

-- this just lays things out vertically for now

module("dlayout_simple", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local LAYOUT = {}

function LAYOUT:Setup() end
function LAYOUT:Compile(compiler)

	compiler.emitBlock([[
		local off = self.yoffset or 0
		local y, a = off, (self:GetTall() - off) / #self.ordered
		for _, v in ipairs(self.ordered) do
			local pnl = self.panels[v]
			pnl:SetPos(0, y)
			pnl:SetSize(self:GetWide(), a)
			y = y + a
		end]])

end

RegisterDermaLayoutClass("Simple", LAYOUT)