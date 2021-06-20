AddCSLuaFile()

G_TransferPlayerStates = G_TransferPlayerStates or {}
G_TransferTags = G_TransferTags or {}

module("bptransfer", package.seeall)

if SERVER then
	util.AddNetworkString("bptransfer")
end

local CommandBits = 3
local CMD_PlayerReady = 0
local CMD_FileBegin = 1
local CMD_FileChunk = 2
local CMD_AckChunk = 3
local CMD_AckFile = 4
local CMD_Refresh = 5

local STATE_Idle = 0
local STATE_Active = 1
local STATE_AwaitAck = 2

local meta = bpcommon.MetaTable("bptransfer")

function meta:Init( player )

	self.pending = {}
	self.chunkSize = 0x2000
	self.chunkIndex = -1
	self.state = STATE_Idle
	self.timeout = nil
	self.player = player
	self.current = nil
	self.transferTimeout = 5

	return self

end

function meta:GetPlayer()

	return self.player

end

function meta:GetName()

	return "Downloader[" .. self.player:Nick() .. "]"

end

function meta:AddData(data, tag, name)

	local buf = NewBuffer(true)
	buf:Write(data)
	buf:Flush()

	local cacheFile = buf:GetCacheFilename()
	local f = file.Open(cacheFile, "rb", "DATA")
	if f == nil then print("Stream buffer not found") return false end

	local size = f:Size()
	local entry = {
		buffer = buf, --prevent buffer from closing
		name = name or string.GetFileFromFilename(cacheFile),
		file = f,
		chunks = math.ceil( size / self.chunkSize ),
		size = size,
		tag = tag,
	}

	entry.remaining = entry.chunks

	return self:AddEntry(entry)

end

function meta:AddFile(fileName, tag, searchPath)

	local f = file.Open(fileName, "rb", searchPath or "DATA")
	if f == nil then print("File not found: " .. fileName) return false end

	local size = f:Size()
	local entry = {
		name = string.GetFileFromFilename(fileName),
		file = f,
		chunks = math.ceil( size / self.chunkSize ),
		size = size,
		tag = tag,
	}

	entry.remaining = entry.chunks

	return self:AddEntry(entry)

end

