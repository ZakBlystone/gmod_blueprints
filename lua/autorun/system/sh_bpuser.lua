AddCSLuaFile()

module("bpuser", package.seeall)

local meta = bpcommon.MetaTable("bpuser")

function meta:Init()

	return self

end

function meta:WriteToStream(stream, mode, version)

end

function meta:ReadFromStream(stream, mode, version)

end

function New(...) return bpcommon.MakeInstance(meta, ...) end