AddCSLuaFile()

module("bpvariable", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpvariable")

function meta:Init(type, repmode)

	if type then
		self.pintype = type:WithOuter( self )
	end

	self.repmode = repmode

	self.getterNodeType = bpnodetype.New():WithOuter( self )
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

			compiler:CompileReturnPin( node )
			return true

		end

	end

	self.setterNodeType = bpnodetype.New():WithOuter( self )
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
			compiler:CompileReturnPin( node )
			return true

		end

	end

	return self

end

function meta:GetModule()

	return self:FindOuter( bpmodule_meta )

end


function meta:SetDefault( def )

	self.default = def

end

function meta:GetDefault()

	return self.default or self.pintype:GetDefault()

end

function meta:GetName()

	return self.name

end

function meta:GetType()

	return self.pintype

end

function meta:SetType( type )

	local mod = self:GetModule()
	mod:PreModifyNodeType( self.getterNodeType )
	mod:PreModifyNodeType( self.setterNodeType )
	self.pintype = type:Copy():WithOuter(self)
	self.default = self.pintype:GetDefault()
	mod:PostModifyNodeType( self.getterNodeType )
	mod:PostModifyNodeType( self.setterNodeType )

end

function meta:GetterNodeType()

	return self.getterNodeType

end

function meta:SetterNodeType()

	return self.setterNodeType

end

function meta:Serialize(stream)

	stream:Extern( self:GetterNodeType() )
	stream:Extern( self:SetterNodeType() )

	self.pintype = stream:Object(self.pintype or bppintype.New():WithOuter(self), true)
	self.default = stream:Value(self.default)
	self.repmode = stream:Value(self.repmode)

	return stream

end

function New(...) return bpcommon.MakeInstance(meta, ...) end