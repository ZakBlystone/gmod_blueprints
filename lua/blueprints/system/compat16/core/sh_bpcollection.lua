AddCSLuaFile()

module("bpcollection", package.seeall)

local meta = bpcommon.MetaTable("bpcollection")
meta.__call = function(self, ...) return self:Get(...) end

function meta:Init()

	self.tables = {}
	self.blacklist = {}
	return self

end

function meta:Clear()

	self.tables = {}
	self.blacklist = {}

end

function meta:Find( name )

	if self.blacklist[name] then return nil end
	local t = self.tables
	for i=#t, 1, -1 do
		local entry = t[i]
		if entry[name] then return entry[name] end
	end

end

function meta:Blacklist( name )

	self.blacklist[name] = true

end

function meta:Items()

	local i = 1
	local k = nil
	local lst = self.tables
	local blst = self.blacklist
	local n = #lst
	return function()
		::iter::
		if i > n then return end
		k, v = next(lst[i], k)
		while blst[k] do k, v = next(lst[i], k) end
		if k == nil then i = i + 1 goto iter end
		return k, v
	end

end

function meta:Add( tab )

	self.tables[#self.tables+1] = tab
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end