AddCSLuaFile()

module("bplayout", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local meta = bpcommon.MetaTable("bplayout")

meta.HasSlot = false

layoutClasses = bpclassloader.Get("DermaLayout", "blueprints/derma/layouts/", "BPDermaLayoutClassRefresh", meta)

function GetClassLoader() return layoutClasses end

function meta:Init(class)

	self.class = class
	self.data = {}
	self.node = Weak()

	self:SetupClass()

	return self

end

function meta:PostLoad() end

function meta:RequiresSlot() return self.HasSlot end
function meta:SetParam(k, value) self.data[k] = value return self end
function meta:GetParam(k) return self.data[k] end
function meta:GetCodeContext() assert(self.class) return "dermalayout_" .. self.class end
function meta:GetFunctionName() return "__layout_" .. self.class end

function meta:GetNode() return self.node() end
function meta:GetPreview() return self:GetNode() and self:GetNode():GetPreview() end
function meta:GetEdit() return self.edit end
function meta:ApplyPanelValue( pnl, k, v, oldValue ) 

	if pnl.layout then
		pnl.layout[k] = v
		pnl:InvalidateLayout(true)
	end

end

function meta:CustomizeEdit( edit ) 

	edit:BindRaw("valueChanged", self, function(old, new, k)
		local pnl = self:GetPreview()
		if not IsValid(pnl) then return end
		self:ApplyPanelValue(pnl, k, new, old )
	end)

end

function meta:SetupClass()

	if self.classInitialized then return end
	if self.class then
		self.classInitialized = true

		layoutClasses:Install(self.class, self)
		print("Install class: " .. self.class)

		local parms = {}
		self:InitParams( parms )

		for k, v in pairs(parms) do
			if self.data[k] == nil then	self.data[k] = v end
		end

		self.edit = bpvaluetype.FromValue(self.data, function() return self.data end)
		self:CustomizeEdit( self.edit )
	end

end

function meta:Serialize(stream)

	self.class = stream:String(self.class)
	self.data = stream:Value(self.data)

	if stream:IsReading() then self:SetupClass() end

	return stream

end

function meta:InitParams(params)

end

function meta:InitSlotParams(slot)

end

function meta:CompileSlotInitializers(compiler)

end

function New(...) return bpcommon.MakeInstance(meta, ...) end