AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")

module("bpvariable", package.seeall, bpcommon.rescope(bpschema))

local meta = {}
meta.__index = meta

function meta:Init(type, default, flags, ex, repmode)

	self.type = type or PN_Number
	self.default = bit.band(flags or 0, PNF_Table) ~= 0 and "{}" or (default or Defaults[self.type])
	self.flags = flags or 0
	self.ex = ex
	self.repmode = repmode
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

	return {dir, self:GetType(), self:GetName(), self:GetFlags(), self:GetExtended()}

end

function meta:GetterNodeType()

	return PURE {
		pins = {
			{PD_Out, self:GetType(), "value", self:GetFlags(), self:GetExtended()},
		},
		code = "#1 = __self.__" .. self:GetName(),
		compact = true,
		custom = true,
		displayName = "Get" .. self:GetName(),
	}

end

function meta:SetterNodeType()

	return FUNCTION {
		pins = {
			{PD_In, self:GetType(), "value", self:GetFlags(), self:GetExtended()},
			{PD_Out, self:GetType(), "value", self:GetFlags(), self:GetExtended()},
		},
		code = "__self.__" .. self:GetName() .. " = $2 #2 = $2",
		compact = true,
		custom = true,
		displayName = "Set" .. self:GetName(),
	}

end

function meta:WriteToStream(stream, mode, version)

	stream:WriteInt( self.type )
	stream:WriteInt( self.flags )
	bpdata.WriteValue( self.default, stream )
	bpdata.WriteValue( self.name, stream )
	bpdata.WriteValue( self.ex, stream )
	bpdata.WriteValue( self.repmode, stream )

end

function meta:ReadFromStream(stream, mode, version)

	self.type = stream:ReadInt( false )
	self.flags = stream:ReadInt( false )
	self.default = bpdata.ReadValue( stream )
	self.name = bpdata.ReadValue( stream )
	self.ex = bpdata.ReadValue( stream )
	self.repmode = bpdata.ReadValue( stream )

end

function New(...)

	return setmetatable({}, meta):Init(...)

end