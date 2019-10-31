if SERVER then AddCSLuaFile() return end

include("../sh_bpcommon.lua")
include("../sh_bpschema.lua")
include("../sh_bpgraph.lua")
include("../sh_bpnodedef.lua")

module("bpuigraphpin", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

print("PIN")