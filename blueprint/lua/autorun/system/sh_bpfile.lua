AddCSLuaFile()

module("bpfile", package.seeall)

function Sanitizer( str )

	return str

end

local meta = bpcommon.MetaTable("bpfile")

function meta:Init()

	return self

end

function meta:GetName()

	return self.name or ""

end

function meta:WriteToStream(stream, mode, version)

end

function meta:ReadFromStream(stream, mode, version)

end

function New(...) return bpcommon.MakeInstance(meta, ...) end