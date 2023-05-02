AddCSLuaFile()

module("bpobjectlinker", package.seeall)

local meta = bpcommon.MetaTable("bpobjectlinker")
local EXTERN_SET = 0xFFFFFE
local WEAK_SET = 0xFFFFFF

function meta:Init()

	self.objects = {}
	self.nextSetID = 0
	self.order = {}
	self.hashes = {}
	self.orderNum = 1
	self.hashNum = 1
	self.dindent = 0
	self.extern = {}
	self.externUIDNum = 1
	self.externUIDs = {}
	self.externObjLookup = {}
	self.UIDList = {}
	self.postLoadTree = { objects = {}, nodes = {} }
	--self:DSetDebug(true)
	return self

end

function meta:Serialize(stream)

	bpcommon.Profile("serialize-object-meta", function()

		local uidCount = stream:UInt(#self.UIDList)
		local orderCount = stream:UInt(#self.order)
		local hashCount = stream:UInt(#self.hashes)

		--Dprint("Serialize: " .. orderCount .. " orders")
		--Dprint("Serialize: " .. hashCount .. " hashes")

		for i=1, uidCount do
			self.UIDList[i] = stream:GUID(self.UIDList[i])
			self.externUIDs[self.UIDList[i]] = i
		end

		for i=1, orderCount do
			self.order[i] = self.order[i] or {}
			self.order[i][1] = stream:Length(self.order[i][1])
			self.order[i][2] = stream:Length(self.order[i][2])
			if self.order[i][1] == EXTERN_SET then
				self.order[i][3] = stream:Length(self.order[i][3])
			end
		end

		for i=1, hashCount do
			self.hashes[i] = stream:UInt(self.hashes[i])
		end

	end)

	return stream

end

function meta:WalkPostLoadTree( node, marked )

	node = node or self.postLoadTree
	marked = marked or {}

	for _, v in ipairs(node.nodes) do
		self:WalkPostLoadTree(v, marked)
	end

	for _, object in ipairs(node.objects) do
		if not marked[object] then
			if object.PostLoad then object:PostLoad() end
			object.__loaded = true
		end
	end

end

function meta:PostLink(stream)

	bpcommon.Profile("post-link", function()

	if stream:IsWriting() then

		for k, v in ipairs(self.order) do
			if v[1] == WEAK_SET and v[4]() then
				local o = v[4]()
				local ord = self:FindObjectOrder(o)
				if ord ~= 0 then
					v[2] = ord
					--print("LINK WEAK[" .. ord .. "]: " .. tostring(o))
				elseif self.externObjLookup[o] then
					v[1] = EXTERN_SET
					v[2] = self.externObjLookup[o]
					v[3] = self.extern[v[2]][o]
					--print("LINK EXTERN: " .. tostring(o))
				end
			end
		end

	else

		--local m = {}
		for k, v in ipairs(self.order) do
			if v[1] == WEAK_SET then
				local ord = self.order[v[2]]
				if ord ~= nil and self.objects[ord[1]] then
					--m[#m+1] = {"LINK WEAK[" .. v[2] .. "]: ", self.objects[ord[1]][ord[2]]}
					v[4]:Set( self.objects[ord[1]][ord[2]] )
				end
			elseif v[1] == EXTERN_SET and self.extern[v[2]] then
				--m[#m+1] = {"LINK EXTERN: ", self.extern[v[2]][v[3]]}
				v[4]:Set( self.extern[v[2]][v[3]] )
			end
		end
		--[[for _, v in ipairs(m) do
			print( v[1] .. tostring(v[2]) )
		end]]

		-- Ensure objects are post-loaded backwards up the hierarchy
		self:WalkPostLoadTree()

	end

	end)

end

function meta:SerializeMissingDependencies(stream)

	--print("SERIALIZE MISSING DEPENDENCIES")

	local missing = {}
	if stream:IsWriting() then

		local marked = {}
		for k, v in ipairs(self.order) do
			if v[1] == WEAK_SET and v[4]() then
				local o = v[4]()
				local ord = self:FindObjectOrder(o)
				if ord == 0 and not self.externObjLookup[o] then
					if not marked[o] then
						marked[o] = true
						missing[#missing+1] = o
					end
				end
			end
		end

		for _, v in ipairs(missing) do
			print("Write missing dependency: " .. tostring(v))
		end

	end

	missing = stream:ObjectArray(missing)

	for _, v in ipairs(missing) do
		print("Serialize missing dependency: " .. tostring(v))
	end

end

function meta:Construct(hash)

	local meta = bpcommon.GetMetaTableFromHash(hash)
	if meta == nil then error("Unable to find metatable for hash: " .. hash) end
	local obj = bpcommon.MakeInstance(meta)
	obj.__loaded = false
	return obj

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

function meta:GetObjectMeta( obj )

	local meta = getmetatable(obj)
	if meta == nil or meta.__hash == nil then error("Object is not a metatype: " .. tostring(obj) .. " | " .. tostring(meta) .. " | " .. tostring( meta and meta.__hash )) end

	assert(bpcommon.GetMetaTableFromHash(meta.__hash), "Issue with metatable hashes")

	return meta

end

function meta:GetObjectHash( obj )

	local hash = obj
	local hashed = false

	--if obj.GetHash then hash = obj:GetHash() hashed = true end

	return hash, hashed

end

function meta:FindObjectOrder( obj )

	if obj == nil then return 0 end

	local meta = self:GetObjectMeta( obj )
	local set = self:GetSetForHash( meta.__hash )
	local hash, hashed = self:GetObjectHash( obj )

	local existing = set.objects[hash]
	if not hashed and not existing and meta.__eq then
		for k, v in pairs(set.objects) do
			if meta.__eq(obj, k) then existing = v end
		end
	end

	for k, order in ipairs(self.order) do
		if order[1] == set.id and order[2] == existing then return k end
	end

	return 0

end

function meta:DSetDebug(enable)
	self.debug = enable
end

function meta:DPushIndent()
	self.dindent = self.dindent + 1
end

function meta:DPopIndent()
	self.dindent = self.dindent - 1
end

function meta:DPrint(...)
	if self.debug then print(string.rep("  ", self.dindent) .. table.concat({...}, ",")) end
end

function meta:GetExternSet(uid)

	local index = self.externUIDs[uid]
	self.extern[index] = self.extern[index] or {}
	return self.extern[index]

end

function meta:CreateExtern(obj, uid)

	local set = self:GetExternSet( uid )
	set[#set+1] = obj
	set[obj] = #set

	self.externObjLookup[obj] = self.externUIDs[uid]

end

function meta:ReadExtern(stream, obj, uid)

	if obj == nil then return end
	if self.externUIDs[uid] == nil then
		print("Unlinked extern object: " .. bpcommon.GUIDToString( uid ) )
		return
	end

	self:CreateExtern(obj, uid)

end

function meta:WriteExtern(stream, obj, uid)

	if obj == nil then return end

	if not self.externUIDs[uid] then
		self.UIDList[#self.UIDList+1] = uid
		self.externUIDs[uid] = self.externUIDNum
		self.externUIDNum = self.externUIDNum + 1
	end

	self:CreateExtern(obj, uid)

end

function meta:WriteObject(stream, obj)

	if obj == nil then
		self.order[#self.order+1] = {0, 0}
		return
	end

	if not type(obj) == "table" then error("Tried to write non-table object") end

	if obj.__ref then
		if obj() and ( getmetatable(obj()) == nil or getmetatable(obj()).__hash == nil ) then
			print("INVALID POINTED OBJECT: " .. debug.traceback())
		end
		self.order[#self.order+1] = {WEAK_SET, 0, 0, obj}
		return
	end

	local meta = self:GetObjectMeta( obj )
	local set = self:GetSetForHash( meta.__hash )
	local hash, hashed = self:GetObjectHash( obj )

	local existing = set.objects[hash]
	if not hashed and not existing and meta.__eq then
		for k, v in pairs(set.objects) do
			if meta.__eq(obj, k) then existing = v end
		end
	end

	local thisOrderNum = #self.order+1
	if existing then
		self.order[#self.order+1] = {set.id, existing}
		--self:DPrint("SAVED: " .. tostring(obj) .. " [" .. (#self.order) .. "]")
	else
		set.objects[hash] = set.next
		self.order[#self.order+1] = {set.id, set.next}
		self.hashes[#self.hashes+1] = meta.__hash
		set.next = set.next + 1
		--self:DPrint("SAVED: " .. tostring(obj) .. " [" .. (#self.order) .. "]")
		--self:DPushIndent()
		obj:Serialize(stream)
		--self:DPopIndent()
	end

end

function meta:ReadObject(stream, outer)

	local ord = self.order[self.orderNum]
	local thisOrderNum = self.orderNum
	self.orderNum = self.orderNum + 1

	local setID = ord[1]
	local objID = ord[2]

	if setID == WEAK_SET or setID == EXTERN_SET then
		local w = bpcommon.Weak(nil)
		ord[4] = w
		return w
	end

	if objID == 0 then return nil end

	self.objects[setID] = self.objects[setID] or {}
	local set = self.objects[setID]
	if not set[objID] then
		local hash = self.hashes[self.hashNum]
		self.hashNum = self.hashNum + 1

		local obj = self:Construct(hash):WithOuter(outer)
		--self:DPrint("CONSTRUCTED: " .. tostring(obj) .. " [" .. (thisOrderNum) .. "]")
		--self:DPushIndent()
		local prev = self.postLoadTree
		self.postLoadTree = { objects = {}, nodes = {} }
		prev.nodes[#prev.nodes+1] = self.postLoadTree

		obj:Serialize(stream)

		self.postLoadTree = prev
		--self:DPopIndent()
		set[objID] = obj

		self.postLoadTree.objects[#self.postLoadTree.objects+1] = obj

		return obj
	else
		self.postLoadTree.objects[#self.postLoadTree.objects+1] = set[objID]
		return set[objID]
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end