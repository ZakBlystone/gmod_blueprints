AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetStruct() return self:GetType().struct end

function NODE:GeneratePins(pins)

	local struct = self:GetStruct()

	if struct.pinTypeOverride then
		pins[#pins+1] = MakePin(PD_Out, struct:GetName(), struct.pinTypeOverride, PNF_None)
	else
		pins[#pins+1] = MakePin(PD_Out, struct:GetName(), PN_Struct, PNF_None, struct:GetName() )
	end

	bpcommon.Transform(struct.pins:GetTable(), pins, bppin_meta.Copy, PD_In)

	self.BaseClass.GeneratePins(self, pins)

end

function NODE:Compile(compiler, pass)

	local struct = self:GetStruct()

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		compiler:CreatePinVar( self:FindPin(PD_Out, struct:GetName()) )

		return true

	elseif pass == CP_MAINPASS then

		local outValuePin = self:FindPin(PD_Out, struct:GetName())
		local outValueCode = compiler:GetPinCode( outValuePin, true )
		compiler.emit( outValueCode .. " = {" )
		for pinID, pin in self:SidePins(PD_In) do
			if pin:IsType( PN_Exec ) then continue end
			local name = pin:GetName()
			local assignment = "[\"" .. (struct.invNameMap[name:lower()] or name) .. "\"] = " .. compiler:GetPinCode( pin ) .. ","
			compiler.emit(assignment)
		end
		compiler.emit("}")
		if struct.metaTable then compiler.emit("setmetatable( " .. outValueCode .. ", " .. struct.metaTable .. "_ )") end

		if self:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( self:FindPin(PD_Out, "Thru"), true ) ) end
		return true

	end

end

RegisterNodeClass("StructMake", NODE)