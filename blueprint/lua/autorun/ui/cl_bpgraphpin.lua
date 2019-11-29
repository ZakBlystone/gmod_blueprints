if SERVER then AddCSLuaFile() return end

include("../sh_bpcommon.lua")
include("../sh_bpschema.lua")
include("../sh_bpgraph.lua")
include("../sh_bpnodedef.lua")

module("bpuigraphpin", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local meta = bpcommon.MetaTable("bpuigraphpin")

function meta:Init(vnode, editor, pinID, sideIndex)

	self.x = 0
	self.y = 0
	self.pinID = pinID
	self.pin = vnode:GetNode():GetPin(pinID)
	self.sideIndex = sideIndex

	return self

end

function meta:GetSideIndex()

	return self.sideIndex

end

function meta:GetPin()

	return self.pin

end

function meta:SetPos(x,y)

	self.x = x
	self.y = y

end

function meta:GetSize()

	return 10,10

end

function meta:Draw(xOffset, yOffset)

	local x,y = self.x + xOffset, self.y + yOffset

	surface.SetDrawColor( self.pin:GetColor() )
	surface.DrawRect(x,y,10,10)
	surface.SetDrawColor( Color(0,0,0,255) )

end

function New(...) return bpcommon.MakeInstance(meta, ...) end