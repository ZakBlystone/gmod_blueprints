AddCSLuaFile()

module("dnode_window", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

NODE.DermaBase = "DWindow"

function NODE:Setup() 

	self.data = {
		width = 400,
		height = 300,
		title = "Window",
	}

end

RegisterDermaNodeClass("Window", NODE)