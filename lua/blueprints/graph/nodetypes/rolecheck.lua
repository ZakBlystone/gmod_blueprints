AddCSLuaFile()

module("node_rolecheck", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup()

	self:AddFlag(NTF_FallThrough)
	self:SetCodeType(NT_Special)

end

function NODE:GeneratePins(pins)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_In,
		"Exec",
		bpschema.PN_Exec
	)

	local flags = 0
	local cond = self:GetConditionCode()

	if cond == "SERVER" then flags = flags + PNF_Server end
	if cond == "CLIENT" then flags = flags + PNF_Client end

	assert( flags ~= 0 )

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_Out,
		"Thru",
		bpschema.PN_Exec,
		flags
	)

end

function NODE:GetConditionCode()

	return string.upper(self:GetNodeParam("role"))

end

function NODE:GetThruPin() return self:FindPin(PD_Out, "Thru") end
function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_MAINPASS then

		local pinThru = self:GetThruPin()

		local thruConnections = pinThru:GetConnectedPins()
		local cond = self:GetConditionCode()

		if #thruConnections == 0 then
			compiler.emit("goto popcall")
		elseif #thruConnections == 1 then
			compiler.emit("if not " .. cond .. " then goto popcall end" )
			if self.__nextExec ~= thruConnections[1]:GetNode() then compiler.emit( compiler:GetPinCode( pinThru, true ) ) end
		end

		return true

	end

end

RegisterNodeClass("RoleCheck", NODE)