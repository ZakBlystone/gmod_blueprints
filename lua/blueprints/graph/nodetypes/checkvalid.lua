AddCSLuaFile()

module("node_checkvalid", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup()

	self:AddFlag(NTF_FallThrough)

end

function NODE:GeneratePins(pins)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_In,
		"Exec",
		bpschema.PN_Exec
	)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_In,
		"Thing",
		bpschema.PN_Any
	)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_Out,
		"Valid",
		bpschema.PN_Exec
	)

	pins[#pins+1] = bpschema.MakePin(
		bpschema.PD_Out,
		"Not Valid",
		bpschema.PN_Exec
	)

end

function NODE:GetInforms()

	return {2}

end

function NODE:GetConditionCode(compiler)

	local v = compiler:GetPinCode( self:FindPin(PD_In, "Thing") )
	return "__genericIsValid(" .. v .. ")"

end

function NODE:GetTruePin() return self:FindPin(PD_Out, "Valid") end
function NODE:GetFalsePin() return self:FindPin(PD_Out, "Not Valid") end

RegisterNodeClass("CheckValid", NODE, "If")