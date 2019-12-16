AddCSLuaFile()

module("bpnet", package.seeall, bpcommon.rescope(bpcompiler))

local CMD_Upload = 0
local CMD_Download = 1
local CMD_Error = 2
local CMD_Install = 3
local CMD_Uninstall = 4
local CMD_Instantiate = 5
local CMD_Destroy = 6

local CompileFlags = CF_Default
local PlayerKey = bpcommon.PlayerKey

local function ErrorHandler( bp, msg, graphID, nodeID )

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
hook.Add("BPModuleError", "bpnetHandleError", ErrorHandler)

if SERVER then

	hook.Add("PlayerDisconnected", "bpnetHandleDisconnect", function(ply)

	end)

	util.AddNetworkString("bpclientcmd")
	util.AddNetworkString("bpservercmd")

	net.Receive("bpservercmd", function(len, ply)

		local cmd = net.ReadUInt(4)

	end)

else

	net.Receive("bpclientcmd", function(len)

		local cmd = net.ReadUInt(4)

	end)

	--[[function DownloadServerModule( mod, steamid )

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

	end]]

end