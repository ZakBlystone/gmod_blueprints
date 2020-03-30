AddCSLuaFile()

module("node_userfuncentry", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GeneratePins(pins)

	pins[#pins+1] = MakePin( PD_Out, "Exec", PN_Exec )

	bpcommon.Transform(self:GetGraph().inputs:GetTable(), pins, bppin_meta.Copy, PD_Out)

end

function NODE:Compile(compiler, pass)

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		for _, pin in self:SidePins(PD_Out) do
			compiler:CreatePinVar( pin )
		end

		return true

	elseif pass == CP_MAINPASS then

		local arg = {}
		for k, pin in self:SidePins(PD_Out) do
			if not pin:IsType( PN_Exec ) then
				arg[#arg+1] = compiler:GetPinCode( pin, true )
			end
		end

		if #arg > 0 then compiler.emit( table.concat(arg, ",\n\t") .. " = ..." ) end

		return true

	end

end

RegisterNodeClass("UserFuncEntry", NODE)