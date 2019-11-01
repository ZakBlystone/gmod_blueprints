AddCSLuaFile()

module("bplist", package.seeall)

bpcommon.CallbackList({
	"ADD",
	"REMOVE",
	"CLEAR",
	"RENAME",
	"PREMODIFY",
	"POSTMODIFY",
})

MODIFY_ADD = 0
MODIFY_REMOVE = 1
MODIFY_RENAME = 2

local meta = {}
meta.__index = meta

function meta:Init(...)

	bpcommon.MakeObservable(self)
	return self:Clear()

end

function meta:NamedItems( prefix )

	self.namedItems = true
	self.namePrefix = (prefix or "Item") .. "_"
	return self

end

function meta:Constructor( func )

	self.constructor = func
	return self

end

function meta:Clear()

	self.items = {}
	self.itemLookup = {}
	self.nextID = 1
	self:FireListeners(CB_CLEAR)
	return self

end

function meta:Advance()
	self.nextID = self.nextID + 1
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

function meta:GetNameForItem( optName, item )

	optName = optName or item.name

	if self.preserveNames then return optName end
	local name = bpcommon.Sanitize(optName) 
	if name == nil then name = self.namePrefix .. item.id end
	return bpcommon.Camelize(name)

end

function meta:CopyInto( other, deep )

	other.items = {}
	other.itemLookup = {}

	if deep then

		other.items = table.Copy( self.items )
		other.itemLookup = table.Copy( self.itemLookup )

	else

		for id, item in self:Items() do
			table.insert( other.items, item )
			other.itemLookup[id] = item
		end

	end

	other.nextID = self.nextID

end

function meta:PreserveNames(preserve)

	self.preserveNames = preserve

end

function meta:Construct( ... )

	return self:ConstructNamed(nil, ...)

end

function meta:ConstructNamed( name, ... )

	if not self.constructor then error("Item type does not have constructor") end
	local item = self.constructor(...)
	return self:Add(item, name)

end

function meta:Add( item, optName )

	if item.id ~= nil then error("Cannot add uniquely indexed items to multiple lists") end
	item.id = self:NextIndex()

	if self.namedItems then
		item.name = self:GetNameForItem( optName, item )
	end

	self:FireListeners(CB_PREMODIFY, MODIFY_ADD, item.id, item)

	table.insert( self.items, item )
	self.itemLookup[item.id] = item
	self:Advance()

	if item.PostInit then item:PostInit() end

	self:FireListeners(CB_ADD, item.id, item)
	self:FireListeners(CB_POSTMODIFY, MODIFY_ADD, item.id, item)

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

			self:FireListeners(CB_PREMODIFY, MODIFY_REMOVE, item.id, item)

			table.remove( items, i ) 
			self:FireListeners(CB_REMOVE, item.id, item)
			self:FireListeners(CB_POSTMODIFY, MODIFY_REMOVE, item.id, item)
			self.itemLookup[item.id] = nil
			item.id = nil
			removed = removed + 1

		end

	end

	return removed

end

function meta:Rename( id, newName )

	local item = self:Get(id)
	if item == nil then return false end

	self:FireListeners(CB_PREMODIFY, MODIFY_RENAME, item.id, item)

	local prev = item.name
	item.name = self:GetNameForItem( newName, item )
	self:FireListeners(CB_RENAME, item.id, prev, item.name)
	self:FireListeners(CB_POSTMODIFY, MODIFY_RENAME, item.id, item)

end

function meta:WriteToStream(stream, mode, version)

	if not self.constructor then error("No constructor for list items") end

	stream:WriteBool(self.namedItems)
	stream:WriteInt(self.nextID, false)
	stream:WriteInt(self:Size(), false)
	for k,v in pairs(self.items) do
		stream:WriteInt(v.id, false)
		if self.namedItems then bpdata.WriteValue( v.name, stream ) end
		if not v.WriteToStream then error("Need stream implementation for list item") end
		v:WriteToStream(stream, mode, version)
	end

end

function meta:ReadFromStream(stream, mode, version)

	if not self.constructor then error("No constructor for list items") end

	self:Clear()
	self.namedItems = stream:ReadBool()
	self.nextID = stream:ReadInt(false)
	local count = stream:ReadInt(false)
	if count > 5000 then error("MAX LIST COUNT EXCEEDED!!!!") end
	for i=1, count do
		local item = self.constructor()
		item.id = stream:ReadInt(false)
		if item.PostInit then item:PostInit() end
		self.itemLookup[item.id] = item
		if self.namedItems then item.name = bpdata.ReadValue( stream ) end
		if not item.ReadFromStream then error("Need stream implementation for list item") end
		item:ReadFromStream(stream, mode, version)
		self:FireListeners(CB_PREMODIFY, MODIFY_ADD, item.id, item)
		table.insert(self.items, item)
		self:FireListeners(CB_ADD, item.id, item)
		self:FireListeners(CB_POSTMODIFY, MODIFY_ADD, item.id, item)
	end

end

function meta:Get( id )

	return self.itemLookup[id]

end

function meta:GetTable()

	return self.items

end

function New()

	return setmetatable({}, meta):Init()

end