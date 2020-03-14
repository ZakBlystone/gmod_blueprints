AddCSLuaFile()

module("node_userfunccall", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GeneratePins(pins)

	local graph = self:GetGraphThunk()

	BaseClass.GeneratePins(self, pins)

	local mod = graph:GetModule()
	if mod and mod.HasSelfPin then
		pins[#pins+1] = MakePin( PD_In, "Self", mod:GetModulePinType() )
	end

	bpcommon.Transform(graph.inputs:GetTable(), pins, bppin_meta.Copy, PD_In)
	bpcommon.Transform(graph.outputs:GetTable(), pins, bppin_meta.Copy, PD_Out)

end

function NODE:Compile(compiler, pass)

	local graph = self:GetGraphThunk()

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		for _, pin in self:SidePins(PD_In) do compiler:CreatePinVar( pin ) end
		for _, pin in self:SidePins(PD_Out) do compiler:CreatePinVar( pin ) end

		return true

	elseif pass == CP_MAINPASS then

		local ret = {}
		for k, pin in self:SidePins(PD_Out) do
			if not pin:IsType( PN_Exec ) then
				local var = compiler:FindVarForPin( pin )
				ret[#ret+1] = compiler:GetVarCode(var)
			end
		end

		local arg = {}
		for k, pin in self:SidePins(PD_In) do
			if not pin:IsType( PN_Exec ) and pin:GetName() ~= "Self" then
				arg[#arg+1] = compiler:GetPinCode( pin, true )
			end
		end

		local selfPinCode = "__self"
		if graph:GetModule().HasSelfPin then
			selfPinCode = compiler:GetPinCode( self:FindPin( PD_In, "Self" ) )
		end

		compiler.emit( table.concat(ret, ",") .. (#ret > 0 and " = " or "") .. selfPinCode .. ":" .. graph:GetName() .. "(" .. table.concat(arg, ",") .. ")"  )

		if self:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( self:FindPin(PD_Out, "Thru"), true ) ) end
		return true

	end

end

RegisterNodeClass("FuncCall", NODE)