AddCSLuaFile()

module("node_structbreak", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetStruct() return self:GetType():FindOuter( bpstruct_meta ) end

function NODE:GeneratePins(pins)

	local struct = self:GetStruct()

	if struct.pinTypeOverride then
		pins[#pins+1] = MakePin(PD_In, struct:GetName(), struct.pinTypeOverride, PNF_None)
	else
		pins[#pins+1] = MakePin(PD_In, struct:GetName(), PN_Struct, PNF_None, struct:GetName() )
	end

	bpcommon.Transform(struct.pins:GetTable(), pins, bppin_meta.Copy, PD_Out)

	BaseClass.GeneratePins(self, pins)

end

function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	local struct = self:GetStruct()

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		compiler:CreatePinVar( self:FindPin(PD_In, struct:GetName()) )

		local input = self:FindPin(PD_In, struct:GetName())
		for pinID, pin in self:SidePins(PD_Out) do
			if pin:IsType( PN_Exec ) then continue end
			compiler:CreatePinRouter( pin, function(pin)
				local name = pin:GetName()
				return { var = compiler:GetPinCode(input) .. "[\"" .. (struct.invNameMap[name:lower()] or name) .. "\"]" }
			end )
		end

		return true

	elseif pass == CP_MAINPASS then

		compiler:CompileReturnPin( self )
		return true

	end

end

RegisterNodeClass("StructBreak", NODE)