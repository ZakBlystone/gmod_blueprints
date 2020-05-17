AddCSLuaFile()

module("dnode_window", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:Compile(compiler, pass)

end

RegisterDermaNodeClass("Window", NODE)