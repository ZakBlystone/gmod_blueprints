AddCSLuaFile()

module("bpvariable", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpvariable")

function meta:Init(type, default, flags, ex, repmode)

	self.type = type or PN_Number
	self.default = bit.band(flags or 0, PNF_Table) ~= 0 and "{}" or (default or Defaults[self.type])
	self.flags = flags or PNF_None
	self.ex = ex
	self.repmode = repmode
	self.pintype = bppintype.New(self.type, self.flags, self.ex)
	return self

end

function meta:GetName()

	return self.name

end

function meta:GetFlags()

	return self.flags

end

function meta:GetType()

	return self.type

end

function meta:GetDefaultValue()

	return self.default

end

function meta:GetExtended()

	return self.ex

end

function meta:CreatePin( dir, nameOverride )

	return MakePin(dir, self:GetName(), self.pintype)

end

function meta:GetterNodeType()

	local ntype = bpnodetype.New()
	ntype:AddFlag( NTF_Compact )
	ntype:AddFlag( NTF_Custom )
	ntype:AddPin( MakePin(PD_Out, "value", self.pintype) )
	ntype:SetCodeType( NT_Pure )
	ntype:SetDisplayName( "Get" .. self:GetName() )
	ntype:SetCode("")
	ntype.Compile = function(node, compiler, pass)

		if pass == bpcompiler.CP_PREPASS then

			compiler:CreatePinRouter( node:FindPin(PD_Out, "value"), function(pin)
				return { var = "__self.__" .. self:GetName() }
			end )
			return true

		elseif pass == bpcompiler.CP_ALLOCVARS then return true
		elseif pass == bpcompiler.CP_MAINPASS then

			if node:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) ) end
			return true

		end

	end
	return ntype

end

function meta:SetterNodeType()

	local ntype = bpnodetype.New()
	ntype:AddFlag( NTF_Compact )
	ntype:AddFlag( NTF_Custom )
	ntype:AddPin( MakePin(PD_In, "value", self.pintype) )
	ntype:AddPin( MakePin(PD_Out, "value", self.pintype) )
	ntype:SetCodeType( NT_Function )
	--ntype:SetCode( "__self.__" .. self:GetName() .. " = $1 #1 = $1" )
	ntype:SetDisplayName( "Set" .. self:GetName() )
	ntype:SetCode("")
	ntype.Compile = function(node, compiler, pass)

		local varName = "__self.__" .. self:GetName()
		if pass == bpcompiler.CP_PREPASS then

			compiler:CreatePinRouter( node:FindPin(PD_Out, "value"), function(pin)
				return { var = varName }
			end )
			return true

		elseif pass == bpcompiler.CP_ALLOCVARS then return true
		elseif pass == bpcompiler.CP_MAINPASS then

			compiler.emit( varName .. " = " .. compiler:GetPinCode( node:FindPin(PD_In, "value") ) )
			if node:GetCodeType() == NT_Function then compiler.emit( compiler:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) ) end
			return true

		end

	end
	return ntype

end

function meta:WriteToStream(stream, mode, version)

	stream:WriteInt( self.type )
	stream:WriteInt( self.flags )
	bpdata.WriteValue( self.default, stream )
	bpdata.WriteValue( self.name, stream )
	bpdata.WriteValue( self.ex, stream )
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

	self.type = stream:ReadInt( false )
	self.flags = stream:ReadInt( false )
	self.default = bpdata.ReadValue( stream )
	self.name = bpdata.ReadValue( stream )
	self.ex = bpdata.ReadValue( stream )
	self.repmode = bpdata.ReadValue( stream )
	self.pintype = bppintype.New(self.type, self.flags, self.ex)

	if version == 1 then self.type = typeRemap[self.type] or self.type end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end