if SERVER then AddCSLuaFile() return end

include("../sh_bpcommon.lua")
include("../sh_bpschema.lua")
include("../sh_bpgraph.lua")
include("../sh_bpnodedef.lua")
include("cl_bpgraphpin.lua")

module("bpuigraphnode", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))