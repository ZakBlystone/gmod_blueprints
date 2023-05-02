AddCSLuaFile()

module("node_if", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup()

end

--[[
IN Exec, PN_Exec
IN Condition, PN_Bool
OUT True, PN_Exec, #Executes if true
OUT False, PN_Exec, #Executes if false
]]

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
		"True",
		bpschema.PN_Exec
	)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_Out,
		"False",
		bpschema.PN_Exec
	)

end

function NODE:GetConditionCode(compiler)

	return compiler:GetPinCode( self:FindPin(PD_In, "Condition") )

end

function NODE:GetFalsePin() return self:FindPin(PD_Out, "False") end
function NODE:GetTruePin() return self:FindPin(PD_Out, "True") end

function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_MAINPASS then

		local pinFalse = self:GetFalsePin()
		local pinTrue = self:GetTruePin()

		local falseConnections = pinFalse:GetConnectedPins()
		local trueConnections = pinTrue:GetConnectedPins()
		local cond = self:GetConditionCode(compiler)

		--if self.__nextExec then print( self:ToString() .. " NEXT: " .. self.__nextExec:ToString() ) else print( self:ToString() .. " NO NEXT") end

		if #falseConnections == 0 and #trueConnections == 0 then
			compiler.emit("goto popcall")
		elseif #trueConnections == 1 and #falseConnections == 0 then
			compiler.emit("if not " .. cond .. " then goto popcall end" )
			if self.__nextExec ~= trueConnections[1]:GetNode() then compiler.emit( compiler:GetPinCode( pinTrue, true ) ) end
		elseif #trueConnections == 0 and #falseConnections == 1 then
			compiler.emit("if " .. cond .. " then goto popcall end" )
			if self.__nextExec ~= falseConnections[1]:GetNode() then compiler.emit( compiler:GetPinCode( pinFalse, true ) ) end
		else
			compiler.emit("if not " .. cond .. " then " .. compiler:GetPinCode( pinFalse, true ) .. " end" )
			if self.__nextExec ~= trueConnections[1]:GetNode() then compiler.emit( compiler:GetPinCode( pinTrue, true ) ) end
		end

		
		return true

	end

end

RegisterNodeClass("If", NODE)