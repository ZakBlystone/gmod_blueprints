AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetOuterGraph() return self:GetType().graph end

function NODE:GeneratePins(pins)

	local graph = self:GetOuterGraph()

	pins[#pins+1] = MakePin( PD_In, "Exec", PN_Exec )

	bpcommon.Transform(graph.outputs:GetTable(), pins, bppin_meta.Copy, PD_In)

end

function NODE:Compile(compiler, pass)

	local graph = self:GetOuterGraph()

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		for _, pin in self:SidePins(PD_In) do
			compiler:CreatePinVar( pin )
		end

		return true

	elseif pass == CP_MAINPASS then

		for k, pin in self:SidePins(PD_In) do
			if not pin:IsType( PN_Exec ) then
				local var = compiler:FindVarForPin( pin )
				compiler.emit( compiler:GetVarCode(var) .. " = " .. compiler:GetPinCode( pin ) )
			end
		end

		local ret = compiler:FindVarForPin(nil, true)
		compiler.emit( compiler:GetVarCode(ret) .. " = true" )
		compiler.emit( "goto __terminus" )

		return true

	end

end

RegisterNodeClass("FuncExit", NODE)