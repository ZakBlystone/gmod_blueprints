AddCSLuaFile()

module("bpobjectlinker", package.seeall)

local meta = bpcommon.MetaTable("bpobjectlinker")
local WEAK_SET = 0xFFFFFF

function meta:Init()

	self.objects = {}
	self.nextSetID = 0
	self.order = {}
	self.hashes = {}
	self.refs = {}
	self.orderNum = 1
	self.hashNum = 1
	self.dindent = 0
	return self

end

function meta:Serialize(stream)

	local orderCount = stream:UInt(#self.order)
	local hashCount = stream:UInt(#self.hashes)

	--Dprint("Serialize: " .. orderCount .. " orders")
	--Dprint("Serialize: " .. hashCount .. " hashes")

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

function meta:GetObjectMeta( obj )

	local meta = getmetatable(obj)
	if meta == nil or meta.__hash == nil then error("Object is not a metatype") end

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

function meta:GetRefTable(obj, noCreate)
	if not noCreate then self.refs[obj] = self.refs[obj] or {} end
	return self.refs[obj]
end

function meta:AppendRef(obj, ord)
	local t = self:GetRefTable(obj)
	t[#t+1] = ord
end

function meta:WriteObject(stream, obj, isExtern)

	if obj == nil then
		self.order[#self.order+1] = {0, 0}
		return
	end

	if not type(obj) == "table" then error("Tried to write non-table object") end

	if obj.__ref then
		local ord = self:FindObjectOrder(obj())
		--if ord ~= 0 then ord = self.order[ord][1] end
		if ord ~= 0 then self:DPrint("PRE-LINKED WEAK[" .. tostring(obj) .. "]: " .. tostring(obj()) .. " [" .. ord .. "]") end
		self.order[#self.order+1] = {ord, WEAK_SET, obj}
		if obj:IsValid() then self:AppendRef(obj(), #self.order) end
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
		self:DPrint("SAVED: " .. tostring(obj) .. " [" .. (#self.order) .. "]")
	else
		set.objects[hash] = set.next
		self.order[#self.order+1] = {set.id, set.next}
		self.hashes[#self.hashes+1] = meta.__hash
		if not isExtern then 
			self:DPrint("SAVED: " .. tostring(obj) .. " [" .. (#self.order) .. "]")
			self:DPushIndent()
			obj:Serialize(stream)
			self:DPopIndent()
		end
		set.next = set.next + 1
	end

	local r = self:GetRefTable(obj, true)
	if r then
		for _, v in ipairs(r) do
			self.order[v][1] = thisOrderNum self:DPrint("POST-LINKED WEAK[" .. tostring(self.order[v][3]) .. "]: " .. tostring(obj) .. " [" .. thisOrderNum .. "]" )
		end
	end

end

function meta:ReadObject(stream, extern, isExtern, outer)

	local ord = self.order[self.orderNum]
	local thisOrderNum = self.orderNum
	self.orderNum = self.orderNum + 1

	local setID = ord[1]
	local objID = ord[2]

	if objID == WEAK_SET then
		local w = bpcommon.Weak(nil)
		if setID ~= 0 and self.order[setID] ~= nil then
			local ord = self.order[setID]
			local set = self.objects[ord[1]]
			if set then
				w:Set( set[ord[2]] )
				self:DPrint("PRE-LINKED WEAK[" .. tostring(w) .. "]: " .. tostring(set[ord[2]]) .. " [" .. setID .. "]" )
				if w:IsValid() then return w end
			end
		end
		self:AppendRef(setID, w)
		return w
	end

	if objID == 0 then return nil end

	self.objects[setID] = self.objects[setID] or {}
	local set = self.objects[setID]
	if not set[objID] then
		local hash = self.hashes[self.hashNum]
		self.hashNum = self.hashNum + 1

		local obj = nil
		if isExtern then
			obj = extern
		else 
			obj = self:Construct(hash):WithOuter(outer)
			self:DPrint("CONSTRUCTED: " .. tostring(obj) .. " [" .. (thisOrderNum) .. "]")
			self:DPushIndent()
			obj:Serialize(stream)
			self:DPopIndent()
		end
		set[objID] = obj

		local r = self:GetRefTable(thisOrderNum, true)
		if r then
			for _, v in ipairs(r) do
				self:DPrint("POST-LINKED WEAK[" .. tostring(v) .. "]: " .. tostring(obj) .. " [" .. (thisOrderNum) .. "]")
				v:Set( obj )
			end
		end

		return obj
	else
		return set[objID]
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end