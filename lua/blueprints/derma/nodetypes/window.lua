AddCSLuaFile()

module("dnode_window", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DFrame"

function NODE:Setup() 

	self.data = {
		width = 400,
		height = 300,
		title = "Window",
	}

end

RegisterDermaNodeClass("Window", NODE)