if SERVER then AddCSLuaFile() end

module("bpnet", package.seeall)

local CMD_Upload = 1
local CMD_Download = 2
local CMD_Error = 3

if SERVER then

	local ServerGraph = bpgraph.New()
	PlayerModules = PlayerModules or {}
	PlayerGraphs = PlayerGraphs or {}

	local function HookModule( bp )

		for k,v in pairs(bp.events) do
			if not v.hook then continue end
			local function safeCall(...) bp.call(k, ...) end
			hook.Add(v.hook, "__bphook_" .. v.graphID .. "_" .. v.nodeID, safeCall)
		end

	end

	local function UnhookModule( bp )

		for k,v in pairs(bp.events) do
			if not v.hook then continue end
			hook.Remove(v.hook, "__bphook_" .. v.graphID .. "_" .. v.nodeID)
		end		

	end

	local function GetPlayerModule( ply ) return PlayerModules[ply:AccountID()] end
	local function SetPlayerModule( ply, bp )

		local prev = GetPlayerModule( ply )
		if prev ~= nil then UnhookModule(prev) end
		PlayerModules[ply:AccountID()] = bp

		bp.onError = function( msg, graphID, nodeID )

			UnhookModule(bp)
			print("BLUEPRINT ERROR: " .. tostring(msg) .. " at " .. tostring(graphID) .. "[" .. tostring(nodeID) .. "]")

			net.Start("bpclientcmd")
			net.WriteUInt(CMD_Error, 4)
			net.WriteUInt(graphID, 32)
			net.WriteUInt(nodeID, 32)
			net.WriteString(msg)
			net.Send( ply )

		end

		HookModule(bp)
		if bp.events["Init"] then bp.call("Init") end

	end

	local function GetPlayerGraph( ply )
		local isNew = false
		if PlayerGraphs[ply:AccountID()] == nil then
			PlayerGraphs[ply:AccountID()] = bpgraph.New()
			isNew = true
		end
		return PlayerGraphs[ply:AccountID()], isNew
	end

	local function SavePlayerGraph( ply )
		local name = ("blueprints/playergraph_" .. ply:AccountID() .. ".txt")
		local graph = GetPlayerGraph( ply )
		local outStream = bpdata.OutStream()
		graph:WriteToStream(outStream)
		outStream:WriteToFile(name, true, true)
		print("Saving: " .. name)
	end

	local function LoadPlayerGraph( ply )
		local name = ("blueprints/playergraph_" .. ply:AccountID() .. ".txt")
		local graph = GetPlayerGraph( ply )
		local inStream = bpdata.InStream()
		if not file.Exists(name, "DATA") then return end
		inStream:LoadFile(name, true, true)
		graph:ReadFromStream(inStream)
	end

	util.AddNetworkString("bpclientcmd")
	util.AddNetworkString("bpservercmd")

	net.Receive("bpservercmd", function(len, ply)

		local cmd = net.ReadUInt(4)

		if cmd == CMD_Upload then

			local graph = GetPlayerGraph( ply )
			--file.Write("last_server_graph_" .. ply:AccountID() .. ".txt", graphdata)

			local inStream = bpdata.InStream()
			inStream:ReadFromNet(true)
			graph:ReadFromStream( inStream )

			local compiled = bpcompile.Compile( graph )
			print("Executing blueprint on server...")
			SetPlayerModule( ply, compiled )
			SavePlayerGraph( ply )

		elseif cmd == CMD_Download then

			local steamID = net.ReadString()
			local graph, isNew = GetPlayerGraph( ply )
			local outStream = bpdata.OutStream()

			if isNew then LoadPlayerGraph( ply ) end

			graph:WriteToStream(outStream)

			net.Start("bpclientcmd")
			net.WriteUInt(CMD_Download, 4)
			outStream:WriteToNet(true)
			net.Send( ply )

		end

	end)

else

	local downloadTarget = nil

	net.Receive("bpclientcmd", function(len)

		print("RECEIVE: " .. len .. " bytes")

		local cmd = net.ReadUInt(4)

		if cmd == CMD_Download then

			local inStream = bpdata.InStream()
			inStream:ReadFromNet(true)
			downloadTarget:ReadFromStream( inStream )

		elseif cmd == CMD_Error then

			_G.G_BPError = {
				graphID = net.ReadUInt(32),
				nodeID = net.ReadUInt(32),
				msg = net.ReadString(),
			}

		end

	end)

	function DownloadServerGraph( graph, steamid )

		downloadTarget = graph

		net.Start("bpservercmd")
		net.WriteUInt(CMD_Download, 4)
		net.WriteString( steamid or LocalPlayer():AccountID() )
		net.SendToServer()

	end

	function SendGraph( graph )

		bpcompile.Compile( graph )

		net.Start("bpservercmd")
		net.WriteUInt(CMD_Upload, 4)

		local outStream = bpdata.OutStream()
		graph:WriteToStream(outStream)
		outStream:WriteToNet(true)

		_G.G_BPError = nil

		--local toSend = outStream:GetString(true, true)

		--net.WriteString(toSend)
		net.SendToServer()

	end

end