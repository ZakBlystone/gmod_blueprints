AddCSLuaFile()

module("node_usereventbind", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetEvent() return self:GetType().event end

function NODE:GeneratePins(pins)

	self.BaseClass.GeneratePins(self, pins)

	local event = self:GetEvent()

	if event:HasFlag( bpevent.EVF_RPC ) and event:HasFlag( bpevent.EVF_Client ) then
		table.insert(pins, MakePin(PD_Out, "Sender", PinType(PN_Ref, PNF_None, "Player")))
	end

	bpcommon.Transform( event.pins:GetTable(), pins, bppin_meta.Copy, PD_Out )

end

function NODE:GetRole()

	local event = self:GetEvent()

	if event:HasFlag( bpevent.EVF_RPC ) then
		if event:HasFlag( bpevent.EVF_Server ) then return ROLE_Client end
		if event:HasFlag( bpevent.EVF_Client ) then return ROLE_Server end
	end
	return ROLE_Shared

end

function NODE:GetCode()

	local ret, arg, pins = PinRetArg( self:GetCodeType(), self:GetPins(), nil, function(s,v,k)
		return s.. " = " .. "arg[" .. (k-1) .. "]"
	end, "\n" )

	return ret

end


RegisterNodeClass("EventBind", NODE)