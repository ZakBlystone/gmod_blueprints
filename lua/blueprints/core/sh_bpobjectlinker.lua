AddCSLuaFile()

module("bpobjectlinker", package.seeall)

local meta = bpcommon.MetaTable("bpobjectlinker")

function meta:Init()

	self.objects = {}
	self.nextSetID = 0
	self.order = {}
	self.hashes = {}
	self.orderNum = 1
	self.hashNum = 1
	return self

end

function meta:Serialize(stream)

	local orderCount = stream:UInt(#self.order)
	local hashCount = stream:UInt(#self.hashes)

	--print("Serialize: " .. orderCount .. " orders")
	--print("Serialize: " .. hashCount .. " hashes")

	for i=1, orderCount do
		self.order[i] = self.order[i] or {}
		self.order[i][1] = stream:Length(self.order[i][1])
		self.order[i][2] = stream:Bits(self.order[i][2], 24)
	end

	for i=1, hashCount do
		self.hashes[i] = stream:UInt(self.hashes[i])
	end

	return stream

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
		self.order[#self.order+1] = {0, 0}
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
		self.order[#self.order+1] = {set.id, existing}
	else
		set.objects[hash] = set.next
		self.order[#self.order+1] = {set.id, set.next}
		self.hashes[#self.hashes+1] = meta.__hash
		set.next = set.next + 1
		obj:Serialize(stream)
	end

end

function meta:ReadObject(stream)

	local ord = self.order[self.orderNum]
	self.orderNum = self.orderNum + 1

	local setID = ord[1]
	local objID = ord[2]

	if objID == 0 then return nil end

	self.objects[setID] = self.objects[setID] or {}
	local set = self.objects[setID]
	if not set[objID] then
		local hash = self.hashes[self.hashNum]
		self.hashNum = self.hashNum + 1

		local obj = self:Construct(hash)
		obj:Serialize(stream)
		set[objID] = obj
		return obj
	else
		return set[objID]
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end

if CLIENT and bpstream ~= nil then

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

end