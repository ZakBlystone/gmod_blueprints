AddCSLuaFile()

module("bpobjectlinker", package.seeall)

local meta = bpcommon.MetaTable("bpobjectlinker")

function meta:Init()

	self.objects = {}
	self.nextSetID = 0
	return self

end

function meta:Serialize(stream)

end

function meta:Construct(hash)

	local meta = bpcommon.GetMetaTableFromHash(hash)
	if meta == nil then error("Unable to find metatable for hash: " .. hash) end
	return bpcommon.MakeInstance(meta)

end

function meta:GetSetForHash(hash)

	local t = self.objects[hash]
	if not t then
		self.objects[hash] = {next = 1, id = self.nextSetID, objects = {}}
		self.nextSetID = self.nextSetID + 1
		if self.nextSetID >= 256 then error("Max object hash set exceeded!!!") end
		t = self.objects[hash]
	end
	return t

end

--[[function meta:RecordObject(obj)

	if obj == nil then return end
	if not type(obj) == "table" then error("Tried to record non-table object") end
	if obj.__hash == nil then error("Object is not a metatype") end

	local set = self:GetSetForHash( obj.__hash )
	if not set[obj] then
		set.objects[obj] = set.next
		set.next = set.next + 1
	end

end]]

function meta:WriteObject(stream, obj)

	if obj == nil then stream:UInt(0) return obj end
	if not type(obj) == "table" then error("Tried to write non-table object") end
	local meta = getmetatable(obj)
	if meta == nil or meta.__hash == nil then error("Object is not a metatype") end

	assert(bpcommon.GetMetaTableFromHash(meta.__hash), "Issue with metatable hashes")

	local set = self:GetSetForHash( meta.__hash )
	if obj == nil then
		stream:UByte(0)
		stream:Bits(0,24)
		return
	end

	local hash = obj
	local hashed = false

	if obj.GetHash then hash = obj:GetHash() hashed = true end

	local existing = set.objects[hash]
	if not hashed and not existing and meta.__eq then
		for k, v in pairs(set.objects) do
			if meta.__eq(obj, k) then existing = v end
		end
	end

	if existing then
		stream:UByte(set.id)
		stream:Bits(existing,24)
	else
		set.objects[hash] = set.next
		stream:UByte(set.id)
		stream:Bits(set.next, 24)
		stream:UInt(meta.__hash)
		obj:Serialize(stream)
		set.next = set.next + 1
	end

end

function meta:ReadObject(stream)

	local setID = stream:UByte()
	local objID = stream:Bits(nil, 24)

	if objID == 0 then return nil end

	self.objects[setID] = self.objects[setID] or {}
	local set = self.objects[setID]
	if not set[objID] then
		local hash = stream:UInt()
		local obj = self:Construct(hash)
		obj:Serialize(stream)
		set[objID] = obj
		return obj
	else
		return set[objID]
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end

--[[if CLIENT then

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	local pt = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt2 = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	stream:Object( pt )
	stream:Object( pt2 )
	local data = stream:Finish()

	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	local t = stream:Object()
	local t = stream:Object()
	print(tostring(t))

end]]