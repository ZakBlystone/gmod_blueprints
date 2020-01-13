AddCSLuaFile()

G_BPNetworkedLists = G_BPNetworkedLists or {}

module("bpnetlist", package.seeall, bpcommon.rescope(bpcommon))

local CommandBits = 3
local IndexBits = 4
local CMD_PushDiff = 0
local CMD_RequestChanges = 1
local CMD_Subscribe = 2
local CMD_Ack = 3

if SERVER then
	util.AddNetworkString("bpnetlist")
end

local meta = bpcommon.MetaTable("bpnetlist")

function meta:Init( index, name, list )

	self.name = name
	self.list = list
	self.index = index
	self.revision = 1

	self.callback = function(...) self:OnListCallback(...) end
	self.list:AddListener(self.callback, bplist.CB_ALL)

	if SERVER then
		self.subscriptions = {}
		self.playerShadows = {}
		for _, pl in ipairs(player.GetAll()) do
			self.playerShadows[pl] = bplist.New()
		end
	else
		self.serverShadow = bplist.New()
		self.subscribed = false
	end

	return self

end

function meta:GetList()

	return self.list

end

function meta:CanApplyPatch( diff, ply )

	return true

end

function meta:AckPatch( rev, ply )

	if rev ~= self.revision then
		ErrorNoHalt("List revision since ack, not patching")
		return
	end

	if SERVER then

		local shadow = self.playerShadows[ply]
		if shadow == nil then ErrorNoHalt("Player doesn't have netlist[" .. self.name .. "]") return end

		bplistdiff.New( shadow, self.list ):Patch( shadow )

	else

		bplistdiff.New( self.serverShadow, self.list ):Patch( self.serverShadow )

	end

end

function meta:ApplyPatch( rev, diff, ply )

	if not self:CanApplyPatch( diff, ply ) then return end

	if rev < self.revision + 1 then
		ErrorNoHalt("Tried to patch from outdated revision: " .. rev .. " -> " .. self.revision .. " fetching latest")
		self:RequestChanges( ply )
		return
	end

	self.revision = rev

	diff:Patch( self.list )

	net.Start("bpnetlist")
	net.WriteUInt(CMD_Ack, CommandBits)
	net.WriteUInt(self.index, IndexBits)
	net.WriteUInt(self.revision, 32)

	if SERVER then

		net.Send(ply)

	else

		net.SendToServer()

	end

end

function meta:PushChanges( ply )

	if SERVER then

		for _, pl in ipairs(player.GetAll()) do

			if ply and pl ~= ply then continue end

			local shadow = self.playerShadows[pl]
			if shadow == nil then ErrorNoHalt("Player doesn't have netlist[" .. self.name .. "]") continue end

			local diff = bplistdiff.New( shadow, self.list )
			if diff:IsEmpty() then continue end

			local stream = bpdata.OutStream():UseStringTable()
			diff:WriteToStream( stream, STREAM_NET )

			net.Start("bpnetlist")
			net.WriteUInt(CMD_PushDiff, CommandBits)
			net.WriteUInt(self.index, IndexBits)
			net.WriteUInt(self.revision, 32)
			stream:WriteToNet( true )
			net.Send(pl)

		end

	else

		local diff = bplistdiff.New( self.serverShadow, self.list )
		if diff:IsEmpty() then return end

		local stream = bpdata.OutStream():UseStringTable()
		diff:WriteToStream( stream, STREAM_NET )

		net.Start("bpnetlist")
		net.WriteUInt(CMD_PushDiff, CommandBits)
		net.WriteUInt(self.index, IndexBits)
		net.WriteUInt(self.revision, 32)
		stream:WriteToNet( true )
		net.SendToServer()

	end

end

function meta:RequestChanges( ply )

	net.Start("bpnetlist")
	net.WriteUInt(CMD_RequestChanges, CommandBits)
	net.WriteUInt(self.index, IndexBits)

	if SERVER then

		net.Send(ply)

	else

		net.SendToServer()

	end

end

function meta:OnListCallback( cb, ... )

	local timerName = "__bplisttimer_" .. self.name

	-- Here we defer because there could be multiple callbacks stacked up in a single frame
	if timer.Exists(timerName) then timer.Remove(timerName) end

	timer.Create(timerName, 0, 1, function()
		self.revision = self.revision + 1

		if SERVER then

			for k,v in pairs(self.subscriptions) do

				if v then self:PushChanges( k ) end

			end

		else

			if self.subscribed then self:PushChanges() end

		end

	end)

end

function meta:SetSubscribed( subscribed, ply )

	if SERVER then

		self.subscriptions[ply] = subscribed

	else

		self.subscribed = subscribed

	end

end

function meta:Subscribe( subscribed, ply )

	net.Start("bpnetlist")
	net.WriteUInt(CMD_Subscribe, CommandBits)
	net.WriteUInt(self.index, IndexBits)
	net.WriteBool(true)

	if SERVER then

		net.Send( ply )

	else

		net.SendToServer()

	end

end

bpcommon.ForwardMetaCallsVia(meta, "bplist", "GetList")

function Register( index, name, list, ... )

	if G_BPNetworkedLists[index] then
		local indexed = G_BPNetworkedLists[index].name
		if indexed ~= name then
			ErrorNoHalt("List index[" .. index .. "] already registered as '" .. indexed .. "' was trying to register as '" .. name .. "'")
		end
		return G_BPNetworkedLists[index] 
	end
	local list = bpcommon.MakeInstance(meta, index, name, list, ...)
	G_BPNetworkedLists[index] = list
	return list

end

net.Receive("bpnetlist", function(len, ply)

	local cmd = net.ReadUInt(CommandBits)
	local id = net.ReadUInt(IndexBits)
	local netlist = G_BPNetworkedLists[id]

	if netlist == nil then ErrorNoHalt("List is not registered: " .. id) return end

	if cmd == CMD_PushDiff then

		local rev = net.ReadUInt(32)
		local diff = bplistdiff.New()
		local stream = bpdata.InStream():UseStringTable():ReadFromNet()
		diff:ReadFromStream( stream, STREAM_NET )
		netlist:ApplyPatch( rev, diff, ply )

	elseif cmd == CMD_RequestChanges then

		netlist:PushChanges( ply )

	elseif cmd == CMD_Subscribe then

		local subscribed = net.ReadBool()
		netlist:SetSubscribed( subscribed, ply )

	elseif cmd == CMD_Ack then

		local rev = net.ReadUInt(32)
		netlist:AckPatch( rev, ply )

	end

end)

if SERVER then

	hook.Add("PlayerDisconnected", "BPNetListPlayerDisconnect", function(ply)
		for _, list in ipairs(G_BPNetworkedLists) do
			list.playerShadows[ply] = nil
			list.subscriptions[ply] = nil
		end
	end)

	hook.Add("PlayerInitialSpawn", "BPNetListPlayerInit", function(ply)
		for _, list in ipairs(G_BPNetworkedLists) do
			list.playerShadows[ply] = bplist.New()
			list.subscriptions[ply] = false
		end
	end)

end