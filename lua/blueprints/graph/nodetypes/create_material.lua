AddCSLuaFile()

module("node_creatematerial", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

shaders = {
	{
		shader = "VertexLitGeneric",
		inputs = {
			MakePin(PD_None, "basetexture", PN_String),
			MakePin(PD_None, "bumpmap", PN_String),
			MakePin(PD_None, "envmap", PN_String),
			MakePin(PD_None, "model", PN_Bool),
			MakePin(PD_None, "selfillum", PN_Bool),
			MakePin(PD_None, "color2", PN_Color),
			MakePin(PD_None, "phong", PN_Bool),
			MakePin(PD_None, "phongExponent", PN_Number),
			MakePin(PD_None, "phongExponentTexture", PN_String),
			MakePin(PD_None, "phongBoost", PN_Number),
			MakePin(PD_None, "phongFresnelRanges", PN_Vector),
			MakePin(PD_None, "detail", PN_String),
			MakePin(PD_None, "alpha", PN_Number),
			MakePin(PD_None, "translucent", PN_Bool),
		},
	},
	{
		shader = "UnlitGeneric",
		inputs = {
			MakePin(PD_None, "basetexture", PN_String),
			MakePin(PD_None, "model", PN_Bool),
			MakePin(PD_None, "detail", PN_String),
			MakePin(PD_None, "alpha", PN_Number),
			MakePin(PD_None, "translucent", PN_Bool),
			MakePin(PD_None, "vertexcolor", PN_Bool),
			MakePin(PD_None, "vertexalpha", PN_Bool),
			MakePin(PD_None, "additive", PN_Bool),
		},
	},
	{
		shader = "LightmappedGeneric",
		inputs = {
			MakePin(PD_None, "basetexture", PN_String),
			MakePin(PD_None, "bumpmap", PN_String),
			MakePin(PD_None, "envmap", PN_String),
			MakePin(PD_None, "selfillum", PN_Bool),
			MakePin(PD_None, "color", PN_Color),
			MakePin(PD_None, "decal", PN_Bool),
			MakePin(PD_None, "detail", PN_String),
			MakePin(PD_None, "alpha", PN_Number),
			MakePin(PD_None, "translucent", PN_Bool),
		},
	},
}

local converters = {
	[PN_Bool] = function(x) return x == "true" and "1" or "0" end
}

function GetShader( name )

	for _, v in ipairs(shaders) do
		if v.shader == name then return v end
	end

end

local NODE = {}

function NODE:Setup()

	self.data.shader = self.data.shader or "UnlitGeneric"

end

function NODE:SetShader( shader )

	self.graph:PreModifyNode( self )
	self.data.shader = shader
	self.graph:PostModifyNode( self )
	self:SetLiteralDefaults( true )

end

function NODE:GetShader()

	return self.data.shader

end

function NODE:GeneratePins(pins)

	BaseClass.GeneratePins(self, pins)

	pins[#pins+1] = MakePin(
		PD_In,
		"Shader",
		PN_Dummy
	)
	pins[#pins]:SetPinClass("MatShader")

	pins[#pins+1] = MakePin(
		PD_In,
		"MaterialName",
		PN_String
	)

	pins[#pins+1] = MakePin(
		PD_Out,
		"Material",
		PN_Ref,
		PNF_None,
		"IMaterial"
	)

	local selectedShader = GetShader( self.data.shader )
	if selectedShader then

		for _, v in ipairs( selectedShader.inputs ) do
			pins[#pins+1] = v:Copy(PD_In)
		end

	else
		print("No shader selected")
	end

end

function NODE:Compile(compiler, pass)

	if pass == CP_PREPASS then

		return true

	elseif pass == CP_ALLOCVARS then

		compiler:CreatePinVar( self:FindPin(PD_Out, "Material") )

		return true

	elseif pass == CP_MAINPASS then

		local materialName = self:FindPin(PD_In, "MaterialName")
		local outValuePin = self:FindPin(PD_Out, "Material")
		local materialNameCode = compiler:GetPinCode( materialName )
		local outValueCode = compiler:GetPinCode( outValuePin, true )
		compiler.emit( string.format("%s = CreateMaterial( %s, \"%s\", {", outValueCode, materialNameCode, self:GetShader() ) )
		for pinID, pin in self:SidePins(PD_In) do
			if pin:IsType( PN_Exec ) or pin == materialName or pin:IsType(PN_Dummy) then continue end
			if #pin:GetConnectedPins() == 0 and pin:GetLiteral() == pin:GetDefault() then continue end

			local name = pin:GetName()
			local value =  compiler:GetPinCode( pin )
			local cv = converters[ pin:GetBaseType() ]
			if cv then value = cv(value) end

			local assignment = "[\"$" .. name:lower() .. "\"] = " .. value .. ","
			compiler.emit(assignment)
		end
		compiler.emit("} )")

		if self:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( self:FindPin(PD_Out, "Thru"), true ) ) end
		return true

	end

end

RegisterNodeClass("CreateMaterial", NODE)