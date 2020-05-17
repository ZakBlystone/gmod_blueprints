AddCSLuaFile()

module("bpdermanode", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local meta = bpcommon.MetaTable("bpdermanode")

dermaClasses = bpclassloader.Get("DermaNode", "blueprints/derma/nodetypes/", "BPDermaClassRefresh", meta)

function meta:Init(class)

	self.parent = Weak()
	self.children = {}
	self.data = {}
	self.class = class

	bpcommon.MakeObservable(self)

	self:SetupClass()

	return self

end

function meta:PostLoad()

	for _, child in ipairs(self.children) do
		if child() then
			child().parent:Set(self)
		end
	end

	self:SetupClass()

end

function meta:SetupClass()

	if self.class then 
		dermaClasses:Install(self.class, self)
	end

end

function meta:GetChildIndex( child )

	assert( isbpdermanode(child) )

	for i=#self.children, 1, -1 do
		if self.children[i]() == child then
			return i
		end
	end
	return -1

end

function meta:AddChild( child, position )

	assert( isbpdermanode(child) )

	if not position then
		self.children[#self.children+1] = Weak(child)
	else
		table.insert(self.children, position, Weak(child))
	end

	child.parent:Set(self)
	self:Broadcast("childAdded", child, self:GetChildIndex(child) )

end

function meta:RemoveChild( child )

	assert( isbpdermanode(child) )

	for i=#self.children, 1, -1 do
		if self.children[i]() == child then
			table.remove(self.children, i)
			child.parent:Reset()
			self:Broadcast("childRemoved", child, i)
		end
	end

end

function meta:Swap( childA, childB )

	assert( isbpdermanode(childA) and isbpdermanode(childB) )

	local idxA = self:GetChildIndex(childA)
	local idxB = self:GetChildIndex(childB)

	assert( idxA ~= -1 and idxB ~= -1 )

	self.children[idxA]:Set(childB)
	self.children[idxB]:Set(childA)

	self:Broadcast("childrenSwapped", childA, childB, idxA, idxB)

end

function meta:Serialize(stream)

	self.children = stream:ObjectArray( self.children, self )
	self.data = stream:Value(self.data)

	return stream

end

function New(...) return bpcommon.MakeInstance(meta, ...) end