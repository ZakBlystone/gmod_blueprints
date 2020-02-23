AddCSLuaFile()

module("bpnet", package.seeall, bpcommon.rescope(bpcompiler, bpcommon))

local CommandBits = 4
local CMD_Install = 0
local CMD_Uninstall = 1
local CMD_Instantiate = 2
local CMD_Destroy = 3
local CMD_ErrorReport = 4

local CompileFlags = CF_Default
local PlayerKey = bpcommon.PlayerKey

if SERVER then
	util.AddNetworkString("bpnet")
end

local function HandleRemoteErrorReport( uid, msg, graphID, nodeID, from )

	if from then
		msg = msg .. " [ on player: " .. from:GetName() .. " ] "
	end

	_G.G_BPError = {
		uid = uid,
		msg = msg,
		graphID = graphID,
		nodeID = nodeID,
		from = from,
	}

end

local function NetErrorDispatch( uid, msg, graphID, nodeID, from )

	if CLIENT then

		net.Start("bpnet")
		net.WriteUInt( CMD_ErrorReport, CommandBits )
		net.WriteData( uid, 16 )
		net.WriteString( msg )
		net.WriteUInt( graphID, 32 )
		net.WriteUInt( nodeID, 32 )
		net.SendToServer()

	else

		local mod = bpenv.Get( uid )
		if not mod then ErrorNoHalt("Module does not exist on the server: " .. tostring(uid)) return end

		local owner = mod:GetOwner()
		local file = bpfilesystem.FindFileByUID( uid )

		if file then
			file:ClearFlag(bpfile.FL_Running)
			bpfilesystem.PushFiles()
		end

		if owner ~= nil then

			local ply = game.SinglePlayer() and player.GetAll()[1] or owner:GetPlayer()
			msg = mod:FormatErrorMessage( msg, graphID, nodeID )

			net.Start("bpnet")
			net.WriteUInt( CMD_ErrorReport, CommandBits )
			net.WriteData( uid, 16 )
			net.WriteString( msg )
			net.WriteUInt( graphID, 32 )
			net.WriteUInt( nodeID, 32 )
			if from then 
				net.WriteBool(true) --Clientside Error
				net.WriteEntity(from)
			else
				net.WriteBool(false) --Serverside Error
			end
			net.Send( ply )

		end

	end

	bpenv.Uninstall( uid )

end

local function ErrorHandler( mod, msg, graphID, nodeID )

	print("***BLUEPRINT ERROR*** : " .. tostring(msg))
	NetErrorDispatch( mod:GetUID(), msg, graphID, nodeID )

end
hook.Add("BPModuleError", "bpnetHandleError", ErrorHandler)

function Install( mod, owner )

	assert(SERVER)

	local instanceUID = bpcommon.GUID()

	mod:Load()
	mod:SetOwner( owner )

	bpenv.Install( mod )
	bpenv.Instantiate( mod:GetUID(), instanceUID )

	local stream = bpdata.OutStream(false, true, true):UseStringTable()
	mod:WriteToStream(stream, STREAM_NET)

	net.Start("bpnet")
	net.WriteUInt( CMD_Install, CommandBits )
	net.WriteData( instanceUID, 16 )
	local s,p = stream:WriteToNet(true)
	--print("Send compiled module size: " .. p .. " bytes")
	net.Broadcast()

end

function Uninstall( uid )

	assert(SERVER)

	bpenv.Uninstall( uid )

	net.Start("bpnet")
	net.WriteUInt( CMD_Uninstall, CommandBits )
	net.WriteData( uid, 16 )
	net.Broadcast()

end

net.Receive("bpnet", function(len, ply)

	local cmd = net.ReadUInt(4)
	if cmd == CMD_Install then

		local uid = net.ReadData( 16 )
		local stream = bpdata.InStream(false, true, true):UseStringTable()
		stream:ReadFromNet(true)
		local mod = bpcompiledmodule.New():ReadFromStream( stream, STREAM_NET )

		mod:Load()
		bpenv.Install( mod )
		bpenv.Instantiate( mod:GetUID(), uid )

	elseif cmd == CMD_Uninstall then

		local uid = net.ReadData(16)
		bpenv.Uninstall( uid )

	elseif cmd == CMD_ErrorReport then

		local uid = net.ReadData( 16 )
		local msg = net.ReadString()
		local graphID = net.ReadUInt( 32 )
		local nodeID = net.ReadUInt( 32 )

		if SERVER then
			NetErrorDispatch( uid, msg, graphID, nodeID, ply )
		else
			local clientSide = net.ReadBool()
			local ply = nil
			if clientSide then ply = net.ReadEntity() end
			HandleRemoteErrorReport( uid, msg, graphID, nodeID, ply )
		end

	end

end)