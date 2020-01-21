AddCSLuaFile()

module("bpnet", package.seeall, bpcommon.rescope(bpcompiler, bpcommon))

local CommandBits = 4
local CMD_Install = 0
local CMD_Uninstall = 1
local CMD_Instantiate = 2
local CMD_Destroy = 3

local CompileFlags = CF_Default
local PlayerKey = bpcommon.PlayerKey

if SERVER then
	util.AddNetworkString("bpnet")
end

local function ErrorHandler( bp, msg, graphID, nodeID )


end
hook.Add("BPModuleError", "bpnetHandleError", ErrorHandler)

function Install( mod )

	assert(SERVER)

	local instanceUID = bpcommon.GUID()

	mod:Load()

	bpenv.Install( mod )
	bpenv.Instantiate( mod:GetUID(), instanceUID )

	local stream = bpdata.OutStream(false, true, true):UseStringTable()
	mod:WriteToStream(stream, STREAM_NET)

	net.Start("bpnet")
	net.WriteUInt( CMD_Install, CommandBits )
	net.WriteData( instanceUID, 16 )
	stream:WriteToNet(true)
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

	end

end)