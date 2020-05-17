if SERVER then AddCSLuaFile() return end

module("bpuidpreview", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local PANEL = {}

function PANEL:Init()

end

function PANEL:Draw2D()

end

derma.DefineControl( "BPDPreview", "Blueprint derma preview renderer", PANEL, "BPViewport2D" )
