AddCSLuaFile()

G_BPFiles = G_BPFiles or {}
G_BPLocalFiles = G_BPLocalFiles or {}

module("bpfilesystem", package.seeall, bpcommon.rescope( bpcommon ))

FT_Local = 0
FT_Remote = 1

local CommandBits = 4
local CMD_AckClientCmd = 0
local CMD_UpdateFileTable = 1
local CMD_TakeLock = 2
local CMD_ReleaseLock = 3
local CMD_RunFile = 4
local CMD_StopFile = 5
local CMD_DeleteFile = 6
local CMD_DownloadFile = 7
local CMD_AckUpload = 8

local FileDirectory = "blueprints/server/"
local FileIndex = FileDirectory .. "__index.txt"
local FileIndexVersion = 1

local ClientFileDirectory = "blueprints/client/"
local ClientPendingCommands = {}

if SERVER then
	file.CreateDir(FileDirectory)
	util.AddNetworkString("bpfilesystem")
else
	file.CreateDir(ClientFileDirectory)
end

function ModuleNameToFilename( name )

	return "bpm_" .. name .. ".txt"

end

function ModulePathToName( path )

	local _, _, name = path:find("bpm_([%w_]+).txt$")
	return name

end

function GetClientDirectory() return ClientFileDirectory end
function GetFiles() return G_BPFiles end
function GetLocalFiles() return G_BPLocalFiles end

local function UIDToModulePath( uid )

	return FileDirectory .. bpcommon.GUIDToString( uid, true ) .. ".txt"

end

local function FindRemoteFile( file )

	assert(CLIENT)

	for _, f in ipairs( GetFiles() ) do
		if f == file then return f end
	end

end

local function FindFileByUID( uid )

	print("Find File " .. bpcommon.GUIDToString(uid))

	for _, f in ipairs( GetFiles() ) do
		if f:GetUID() == uid then return f end
	end
	return nil

end

function IndexLocalFiles( refresh )

	assert(CLIENT)

	print("Indexing")

	if refresh then
		G_BPLocalFiles = {}
	end

	local files, _ = file.Find(ClientFileDirectory .. "*", "DATA")

	local persist = {}
	for _, f in ipairs(files) do

		local head = bpmodule.LoadHeader(ClientFileDirectory .. f)
		local existing = G_BPLocalFiles[head.uid]
		if not existing then

			local entry = bpfile.New(head.uid, bpfile.FT_Module, f)
			entry:SetPath( ClientFileDirectory .. f )
			entry:SetRevision( head.revision )
			G_BPLocalFiles[head.uid] = entry

		else

			existing:SetName(f)

		end

		persist[head.uid] = true

	end

	for k,v in pairs(G_BPLocalFiles) do

		if not persist[k] then 
			G_BPLocalFiles[k] = nil
		else
			local remote = FindRemoteFile( v )
			if remote then 
				remote:CopyRemoteToLocal( v )
			else
				v:ForgetRemote()
			end
		end

	end

	local totalFileCount = 0
	for k,v in pairs(G_BPLocalFiles) do
		totalFileCount = totalFileCount + 1
	end
	print("TOTAL LOCAL FILES: " .. totalFileCount)

	hook.Run("BPFileTableUpdated", FT_Local)

end

function NewModuleFile( name )

	local fileName = ModuleNameToFilename(name)
	local path = ClientFileDirectory .. fileName

	if file.Exists( path, "DATA" ) then
		return nil
	end

	local mod = bpmodule.New()
	mod:CreateDefaults()
	mod:Save( path )
	local entry = bpfile.New(mod:GetUID(), bpfile.FT_Module, fileName)
	entry:SetPath( path )
	G_BPLocalFiles[mod:GetUID()] = entry
	hook.Run("BPFileTableUpdated", FT_Local)

	return entry

end

