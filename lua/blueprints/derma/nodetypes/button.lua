AddCSLuaFile()

module("dnode_button", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end

RegisterDermaNodeClass("Button", NODE)