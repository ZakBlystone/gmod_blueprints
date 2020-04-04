AddCSLuaFile()

module("bpobjectlinker", package.seeall)

local meta = bpcommon.MetaTable("bpobjectlinker")

function meta:Init()

	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end