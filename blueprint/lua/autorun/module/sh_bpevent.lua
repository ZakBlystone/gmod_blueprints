AddCSLuaFile()

module("bpevent", package.seeall, bpcommon.rescope(bpschema))

EVF_None = 0
EVF_RPC = 1
EVF_Broadcast = 2
EVF_Server = 4
EVF_Client = 8

local meta = bpcommon.MetaTable("bpevent")

bpcommon.AddFlagAccessors(meta)

function meta:Init()

	self.flags = 0
	self.pins = bplist.New():NamedItems("Pins"):Constructor(bpvariable.New)
	self.pins:AddListener(function(cb, action, id, var)

		if self.module then
			if cb == bplist.CB_PREMODIFY then
				self.module:PreModifyNodeType( "__Event" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
				self.module:PreModifyNodeType( "__EventCall" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			elseif cb == bplist.CB_POSTMODIFY then
				self.module:PostModifyNodeType( "__Event" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
				self.module:PostModifyNodeType( "__EventCall" .. self.id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			end
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	return self

end

function meta:SetName(name)

	self.name = name

end

function meta:GetName()

	return self.name

end

function meta:CallNodeType()

	local ntype = bpnodetype.New()
	ntype:SetName("__EventCall" .. self.id)
	ntype:SetDisplayName("Call " .. self:GetName())
	ntype:SetCodeType(NT_Function)
	ntype:SetDescription("Call " .. self:GetName() .. " event")
	ntype:SetCategory(self:GetName())
	ntype:AddFlag(NTF_Custom)

	for _, pin in self.pins:Items() do
		ntype:AddPin( pin:CreatePin(PD_In) )
	end

	local ret, arg, pins = PinRetArg( ntype )
	ntype:SetCode( "__self:__Event" .. self.id .. "(" .. arg .. ")" )

	return ntype

end

function meta:EventNodeType()

	local ntype = bpnodetype.New()
	ntype:SetName("__Event" .. self.id)
	ntype:SetDisplayName(self:GetName())
	ntype:SetCodeType(NT_Event)
	ntype:SetDescription("Custom Event: " .. self:GetName())
	ntype:SetCategory(self:GetName())
	ntype:AddFlag(NTF_Custom)
	ntype:AddFlag(NTF_NotHook)

	for _, pin in self.pins:Items() do
		ntype:AddPin( pin:CreatePin(PD_Out) )
	end

	local ret, arg, pins = PinRetArg( ntype, nil, function(s,v,k)
		return s.. " = " .. "arg[" .. (k-1) .. "]"
	end, "\n" )

	ntype:SetCode(ret)

	return ntype

end

function meta:WriteToStream(stream, mode, version)

	self.pins:WriteToStream(stream, mode, version)
	stream:WriteBits(self.flags, 8)
	return self

end

function meta:ReadFromStream(stream, mode, version)

	self.pins:ReadFromStream(stream, mode, version)
	self.bits = stream:ReadBits(8)
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end