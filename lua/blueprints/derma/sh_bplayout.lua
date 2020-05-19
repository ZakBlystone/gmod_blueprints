AddCSLuaFile()

module("bplayout", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local meta = bpcommon.MetaTable("bplayout")

layoutClasses = bpclassloader.Get("DermaLayout", "blueprints/derma/layouts/", "BPDermaLayoutClassRefresh", meta)

function meta:Init(class)

	self.class = class
	self.data = {}

	self:SetupClass()

	return self

end

function meta:PostLoad()

	self:SetupClass()

end

function meta:SetupClass()

	if self.class then 
		layoutClasses:Install(self.class, self)
		print("Install class: " .. self.class)
	end

end

function meta:Serialize(stream)

	self.class = stream:String(self.class)
	self.data = stream:Value(self.data)
	return stream

end

function meta:InitializeLayoutData(node)

end

function meta:Compile(compiler) end

function New(...) return bpcommon.MakeInstance(meta, ...) end