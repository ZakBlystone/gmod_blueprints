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
			self.diff[#self.diff+1] = { act = ELEMENT_ADDED, id = copy.id, item = copy, name = item.name }
			copy.id = nil

		end

	end

	for id, item in old:Items() do

		local entry = new:Get(id)
		if entry == nil then

			self.diff[#self.diff+1] = { act = ELEMENT_REMOVED, id = item.id }

		elseif entry ~= item then

			self.diff[#self.diff+1] = { act = ELEMENT_MODIFIED, id = id, item = entry }

		end

	end

	return self

end

function meta:Constructor( func )

	self.constructor = func
	return self

end

function meta:IsEmpty()

	return #self.diff == 0

end

function meta:Patch(list)

	for k,v in ipairs(self.diff) do

		local act = v.act
		if act == ELEMENT_REMOVED then list:Remove( v.id ) end
		if act == ELEMENT_ADDED then list:Add( table.Copy(v.item), v.name, v.id ) end
		if act == ELEMENT_MODIFIED then list:Replace( v.id, table.Copy(v.item) ) end

	end

end

function meta:WriteToStream(stream, mode, version)

	stream:WriteInt( #self.diff, false )
	for _, v in ipairs(self.diff) do

		local act = v.act

		stream:WriteBits( act, 8 )
		if act == ELEMENT_REMOVED then

			stream:WriteInt( v.id, false )

		elseif act == ELEMENT_ADDED then

			stream:WriteInt( v.id, false )
			v.item:WriteToStream( stream, mode, version )
			bpdata.WriteValue( v.name, stream )

		elseif act == ELEMENT_MODIFIED then

			stream:WriteInt( v.id, false )
			v.item:WriteToStream( stream, mode, version )

		end

	end

end

function meta:ReadFromStream(stream, mode, version)

	if not self.constructor then error("No constructor for list items") end

	self.diff = {}
	local n = stream:ReadInt( false )
	for i=1, n do

		local act = stream:ReadBits( 8 )
		if act == ELEMENT_REMOVED then

			local id = stream:ReadInt( false )
			self.diff[#self.diff+1] = { act = act, id = id }

		elseif act == ELEMENT_ADDED then

			local id = stream:ReadInt( false )
			local item = self.constructor()
			item:ReadFromStream( stream, mode, version )

			local name = bpdata.ReadValue( stream )
			self.diff[#self.diff+1] = { act = act, id = id, item = item, name = name }

		elseif act == ELEMENT_MODIFIED then

			local id = stream:ReadInt( false )
			local item = self.constructor()
			item:ReadFromStream( stream, mode, version )

			self.diff[#self.diff+1] = { act = act, id = id, item = item }

		end

	end

end

function meta:ToString()

	local str = "diff:"
	for _, v in ipairs(self.diff) do

		if v.act == ELEMENT_REMOVED then str = str .. "\n - " .. v.id end
		if v.act == ELEMENT_ADDED then str = str .. "\n + " .. v.id .. " [" .. tostring(v.name) .. "]" .. " : " .. tostring(v.item) end
		if v.act == ELEMENT_MODIFIED then str = str .. "\n : " .. v.id .. " : " .. tostring(v.item) end

	end

	return str

end

function New(...) return bpcommon.MakeInstance(meta, ...) end