AddCSLuaFile()

G_BPFiles = G_BPFiles or {}
G_BPLocalFiles = G_BPLocalFiles or {}

module("bpfilesystem", package.seeall, bpcommon.rescope( bpcommon ))

FT_Local = 0
FT_Remote = 1

local CommandBits = 4
local CMD_UpdateFileTable = 0

local FileDirectory = "blueprints/server/"
local FileIndex = FileDirectory .. "__index.txt"
local FileIndexVersion = 1

local ClientFileDirectory = "blueprints/client/"

if SERVER then
	file.CreateDir(FileDirectory)
	util.AddNetworkString("bpfilesystem")
else
	file.CreateDir(ClientFileDirectory)
end

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
	return file

end

function IndexLocalFiles()

	assert(CLIENT)

	local files, _ = file.Find(ClientFileDirectory .. "*", "DATA")

	G_BPLocalFiles = {}
	for _, f in ipairs(files) do

		local head = bpmodule.LoadHeader(ClientFileDirectory .. f)
		local entry = FindRemoteFile( bpfile.New(head.uid, bpfile.FT_Module, f) )
		entry:SetPath( ClientFileDirectory .. f )
		G_BPLocalFiles[#G_BPLocalFiles+1] = entry

	end

	hook.Run("BPFileTableUpdated", FT_Local)

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

	PushFiles()

end


if SERVER then

	hook.Add("BPClientReady", "bpfilesystem", function(ply)
		print("CLIENT READY, PUSH FILES: " .. tostring(ply) .. " " .. #G_BPFiles)
		PushFiles(ply)
	end)

	hook.Add("BPTransferRequest", "bpfilesystem", function(state, data)
		print( tostring( state:GetPlayer() ) )
		if data.tag == "module" then return true end
	end)

	hook.Add("BPTransferReceived", "bpfilesystem", function(state, data)
		if data.tag == "module" then

			local owner = bpusermanager.FindUserForPlayer( state:GetPlayer() )
			if owner == nil then error("Unable to get user for file owner") end

			local moduleData = data.buffer:GetString()
			local stream = bpdata.InStream(false, true):UseStringTable()
			if not stream:LoadString(moduleData, true, false) then error("Failed to load file locally") end

			local name = bpdata.ReadValue(stream)
			local mod = bpmodule.New():ReadFromStream(stream, STREAM_NET)
			local filename = UIDToModulePath( mod:GetUID() )
			mod:Save(filename)

			local entry = bpfile.New( mod:GetUID(), bpfile.FT_Module )
			entry:SetOwner( owner )
			entry:SetName( name )
			entry:TakeLock( owner )

			print("Module uploaded: " .. tostring(name) .. " -> " .. filename)

			AddFile(entry)
			SaveIndex()

		end
	end)

else

	hook.Add("BPClientReady", "bpfilesystem", function()
		IndexLocalFiles()
	end)

end

function UploadObject( object, name )

	assert( CLIENT )
	assert( isbpmodule(object) )

	local stream = bpdata.OutStream(false, true, true):UseStringTable()

	bpdata.WriteValue(name, stream)
	object:WriteToStream(stream, STREAM_NET)

	local data = stream:GetString(true, false)
	local transfer = bptransfer.GetState(LocalPlayer())
	if not transfer:AddData(data, "module", "test") then
		print("Failed to add file to transfer")
	end

end

net.Receive("bpfilesystem", function(len, ply)

	local cmd = net.ReadUInt(CommandBits)
	if cmd == CMD_UpdateFileTable then
		local stream = bpdata.InStream(false, true)
		stream:ReadFromNet(true)
		G_BPFiles = bpdata.ReadArray(bpfile_meta, stream, STREAM_NET)
		print("Updated remote files: " .. #G_BPFiles)
		hook.Run("BPFileTableUpdated", FT_Remote)

		IndexLocalFiles()
	end

end)

if CLIENT then

	concommand.Add("bp_uploadtest", function(p,c,a)

		if not a[1] then return end

		local mod = bpmodule.New()
		mod:Load("blueprints/bpm_" .. a[1] .. ".txt")

		print("Try uploading module")
		UploadObject( mod, a[1] )

	end)

end

if SERVER then
	
	LoadIndex()
	hook.Add("Initialize", "bpfilesystem", function()
		LoadIndex()
	end)

else

	IndexLocalFiles()

end