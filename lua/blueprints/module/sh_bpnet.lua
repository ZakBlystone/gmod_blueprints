AddCSLuaFile()

module("bpnet", package.seeall, bpcommon.rescope(bpcompiler, bpcommon))

local CommandBits = 4
local CMD_Install = 0
local CMD_Uninstall = 1
local CMD_Instantiate = 2
local CMD_Destroy = 3
local CMD_ErrorReport = 4
local CMD_InstallMultiple = 5

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
		if not mod then ErrorNoHalt("Module does not exist on the server: " .. bpcommon.GUIDToString(uid) .. "\n") return end

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

	local instances = bpenv.GetInstances( mod:GetUID() )
	print("NUM INSTANCES: " .. #instances)

end

function Uninstall( uid )

	assert(SERVER)

	bpenv.Uninstall( uid )

	net.Start("bpnet")
	net.WriteUInt( CMD_Uninstall, CommandBits )
	net.WriteData( uid, 16 )
	net.Broadcast()

end

if SERVER then

	function InstallRunningModules( ply )

		if not IsValid(ply) then print("Failed to send blueprints to unknown player") end
		print("SENDING BLUEPRINTS TO CLIENT: " .. ply:Nick() )

		local files = bpfilesystem.GetFiles()
		local agg = bpdata.OutStream(false, true, true):UseStringTable()

		local count = 0
		for k,v in ipairs(files) do
			local uid = v:GetUID()
			if bpenv.IsInstalled( uid ) then count = count + 1 end
		end

		agg:WriteInt(count, false)
		print("Send " .. count .. " blueprints...")

		for k,v in ipairs(files) do

			local uid = v:GetUID()
			if bpenv.IsInstalled( uid ) then

				local instances = bpenv.GetInstances( uid )

				print("Packing Blueprint " .. v:GetName() .. "...")
				local cmod = bpenv.Get( v:GetUID() )  --mod:Build( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
				cmod:WriteToStream(agg, STREAM_NET)

				print("Write " .. #instances .. " instances.")
				agg:WriteInt(#instances, false)
				for _, inst in ipairs(instances) do
					agg:WriteStr(inst.guid)
				end
			end
		end

		net.Start("bpnet")
		net.WriteUInt( CMD_InstallMultiple, CommandBits )
		local s,p = agg:WriteToNet(true)
		print("Send compiled chunk size: " .. p .. " bytes")
		net.Send( ply )

	end

	hook.Add("BPClientReady", "transmitAllModules", function(ply)

		InstallRunningModules(ply)

	end)

end

-- Creates placeholder entities for blueprint classes which haven't been networked yet
hook.Add("NetworkEntityCreated", "handleNetEnts", function(ent)

	if IsValid(ent) then
		if ent:IsScripted() then

			if ent:IsWeapon() then

				--print("Network Weapon Created: " .. ent:GetClass())
				local t = weapons.Get( ent:GetClass() )
				if t == nil then
					--print("Registering interim weapon for: " .. ent:GetClass())
					weapons.Register({ Base = "weapon_base" }, ent:GetClass())
				end

			else

				--print("Network Entity Created: " .. ent:GetClass())
				local t = scripted_ents.Get( ent:GetClass() )
				if t == nil then
					--print("Registering interim entity for: " .. ent:GetClass())
					scripted_ents.Register({ Type = "anim" }, ent:GetClass())
				end

			end

		end

	end

end)


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

	elseif cmd == CMD_InstallMultiple then

		assert(CLIENT)

		--print("Module pack " .. len .. " bytes.")
		local stream = bpdata.InStream(false, true, true):UseStringTable()
		stream:ReadFromNet(true)

		local count = stream:ReadInt(false)
		--print("Reading " .. count .. " blueprints")

		for i=1, count do

			--print("Reading module " .. i)
			local mod = bpcompiledmodule.New():ReadFromStream( stream, STREAM_NET )
			local numInstances = stream:ReadInt(false)

			--print(numInstances .. " instances")

			local instances = {}
			for i=1, numInstances do
				instances[#instances+1] = stream:ReadStr()
			end

			--print("Loading module")
			mod:Load()
			bpenv.Install( mod )

			for _, inst in ipairs(instances) do
				bpenv.Instantiate( mod:GetUID(), inst )
			end

		end

	end

end)