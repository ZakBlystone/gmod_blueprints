if SERVER then AddCSLuaFile() end

module("bpnet", package.seeall)

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

	local function GetPlayerModule( ply ) return PlayerModules[ply:SteamID()] end
	local function SetPlayerModule( ply, bp )

		local prev = GetPlayerModule( ply )
		if prev ~= nil then UnhookModule(prev) end
		PlayerModules[ply:SteamID()] = bp

		bp.onError = function( msg, graphID, nodeID )

			UnhookModule(bp)
			print("BLUEPRINT ERROR: " .. tostring(msg) .. " at " .. tostring(graphID) .. "[" .. tostring(nodeID) .. "]")

		end

		HookModule(bp)
		if bp.events["Init"] then bp.call("Init") end

	end

	local function GetPlayerGraph( ply )
		PlayerGraphs[ply:SteamID()] = PlayerGraphs[ply:SteamID()] or bpgraph.New()
		return PlayerGraphs[ply:SteamID()]
	end

	util.AddNetworkString("bpclientcmd")
	util.AddNetworkString("bpservercmd")

	local CMD_Upload = 1
	local CMD_Download = 2

	net.Receive("bpservercmd", function(len, ply)

		local cmd = net.ReadUInt(4)

		if cmd == CMD_Upload then

			local graph = GetPlayerGraph( ply )
			--file.Write("last_server_graph_" .. ply:SteamID() .. ".txt", graphdata)

			local inStream = bpdata.InStream()
			inStream:ReadFromNet(true)
			graph:ReadFromStream( inStream )

			local compiled = bpcompile.Compile( graph )
			print("Executing blueprint on server...")
			SetPlayerModule( ply, compiled )

		elseif cmd == CMD_Download then

			local steamID = net.ReadString()
			local graph = GetPlayerGraph( ply )
			local outStream = bpdata.OutStream()
			graph:WriteToStream(outStream)

			net.Start("bpclientcmd")
			outStream:WriteToNet(true)
			net.Send( ply )

		end

	end)

else

	local downloadTarget = nil

	net.Receive("bpclientcmd", function(len)

		print("RECEIVE: " .. len .. " bytes")

		local inStream = bpdata.InStream()
		inStream:ReadFromNet(true)
		downloadTarget:ReadFromStream( inStream )

	end)

	function DownloadServerGraph( graph, steamid )

		downloadTarget = graph

		net.Start("bpservercmd")
		net.WriteUInt(2, 4)
		net.WriteString( steamid or LocalPlayer():SteamID() )
		net.SendToServer()

	end

	function SendGraph( graph )

		bpcompile.Compile( graph )

		net.Start("bpservercmd")
		net.WriteUInt(1, 4)

		local outStream = bpdata.OutStream()
		graph:WriteToStream(outStream)
		outStream:WriteToNet(true)

		--local toSend = outStream:GetString(true, true)

		--net.WriteString(toSend)
		net.SendToServer()

	end

end