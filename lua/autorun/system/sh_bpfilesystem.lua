AddCSLuaFile()

module("bpfilesystem", package.seeall)

local meta = bpcommon.MetaTable("bpfilesystem")

local LIST_INDEX_SERVER = 0
local LIST_INDEX_CLIENT = 1

function meta:Init( index, name )

	local list = bplist.New():Constructor(bpfile.New):NamedItems():SetSanitizer( bpfile.Sanitizer )
	self.files = bpnetlist.Register(index, "filesystem_" .. name, list)

	return self

end

function meta:GetFiles()

	return self.files

end

function New(...) return bpcommon.MakeInstance(meta, ...) end

_G.G_FS_Server = New(LIST_INDEX_SERVER, "server")
_G.G_FS_Client = New(LIST_INDEX_CLIENT, "client")