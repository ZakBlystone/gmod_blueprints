AddCSLuaFile()

module("dnode_button", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:Compile(compiler, pass)

end

RegisterDermaNodeClass("Button", NODE)