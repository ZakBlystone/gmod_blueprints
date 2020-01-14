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
	self.pins = bplist.New():NamedItems("Pins"):Constructor(bppin.New)
	self.pins:AddListener(function(cb, action, id, var)

		if self.module then
			if cb == bplist.CB_PREMODIFY then
				self.module:PreModifyNodeType( "__Event" .. self.id )
				self.module:PreModifyNodeType( "__EventCall" .. self.id )
			elseif cb == bplist.CB_POSTMODIFY then
				self.module:PostModifyNodeType( "__Event" .. self.id )
				self.module:PostModifyNodeType( "__EventCall" .. self.id )
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
		ntype:AddPin( pin:Copy(PD_In) )
	end

	--local ret, arg, pins = PinRetArg( ntype )
	--ntype:SetCode( "__self:__Event" .. self.id .. "(" .. arg .. ")" )
	ntype:SetCode("")

	ntype.Compile = function(node, compiler, pass)

		if pass == bpcompiler.CP_PREPASS then

			print("EVENT CALL PREPASS")

			node.recv = compiler:AllocThunk(bpcompiler.TK_NETCODE)
			node.send = compiler:AllocThunk(bpcompiler.TK_GENERIC)
			node.send.begin()

			node.send.emit("__self:netPostCall( function()")
			node.send.emit("__self:netStartMessage(" .. node.recv.id .. ")")
			for _, pin in node:SidePins(PD_In, function(x) return not x:IsType(PN_Exec) end) do
				local nthunk = GetNetworkThunk(pin)
				if nthunk ~= nil then
					local vcode = compiler:GetPinCode(pin)
					if pin:HasFlag(PNF_Table) then
						node.send.emit("__self:netWriteTable( function(x) " .. nthunk.write:gsub("@","x") ..  " end, " .. vcode .. ")")
					else
						node.send.emit(nthunk.write:gsub("@", vcode ))
					end
				end
			end
			node.send.emit("if SERVER then net.Broadcast() else net.SendToServer() end")
			node.send.emit("end)")

			node.send.emit( compiler:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) )
			node.send.finish()

			node.recv.begin()
			node.recv.emit("if msgID == " .. node.recv.id .. " then")
			local call = "self:__Event" .. self.id .. "( "
			local t = {}
			for _, pin in node:SidePins(PD_In, function(x) return not x:IsType(PN_Exec) end) do
				local nthunk = GetNetworkThunk(pin)
				if nthunk ~= nil then
					if pin:HasFlag(PNF_Table) then
						table.insert(t, "__self:netReadTable( function(x) return " .. nthunk.read .. " end )")
					else
						table.insert(t, nthunk.read)
					end
				else
					table.insert(t, "nil")
				end
			end
			call = call .. table.concat(t, ", ") .. " )"
			node.recv.emit(call)
			node.recv.emit("end")
			node.recv.finish()
			return true
		elseif pass == bpcompiler.CP_MAINPASS then
			compiler.emitContext(node.send.context) return true
		elseif pass == bpcompiler.CP_NETCODEMSG then
			compiler.emitContext(node.recv.context) return true
		end

	end

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
		ntype:AddPin( pin:Copy(PD_Out) )
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

	if not version or version >= 4 then
		self.pins:ReadFromStream(stream, mode, version)
	else
		local oldPins = bplist.New():NamedItems("Pins"):Constructor(bpvariable.New)
		oldPins:ReadFromStream(stream, mode, version)
		for _, v in oldPins:Items() do
			self.pins:Add( v:CreatePin(PD_None) )
		end
	end
	self.flags = stream:ReadBits(8)
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end