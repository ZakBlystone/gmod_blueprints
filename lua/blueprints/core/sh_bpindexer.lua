AddCSLuaFile()

module("bpindexer", package.seeall)

local meta = bpcommon.MetaTable("bpindexer")
meta.__call = function(self, ...) return self:Get(...) end

function meta:Init()

	self.indices = {}
	self.next = 0
	return self

end

function meta:Get(v)

	local indices = self.indices
	local e = indices[v]
	if e then return e end
	indices[v] = self.next + 1
	self.next = self.next + 1
	return self.next

end

function New(...) return bpcommon.MakeInstance(meta, ...) end