function meta:AddEntry(entry)

	if self.filePendingAck and self.filePendingAck.name == entry.name then 
		self.filePendingAck = entry
		--print("Update ack-pending file: " .. entry.name)
		return true
	end

	for k,v in ipairs(self.pending) do
		if v.name == entry.name then 
			self.pending[k] = entry 
			--print("Update pending file: " .. entry.name) 
			return true
		end
	end

	
	self.pending[#self.pending+1] = entry
	return true

end

function meta:Update()

	if self.current == nil and self.filePendingAck == nil then
		if self.pending[1] then
			self:StartFile(self.pending[1])
		else
			self.state = STATE_Idle
		end
		return
	end

	if self.state == STATE_Idle then return end
	if self.state == STATE_AwaitAck then
		self.timeout = self.timeout - FrameTime()
		if self.timeout <= 0 then self:Cancel("Remote timed out") end
		return
	end

	local current = self.current
	if current.remaining == 0 then self:OnRemoteFinished(current) return end

	current.remaining = current.remaining - 1

	local bytes = current.file:Read(self.chunkSize)
	if bytes ~= nil then
		local len = bytes:len()
		self:SendChunk(bytes, bytes:len())
	end

	self.state = STATE_AwaitAck
	self.timeout = self.transferTimeout

end

function meta:OnRemoteFinished(entry)

	self:CloseFile()
	self.current = nil

	hook.Call("BPTransferRemoteReceived", nil, self, entry)

	if SERVER then
		--print(self:GetName() .. " finished downloading file: " .. entry.name)
	else
		--print(self:GetName() .. " finished uploading file: " .. entry.name)
	end

end

function meta:OnLocalFileFinished(data)

	hook.Call("BPTransferReceived", nil, self, data)

end

function meta:OnAckFile()

	if not self.filePendingAck then self:Cancel("No file pending") return end
	self.current = self.filePendingAck
	self.filePendingAck = nil

	self.state = STATE_Active

end

function meta:OnAckChunk(index, size)

	if self.chunkIndex == index then
		self.chunkIndex = self.chunkIndex + 1
	else
		self:Cancel("Remote acked unordered chunk")
		return
	end

	self.state = STATE_Active

end

function meta:StartFile(entry)

	self.state = STATE_AwaitAck
	self.timeout = self.transferTimeout
	self.filePendingAck = entry
	self.chunkIndex = 1

	table.remove(self.pending, 1)

	--print("Send file[" .. entry.name .. "] to " .. self:GetName() .. ": " .. entry.chunks .. " chunks " .. (1+bit.rshift(entry.size, 10)) .. " kB")

	net.Start("bptransfer")
	net.WriteUInt(CMD_FileBegin, CommandBits)
	net.WriteUInt(entry.size, 32)
	net.WriteUInt(entry.chunks, 16)
	net.WriteString(entry.name)
	net.WriteString(entry.tag)

	self:Send()

end

function meta:OnFileRequest(name, tag, size, chunks)

	--print("Remote file send request: " .. name .. " - " .. tag .. " " .. chunks .. " chunks " .. (1+bit.rshift(size, 10)) .. " kB")

	self.recv = {
		buffer = NewBuffer( true ),
		chunks = chunks,
		size = size,
		name = name,
		tag = tag,
		chunk = 0,
	}

	if hook.Call("BPTransferRequest", nil, self, self.recv) == false then
		self:Cancel("File transfer denied")
		return
	end

	net.Start("bptransfer")
	net.WriteUInt(CMD_AckFile, CommandBits)
	self:Send()

end

function meta:OnReceiveChunk(index, data, size)

	if self.recv == nil then self:Cancel("No receive buffer for chunks") return end
	self.recv.buffer:Write(data)

	--print("Recv Chunk: id:" .. index .. " size:" .. size)

	hook.Call("BPTransferProgress", nil, self, index, self.recv.chunks)

	if index == self.recv.chunks then
		self:OnLocalFileFinished(self.recv)
		self.recv = nil
		return
	end

end

function meta:SendChunk(data, size)

	net.Start("bptransfer")
	net.WriteUInt(CMD_FileChunk, CommandBits)
	net.WriteUInt(self.chunkIndex, 16)
	net.WriteUInt(size, 16)
	net.WriteData(data, size)
	self:Send()

end

function meta:Send()

	if SERVER then
		net.Send(self.player)
	else
		net.SendToServer()
	end

end

function meta:CloseFile()

	if self.current ~= nil then
		if self.current.file ~= nil then
			self.current.file:Close()
			self.current.file = nil
		end
		if self.current.buffer then
			self.current.buffer:Close()
		end
	end

end

function meta:Cancel(msg)

	hook.Call("BPTransferStopped", nil, self, msg)
	print("Transfer cancelled: " .. self:GetName() .. " [" .. tostring(self) .. "] reason: " .. tostring(msg))

	self:CloseFile()

	self.state = STATE_Idle
	self.current = nil
	self.filePendingAck = nil

end

local function TransferState(...) return bpcommon.MakeInstance(meta, ...) end

function GetState(ply)
	return G_TransferPlayerStates[ply]
end

function GetStates()
	return G_TransferPlayerStates
end

function RegisterTag(tag, info)
	G_TransferTags[tag] = info
end

function GetTag(tag)
	return G_TransferTags[tag]
end

hook.Add("Think", "BPUpdateTransfers", function()
	for k,v in pairs(G_TransferPlayerStates) do v:Update() end
end)

net.Receive("bptransfer", function(len, ply)

	local state = nil
	if SERVER then
		state = GetState(ply)
	else
		state = GetState(LocalPlayer())
	end

	local cmd = net.ReadUInt(CommandBits)

	if cmd == CMD_Refresh then
		G_TransferPlayerStates = {}
		return
	end
	
	-- Initialize player when they are ready
	if cmd == CMD_PlayerReady then
		if G_TransferPlayerStates[ply] then return end
		G_TransferPlayerStates[ply] = TransferState(ply)
		hook.Call("BPTransferStateReady", nil, ply, GetState(ply))
		--print("!!!Transfer state ready: " .. GetState(ply):GetName())
		return 
	end

	if state == nil then ErrorNoHalt("Player doesn't have a playerstate: " .. tostring(ply)) return end

	if cmd == CMD_FileBegin then
		local size = net.ReadUInt(32)
		local chunks = net.ReadUInt(16)
		local name = net.ReadString()
		local tag = net.ReadString()
		state:OnFileRequest(name, tag, size, chunks)
	end

	if cmd == CMD_FileChunk then
		local chunkIndex = net.ReadUInt(16)
		local chunkSize = net.ReadUInt(16)
		local chunkData = net.ReadData(chunkSize)
		state:OnReceiveChunk(chunkIndex, chunkData, chunkSize)
		net.Start("bptransfer")
		net.WriteUInt(CMD_AckChunk, CommandBits)
		net.WriteUInt(chunkIndex, 16)
		net.WriteUInt(chunkSize, 16)
		state:Send()
	end

	if cmd == CMD_AckChunk then
		local chunkIndex = net.ReadUInt(16)
		local chunkSize = net.ReadUInt(16)
		state:OnAckChunk(chunkIndex, chunkSize)
	end

	if cmd == CMD_AckFile then
		state:OnAckFile()
	end

end)

if SERVER then

	hook.Add("PlayerDisconnected", "BPReportPlayerDone", function(ply)
		G_TransferPlayerStates[ply] = nil
	end)

	concommand.Add("bp_refresh_transfer_states", function(ply)
		if not ply:IsAdmin() then return end
		G_TransferPlayerStates = {}
		net.Start("bptransfer")
		net.WriteUInt(CMD_Refresh, CommandBits)
		net.Broadcast()
	end)

elseif CLIENT then

	hook.Add("BPClientReady", "BPReportPlayerReady", function()
		if G_TransferPlayerStates[LocalPlayer()] == nil then

			G_TransferPlayerStates[LocalPlayer()] = TransferState(LocalPlayer())
			net.Start("bptransfer")
			net.WriteUInt(CMD_PlayerReady, CommandBits)
			net.SendToServer()

		end
	end)

	surface.CreateFont( "DownloadStatusFont", {
		font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		size = ScreenScale(10),
		weight = 500,
	} )

	surface.CreateFont( "DownloadStatusTitle", {
		font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		size = ScreenScale(15),
		weight = 500,
	} )

	local hudAlpha = 0
	local hudTargetAlpha = 0
	local hudData = {
		title = "",
		progress = 0,
		progressLerp = 0,
	}

	hook.Add("BPTransferRequest", "HUDStatus", function(state, data)
		local tag = GetTag(data.tag)
		if tag and tag.status then 
			hudData.title = tag.status 
		else
			hudData.title = "Downloading '" .. data.name .. "'"
		end
		hudTargetAlpha = 1
		hudData.progress = 0
		hudData.progressLerp = 0
	end)

	hook.Add("BPTransferProgress", "HUDStatus", function(state, chunk, num)
		hudData.progress = chunk / num
		if hudData.progress == 1 then hudData.progressLerp = 1 end
	end)

	hook.Add("BPTransferReceived", "HUDStatus", function(state, data)
		hudTargetAlpha = 0
	end)

	hook.Add("HUDPaint", "BPTransferStatus", function()

		local ft = FrameTime()
		hudAlpha = hudAlpha + (hudTargetAlpha - hudAlpha) * (1 - math.exp(ft * -5))
		hudData.progressLerp = hudData.progressLerp + (hudData.progress - hudData.progressLerp) * (1 - math.exp(ft * -3))

		local alpha = hudAlpha
		local width = ScreenScale(300)
		local height = ScreenScale(32)
		local textOffsetHorizontal = ScreenScale(3)
		local textOffsetVertical = ScreenScale(3)
		local progress = hudData.progressLerp

		local downloadStr = hudData.title .. string.rep(".", (4*CurTime()) % 3)
		local percentText = math.Round(progress*100) .. "%"
		if hudData.progress == 1 then percentText = "Done" end

		local x,y = ScrW()/2 - width/2, 30 * hudAlpha
		local w,h = width, height

		draw.RoundedBox(5, x, y, width, height, Color(0,0,0,180*alpha))
		draw.SimpleText(downloadStr, "DownloadStatusFont", ScrW()/2 - width/2 + textOffsetHorizontal, y + textOffsetVertical, Color(255,255,255,255*alpha), TEXT_ALIGN_LEFT )

		width = width - ScreenScale(30)
		height = ScreenScale(12)

		render.SetStencilEnable(true)
		render.ClearStencil()
		render.SetStencilReferenceValue( 1 )
		render.SetStencilWriteMask( 0xFF )
		render.SetStencilTestMask( 0xFF )
		render.SetStencilCompareFunction( STENCIL_ALWAYS )
		render.SetStencilPassOperation( STENCIL_REPLACE )
		render.SetStencilFailOperation( STENCIL_KEEP )
		render.SetStencilZFailOperation( STENCIL_KEEP )
		render.OverrideColorWriteEnable(true, false)
		surface.SetDrawColor(color_white)
		surface.DrawRect(ScrW()/2 - width/2, y + h - height - ScreenScale(5), width * progress+2, height+2)
		render.OverrideColorWriteEnable(false, false)
		render.SetStencilPassOperation( STENCIL_KEEP )

		render.SetStencilCompareFunction( STENCIL_EQUAL )
		draw.RoundedBox(6, ScrW()/2 - width/2, y + h - height - ScreenScale(5), width, height, Color(100,150,255,180*alpha))
		draw.SimpleText(percentText, "DownloadStatusFont", ScrW()/2, y + h - height + ScreenScale(1), Color(255,255,255,255*alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
		draw.RoundedBox(6, ScrW()/2 - width/2, y + h - height - ScreenScale(5), width, height, Color(200,200,200,180*alpha))
		draw.SimpleText(percentText, "DownloadStatusFont", ScrW()/2, y + h - height + ScreenScale(1), Color(50,50,50,255*alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

		render.SetStencilEnable(false)

	end)

end