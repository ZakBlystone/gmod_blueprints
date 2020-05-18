AddCSLuaFile()

module("bpdermanode", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local meta = bpcommon.MetaTable("bpdermanode")

print("DEFINED BPDERMANODE METATABLE: " .. tostring(meta))

meta.DermaBase = ""

dermaClasses = bpclassloader.Get("DermaNode", "blueprints/derma/nodetypes/", "BPDermaClassRefresh", meta)

function meta:Init(class, parent, position)

	self.layout = Ref()
	self.parent = Weak()
	self.children = {}
	self.data = {}
	self.class = class

	bpcommon.MakeObservable(self)

	self:SetupClass()

	if parent then
		parent:AddChild(self, position)
	end

	return self

end

function meta:SetLayout(layout)

	self.layout:Set(layout)

end

function meta:GetLayout()

	return self.layout()

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
		print("Install class: " .. self.class)
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
		self.children[#self.children+1] = Ref(child)
	else
		table.insert(self.children, position, Ref(child))
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

function meta:GetChildren()

	local t = {}
	for _, child in ipairs(self.children) do
		t[#t+1] = child()
	end
	return t

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

	self.layout = stream:Object(self.layout, self)
	self.children = stream:ObjectArray( self.children, self )
	self.data = stream:Value(self.data)

	return stream

end

function meta:GenerateMemberCode(compiler, name)

	if name == "Init" then

		compiler.emit("self.panels = {}")
		for _, child in ipairs(self:GetChildren()) do

			local id = compiler:GetID(child)
			compiler.emit("self.panels[" .. id .. "] = __makePanel(" .. id .. ", self)")

		end

	end

end

function meta:CompileMember(compiler, name)

	compiler.emit("function PANEL:" .. name .. "(...)")
	compiler.pushIndent()
	self:GenerateMemberCode(compiler, name)
	compiler.popIndent()
	compiler.emit("end")

end

function meta:Compile(compiler, pass)

	if pass == CP_MAINPASS then

		print("COMPILE NODE: ", tostring(self))

		for _, child in ipairs(self:GetChildren()) do
			child:Compile(compiler, pass)
		end

		compiler.emit("local PANEL = {Base = " .. self.DermaBase .. "} __panels[" .. compiler:GetID(self) .. "] = PANEL")
		self:CompileMember(compiler, "Init")

	else

		print("COMPILE NODE PASS: ", tostring(self), pass)

	end

end


function New(...) return bpcommon.MakeInstance(meta, ...) end