AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetOuterGraph() return self:GetType().graph end

function NODE:GeneratePins(pins)

	local graph = self:GetOuterGraph()

	pins[#pins+1] = MakePin( PD_Out, "Exec", PN_Exec )

	bpcommon.Transform(graph.inputs:GetTable(), pins, bppin_meta.Copy, PD_Out)

end

function NODE:Compile(compiler, pass)

	local graph = self:GetOuterGraph()

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		for _, pin in self:SidePins(PD_Out) do
			compiler:CreatePinVar( pin )
		end

		return true

	elseif pass == CP_MAINPASS then

		local ipin = 1
		for k, pin in self:SidePins(PD_Out) do
			if not pin:IsType( PN_Exec ) then
				compiler.emit( compiler:GetPinCode( pin, true ) .. " = arg[" .. ipin .. "]" )
				ipin = ipin + 1
			end
		end

		return true

	end

end

RegisterNodeClass("FuncEntry", NODE)