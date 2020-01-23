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
	self.pins = bplist.New(bppin_meta):NamedItems("Pins")
	self.pins:AddListener(function(cb, action, id, var)

		if self.module then
			if cb == bplist.CB_PREMODIFY then
				self.module:PreModifyNodeType( self.eventNodeType )
				self.module:PreModifyNodeType( self.callNodeType )
			elseif cb == bplist.CB_POSTMODIFY then
				self.module:PostModifyNodeType( self.eventNodeType )
				self.module:PostModifyNodeType( self.callNodeType )
			end
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	-- Event node on receiving end
	self.eventNodeType = bpnodetype.New()
	self.eventNodeType:AddFlag(NTF_Custom)
	self.eventNodeType:AddFlag(NTF_NotHook)
	self.eventNodeType:SetCodeType(NT_Event)
	self.eventNodeType.GetDisplayName = function() return self:GetName() end
	self.eventNodeType.GetDescription = function() return "Custom Event: " .. self:GetName() end
	self.eventNodeType.GetCategory = function() return self:GetName() end
	self.eventNodeType.GetRawPins = function() return bpcommon.Transform( self.pins:GetTable(), {}, bppin_meta.Copy, PD_Out ) end
	self.eventNodeType.GetCode = function(ntype)

		local ret, arg, pins = PinRetArg( ntype, nil, function(s,v,k)
			return s.. " = " .. "arg[" .. (k-1) .. "]"
		end, "\n" )

		return ret

	end

	-- Event calling node
	self.callNodeType = bpnodetype.New()
	self.callNodeType:AddFlag(NTF_Custom)
	self.callNodeType:SetCodeType(NT_Function)
	self.callNodeType:SetCode("")
	self.callNodeType.GetDisplayName = function() return "Call " .. self:GetName() end
	self.callNodeType.GetDescription = function() return "Call " .. self:GetName() .. " event" end
	self.callNodeType.GetCategory = function() return self:GetName() end
	self.callNodeType.GetRawPins = function() return bpcommon.Transform( self.pins:GetTable(), {}, bppin_meta.Copy, PD_In ) end
	self.callNodeType.Compile = function(node, compiler, pass)

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
						t[#t+1] = "__self:netReadTable( function(x) return " .. nthunk.read .. " end )"
					else
						t[#t+1] = nthunk.read
					end
				else
					t[#t+1] = nil
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

	return self

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

function meta:WriteToStream(stream, mode, version)

	self.pins:WriteToStream(stream, mode, version)
	stream:WriteBits(self.flags, 8)
	return self

end

function meta:ReadFromStream(stream, mode, version)

	if not version or version >= 4 then
		self.pins:ReadFromStream(stream, mode, version)
	else
		local oldPins = bplist.New(bpvariable_meta):NamedItems("Pins")
		oldPins:ReadFromStream(stream, mode, version)
		for _, v in oldPins:Items() do
			self.pins:Add( v:CreatePin(PD_None) )
		end
	end
	self.flags = stream:ReadBits(8)
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end