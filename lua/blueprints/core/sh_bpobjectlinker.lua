AddCSLuaFile()

module("bpobjectlinker", package.seeall)

local meta = bpcommon.MetaTable("bpobjectlinker")

function meta:Init()

	self.objects = {}
	self.nextSetID = 0
	return self

end

function meta:Serialize(stream)

	if stream:IsReading() then

		local numSets = stream:UByte()
		for i=1, numSets do

			local setID = stream:UByte()
			local hash = stream:UInt()
			local numObjects = stream:Bits(nil, 24)
			self.objects[setID] = {}

			for j=1, numObjects do
				local obj = self:Construct(hash)
				obj:Serialize(stream)
				self.objects[setID][j] = obj
			end

		end

	end

	if stream:IsWriting() then

		local numSets = 0
		for hash, set in pairs(self.objects) do
			numSets = numSets + 1
		end
		stream:UByte(numSets)

		for hash, set in pairs(self.objects) do

			stream:UByte(set.id)
			stream:UInt(hash)

			local numObjects = 0
			for obj, id in pairs(set) do
				numObjects = numObjects + 1
			end
			stream:Bits(numObjects, 24)

			for obj, id in pairs(set) do
				obj:Serialize(stream)
			end

		end
		return

	end

end

function meta:Construct(hash)

	local meta = bpcommon.GetMetaTableFromHash(hash)
	if meta == nil then error("Unable to find metatable for hash: " .. hash) end
	return bpcommon.MakeInstance(meta)

end

function meta:GetSetForHash(hash)

	local t = self.objects[hash]
	if not t then
		self.objects[hash] = {next = 0, id = self.nextSetID}
		self.nextSetID = self.nextSetID + 1
		if self.nextSetID >= 256 then error("Max object hash set exceeded!!!") end
		t = self.objects[hash]
	end
	return t

end

function meta:RecordObject(obj)

	if obj == nil then return end
	if not type(obj) == "table" then error("Tried to record non-table object") end
	if obj.__hash == nil then error("Object is not a metatype") end

	local set = self:GetSetForHash( obj.__hash )
	if not set[obj] then
		set[obj] = set.next
		set.next = set.next + 1
	end

end

function meta:WriteObject(stream, obj)

	if obj == nil then stream:UInt(0) return obj end
	if not type(obj) == "table" then error("Tried to write non-table object") end
	if obj.__hash == nil then error("Object is not a metatype") end

	local set = self:GetSetForHash( obj.__hash )
	if set[obj] then
		stream:UByte(set.id)
		stream:Bits(set[obj],24)
	else
		set[obj] = set.next
		stream:UByte(set.id)
		stream:Bits(set.next, 24)
		set.next = set.next + 1
	end

end

function meta:ReadObject(stream)

	local setID = stream:UByte()
	local objID = stream:Bits(nil, 24)

	local set = self.objects[setID]
	if not set then error("No set for object class: " .. setID) end
	return set[objID]

end

function New(...) return bpcommon.MakeInstance(meta, ...) end