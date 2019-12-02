if SERVER then AddCSLuaFile() end

include("sh_bpcompiler.lua")
include("sh_bpmodule.lua")

module("bpnet", package.seeall, bpcommon.rescope(bpcompiler))

local CMD_Upload = 0
local CMD_Download = 1
local CMD_Error = 2
local CMD_Install = 3
local CMD_Uninstall = 4
local CMD_Instantiate = 5
ClientModules = ClientModules or {}

local CompileFlags = CF_Default

local function PlayerKey(ply)
	return ply:AccountID() or "singleplayer"
end

local function ErrorHandler( bp, msg, graphID, nodeID )

	bp:SetEnabled(false)
	print("BLUEPRINT ERROR: " .. tostring(msg) .. " at " .. tostring(graphID) .. "[" .. tostring(nodeID) .. "]")

	if SERVER then

		net.Start("bpclientcmd")
		net.WriteUInt(CMD_Error, 4)
		net.WriteUInt(bp.id, 32)
		net.WriteUInt(graphID, 32)
		net.WriteUInt(nodeID, 32)
		net.WriteString(msg)
		net.Send( bp.owner )

	else

		print("ERROR MSG: " .. msg)

	end

end

if SERVER then

	local ServerGraph = bpgraph.New()
	PlayerModules = PlayerModules or {}

	local function GetPlayerModule( ply ) return PlayerModules[PlayerKey(ply)] end
	local function SetPlayerModule( ply, bp )

		local prev = GetPlayerModule( ply )
		if prev ~= nil then 
			prev:SetEnabled(false)
			net.Start("bpclientcmd")
			net.WriteUInt(CMD_Uninstall, 4)
			net.WriteString(bpcommon.GUIDToString( prev.uniqueID ) )
			net.Broadcast()
		end
		PlayerModules[PlayerKey(ply)] = bp

		bp.owner = ply
		bp:SetErrorHandler( ErrorHandler )
		bp:SetEnabled(true)
		net.Start("bpclientcmd")
		net.WriteUInt(CMD_Install, 4)
		bp:NetSend()
		net.Broadcast()

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
		bp:Save(name)
	end

	local function LoadPlayerBlueprint( ply )
		local name = ("blueprints/playerblueprint_" .. PlayerKey(ply) .. ".txt")
		local bp = GetPlayerBlueprint( ply )
		if not file.Exists(name, "DATA") then return end
		bp:Load(name)
	end

	hook.Add("PlayerDisconnected", "bphandledisconnect", function(ply)

		local m = GetPlayerModule(ply)
		if m ~= nil then 
			m:SetEnabled(false)
			net.Start("bpclientcmd")
			net.WriteUInt(CMD_Uninstall, 4)
			net.WriteString(bpcommon.GUIDToString( m.uniqueID ))
			net.Broadcast()
		end

	end)

	util.AddNetworkString("bpclientcmd")
	util.AddNetworkString("bpservercmd")

	net.Receive("bpservercmd", function(len, ply)

		local cmd = net.ReadUInt(4)

		if cmd == CMD_Upload then

			local mod = bpmodule.New()
			mod:NetRecv()

			local ok, res = mod:Compile(CompileFlags)
			if ok then

				SetPlayerModule( ply, mod )
				SavePlayerBlueprint( ply )
				print("Executing " .. ply:Nick() .. "'s blueprint on server: " .. mod:ToString())

			else

				print("Failed to execute " .. ply:NicK() .. "'s blueprint on server: " .. mod:ToString() .. " : " .. tostring(res))

			end

		elseif cmd == CMD_Download then

			local steamID = net.ReadString()
			local mod, isNew = GetPlayerBlueprint( ply )

			if isNew then LoadPlayerBlueprint( ply ) end

			net.Start("bpclientcmd")
			net.WriteUInt(CMD_Download, 4)
			mod:NetSend()
			net.Send( ply )

		end

	end)

else

	local downloadTarget = nil

	net.Receive("bpclientcmd", function(len)

		print("RECV: " .. math.ceil(len/8) .. " bytes (" .. math.ceil(len/8192) .. "kb)")

		local cmd = net.ReadUInt(4)

		if cmd == CMD_Download then

			downloadTarget:NetRecv()

		elseif cmd == CMD_Error then

			_G.G_BPError = {
				moduleID = net.ReadUInt(32),
				graphID = net.ReadUInt(32),
				nodeID = net.ReadUInt(32),
				msg = net.ReadString(),
			}

		elseif cmd == CMD_Install then

			local mod = bpmodule.New()
			mod:NetRecv()

			local uid = bpcommon.GUIDToString( mod.uniqueID )
			local ok, res = mod:Compile(CompileFlags)
			if ok then

				if ClientModules[uid] ~= nil then
					print("DISABLE PREVIOUS MODULE: " .. uid)
					ClientModules[uid]:SetEnabled(false)
				end
				ClientModules[uid] = mod
				mod:SetErrorHandler( ErrorHandler )
				mod:SetEnabled(true)

				print("INSTALL MODULE: " .. uid)

			else

				print("UNABLE TO INSTALL MODULE: " .. uid .. " : " .. res)

			end

		elseif cmd == CMD_Uninstall then

			local uid = net.ReadString()
			print("UN-INSTALL MODULE: " .. uid)

			if ClientModules[uid] ~= nil then
				ClientModules[uid]:SetEnabled(false)
				ClientModules[uid] = nil
			else
				print("No module found")
			end

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

		mod:Compile(CompileFlags)

		net.Start("bpservercmd")
		net.WriteUInt(CMD_Upload, 4)
		mod:NetSend()

		_G.G_BPError = nil

		--local toSend = outStream:GetString(true, true)

		--net.WriteString(toSend)
		net.SendToServer()

	end

end