AddCSLuaFile()

module("node_eventbind", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:Compile(compiler, pass)

	if pass == CP_MAINPASS then

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

RegisterNodeClass("EventBind", NODE)