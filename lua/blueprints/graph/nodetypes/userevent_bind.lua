AddCSLuaFile()

module("node_usereventbind", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetEvent() return self:GetType():FindOuter(bpevent_meta) end

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

function NODE:BuildRecvThunk(compiler)

	local event = self:GetEvent()

	self.recv.begin()
	self.recv.emit("if msgID == " .. compiler:GetID(event) .. " then")

	local sender = self:FindPin(PD_Out, "Sender")

	local call = "self:__Event" .. compiler:GetID(event) .. "( "
	local t = {}
	if event:HasFlag( bpevent.EVF_Client ) then t[#t+1] = "pl" end
	for _, pin in self:SidePins(PD_Out, function(x) return not x:IsType(PN_Exec) and x ~= sender end) do
		local nthunk = pin.GetNetworkThunk and pin:GetNetworkThunk()
		if nthunk ~= nil then
			if pin:HasFlag(PNF_Table) then
				t[#t+1] = "(function() local t = {} for i=1, net.ReadUInt(24) do t[#t+1] = " .. nthunk.read .. " end return t end)()"
			else
				t[#t+1] = nthunk.read
			end
		else
			t[#t+1] = "nil"
		end
	end

	call = call .. table.concat(t, ", ") .. " )"

	self.recv.emit(call)
	self.recv.emit("end")
	self.recv.finish()

end

function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	local event = self:GetEvent()

	if pass == CP_PREPASS then

		if event:HasFlag( bpevent.EVF_RPC ) then

			self.recv = compiler:AllocThunk(TK_NETCODE)
			self:BuildRecvThunk( compiler )

		end
		return true

	elseif pass == CP_MAINPASS then

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

		return true

	elseif pass == CP_NETCODEMSG then

		if event:HasFlag( bpevent.EVF_RPC ) and self.recv ~= nil then
			compiler.emitContext(self.recv.context)
			return true 
		end

	end

end

RegisterNodeClass("UserEventBind", NODE)