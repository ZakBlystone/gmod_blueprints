AddCSLuaFile()

module("bplist", package.seeall)

MODIFY_ADD = 0
MODIFY_REMOVE = 1
MODIFY_RENAME = 2
MODIFY_REPLACE = 3

local meta = bpcommon.MetaTable("bplist")
meta.__tostring = function(self) return self:ToString() end
meta.__index = meta

function meta:Init( meta )

	self.itemMeta = meta
	self.indexed = true
	bpcommon.MakeObservable(self)
	return self:Clear()

end

function meta:GetItemMeta()

	return self.itemMeta

end

function meta:NamedItems( prefix )

	self.namedItems = true
	self.namePrefix = (prefix or "Item") .. "_"
	return self

end

function meta:Indexed( bIndexed )

	self.indexed = bIndexed
	return self

end

function meta:Clear()

	self.items = {}
	self.itemLookup = {}
	self.nextID = 1
	self:Broadcast("cleared")
	return self

end

function meta:Advance(forceIndex)
	self.nextID = (forceIndex or self.nextID) + 1
end

function meta:NextIndex()
	return self.nextID
end

function meta:Items( reverse )

	local items = self.items

	if reverse then
		local i = #items + 1
		return function() 
			i = i - 1
			if i > 0 then return items[i].id, items[i] end
		end
	else
		local i, n = 0, #items
		return function()
			if #items ~= n then error("Concurrent modification of list!") end
			i = i + 1
			if i <= n then return items[i].id, items[i] end
		end
	end

end

function meta:ItemIDs( reverse )

	local items = self.items

	if reverse then
		local i = #items + 1
		return function() 
			i = i - 1
			if i > 0 then return items[i].id end
		end
	else
		local i, n = 0, #items
		return function() 
			if #items ~= n then error("Concurrent modification of list!") end
			i = i + 1
			if i <= n then return items[i].id end
		end
	end

end

function meta:Size()

	return #self.items

end

function meta:SetSanitizer( func )

	self.sanitizer = func
	return self

end

function meta:GetNameForItem( name, item )

	name = name or item.name

	if self.preserveNames then return name end

	if self.sanitizer then
		name = self.sanitizer(name)
	else
		name = bpcommon.Sanitize(name)
		if name == nil then name = self.namePrefix .. item.id end
		name = bpcommon.Camelize(name)
	end

	local namesTaken = {}
	for _, item in self:Items() do namesTaken[item:GetName()] = true end
	return bpcommon.CreateUniqueKey(namesTaken, name)

end

