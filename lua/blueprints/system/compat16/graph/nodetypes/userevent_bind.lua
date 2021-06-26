AddCSLuaFile()

module("node_usereventbind", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetEvent() return self:GetType().event end

function NODE:GeneratePins(pins)

	BaseClass.GeneratePins(self, pins)

	local event = self:GetEvent()

	if event:HasFlag( bpevent.EVF_RPC ) and event:HasFlag( bpevent.EVF_Client ) then
		table.insert(pins, MakePin(PD_Out, "Sender", bppintype.New(PN_Ref, PNF_None, "Player")))
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

function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MAINPASS then

		local arg = {}
		for k, pin in self:SidePins(PD_Out) do
			if not pin:IsType( PN_Exec ) then
				arg[#arg+1] = compiler:GetPinCode( pin, true )
			end
		end

		if #arg > 0 then compiler.emit( table.concat(arg, ",\n\t") .. " = ..." ) end

		return true

	elseif pass == CP_METAPASS then

		local graph = self:GetGraph()
		compiler:CompileGraphMetaHook(graph, self, self:GetTypeName())

	end

end

RegisterNodeClass("UserEventBind", NODE)