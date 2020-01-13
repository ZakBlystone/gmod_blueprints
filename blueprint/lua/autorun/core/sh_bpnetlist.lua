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
			self.playerShadows[pl] = self:CreateShadow()
		end
	else
		self.serverShadow = self:CreateShadow()
		self.subscribed = false
	end

	self.AddListener = function(self, ...) self.list:AddListener(...) end
	self.RemoveListener = function(self, ...) self.list:RemoveListener(...) end

	return self

end

function meta:CreateShadow()

	local shadow = bplist.New()
	shadow.namedItems = self.list.namedItems
	shadow.namePrefix = self.list.namePrefix
	shadow.constructor = self.list.constructor
	shadow.sanitizer = self.list.sanitizer
	return shadow

end

function meta:GetPlayerShadow(pl)

	local shadow = self.playerShadows[pl]
	if shadow == nil then
		print("Player[" .. tostring(pl) .. "] doesn't have netlist[" .. self.name .. "], creating...")
		shadow = self:CreateShadow()
		self.playerShadows[pl] = shadow
	end

	return shadow

end

function meta:GetList()

	return self.list

end

function meta:CanApplyPatch( diff, ply )

	return true

end

function meta:AckPatch( rev, ply )

	if rev ~= self.revision then
		ErrorNoHalt("!!! List revision since ack, not patching")
		return
	end

	if SERVER then

		local shadow = self:GetPlayerShadow(ply)

		print("Client[" .. tostring(ply) .. "] ack patch '" .. self.name .. "' " .. rev)
		bplistdiff.New( shadow, self.list ):Patch( shadow )

		print( shadow:ToString("updated_player_shadow") )

	else

		bplistdiff.New( self.serverShadow, self.list ):Patch( self.serverShadow )
		print("Server ack patch '" .. self.name .. "' " .. rev)

		print( self.serverShadow:ToString("updated_server_shadow") )

	end

end

function meta:ApplyPatch( rev, diff, ply )

	if not self:CanApplyPatch( diff, ply ) then return end

	if rev < self.revision then
		ErrorNoHalt("Tried to patch '" .. self.name .. "' from outdated revision: " .. rev .. " -> " .. self.revision .. " fetching latest")
		--self:RequestChanges( ply )
		return
	else
		print("Applying patch for '" .. self.name .. "' " .. self.revision .. " -> " .. rev)
		print( diff:ToString() )
	end

	self.revision = rev

	diff:Patch( self.list )

	print(self.list:ToString("New List"))

	if SERVER then diff:Patch( self:GetPlayerShadow(ply) ) print( self:GetPlayerShadow(ply):ToString("patched_player_shadow") ) end
	if CLIENT then diff:Patch( self.serverShadow ) print( self.serverShadow:ToString("patched_server_shadow") ) end

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

	self.revision = self.revision + 1

	print("Pushing changes")
	print( self.list:ToString("from") )

	if SERVER then

		for _, pl in ipairs(player.GetAll()) do

			if ply and pl ~= ply then continue end

			local shadow = self:GetPlayerShadow(pl)

			print( shadow:ToString("playershadow_" .. tostring(pl)) )

			local diff = bplistdiff.New( shadow, self.list )
			if diff:IsEmpty() then print("No changes since shadow, not sending diff to client[" .. tostring(pl) .. "], pushing anyway...") end

			local stream = bpdata.OutStream():UseStringTable()
			diff:WriteToStream( stream, STREAM_NET )

			net.Start("bpnetlist")
			net.WriteUInt(CMD_PushDiff, CommandBits)
			net.WriteUInt(self.index, IndexBits)
			net.WriteUInt(self.revision, 32)
			stream:WriteToNet( true )
			net.Send(pl)

			print("Sending patch to player[" .. self.name .. "]: " .. self.revision .. " -> " .. tostring(pl))
			print( diff:ToString() )

		end

	else

		print( self.serverShadow:ToString("servershadow") )

		local diff = bplistdiff.New( self.serverShadow, self.list )
		if diff:IsEmpty() then print("No changes since shadow, not sending diff to server, pushing anyway...") end

		local stream = bpdata.OutStream():UseStringTable()
		diff:WriteToStream( stream, STREAM_NET )

		net.Start("bpnetlist")
		net.WriteUInt(CMD_PushDiff, CommandBits)
		net.WriteUInt(self.index, IndexBits)
		net.WriteUInt(self.revision, 32)
		stream:WriteToNet( true )
		net.SendToServer()

		print("Sending patch to server[" .. self.name .. "]: " .. self.revision)
		print( diff:ToString() )

	end

end

function meta:RequestChanges( ply )

	net.Start("bpnetlist")
	net.WriteUInt(CMD_RequestChanges, CommandBits)
	net.WriteUInt(self.index, IndexBits)

	if SERVER then

		print("Requesting changes for '" .. self.name .. "' from client: " .. tostring(ply))
		net.Send(ply)

	else

		print("Requesting changes for '" .. self.name .. "' from server")
		net.SendToServer()

	end

end

function meta:OnListCallback( cb, ... )

	local timerName = "__bplisttimer_" .. self.name

	-- Here we defer because there could be multiple callbacks stacked up in a single frame
	if timer.Exists(timerName) then timer.Remove(timerName) end

	timer.Create(timerName, 0, 1, function()

		print("Detected list change[" .. self.name .. "], pushing changes to subscribers: " .. self.revision .. " -> " .. (self.revision+1))

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

	local k = subscribed and "subscribed to" or "unsubscribed from"

	if SERVER then

		print("Client[" .. tostring(ply) .. "] " .. k .. " list[" .. self.name .. "]")
		self.subscriptions[ply] = subscribed

	else

		print("Server " .. k .. " list[" .. self.name .. "]")
		self.subscribed = subscribed

	end

	if subscribed then self:PushChanges(ply) end

end

function meta:Subscribe( subscribed, ply )

	net.Start("bpnetlist")
	net.WriteUInt(CMD_Subscribe, CommandBits)
	net.WriteUInt(self.index, IndexBits)
	net.WriteBool(subscribed)

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
		local diff = bplistdiff.New():Constructor( netlist.list.constructor )
		local stream = bpdata.InStream():UseStringTable():ReadFromNet(true)
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