function meta:MoveInto( other )

	other:Clear()

	local nextID = 0
	for id, item in self:Items() do
		item:WithOuter( other )
		other.items[#other.items+1] = item
		other.itemLookup[id] = item
		nextID = math.max(id+1, nextID)
	end

	other.nextID = nextID
	self:Clear()

end

function meta:CopyInto( other )

	other.items = {}
	other.itemLookup = {}

	for id, item in self:Items() do
		local copy = item.Copy and item:Copy() or bpcommon.CopyTable( item )
		copy:WithOuter( other )
		copy.id = item.id
		other.items[#other.items+1] = copy
		other.itemLookup[id] = copy
	end

	other.nextID = self.nextID
	return other

end

function meta:PreserveNames(preserve)

	self.preserveNames = preserve
	return self

end

function meta:ConstructObject( ... )

	local obj = bpcommon.MakeInstance( self.itemMeta, ... ):WithOuter( self )
	return obj

end

function meta:Construct( ... )

	return self:ConstructNamed(nil, ...)

end

function meta:ConstructNamed( name, ... )

	local item = self:ConstructObject( ... )
	return self:Add(item, name)

end

function meta:Add( item, optName, forceIndex )

	if item.id ~= nil then error("Cannot add uniquely indexed items to multiple lists") end
	item.id = forceIndex or self:NextIndex()

	if self.namedItems then
		item.name = self:GetNameForItem( optName, item )
	end

	item:WithOuter( self )

	self:Broadcast("preModify", MODIFY_ADD, item.id, item)

	self.items[#self.items+1] = item
	self.itemLookup[item.id] = item
	self:Advance(forceIndex)

	if item.PostInit then item:PostInit() end

	self:Broadcast("added", item.id, item)
	self:Broadcast("postModify", MODIFY_ADD, item.id, item)

	return item.id, item

end

function meta:Remove( id )

	return self:RemoveIf( function(x) return x.id == id end )

end

function meta:RemoveIf( cond )

	local removed = 0
	local items = self.items
	for i=#items, 1, -1 do

		local item = items[i]
		if cond( item ) then

			self:Broadcast("preModify", MODIFY_REMOVE, item.id, item)

			table.remove( items, i ) 
			self:Broadcast("removed", item.id, item)
			self:Broadcast("postModify", MODIFY_REMOVE, item.id, item)
			self.itemLookup[item.id] = nil
			item.id = nil
			removed = removed + 1

		end

	end

	return removed

end

function meta:Rename( id, newName, force )

	local item = self:Get(id)
	if item == nil then return false end
	if not force and (item.CanRename and not item:CanRename()) then return false end

	if newName == item.name then return false end

	self:Broadcast("preModify", MODIFY_RENAME, item.id, item)

	local prev = item.name
	item.name = self:GetNameForItem( newName, item )
	self:Broadcast("renamed", item.id, prev, item.name)
	self:Broadcast("postModify", MODIFY_RENAME, item.id, item)

end

function meta:Replace( id, item )

	local oldItem, oldItemIdx = nil, nil
	for i, exist in ipairs(self.items) do
		if exist.id == id then
			oldItem = exist
			oldItemIdx = i
			break
		end
	end

	if not oldItem then error("Attempt to replace invalid index: " .. id .. " " .. tostring(oldItemIdx)) end

	self:Broadcast("preModify", MODIFY_REPLACE, item.id, item)
	self.itemLookup[id] = item
	self.items[oldItemIdx] = item
	self:Broadcast("postModify", MODIFY_REPLACE, item.id, item)

end

function meta:Serialize(stream)

	if stream:IsReading() then self:Clear() end

	self.namedItems = stream:Bool(self.namedItems)
	if self.indexed then self.nextID = stream:UInt(self.nextID) end
	local count = stream:UInt(self:Size())
	--print("List serialize " .. count .. " items")
	for i=1, count do

		local item = self.items[i] or self:ConstructObject()
		if self.indexed then item.id = stream:UInt(item.id) end
		if self.namedItems then item.name = stream:Value(item.name) end
		stream:Object(item, true)

		if stream:IsReading() then

			if item.PostInit then item:PostInit() end
			if self.indexed then self.itemLookup[item.id] = item end
			self:Broadcast("preModify", MODIFY_ADD, item.id, item)
			self.items[i] = item
			self:Broadcast("added", item.id, item)
			self:Broadcast("postModify", MODIFY_ADD, item.id, item)

		end

	end

	return stream

end

function meta:WriteToStream(stream, mode, version) -- deprecate

	stream:WriteBool(self.namedItems)
	if self.indexed then stream:WriteInt(self.nextID, false) end
	stream:WriteInt(self:Size(), false)
	for _,v in ipairs(self.items) do
		if self.indexed then stream:WriteInt(v.id, false) end
		if self.namedItems then bpdata.WriteValue( v.name, stream ) end
		if not v.WriteToStream then error("Need stream implementation for list item") end
		v:WriteToStream(stream, mode, version)
	end

end

function meta:ReadFromStream(stream, mode, version) -- deprecate

	bpcommon.Profile("list-read", function()

		self:Clear()
		self.namedItems = stream:ReadBool()
		if self.indexed then self.nextID = stream:ReadInt(false) end
		local count = stream:ReadInt(false)
		if count > 5000 then error("MAX LIST COUNT EXCEEDED!!!!") end
		for i=1, count do
			local item = self:ConstructObject()
			item.id = self.indexed and stream:ReadInt(false) or i
			if item.PostInit then item:PostInit() end
			self.itemLookup[item.id] = item
			if self.namedItems then item.name = bpdata.ReadValue( stream ) end
			if not item.ReadFromStream then error("Need stream implementation for list item") end
			item:ReadFromStream(stream, mode, version)
			self:Broadcast("preModify", MODIFY_ADD, item.id, item)
			self.items[#self.items+1] = item
			self:Broadcast("added", item.id, item)
			self:Broadcast("postModify", MODIFY_ADD, item.id, item)
		end

	end)

	return self

end

function meta:Get( id )

	return self.itemLookup[id]

end

function meta:GetTable()

	return self.items

end

function meta:ToString(name)

	local str = (name or "list") .. ":"
	for id, item in self:Items() do
		str = str .. "\n [" .. id .. "] = " .. tostring(item)
	end
	return str

end

function New(...) return bpcommon.MakeInstance(meta, ...) end