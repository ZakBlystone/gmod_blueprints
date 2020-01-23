AddCSLuaFile()

G_BPUsers = G_BPUsers or {}
G_BPGroups = G_BPGroups or {}

module("bpusermanager", package.seeall, bpcommon.rescope( bpcommon ))

local TableFlagBits = 2
local TF_Users = 1
local TF_Groups = 2
local TF_All = bit.bor(TF_Users, TF_Groups)

local GroupBits = 5
local CommandBits = 4
local CMD_Login = 0
local CMD_LoginAck = 1
local CMD_UpdateTables = 2
local CMD_AddGroup = 3
local CMD_RemoveGroup = 4
local CMD_AddUser = 5
local CMD_RemoveUser = 6
local CMD_SetGroupFlag = 7
local CMD_ClearGroupFlag = 8

local UserFile = "blueprints/__users.txt"
local UserFileVersion = 1

if SERVER then
	util.AddNetworkString("bpusermanager")
end

function GetUsers() return G_BPUsers end
function GetGroups() return G_BPGroups end

function GetGroupID( group )

	for i=1, #G_BPGroups do if G_BPGroups[i] == group then return i-1 end end
	return -1

end

function GetUserID( user )

	for i=1, #G_BPUsers do if G_BPUsers[i] == user then return i-1 end end
	return -1

end

function GetGroupByName( name )

	for _, v in ipairs(G_BPGroups) do
		if v.name == name then return v end
	end
	return nil

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

