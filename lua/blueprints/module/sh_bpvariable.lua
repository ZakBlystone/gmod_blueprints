AddCSLuaFile()

module("bpvariable", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpvariable")

function meta:Init(type, repmode)

	if type then
		self.pintype = type:WithOuter( self )
		self.pintemplate = MakePin( PD_Out, "value", self.pintype )
		self.pintemplate:InitPinClass()
	end

	self.repmode = repmode or REP_None

	self.getterNodeType = bpnodetype.New():WithOuter( self )
	self.getterNodeType:AddFlag( NTF_Compact )
	self.getterNodeType:AddFlag( NTF_Custom )
	self.getterNodeType:SetCodeType( NT_Pure )
	self.getterNodeType:SetCode("")
	self.getterNodeType.GetDisplayName = function() return "Get" .. self:GetName() end
	self.getterNodeType.GetRawPins = function() return { MakePin( PD_Out, "value", self.pintype ) } end
	self.getterNodeType.Compile = function(node, compiler, pass)

		if pass == bpcompiler.CP_ALLOCVARS then 

			compiler:CreatePinRouter( node:FindPin(PD_Out, "value"), function(pin)
				return { var = self:GetAlias( compiler, true ) }
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

		if pass == bpcompiler.CP_ALLOCVARS then 

			compiler:CreatePinRouter( node:FindPin(PD_Out, "value"), function(pin)
				return { var = self:GetAlias( compiler, true ) }
			end )
			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			compiler.emit( self:GetAlias( compiler, true ) .. " = " .. compiler:GetPinCode( node:FindPin(PD_In, "value") ) )
			compiler:CompileReturnPin( node )
			return true

		end

	end

	return self

end

function meta:Destroy()

	self.getterNodeType:Destroy()
	self.setterNodeType:Destroy()

end

function meta:GetModule()

	return self:FindOuter( bpmodule_meta )

end


function meta:SetDefault( def )

	self.default = def

end

function meta:GetDefault()

	if self.default == "__emptyTable" then return "__emptyTable()" end
	return self.default or self.pintype:GetDefault()

end

function meta:GetName()

	return self.name

end

function meta:GetType()

	return self.pintype

end

function meta:SetType( type )

	print("SET TYPE TO: " .. tostring(type))

	local mod = self:GetModule()
	self.getterNodeType:PreModify()
	self.setterNodeType:PreModify()
	self.pintype = type:Copy(self)
	self.pintemplate = MakePin( PD_Out, "value", self.pintype )
	self.pintemplate:InitPinClass()
	self.default = self.pintype:GetDefault()
	self.getterNodeType:PostModify()
	self.setterNodeType:PostModify()

	print("AS: " .. tostring(self.pintype))

end

function meta:GetAlias( compiler, inGraph, noSelf )

	local name = self:GetName()
	if compiler.compactVars then name = tostring(compiler:GetID(self)) end
	local varName = "__" .. name
	if self:FindOuter( bpgraph_meta ) == nil then
		if not noSelf then varName = "self." .. varName end
		if inGraph then varName = "__" .. varName end
	end
	return varName

end

function meta:GetterNodeType()

	return self.getterNodeType

end

function meta:SetterNodeType()

	return self.setterNodeType

end

function meta:Serialize(stream)

	stream:Extern( self:GetterNodeType(), "\xE3\x09\x45\x7E\xCF\x3C\xFB\xB9\x80\x00\x00\x19\x52\x63\x95\xCA" )
	stream:Extern( self:SetterNodeType(), "\xE3\x09\x45\x7E\x9F\x38\x84\x65\x80\x00\x00\x1A\x52\x73\xBD\xDA" )

	self.pintype = stream:Object(self.pintype, self)
	self.default = stream:Value(self.default)
	self.repmode = stream:Value(self.repmode)

	if stream:IsReading() then
		self.repmode = self.repmode or REP_None

		self.pintemplate = MakePin( PD_Out, "value", self.pintype )
		self.pintemplate:InitPinClass()
	end

	return stream

end

function meta:BuildSendFunctor( compiler )

	local pin = MakePin( PD_Out, "value", self.pintype ):InitPinClass()
	local nthunk = pin.GetNetworkThunk and pin:GetNetworkThunk()
	print("NTHUNK: " .. tostring(pin))
	if not nthunk then return nil end

	if pin:HasFlag(PNF_Table) then
		return ("function(self) _wu(#_V, 24) for _,v in ipairs(_V) do " .. nthunk.write:gsub("@","_V") .. " end end"):gsub("_V", self:GetAlias(compiler, false))
	else
		return "function(self) " .. nthunk.write:gsub("@", self:GetAlias(compiler, false)) .. " end"
	end

end

function meta:BuildRecvFunctor( compiler )

	local pin = self.pintemplate
	local nthunk = pin.GetNetworkThunk and pin:GetNetworkThunk()
	if not nthunk then return nil end

	if pin:HasFlag(PNF_Table) then
		return "function() local t = {} for i=1, _ru(24) do t[#t+1] = " .. nthunk.read .. " end return t end"
	else
		return "function() return " .. nthunk.read .. " end"
	end

end

function meta:BuildCopyFunctor( compiler )

	local pin = self.pintemplate
	local nthunk = pin.GetNetworkThunk and pin:GetNetworkThunk()
	if not nthunk then return nil end

	if nthunk.copy then
		return "function(self) return " .. nthunk.copy:gsub("@", self:GetAlias(compiler, false)) .. " end"
	end

end

function meta:GetCompileDefault()

	local def = self:GetDefault()
	local vtype = self:GetType()

	if def == nil then
		if vtype:GetBaseType() == PN_String and bit.band(vtype:GetFlags(), PNF_Table) == 0 then def = "\"\"" end
		if vtype:GetBaseType() == PN_Asset and bit.band(vtype:GetFlags(), PNF_Table) == 0 then def = "\"\"" end
	end

	if type(def) == "string" then
		return tostring(def)
	else
		print("Emit variable as non-string")
		local pt = bpvaluetype.FromPinType( vtype, function() return def end, function(v) def = v end )
		if def and pt then return pt:ToString() end
	end

	return nil

end

function meta:SupportsReplication()

	local pin = self.pintemplate
	local vtype = self:GetType()
	local nthunk = pin.GetNetworkThunk and pin:GetNetworkThunk()
	if not nthunk then return false end
	if bit.band(vtype:GetFlags(), PNF_Table) ~= 0 then return false end
	return true

end

function meta:Compile( compiler )

	local def = self:GetCompileDefault()
	local vtype = self:GetType()
	local id = compiler:GetID(self)

	--print("COMPILE VARIABLE: " .. vtype:ToString(true) .. " type: " .. type(def))

	local varName = self:GetName()
	if compiler.compactVars then varName = id end
	if def ~= nil then
		compiler.emit(self:GetAlias(compiler, false) .. " = " .. tostring(def))
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end