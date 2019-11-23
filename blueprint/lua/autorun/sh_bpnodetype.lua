AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bppin.lua")

module("bpnodetype", package.seeall, bpcommon.rescope(bpschema))

local meta = {}
meta.__index = meta
meta.__tostring = function(self) return self:ToString() end

function meta:Init()

	self.flags = 0
	self.role = 0
	self.type = 0
	self.code = nil
	self.displayName = nil
	self.desc = nil
	self.nodeClass = nil
	self.nodeParams = {}
	self.requiredMeta = {}
	self.pinRedirects = {}
	self.jumpSymbols = {}
	self.locals = {}
	self.informs = {}
	self.pins = {}
	self.warning = nil
	return self

end

function meta:AddPin(pin) table.insert(self.pins, pin) end
function meta:AddRequiredMeta(meta) table.insert(self.requiredMeta, meta) end
function meta:AddPinRedirect(fromName, toName) self.pinRedirects[fromName] = toName end
function meta:AddJumpSymbol(name) table.insert(self.jumpSymbols, name) end
function meta:AddLocal(name) table.insert(self.locals, name) end
function meta:AddInform(pinID) table.insert(self.informs, pinID) end
function meta:SetRole(role) self.role = role end
function meta:SetType(type) self.type = type end
function meta:SetName(name) self.name = name end
function meta:SetCode(code) self.code = code end
function meta:SetDisplayName(name) self.displayName = name end
function meta:SetDescription(desc) self.desc = desc end
function meta:SetNodeClass(class) self.nodeClass = class end
function meta:SetNodeParam(key, value) self.nodeParams[key] = value end
function meta:SetWarning(msg) self.warning = msg end
function meta:GetRole() return self.role end
function meta:GetType() return self.type end
function meta:GetName() return self.name end
function meta:GetCode() return self.code end
function meta:GetJumpSymbols() return self.jumpSymbols end
function meta:GetLocals() return self.locals end
function meta:GetDisplayName() return self.displayName end
function meta:GetDescription() return self.desc end
function meta:GetNodeClass() return self.nodeClass end
function meta:GetNodeParam(key) return self.nodeParams[key] end
function meta:GetRequiredMeta() return self.requiredMeta end

function meta:AddFlag(fl) self.flags = bit.bor(self.flags, fl) end
function meta:HasFlag(fl) return bit.band(self.flags, fl) ~= 0 end

function meta:WriteToStream(stream)

	assert(stream:IsUsingStringTable())
	stream:WriteBits(self.flags, 8)
	stream:WriteBits(self.role, 8)
	stream:WriteStr(self.name)
	stream:WriteStr(self.code)
	stream:WriteStr(self.displayName)
	stream:WriteStr(self.nodeClass)
	stream:WriteStr(self.warning)
	stream:WriteStr(self.desc)
	bpdata.WriteValue(self.nodeParams, stream)
	bpdata.WriteValue(self.requiredMeta, stream)
	bpdata.WriteValue(self.pinRedirects, stream)
	bpdata.WriteValue(self.jumpSymbols, stream)
	bpdata.WriteValue(self.locals, stream)
	bpdata.WriteValue(self.informs, stream)

	stream:WriteBits(#self.pins, 8)
	for i=1, #self.pins do
		self.pins[i]:WriteToStream(stream)
	end

	return self

end

function meta:ReadFromStream(stream)

	assert(stream:IsUsingStringTable())
	self.flags = stream:ReadBits(8)
	self.role = stream:ReadBits(8)
	self.name = stream:ReadStr()
	self.code = stream:ReadStr()
	self.displayName = stream:ReadStr()
	self.nodeClass = stream:ReadStr()
	self.warning = stream:ReadStr()
	self.desc = stream:ReadStr()
	self.nodeParams = bpdata.ReadValue(stream)
	self.requiredMeta = bpdata.ReadValue(stream)
	self.pinRedirects = bpdata.ReadValue(stream)
	self.jumpSymbols = bpdata.ReadValue(stream)
	self.locals = bpdata.ReadValue(stream)
	self.informs = bpdata.ReadValue(stream)

	local numPins = stream:ReadBits(8)
	for i=1, numPins do
		table.insert(self.pins, bppin.New():ReadFromStream(stream))
	end

	return self

end

function meta:ToString()

	return self:GetName()

end

function New(...)

	return setmetatable({}, meta):Init(...)

end