local function LocalAddGroup( name, flags, hardcoded )

	for _, v in ipairs(G_BPGroups) do
		if v:GetName() == name then error("Group already exists: " .. name) return end
	end

	local group = bpgroup.New( name, flags )
	if hardcoded then group:SetFlag( bpgroup.FL_Locked ) end
	G_BPGroups[#G_BPGroups+1] = group
	return group

end

local function RemoveGroup( group )

	if group:HasFlag( bpgroup.FL_Locked ) then return end

	local id = GetGroupID( group )
	for _, user in ipairs( G_BPUsers ) do
		user:ShiftGroupBits( id )
	end

	table.remove( G_BPGroups, id + 1 )

end

local function CreateDefaultGroups()

	LocalAddGroup( "admins", bpgroup.FL_AllPermissions, true ):SetColor( Color(255,100,100) )
	LocalAddGroup( "auditors", bit.bor(bpgroup.FL_CanViewAny, bpgroup.FL_CanToggle) ):SetColor( Color(255,100,255) )
	LocalAddGroup( "trusted", bit.bor(bpgroup.FL_CanUpload, bpgroup.FL_CanRunLocally, bpgroup.FL_CanUseProtected, bpgroup.FL_CanToggle) ):SetColor( Color(100,255,100) )
	LocalAddGroup( "newbie", bit.bor(bpgroup.FL_CanUpload) ):SetColor( Color(100,100,100) )

end

local function PushTables( flags, ply )

	assert(SERVER)
	net.Start("bpusermanager")
	net.WriteUInt(CMD_UpdateTables, CommandBits)
	net.WriteUInt(flags, TableFlagBits)
	local stream = bpdata.OutStream()
	if bit.band(flags, TF_Users) ~= 0 then bpdata.WriteArray(bpuser_meta, G_BPUsers, stream, STREAM_NET) end
	if bit.band(flags, TF_Groups) ~= 0 then bpdata.WriteArray(bpgroup_meta, G_BPGroups, stream, STREAM_NET) end
	stream:WriteToNet( true )
	if ply then net.Send(ply) else net.Broadcast() end

end

local function LoadTables()

	if file.Exists( UserFile, "DATA" ) then

		local stream = bpdata.InStream(false, true)
		stream:LoadFile( UserFile, false, false )
		local version = stream:ReadInt(false)
		G_BPUsers = bpdata.ReadArray(bpuser_meta, stream, STREAM_FILE, version)
		G_BPGroups = bpdata.ReadArray(bpgroup_meta, stream, STREAM_FILE, version)

	else

		G_BPGroups = {}
		CreateDefaultGroups()

	end

end

local function SaveTables()

	local stream = bpdata.OutStream(false, true)
	stream:WriteInt(UserFileVersion, false)
	bpdata.WriteArray(bpuser_meta, G_BPUsers, stream, STREAM_FILE, UserFileVersion)
	bpdata.WriteArray(bpgroup_meta, G_BPGroups, stream, STREAM_FILE, UserFileVersion)
	stream:WriteToFile( UserFile, false, false )

end

local function HandleLogin( ply )

	assert(SERVER)

	local stream = bpdata.InStream():ReadFromNet(true)
	local user = bpuser.New():ReadFromStream( stream, STREAM_NET )

	if user:IsValid() then

		local existing = FindUser( user )
		if existing then
			print("Found existing user: " .. user:GetName() .. " -> " .. existing:GetName())
			existing.name = user:GetName()
			user = existing
		else
			user:SetFlag( bpuser.FL_NewUser )
			G_BPUsers[#G_BPUsers+1] = user
			SaveTables()
		end

		if ply:IsAdmin() then
			print( user:GetName() .. " is an admin, adding to admin group" )
			user:AddGroup( GetGroupByName("admins") )
		end

		if not user:HasFlag( bpuser.FL_LoggedIn ) then
			user:SetFlag( bpuser.FL_LoggedIn )
			hook.Run("BPClientReady", ply)
		end

		net.Start("bpusermanager")
		net.WriteUInt(CMD_LoginAck, CommandBits)
		net.Send(ply)

		PushTables(TF_All)

	end

end

function GetLocalUser()

	return _G.G_BPLocalUser

end

function Login()

	assert(CLIENT)
	print("Logging into server")

	net.Start("bpusermanager")
	net.WriteUInt(CMD_Login, CommandBits)

	local user = bpuser.New(LocalPlayer())
	_G.G_BPLocalUser = user

	assert(user:IsValid())

	local stream = bpdata.OutStream()
	user:WriteToStream( stream, STREAM_NET )
	stream:WriteToNet( true )

	net.SendToServer()

end

function AddUser(group, user)

	assert(CLIENT)
	local groupID = GetGroupID(group)
	local userID = GetUserID(user)
	if groupID == -1 then error("Group not found") end
	if userID == -1 then error("User not found") end

	net.Start("bpusermanager")
	net.WriteUInt(CMD_AddUser, CommandBits)
	net.WriteUInt(groupID, GroupBits)
	net.WriteUInt(userID, 32)
	net.SendToServer()

end

function RemoveUser(group, user)

	assert(CLIENT)
	local groupID = GetGroupID(group)
	local userID = GetUserID(user)
	if groupID == -1 then error("Group not found") end
	if userID == -1 then error("User not found") end

	net.Start("bpusermanager")
	net.WriteUInt(CMD_RemoveUser, CommandBits)
	net.WriteUInt(groupID, GroupBits)
	net.WriteUInt(userID, 32)
	net.SendToServer()

end

function AddGroup(name)

	assert(CLIENT)
	net.Start("bpusermanager")
	net.WriteUInt(CMD_AddGroup, CommandBits)
	net.WriteString(name)
	net.SendToServer()

end

function RemoveGroup(group)

	assert(CLIENT)
	local groupID = GetGroupID(group)
	if groupID == -1 then error("Group not found") end
	net.Start("bpusermanager")
	net.WriteUInt(CMD_RemoveGroup, CommandBits)
	net.WriteUInt(groupID, GroupBits)
	net.SendToServer()

end

function SetGroupFlag(group, flag)

	assert(CLIENT)
	local groupID = GetGroupID(group)
	if groupID == -1 then error("Group not found") end
	net.Start("bpusermanager")
	net.WriteUInt(CMD_SetGroupFlag, CommandBits)
	net.WriteUInt(flag, 16)
	net.SendToServer()

end

function ClearGroupFlag(group, flag)

	assert(CLIENT)
	local groupID = GetGroupID(group)
	if groupID == -1 then error("Group not found") end
	net.Start("bpusermanager")
	net.WriteUInt(CMD_ClearGroupFlag, CommandBits)
	net.WriteUInt(flag, 16)
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
			print("Logged in!")
			hook.Run("BPClientReady")
		end
	elseif cmd == CMD_UpdateTables then
		assert(CLIENT)
		local flags = net.ReadUInt(TableFlagBits)
		local stream = bpdata.InStream():ReadFromNet(true)
		if bit.band(flags, TF_Users) ~= 0 then
			print("Updating user table")
			G_BPUsers = bpdata.ReadArray(bpuser_meta, stream, STREAM_NET)
			PrintTable(G_BPUsers)
			for _, user in ipairs(G_BPUsers) do
				if user == _G.G_BPLocalUser then _G.G_BPLocalUser = user end
			end
			hook.Run("BPUserTableUpdated")
		end
		if bit.band(flags, TF_Groups) ~= 0 then
			print("Updating group table")
			G_BPGroups = bpdata.ReadArray(bpgroup_meta, stream, STREAM_NET)
			hook.Run("BPGroupTableUpdated")
		end
	elseif cmd == CMD_AddUser then
		assert(SERVER)
		if sendingUser:HasPermission( bpgroup.FL_CanEditUsers ) then
			local group = G_BPGroups[ net.ReadUInt(GroupBits) + 1 ]
			local user = G_BPUsers[ net.ReadUInt(32) + 1 ]
			user:AddGroup( group )
			PushTables(TF_Users)
		end
	elseif cmd == CMD_RemoveUser then
		assert(SERVER)
		if sendingUser:HasPermission( bpgroup.FL_CanEditUsers ) then
			local group = G_BPGroups[ net.ReadUInt(GroupBits) + 1 ]
			local user = G_BPUsers[ net.ReadUInt(32) + 1 ]
			local adminGroup = GetGroupByName("admins")
			if user == sendingUser and sendingUser:IsInGroup( adminGroup ) and group == adminGroup then
				print(user:GetName() .. " tried to remove themselves from admin group")
				return
			end
			user:RemoveGroup( group )
			PushTables(TF_Users)
		end
	elseif cmd == CMD_AddGroup then
		assert(SERVER)
		if sendingUser:HasPermission( bpgroup.FL_CanEditGroups ) then
			local name = net.ReadString()
			LocalAddGroup(name)
			PushTables(TF_Groups)
		end
	elseif cmd == CMD_RemoveGroup then
		assert(SERVER)
		if sendingUser:HasPermission( bpgroup.FL_CanEditGroups ) then
			local group = G_BPGroups[ net.ReadUInt(GroupBits) + 1 ]
			RemoveGroup(group)
			PushTables(TF_Groups)
		end
	elseif cmd == CMD_SetGroupFlag then
		assert(SERVER)
		if sendingUser:HasPermission( bpgroup.FL_CanEditPermissions ) then
			local group = G_BPGroups[ net.ReadUInt(GroupBits) + 1 ]
			local flag = net.ReadUInt(8)
			if group:HasFlag( bpgroup.FL_Locked ) then return end
			if flag == bpgroup.FL_Locked then return end
			group:SetFlag( flag )
			PushTables(TF_Groups)
		end
	elseif cmd == CMD_ClearGroupFlag then
		assert(SERVER)
		if sendingUser:HasPermission( bpgroup.FL_CanEditPermissions ) then
			local group = G_BPGroups[ net.ReadUInt(GroupBits) + 1 ]
			local flag = net.ReadUInt(8)
			if group:HasFlag( bpgroup.FL_Locked ) then return end
			group:ClearFlag( flag )
			PushTables(TF_Groups)
		end
	end

end)

if SERVER then

	hook.Add("Initialize", "bpusermanager", function()
		LoadTables()
	end)

	hook.Add("PlayerDisconnected", "bpusermanager", function(ply)
		local user = FindUserForPlayer(ply)
		if user then user:ClearFlag( bpuser.FL_LoggedIn ) end
		PushTables(TF_Users)
	end)

	LoadTables()

elseif CLIENT then

	hook.Add("Initialize", "bpusermanager", function()
		print("INITIALIZE ON CLIENT:::")
		print(tostring(LocalPlayer()))
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