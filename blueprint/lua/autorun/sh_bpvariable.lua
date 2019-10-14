AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")

module("bpvariable", package.seeall, bpcommon.rescope(bpschema))

local meta = {}
meta.__index = meta

function meta:Init(type, default, flags)

	self.type = type or PN_Number
	self.default = bit.band(flags, PNF_Table) and "{}" or (default or Defaults[var.type])
	self.flags = flags or 0
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

function meta:GetterNodeType()

	return PURE {
		pins = {
			{PD_Out, self:GetType(), "value", self:GetFlags()},
		},
		code = "#1 = __self.__" .. self:GetName(),
		compact = true,
		custom = true,
	}

end

function meta:SetterNodeType()

	return FUNCTION {
		pins = {
			{PD_In, self:GetType(), "value", self:GetFlags()},
			{PD_Out, self:GetType(), "value", self:GetFlags()},
		},
		code = "__self.__" .. self:GetName() .. " = $2 #2 = $2",
		compact = true,
		custom = true,
	}

end

function New(...)

	return setmetatable({}, meta):Init(...)

end