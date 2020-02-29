AddCSLuaFile()

module("bpvariable", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpvariable")

function meta:Init(type, repmode)

	if type then
		self.pintype = type
		self.default = self.pintype:GetDefault()
	end

	self.repmode = repmode

	self.getterNodeType = bpnodetype.New()
	self.getterNodeType:AddFlag( NTF_Compact )
	self.getterNodeType:AddFlag( NTF_Custom )
	self.getterNodeType:SetCodeType( NT_Pure )
	self.getterNodeType:SetCode("")
	self.getterNodeType.GetDisplayName = function() return "Get" .. self:GetName() end
	self.getterNodeType.GetRawPins = function() return { MakePin( PD_Out, "value", self.pintype ) } end
	self.getterNodeType.Compile = function(node, compiler, pass)

		local varName = "__self.__" .. self:GetName()
		if compiler.compactVars then varName = "__self.__" .. self.id end

		if pass == bpcompiler.CP_ALLOCVARS then 

			compiler:CreatePinRouter( node:FindPin(PD_Out, "value"), function(pin)
				return { var = varName }
			end )

			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			if node:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) ) end
			return true

		end

	end

	self.setterNodeType = bpnodetype.New()
	self.setterNodeType:AddFlag( NTF_Compact )
	self.setterNodeType:AddFlag( NTF_Custom )
	self.setterNodeType:SetCodeType( NT_Function )
	self.setterNodeType:SetCode("")
	self.setterNodeType.GetDisplayName = function() return "Set" .. self:GetName() end
	self.setterNodeType.GetRawPins = function() return { MakePin( PD_In, "value", self.pintype ), MakePin( PD_Out, "value", self.pintype ) } end
	self.setterNodeType.Compile = function(node, compiler, pass)

		local varName = "__self.__" .. self:GetName()
		if compiler.compactVars then varName = "__self.__" .. self.id end

		if pass == bpcompiler.CP_ALLOCVARS then 

			compiler:CreatePinRouter( node:FindPin(PD_Out, "value"), function(pin)
				return { var = varName }
			end )
			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			compiler.emit( varName .. " = " .. compiler:GetPinCode( node:FindPin(PD_In, "value") ) )
			if node:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) ) end
			return true

		end

	end

	return self

end

function meta:GetName()

	return self.name

end

function meta:GetType()

	return self.pintype

end

function meta:SetType( type )

	self.module:PreModifyNodeType( self.getterNodeType )
	self.module:PreModifyNodeType( self.setterNodeType )
	self.pintype = type
	self.default = self.pintype:GetDefault()
	self.module:PostModifyNodeType( self.getterNodeType )
	self.module:PostModifyNodeType( self.setterNodeType )

end

function meta:CreatePin( dir, nameOverride )

	return MakePin(dir, self:GetName(), self.pintype)

end

function meta:GetterNodeType()

	return self.getterNodeType

end

function meta:SetterNodeType()

	return self.setterNodeType

end

function meta:WriteToStream(stream, mode, version)

	self.pintype:WriteToStream(stream, mode, version)
	bpdata.WriteValue( self.default, stream )
	bpdata.WriteValue( self.repmode, stream )

end

-- v1 -> v2 the schema typelist changed
local typeRemap = {
	[10] = PN_String,
	[11] = PN_Color,
	[13] = PN_Angles,
	[14] = PN_Enum,
	[15] = PN_Ref,
	[16] = PN_Struct,
	[17] = PN_Func,
}

function meta:ReadFromStream(stream, mode, version)

	self.pintype = bppintype.New():ReadFromStream(stream, mode, version)
	self.default = bpdata.ReadValue( stream )
	self.repmode = bpdata.ReadValue( stream )
	self.default = self.pintype:GetDefault()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end