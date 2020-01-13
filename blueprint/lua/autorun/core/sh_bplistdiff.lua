AddCSLuaFile()

module("bplistdiff", package.seeall)

ELEMENT_REMOVED = 1
ELEMENT_ADDED = 2
ELEMENT_MODIFIED = 3

local meta = bpcommon.MetaTable("bplistdiff")
meta.__index = meta

function meta:Init(old, new)

	self.diff = {}

	if old == nil or new == nil then return self end

	for id, item in new:Items() do

		local entry = old:Get(id)
		if entry == nil then

			local copy = table.Copy( item )
			table.insert(self.diff, { ELEMENT_ADDED, copy, copy.id })
			copy.id = nil

		end

	end

	for id, item in old:Items() do

		local entry = new:Get(id)
		if entry == nil then

			table.insert(self.diff, { ELEMENT_REMOVED, item.id })

		elseif entry ~= item then

			table.insert(self.diff, { ELEMENT_MODIFIED, entry })

		end

	end

	return self

end

function meta:IsEmpty()

	return #self.diff == 0

end

function meta:Patch(list)

	for k,v in ipairs(self.diff) do

		if v[1] == ELEMENT_REMOVED then list:Remove( v[2] ) end
		if v[1] == ELEMENT_ADDED then list:Add( v[2], v[2].name, v[3] ) end
		if v[1] == ELEMENT_MODIFIED then list:Replace( v[2].id, v[2] ) end

	end

end

function meta:WriteToStream(stream, mode, version)

	bpdata.WriteValue( stream, self.diff )

end

function meta:ReadFromStream(stream, mode, version)

	self.diff = bpdata.ReadValue( stream )

end

function New(...) return bpcommon.MakeInstance(meta, ...) end