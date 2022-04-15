AddCSLuaFile()

G_BPUsers = G_BPUsers or {}
G_BPGroups = G_BPGroups or {}

module("bpusermanager", package.seeall, bpcommon.rescope( bpcommon, bpstream ))

local CommandBits = 4
local CMD_Login = 0
local CMD_LoginAck = 1
local CMD_UpdateTables = 2

local UserFile = bpcommon.BLUEPRINT_DATA_PATH .. "/__users.txt"
local NewUserFile = bpcommon.BLUEPRINT_DATA_PATH .. "/server/__users.txt"

if SERVER then
	util.AddNetworkString("bpusermanager")
end

function GetUsers() return G_BPUsers end

function GetUserID( user )

	for i=1, #G_BPUsers do if G_BPUsers[i] == user then return i-1 end end
	return -1

end

function FindUserForPlayer( ply )

	if game.SinglePlayer() and SERVER then
		for _, v in ipairs( G_BPUsers ) do
			if v:HasFlag( bpuser.FL_LoggedIn ) then return v end
		end
		return nil
	end

	for _, v in ipairs( G_BPUsers ) do
		if v:GetPlayer() == ply then return v end
	end

end

function FindUser( user )

	for _, v in ipairs( G_BPUsers ) do
		if v == user then return v end
	end

end

local function PushTables( ply )

	assert(SERVER)
	net.Start("bpusermanager")
	net.WriteUInt(CMD_UpdateTables, CommandBits)
	local stream = bpstream.New("users", MODE_Network):Out()
	stream:ObjectArray(G_BPUsers)
	stream:Finish()
	if ply then net.Send(ply) else net.Broadcast() end

end

local function SaveTables()

	local stream = bpstream.New("users", MODE_File, NewUserFile):Out()
	stream:ObjectArray(G_BPUsers)
	stream:Finish()

end

local function LoadTables()

	-- Check if old userfile exists, load and rewrite
	if file.Exists( UserFile, "DATA" ) then

		-- For compatibility
		local meta = bpcommon.MetaTable("bpgroup")

		function meta:Init() return self end
		function meta:Serialize(stream)
			stream:Value(self.name)
			stream:Value(self.color)
			stream:Bits(self.flags, 16)
			return stream
		end

		local stream = bpstream.New("users", MODE_File, UserFile):In()
		G_BPUsers = stream:ObjectArray()
		stream:ObjectArray()
		stream:Finish()

		file.Delete(UserFile)
		SaveTables()

	elseif file.Exists( NewUserFile, "DATA" ) then

		local stream = bpstream.New("users", MODE_File, NewUserFile):In()
		G_BPUsers = stream:ObjectArray()
		stream:Finish()

	else

		G_BPGroups = {}

	end

end

local function HandleLogin( ply )

	assert(SERVER)

	local stream = bpstream.New("users", MODE_Network):In()
	local user = stream:Object()
	stream:Finish()

	if user:IsValid() then

		local existing = FindUser( user )
		if existing then
			--print("Found existing user: " .. user:GetName() .. " -> " .. existing:GetName())
			existing.name = user:GetName()
			user = existing
		else
			user:SetFlag( bpuser.FL_NewUser )
			G_BPUsers[#G_BPUsers+1] = user
			SaveTables()
		end

		if not user:HasFlag( bpuser.FL_LoggedIn ) then
			user:SetFlag( bpuser.FL_LoggedIn )
			hook.Run("BPClientReady", ply)
		end

		net.Start("bpusermanager")
		net.WriteUInt(CMD_LoginAck, CommandBits)
		net.Send(ply)

		PushTables()

	end

end

function GetLocalUser()

	return _G.G_BPLocalUser

end

function Login()

	assert(CLIENT)
	--print("Logging into server")

	net.Start("bpusermanager")
	net.WriteUInt(CMD_Login, CommandBits)

	local user = bpuser.New(LocalPlayer())
	_G.G_BPLocalUser = user

	assert(user:IsValid())

	local stream = bpstream.New("users", MODE_Network):Out()
	stream:Object(user)
	stream:Finish()

	net.SendToServer()

end

local isLoggedIn = false

net.Receive("bpusermanager", function(len, ply)

	local sendingUser = nil
	if ply then sendingUser = FindUserForPlayer(ply) end

	local cmd = net.ReadUInt(CommandBits)
	if cmd == CMD_Login then
		assert(SERVER)
		HandleLogin(ply)
	elseif cmd == CMD_LoginAck then
		assert(CLIENT)
		if not isLoggedIn then
			isLoggedIn = true
			--print("Logged in!")
			hook.Run("BPClientReady")
		end
	elseif cmd == CMD_UpdateTables then
		assert(CLIENT)
		local stream = bpstream.New("users", MODE_Network):In()
		G_BPUsers = stream:ObjectArray()
		--PrintTable(G_BPUsers)
		for _, user in ipairs(G_BPUsers) do
			if user == _G.G_BPLocalUser then _G.G_BPLocalUser = user end
		end
		hook.Run("BPUserTableUpdated")
		stream:Finish()
	end

end)

if SERVER then

	hook.Add("Initialize", "bpusermanager", function()
		LoadTables()
	end)

	hook.Add("PlayerDisconnected", "bpusermanager", function(ply)
		local user = FindUserForPlayer(ply)
		if user then user:ClearFlag( bpuser.FL_LoggedIn ) end
		PushTables()
	end)

	LoadTables()

elseif CLIENT then

	hook.Add("Initialize", "bpusermanager", function()
		--print("INITIALIZE ON CLIENT:::")
		--print(tostring(LocalPlayer()))
	end)

	local nextLoginAttempt = 0
	hook.Add("StartCommand", "bpusermanager", function()
		if not isLoggedIn then
			if nextLoginAttempt < CurTime() then
				Login()
				nextLoginAttempt = CurTime() + 1
			end
		end
	end)

end