AddCSLuaFile()

module("bplist", package.seeall)

MODIFY_ADD = 0
MODIFY_REMOVE = 1
MODIFY_RENAME = 2
MODIFY_REPLACE = 3

local meta = bpcommon.MetaTable("bplist")
meta.__index = meta

function meta:Init( meta )

	self.itemMeta = meta
	self.indexed = true
	bpcommon.MakeObservable(self)
	return self:Clear()

end

function meta:Destroy()

	for _, item in self:Items() do
		if item.Destroy then item:Destroy() end
	end

end

function meta:GetItemMeta()

	return self.itemMeta

end

function meta:NamedItems( prefix )

	self.namedItems = true
	self.namePrefix = (prefix or "Item")
	return self

end

function meta:Indexed( bIndexed )

	self.indexed = bIndexed
	return self

end

function meta:Clear()

	self.items = {}
	self:Broadcast("cleared")
	return self

end

function meta:Items( reverse )

	local items = self.items

	if reverse then
		local i = #items + 1
		return function() 
			i = i - 1
			if i > 0 then return i, items[i] end
		end
	else
		local i, n = 0, #items
		return function()
			if #items ~= n then error("Concurrent modification of list!") end
			i = i + 1
			if i <= n then return i, items[i] end
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
		if name == nil then name = self.namePrefix end
		name = bpcommon.Camelize(name)
	end

	local namesTaken = {}
	for _, item in self:Items() do namesTaken[item:GetName()] = true end
	return bpcommon.CreateUniqueKey(namesTaken, name)

end

function meta:MoveInto( other )

	other:Clear()

	for id, item in self:Items() do
		item:WithOuter( other )
		other.items[#other.items+1] = item
	end

	self:Clear()

end

function meta:CopyInto( other )

	other.items = {}

	for id, item in self:Items() do
		local copy = item.Copy and item:Copy() or bpcommon.CopyTable( item )
		copy:WithOuter( other )
		other.items[#other.items+1] = copy
	end

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

	if self.namedItems then
		item.name = self:GetNameForItem( optName, item )
	end

	local i = #self.items+1

	item:WithOuter( self )

	self:Broadcast("preModify", MODIFY_ADD, i, item)

	self.items[i] = item

	self:Broadcast("added", i, item)
	self:Broadcast("postModify", MODIFY_ADD, i, item)

	return i, item

end

function meta:Remove( item )

	return self:RemoveIf( function(x) return x == item end )

end

function meta:RemoveIf( cond )

	local removed = 0
	local items = self.items
	for i=#items, 1, -1 do

		local item = items[i]
		if cond( item ) then

			self:Broadcast("preModify", MODIFY_REMOVE, i, item)

			table.remove( items, i ) 
			self:Broadcast("removed", i, item)
			self:Broadcast("postModify", MODIFY_REMOVE, i, item)
			removed = removed + 1

		end

	end

	return removed

end

function meta:Rename( item, newName, force )

	if item == nil then return false end
	if not force and (item.CanRename and not item:CanRename()) then return false end

	if newName == item.name then return false end
	local i = self:FindIndex( item )

	self:Broadcast("preModify", MODIFY_RENAME, i, item)

	local prev = item.name
	item.name = self:GetNameForItem( newName, item )
	self:Broadcast("renamed", i, item, prev, item.name)
	self:Broadcast("postModify", MODIFY_RENAME, i, item)

end

function meta:Serialize(stream)

	if stream:IsReading() then self:Clear() end

	self.namedItems = stream:Bool(self.namedItems)
	if self.indexed and stream:GetVersion() < 4 then stream:UInt(0) end --Compat, remove soon
	local count = stream:UInt(self:Size())
	if count > 5000 then error("MAX LIST COUNT EXCEEDED!!!!") end
	local goodNextID = 0
	for i=1, count do

		self.items[i] = stream:Object(self.items[i], self)
		local item = self.items[i]
		if self.indexed and stream:GetVersion() < 4 then stream:UInt(0) end --Compat, remove soon
		if self.namedItems then item.name = stream:String(item.name) end

		if stream:IsReading() then

			self:Broadcast("preModify", MODIFY_ADD, i, item)
			self.items[i] = item
			self:Broadcast("added", i, item)
			self:Broadcast("postModify", MODIFY_ADD, i, item)

		end

	end

	return stream

end

function meta:FindIndex( item )

	for i, found in self:Items() do
		if rawequal(found, item) then return i end
	end
	return -1

end

function meta:Get( i )

	return self.items[i]

end

function meta:GetTable()

	return self.items

end

function meta:ToString(name)

	local str = (name or "list") .. ":"
	for id, item in self:Items() do
		--str = str .. "\n [" .. id .. "] = " .. tostring(item)
	end
	return str

end

function New(...) return bpcommon.MakeInstance(meta, ...) end