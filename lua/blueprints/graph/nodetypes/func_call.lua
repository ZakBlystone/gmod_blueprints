AddCSLuaFile()

module("node_funccall", package.seeall, bpcommon.rescope(bpschema, bpcompiler, bpnodetype))

local NODE = {}

function NODE:Setup() end
function NODE:Compile(compiler, pass)

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		for _, pin in self:SidePins(PD_In) do compiler:CreatePinVar( pin ) end
		for _, pin in self:SidePins(PD_Out) do compiler:CreatePinVar( pin ) end

		return true

	elseif pass == CP_MAINPASS then

		local name = self:GetRawName()
		local group = self:GetGroup()
		local context = self:GetContext()
		if group == nil then error("Function call without group!") end

		local groupName = group:GetName()
		local call = nil

		-- Determine function call statement based on context
		if context == NC_Class then

			call = groupName .. "_." .. name
			if self:HasFlag(NTF_DirectCall) then call = "__self:" .. name end

		elseif context == NC_Lib then

			call = groupName == "GLOBAL" and name or groupName .. "." .. name

		else

			error("Invalid call context")

		end

		-- Compile pins
		local ret = {}
		for k, pin in self:SidePins(PD_Out, bpnode.PF_NoExec) do
			ret[#ret+1] = compiler:GetPinCode( pin )
		end

		local arg = {}
		for k, pin in self:SidePins(PD_In, bpnode.PF_NoExec) do
			arg[#arg+1] = compiler:GetPinCode( pin, true )
		end

		-- Emit call statement
		compiler.emit( table.concat(ret, ",") .. (#ret > 0 and " = " or "") .. call .. "(" .. table.concat(arg, ",") .. ")"  )

		-- Non-pure functions must emit return jump code
		if self:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( self:FindPin(PD_Out, "Thru"), true ) ) end
		return true

	end

end

RegisterNodeClass("FuncCall", NODE)