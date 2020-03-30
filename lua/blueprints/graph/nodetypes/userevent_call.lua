AddCSLuaFile()

module("node_usereventcall", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:GetEvent() return self:GetType().event end

function NODE:GeneratePins(pins)

	BaseClass.GeneratePins(self, pins)

	local event = self:GetEvent()

	if event:HasFlag( bpevent.EVF_RPC ) and not event:HasFlag( bpevent.EVF_Broadcast ) and event:HasFlag( bpevent.EVF_Server ) then
		table.insert(pins, MakePin(PD_In, "Recipient", PinType(PN_Ref, PNF_None, "Player")))
	end

	bpcommon.Transform( event.pins:GetTable(), pins, bppin_meta.Copy, PD_In )

end

function NODE:GetRole()

	local event = self:GetEvent()

	if event:HasFlag( bpevent.EVF_RPC ) then
		if event:HasFlag( bpevent.EVF_Server ) then return ROLE_Server end
		if event:HasFlag( bpevent.EVF_Client ) then return ROLE_Client end
	end
	return ROLE_Shared

end

function NODE:BuildSendThunk(compiler)

	local event = self:GetEvent()

	self.send.begin()
	self.send.emit("__self:netPostCall( function(...) local arg = {...}")
	self.send.emit("__self:netStartMessage(" .. self.recv.id .. ")")

	local recipient = self:FindPin(PD_In, "Recipient")
	local args = {}

	for _, pin in self:SidePins(PD_In, function(x) return not x:IsType(PN_Exec) and x ~= recipient end) do
		local nthunk = GetNetworkThunk(pin)
		if nthunk ~= nil then
			local vcode = compiler:GetPinCode(pin)
			local num = #args + 1
			args[num] = vcode
			if pin:HasFlag(PNF_Table) then
				self.send.emit("__netWriteTable( function(x) " .. nthunk.write:gsub("@","x") ..  " end, arg[" .. num .. "])")
			else
				self.send.emit(nthunk.write:gsub("@", "arg[" .. num .. "]"))
			end
		end
	end

	if event:HasFlag( bpevent.EVF_Server ) then
		if event:HasFlag( bpevent.EVF_Broadcast ) then
			self.send.emit("net.Broadcast()")
		else
			args[#args+1] = compiler:GetPinCode( recipient )
			self.send.emit("net.Send(arg[" .. #args .. "])")
		end
	else
		self.send.emit("net.SendToServer()")
	end

	table.insert(args, 1, "end")
	self.send.emit( table.concat(args, ", ") .. ")")

	self.send.emit( compiler:GetPinCode( self:FindPin(PD_Out, "Thru"), true ) )
	self.send.finish()

end

function NODE:BuildRecvThunk(compiler)

	local event = self:GetEvent()

	self.recv.begin()
	self.recv.emit("if msgID == " .. self.recv.id .. " then")

	local recipient = self:FindPin(PD_In, "Recipient")

	local call = "self:__Event" .. event.id .. "( "
	local t = {}
	if event:HasFlag( bpevent.EVF_Client ) then t[#t+1] = "pl" end
	for _, pin in self:SidePins(PD_In, function(x) return not x:IsType(PN_Exec) and x ~= recipient end) do
		local nthunk = GetNetworkThunk(pin)
		if nthunk ~= nil then
			if pin:HasFlag(PNF_Table) then
				t[#t+1] = "__netReadTable( function(x) return " .. nthunk.read .. " end )"
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

function NODE:BuildCallThunk( compiler )

	local event = self:GetEvent()

	local call = "__self:__Event" .. event.id .. "( "
	local t = {}
	for _, pin in self:SidePins(PD_In, function(x) return not x:IsType(PN_Exec) end) do
		t[#t+1] = compiler:GetPinCode(pin)
	end
	call = call .. table.concat(t, ", ") .. " )"

	self.call.begin()
	self.call.emit(call)
	self.call.emit( compiler:GetPinCode( self:FindPin(PD_Out, "Thru"), true ) )
	self.call.finish()

end

function NODE:Compile(compiler, pass)

	local event = self:GetEvent()
	if pass == bpcompiler.CP_PREPASS then

		if event:HasFlag( bpevent.EVF_RPC ) then

			self.recv = compiler:AllocThunk(bpcompiler.TK_NETCODE)
			self.send = compiler:AllocThunk(bpcompiler.TK_GENERIC)

			self:BuildRecvThunk( compiler )
			self:BuildSendThunk( compiler )

		else

			self.call = compiler:AllocThunk(bpcompiler.TK_GENERIC)

			self:BuildCallThunk( compiler )

		end
		return true

	elseif pass == bpcompiler.CP_MAINPASS then

		if event:HasFlag( bpevent.EVF_RPC ) then
			compiler.emitContext(self.send.context)
		else
			compiler.emitContext(self.call.context)
		end

		return true

	elseif pass == bpcompiler.CP_NETCODEMSG then

		if event:HasFlag( bpevent.EVF_RPC ) then
			compiler.emitContext(self.recv.context)
			return true 
		end

	end

end

RegisterNodeClass("UserEventCall", NODE)