local function PushFiles(ply)

	assert(SERVER)

	print("FileTable: " .. #G_BPFiles)

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_UpdateFileTable, CommandBits)

	local stream = bpdata.OutStream(false, true)
	bpdata.WriteArray(bpfile_meta, G_BPFiles, stream, STREAM_NET)
	stream:WriteToNet(true)
	if ply then net.Send(ply) else net.Broadcast() end

end

local function SaveIndex()

	local stream = bpdata.OutStream(false, true)
	stream:WriteInt(FileIndexVersion, false)
	bpdata.WriteArray(bpfile_meta, G_BPFiles, stream, STREAM_FILE)
	stream:WriteToFile( FileIndex, false, false )

end

local function LoadIndex()

	if file.Exists( FileIndex, "DATA" ) then

		local stream = bpdata.InStream(false, true)
		stream:LoadFile( FileIndex, false, false )
		local version = stream:ReadInt(false)
		G_BPFiles = bpdata.ReadArray(bpfile_meta, stream, STREAM_FILE)

		for _, f in ipairs(G_BPFiles) do
			local path = UIDToModulePath( f:GetUID() )
			local head = bpmodule.LoadHeader( path )
			if bpenv.NumRunningInstances( f:GetUID() ) > 0 then
				f:SetFlag( bpfile.FL_Running )
			end
			f:SetPath( path )
			f:SetRevision( head.revision )
		end

		print("Loaded file index: " .. #G_BPFiles)

		PushFiles()

	else

		G_BPFiles = {}
		PushFiles()

	end

end

local function AddFile( newFile )

	assert(SERVER)

	newFile:SetFlag(bpfile.FL_IsServerFile)

	for i, file in ipairs(G_BPFiles) do
		if file == newFile then
			G_BPFiles[i] = newFile
			return
		end
	end

	G_BPFiles[#G_BPFiles+1] = newFile

end

local function RunLocalFile( file )

	local modulePath = UIDToModulePath( file:GetUID() )
	local mod = bpmodule.New()
	mod:Load( modulePath )
	local cmod = mod:Compile( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )

	bpnet.Install( cmod )

	file:SetFlag(bpfile.FL_Running)

end

local function StopLocalFile( file )

	bpnet.Uninstall( file:GetUID() )

	file:ClearFlag(bpfile.FL_Running)

end

local function DeleteLocalFile( fileObject )

	for i, f in ipairs(G_BPFiles) do
		if f == fileObject then
			bpnet.Uninstall( fileObject:GetUID() )
			file.Delete( fileObject:GetPath() )
			table.remove( G_BPFiles, i )
			break
		end
	end

	SaveIndex()

end

local function DownloadLocalFile( file, ply )

	local state = bptransfer.GetState( ply )
	local stream = bpdata.OutStream(false, true, true):UseStringTable()

	local modulePath = UIDToModulePath( file:GetUID() )
	local mod = bpmodule.New()
	mod:Load( modulePath )
	mod:WriteToStream(stream, STREAM_NET)

	local data = stream:GetString(true, false)
	if not state:AddData(data, "module", file:GetName()) then
		return false
	end

	return true

end

if SERVER then

	hook.Add("BPClientReady", "bpfilesystem", function(ply)
		print("CLIENT READY, PUSH FILES: " .. tostring(ply) .. " " .. #G_BPFiles)
		PushFiles(ply)
	end)

	hook.Add("BPTransferRequest", "bpfilesystem", function(state, data)
		print( tostring( state:GetPlayer() ) )
		if data.tag == "module" then
			local user = bpusermanager.FindUserForPlayer( state:GetPlayer() )
			if not user:HasPermission(bpgroup.FL_CanUpload) then return false end
		end
	end)

	hook.Add("BPTransferReceived", "bpfilesystem", function(state, data)
		if data.tag == "module" then

			local owner = bpusermanager.FindUserForPlayer( state:GetPlayer() )
			if owner == nil then error("Unable to get user for file owner") end

			local moduleData = data.buffer:GetString()
			local stream = bpdata.InStream(false, true):UseStringTable()
			if not stream:LoadString(moduleData, true, false) then error("Failed to load file locally") end

			local execute = bpdata.ReadValue(stream)
			local name = bpdata.ReadValue(stream)
			local mod = bpmodule.New():ReadFromStream(stream, STREAM_NET)
			local filename = UIDToModulePath( mod:GetUID() )
			local file = FindFileByUID( mod:GetUID() )

			if file then

				if not file:CanTakeLock( owner ) then 
					error("User does not have lock on file") 
				end

			else

				local entry = bpfile.New( mod:GetUID(), bpfile.FT_Module )
				entry:SetOwner( owner )
				entry:SetName( name )
				entry:SetPath( filename )
				entry:TakeLock( owner )
				AddFile(entry)

				file = entry

			end

			mod.revision = mod.revision + 1
			print("Module increment revision: " .. mod.revision)
			mod:Save(filename)

			file:SetRevision( mod.revision )

			net.Start("bpfilesystem")
			net.WriteUInt(CMD_AckUpload, CommandBits)
			net.WriteData(mod:GetUID(), 16)
			net.WriteUInt(mod.revision, 32)
			net.Send( state:GetPlayer() )

			print("Module uploaded: " .. tostring(name) .. " -> " .. filename)
			print("Module marked for execute: " .. tostring(execute))

			if execute and owner:HasPermission(bpgroup.FL_CanToggle) then
				RunLocalFile( file )
			end

			SaveIndex()
			PushFiles()

		end
	end)

else

	hook.Add("BPTransferReceived", "bpfilesystem", function(state, data)
		if data.tag == "module" then

			local moduleData = data.buffer:GetString()
			local stream = bpdata.InStream(false, true):UseStringTable()
			if not stream:LoadString(moduleData, true, false) then error("Failed to load file locally") end

			local path = ClientFileDirectory .. ModuleNameToFilename(data.name)
			local mod = bpmodule.New()
			mod:ReadFromStream( stream, STREAM_NET )

			if file.Exists(path, "DATA") then
				local head = bpmodule.LoadHeader(path)
				if mod:GetUID() == head.uid then
					if mod.revision >= head.revision then
						print("Updated local copy : " .. path)
						mod:Save( path )
						local f = G_BPLocalFiles[ mod:GetUID() ]
						f:SetRevision( mod.revision )
					else
						print("Local module is newer : " .. path)
					end
				else
					print("Unmatched module with same path : " .. bpcommon.GUIDToString( head.uid ) .. " <<-- " .. bpcommon.GUIDToString( mod:GetUID() ))
				end
			else
				mod:Save( path )

				local entry = bpfile.New(mod:GetUID(), bpfile.FT_Module, path)
				entry:SetPath( path )
				entry:SetRevision( mod.revision )
				G_BPLocalFiles[mod:GetUID()] = entry
			end

			IndexLocalFiles()

		end
	end)

	hook.Add("BPClientReady", "bpfilesystem", function()
		IndexLocalFiles()
	end)

end

local function ClientCommand( callback, cmd )

	if ClientPendingCommands[cmd] then
		ClientPendingCommands[cmd].callback(false, "Timed out")
	end

	local nop = function() end

	ClientPendingCommands[cmd] = {
		callback = callback or nop,
		cmd = cmd,
		time = CurTime(),
	}

end

local function AckClientCommand( ply, cmd, result )

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_AckClientCmd, CommandBits)
	net.WriteUInt(cmd, CommandBits)
	net.WriteBool(result ~= nil)
	if result then net.WriteString(result) end
	net.Send(ply)

end

function MarkFileAsChanged( file, changed )

	if changed == nil then changed = true end

	assert( CLIENT )
	if changed == file:HasFlag( bpfile.FL_HasLocalChanges ) then return end
	if changed then file:SetFlag( bpfile.FL_HasLocalChanges ) else file:ClearFlag( bpfile.FL_HasLocalChanges ) end
	IndexLocalFiles()

end

function UploadObject( object, name, execute )

	assert( CLIENT )
	assert( isbpmodule(object) )

	local stream = bpdata.OutStream(false, true, true):UseStringTable()

	bpdata.WriteValue(execute, stream)
	bpdata.WriteValue(name, stream)
	object:WriteToStream(stream, STREAM_NET)

	local data = stream:GetString(true, false)
	local transfer = bptransfer.GetState(LocalPlayer())
	if not transfer:AddData(data, "module", "test") then
		print("Failed to add file to transfer")
	end

end

function TakeLock( file, callback )

	assert(CLIENT)

	ClientCommand( callback, CMD_TakeLock )

	local localFile = G_BPLocalFiles[file:GetUID()]
	if localFile == nil then return end

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_TakeLock, CommandBits)
	net.WriteData(localFile:GetUID(), 16)
	net.WriteUInt(localFile:GetRevision(), 32)
	net.SendToServer()

end

function ReleaseLock( file, callback )

	assert(CLIENT)

	ClientCommand( callback, CMD_ReleaseLock )

	local localFile = G_BPLocalFiles[file:GetUID()]
	if localFile == nil then return end

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_ReleaseLock, CommandBits)
	net.WriteData(localFile:GetUID(), 16)
	net.SendToServer()

