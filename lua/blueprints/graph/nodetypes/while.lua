AddCSLuaFile()

module("node_while", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup()

	self:AddFlag(NTF_CallStack)
	self:AddFlag(NTF_Experimental)

end

function NODE:GeneratePins(pins)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_In,
		"Exec",
		bpschema.PN_Exec
	)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_In,
		"Condition",
		bpschema.PN_Bool
	)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_Out,
		"While True",
		bpschema.PN_Exec
	)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_Out,
		"Finished",
		bpschema.PN_Exec
	)

end

function NODE:GetConditionPin() return self:FindPin(PD_In, "Condition") end
function NODE:GetWhilePin() return self:FindPin(PD_Out, "While True") end
function NODE:GetFinishedPin() return self:FindPin(PD_Out, "Finished") end

function NODE:GetJumpSymbols()
	return {"iter"}
end

function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_MAINPASS then
		
		return true

	elseif pass == CP_FUNCTIONPASS then

		local pinCondition = self:GetConditionPin()
		local pinWhile = self:GetWhilePin()
		local pinFinished = self:GetFinishedPin()

		local cond = compiler:GetPinCode( pinCondition )
		local jumptable = compiler:GetGraphJumpTable(self:GetGraph())
		local nodeID = compiler:GetID(self)
		local graphID = compiler:GetID(self:GetGraph())
		local emitted = {}

		local iter_jumpcode = jumptable[nodeID]["iter"]

		compiler.emit("::jmp_" .. iter_jumpcode .. "::")

		-- walk through all connected pure nodes, emit each node's code context once
		compiler:WalkBackPureNodes(self, function(pure)
			if emitted[pure] then return end
			emitted[pure] = true
			print(tostring(pure))
			compiler.emitContext( CTX_SingleNode .. graphID .. "_" .. compiler:GetID(pure), 1 )
		end)

		compiler.pushIndent()
		if compiler.debug then compiler.emit("_FR_DBG(" .. nodeID .. ")") end
		if compiler.ilp then compiler.emit((compiler.debug and "_FR_ILPD" or "_FR_ILP") .. "(" .. compiler.ilpmax .. ", " .. nodeID .. ")") end
		compiler.emit("if " .. cond .. " then sp=sp+1 cs[sp]=" .. iter_jumpcode .. " " .. compiler:GetPinCode(pinWhile, true) .. " end" )
		compiler.emit( compiler:GetPinCode(pinFinished, true) )
		compiler.popIndent()

		return true

	end

end

RegisterNodeClass("While", NODE)