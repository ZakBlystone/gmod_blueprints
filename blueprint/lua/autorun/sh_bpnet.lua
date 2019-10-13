if SERVER then AddCSLuaFile() end

module("bpnet", package.seeall)

local CMD_Upload = 1
local CMD_Download = 2
local CMD_Error = 3

local function PlayerKey(ply)
	return ply:AccountID() or "singleplayer"
end

if SERVER then

	local ServerGraph = bpgraph.New()
	PlayerModules = PlayerModules or {}

	local function ErrorHandler( bp, msg, graphID, nodeID )

		bp:SetEnabled(false)
		print("BLUEPRINT ERROR: " .. tostring(msg) .. " at " .. tostring(graphID) .. "[" .. tostring(nodeID) .. "]")

		net.Start("bpclientcmd")
		net.WriteUInt(CMD_Error, 4)
		net.WriteUInt(bp.id, 32)
		net.WriteUInt(graphID, 32)
		net.WriteUInt(nodeID, 32)
		net.WriteString(msg)
		net.Send( bp.owner )

	end

	local function GetPlayerModule( ply ) return PlayerModules[PlayerKey(ply)] end
	local function SetPlayerModule( ply, bp )

		local prev = GetPlayerModule( ply )
		if prev ~= nil then prev:SetEnabled(false) end
		PlayerModules[PlayerKey(ply)] = bp

		bp.owner = ply
		bp:SetErrorHandler( ErrorHandler )
		bp:SetEnabled(true)

	end

	local function GetPlayerBlueprint( ply )
		local isNew = false
		if PlayerModules[PlayerKey(ply)] == nil then
			PlayerModules[PlayerKey(ply)] = bpmodule.New()
			PlayerModules[PlayerKey(ply)]:NewGraph("EventGraph")
			isNew = true
		end

		return PlayerModules[PlayerKey(ply)], isNew
	end

	local function SavePlayerBlueprint( ply )
		local name = ("blueprints/playerblueprint_" .. PlayerKey(ply) .. ".txt")
		local bp = GetPlayerBlueprint( ply )
		local outStream = bpdata.OutStream()
		bp:WriteToStream(outStream)
		outStream:WriteToFile(name, true, true)
		print("Saving: " .. name)
	end

	local function LoadPlayerBlueprint( ply )
		local name = ("blueprints/playerblueprint_" .. PlayerKey(ply) .. ".txt")
		local bp = GetPlayerBlueprint( ply )
		local inStream = bpdata.InStream()
		if not file.Exists(name, "DATA") then return end
		inStream:LoadFile(name, true, true)
		bp:ReadFromStream(inStream)
	end

	hook.Add("PlayerDisconnected", "bphandledisconnect", function(ply)

		local m = GetPlayerModule(ply)
		if m ~= nil then m:SetEnabled(false) end

	end)

	util.AddNetworkString("bpclientcmd")
	util.AddNetworkString("bpservercmd")

	net.Receive("bpservercmd", function(len, ply)

		local cmd = net.ReadUInt(4)

		if cmd == CMD_Upload then

			local mod = bpmodule.New()
			local inStream = bpdata.InStream()
			inStream:ReadFromNet(true)
			mod:ReadFromStream( inStream )
			mod:Compile()
			SetPlayerModule( ply, mod )
			SavePlayerBlueprint( ply )
			print("Executing blueprint on server...")

		elseif cmd == CMD_Download then

			local steamID = net.ReadString()
			local mod, isNew = GetPlayerBlueprint( ply )
			local outStream = bpdata.OutStream()

			if isNew then LoadPlayerBlueprint( ply ) end

			mod:WriteToStream(outStream)

			net.Start("bpclientcmd")
			net.WriteUInt(CMD_Download, 4)
			outStream:WriteToNet(true)
			net.Send( ply )

		end

	end)

else

	local downloadTarget = nil

	net.Receive("bpclientcmd", function(len)

		print("RECV: " .. math.ceil(len/8) .. " bytes (" .. math.ceil(len/8192) .. "kb)")

		local cmd = net.ReadUInt(4)

		if cmd == CMD_Download then

			local inStream = bpdata.InStream()
			inStream:ReadFromNet(true)
			downloadTarget:ReadFromStream( inStream )

		elseif cmd == CMD_Error then

			_G.G_BPError = {
				moduleID = net.ReadUInt(32),
				graphID = net.ReadUInt(32),
				nodeID = net.ReadUInt(32),
				msg = net.ReadString(),
			}

		end

	end)

	function DownloadServerModule( mod, steamid )

		downloadTarget = mod

		net.Start("bpservercmd")
		net.WriteUInt(CMD_Download, 4)
		net.WriteString( steamid or PlayerKey(LocalPlayer()) )
		net.SendToServer()

	end

	function SendModule( mod )

		mod:Compile()

		net.Start("bpservercmd")
		net.WriteUInt(CMD_Upload, 4)

		local outStream = bpdata.OutStream()
		mod:WriteToStream(outStream)
		outStream:WriteToNet(true)

		_G.G_BPError = nil

		--local toSend = outStream:GetString(true, true)

		--net.WriteString(toSend)
		net.SendToServer()

	end

end