end

function RunFile( file, callback )

	assert(CLIENT)

	ClientCommand( callback, CMD_RunFile )

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_RunFile, CommandBits)
	net.WriteData(file:GetUID(), 16)
	net.SendToServer()

end

function StopFile( file, callback )

	assert(CLIENT)

	ClientCommand( callback, CMD_StopFile )

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_StopFile, CommandBits)
	net.WriteData(file:GetUID(), 16)
	net.SendToServer()

end

function DeleteFile( file, callback )

	assert(CLIENT)

	ClientCommand( callback, CMD_DeleteFile )

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_DeleteFile, CommandBits)
	net.WriteData(file:GetUID(), 16)
	net.SendToServer()

end

function DownloadFile( file, callback )

	assert(CLIENT)

	ClientCommand( callback, CMD_DownloadFile )

	net.Start("bpfilesystem")
	net.WriteUInt(CMD_DownloadFile, CommandBits)
	net.WriteData(file:GetUID(), 16)
	net.SendToServer()

end

net.Receive("bpfilesystem", function(len, ply)

	local cmd = net.ReadUInt(CommandBits)
	if cmd == CMD_AckClientCmd then
		local cc = net.ReadUInt(CommandBits)
		local res = net.ReadBool()
		local str = nil
		if res then str = net.ReadString() end
		local v = ClientPendingCommands[cc]
		if v then v.callback( not res, str ) end
		ClientPendingCommands[cc] = nil
	elseif cmd == CMD_UpdateFileTable then
		local stream = bpdata.InStream(false, true)
		stream:ReadFromNet(true)
		G_BPFiles = bpdata.ReadArray(bpfile_meta, stream, STREAM_NET)
		print("Updated remote files: " .. #G_BPFiles)
		hook.Run("BPFileTableUpdated", FT_Remote)
		IndexLocalFiles()
	elseif cmd == CMD_TakeLock then
		assert(SERVER)
		local user = bpusermanager.FindUserForPlayer( ply )
		if not user then AckClientCommand(ply, cmd, "Not logged in") return end
		local file = FindFileByUID(net.ReadData(16))
		if not file then AckClientCommand(ply, cmd, "File not found") return end
		if not file:CanTakeLock(user) then AckClientCommand(ply, cmd, "File is locked by someone else") return end
		local remoteRev = net.ReadUInt(32)
		if file:GetRevision() > remoteRev then AckClientCommand(ply, cmd, "Your file is older than the server's, download latest") return end
		file:TakeLock(user)
		AckClientCommand(ply, cmd)
		SaveIndex()
		PushFiles()
	elseif cmd == CMD_ReleaseLock then
		assert(SERVER)
		local user = bpusermanager.FindUserForPlayer( ply )
		if not user then AckClientCommand(ply, cmd, "Not logged in") return end
		local file = FindFileByUID(net.ReadData(16))
		if not file then AckClientCommand(ply, cmd, "File not found") return end
		if not file:CanTakeLock(user) then AckClientCommand(ply, cmd, "File is locked by someone else") return end
		file:ReleaseLock()
		AckClientCommand(ply, cmd)
		SaveIndex()
		PushFiles()
	elseif cmd == CMD_RunFile then
		assert(SERVER)
		local user = bpusermanager.FindUserForPlayer( ply )
		if not user then AckClientCommand(ply, cmd, "Not logged in") return end
		local file = FindFileByUID(net.ReadData(16))
		if not file then AckClientCommand(ply, cmd, "File not found") return end
		if not user:HasPermission(bpgroup.FL_CanToggle) then AckClientCommand(ply, cmd, "Insufficient Permissions") return end
		RunLocalFile( file )
		AckClientCommand(ply, cmd)
		PushFiles()
	elseif cmd == CMD_StopFile then
		assert(SERVER)
		local user = bpusermanager.FindUserForPlayer( ply )
		if not user then AckClientCommand(ply, cmd, "Not logged in") return end
		local file = FindFileByUID(net.ReadData(16))
		if not file then AckClientCommand(ply, cmd, "File not found") return end
		if not user:HasPermission(bpgroup.FL_CanToggle) then AckClientCommand(ply, cmd, "Insufficient Permissions") return end
		StopLocalFile( file )
		AckClientCommand(ply, cmd)
		PushFiles()
	elseif cmd == CMD_DeleteFile then
		assert(SERVER)
		local user = bpusermanager.FindUserForPlayer( ply )
		if not user then AckClientCommand(ply, cmd, "Not logged in") return end
		local file = FindFileByUID(net.ReadData(16))
		if not file then AckClientCommand(ply, cmd, "File not found") return end
		if not file:CanTakeLock(user) and not user:HasPermission(bpgroup.FL_CanDelete) then AckClientCommand(ply, cmd, "Insufficient Permissions") return end
		DeleteLocalFile( file )
		AckClientCommand(ply, cmd)
		PushFiles()
	elseif cmd == CMD_DownloadFile then
		assert(SERVER)
		local user = bpusermanager.FindUserForPlayer( ply )
		if not user then AckClientCommand(ply, cmd, "Not logged in") return end
		local file = FindFileByUID(net.ReadData(16))
		if not file then AckClientCommand(ply, cmd, "File not found") return end
		if not file:CanTakeLock(user) then AckClientCommand(ply, cmd, "File is locked by someone else") return end
		if DownloadLocalFile( file, ply ) then
			AckClientCommand(ply, cmd)
		else
			AckClientCommand(ply, cmd, "Failed to download file")
		end
	elseif cmd == CMD_AckUpload then
		assert(CLIENT)
		local uid = net.ReadData(16)
		local rev = net.ReadUInt(32)
		local file = G_BPLocalFiles[uid]
		if file then
			local mod = bpmodule.New()
			mod:Load( file:GetPath() )
			assert(mod.revision <= rev)
			mod.revision = rev
			mod:Save( file:GetPath() )
			file:SetRevision( rev )
			IndexLocalFiles()
		end
	end

end)

if SERVER then
	
	LoadIndex()
	hook.Add("Initialize", "bpfilesystem", function()
		LoadIndex()
	end)

else

	IndexLocalFiles()
	hook.Add("Think", "bpfilesystem", function()
		for k,v in pairs(ClientPendingCommands) do
			if CurTime() - v.time > 5 then
				ClientPendingCommands[k].callback(false, "Timed Out")
				ClientPendingCommands[k] = nil
			end
		end
	end)

end