AddCSLuaFile()

module("bpevent", package.seeall, bpcommon.rescope(bpschema))

EVF_None = 0
EVF_RPC = 1
EVF_Broadcast = 2
EVF_Server = 4 -- Server -> Client
EVF_Client = 8 -- Client -> Server

EVF_Mask_Netmode = bit.bor( EVF_RPC, EVF_Broadcast, EVF_Server, EVF_Client )

NetModes = {
	{"None", EVF_None },
	{"Send to Server", bit.bor( EVF_RPC, EVF_Client )},
	{"Send to Client", bit.bor( EVF_RPC, EVF_Server )},
	{"Broadcast", bit.bor( EVF_RPC, EVF_Server, EVF_Broadcast )},
}

local meta = bpcommon.MetaTable("bpevent")

bpcommon.AddFlagAccessors(meta)

function meta:Init()

	self.flags = 0
	self.pins = bplist.New(bppin_meta):NamedItems("Pins"):WithOuter(self)
	self.pins:Bind("preModify", self, self.PreModify)
	self.pins:Bind("postModify", self, self.PostModify)

	-- Event node on receiving end
	self.eventNodeType = bpnodetype.New():WithOuter(self)
	self.eventNodeType:AddFlag(NTF_Custom)
	self.eventNodeType:AddFlag(NTF_NotHook)
	self.eventNodeType:SetCodeType(NT_Event)
	self.eventNodeType:SetNodeClass("UserEventBind")
	self.eventNodeType.GetDisplayName = function() return self:GetName() end
	self.eventNodeType.GetDescription = function() return "Custom Event: " .. self:GetName() end
	self.eventNodeType.GetCategory = function() return self:GetName() end
	self.eventNodeType.event = self

	-- Event calling node
	self.callNodeType = bpnodetype.New():WithOuter(self)
	self.callNodeType:AddFlag(NTF_Custom)
	self.callNodeType:SetCodeType(NT_Function)
	self.callNodeType:SetNodeClass("UserEventCall")
	self.callNodeType.GetDisplayName = function() return "Call " .. self:GetName() end
	self.callNodeType.GetDescription = function() return "Call " .. self:GetName() .. " event" end
	self.callNodeType.GetCategory = function() return self:GetName() end
	self.callNodeType.event = self

	return self

end

function meta:GetModule()

	return self:FindOuter( bpmodule_meta )

end

function meta:PreModify()

	local mod = self:GetModule()
	mod:PreModifyNodeType( self.eventNodeType )
	mod:PreModifyNodeType( self.callNodeType )

end

function meta:PostModify()

	local mod = self:GetModule()
	mod:PostModifyNodeType( self.eventNodeType )
	mod:PostModifyNodeType( self.callNodeType )

end

function meta:SetName(name)

	self.name = name

end

function meta:GetName()

	return self.name

end

function meta:CallNodeType()

	return self.callNodeType

end

function meta:EventNodeType()

	return self.eventNodeType

end

function meta:Serialize(stream)

	self.pins:Serialize(stream)
	self.flags = stream:Bits(self.flags, 8)

	return stream

end

function New(...) return bpcommon.MakeInstance(meta, ...) end