AddCSLuaFile()

module("node_funccall", package.seeall, bpcommon.rescope(bpschema, bpcompiler, bpnodetype))

local NODE = {}

local ServerRoleCheckType = bpnodetype.New():WithOuter( self )
ServerRoleCheckType:SetNodeClass("RoleCheck")
ServerRoleCheckType:SetNodeParam("role", "server")

local ClientRoleCheckType = bpnodetype.New():WithOuter( self )
ClientRoleCheckType:SetNodeClass("RoleCheck")
ClientRoleCheckType:SetNodeParam("role", "client")

function NODE:Setup() end
function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		for _, pin in self:SidePins(PD_In) do compiler:CreatePinVar( pin ) end
		for _, pin in self:SidePins(PD_Out) do compiler:CreatePinVar( pin ) end

		return true

	elseif pass == CP_MAINPASS then

		local name = self:GetName()
		local group = self:GetGroup()
		local context = self:GetContext()
		if group == nil then error("Function call without group!") end

		local groupName = group:GetName()
		local call = nil
		local nometa = false

		-- Determine function call statement based on context
		if context == NC_Class then

			call = groupName .. "_." .. name
			if self:HasFlag(NTF_DirectCall) then call = "__self:" .. name end
			if group:HasFlag(bpnodetypegroup.FL_NoIndexMeta) then
				call = ":" .. name
				nometa = true
			end

		elseif context == NC_Lib then

			call = groupName == "GLOBAL" and name or groupName .. "." .. name

		else

			error("Invalid call context")

		end

		--print("COMPILE CALL: " .. self:ToString())

		-- Compile pins
		local ret = {}
		for k, pin in self:SidePins(PD_Out, bpnode.PF_NoExec) do
			ret[#ret+1] = compiler:GetPinCode( pin )
		end

		local arg = {}
		for k, pin in self:SidePins(PD_In, bpnode.PF_NoExec) do
			arg[#arg+1] = compiler:GetPinCode( pin, true )
		end

		-- Prepend first argument in obj:Func style call
		if nometa then
			local selfPin = arg[1]
			table.remove(arg,1)
			call = selfPin .. call

			print("FUNC CALL WITH NOMETA: " .. tostring(call))
		end

		-- Emit call statement
		compiler.emit( table.concat(ret, ",") .. (#ret > 0 and " = " or "") .. call .. "(" .. table.concat(arg, ",") .. ")"  )

		-- Non-pure functions must emit return jump code
		compiler:CompileReturnPin( self )
		return true

	end

end

function NODE:Expand()

	if self:GetCodeType() == NT_Function then

		local exec = self:FindPin(PD_In, "Exec")
		if exec then

			local exec_sv = exec:HasFlag( PNF_Server )
			local exec_cl = exec:HasFlag( PNF_Client )

			local sourcePins = exec:GetConnectedPins()
			for _, pin in ipairs(sourcePins) do

				local source_sv = pin:HasFlag( PNF_Server )
				local source_cl = pin:HasFlag( PNF_Client )

				if source_sv ~= exec_sv or source_cl ~= exec_cl then

					print("Expand to role check: " .. tostring(self))

					local t = exec_cl and ClientRoleCheckType or ServerRoleCheckType
					assert(t ~= nil)

					local node = self:GetGraph():AddIntermediate(t)
					node:Initialize()

					pin:BreakAllLinks()
					pin:MakeLink( node:FindPin(PD_In, "Exec") )
					node:FindPin(PD_Out, "Thru"):MakeLink( exec )

				end

			end

		end

	end

end

RegisterNodeClass("FuncCall", NODE)