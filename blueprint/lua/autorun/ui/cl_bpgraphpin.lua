if SERVER then AddCSLuaFile() return end

include("../sh_bpcommon.lua")
include("../sh_bpschema.lua")
include("../sh_bpgraph.lua")
include("../sh_bpnodedef.lua")

module("bpuigraphpin", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local meta = bpcommon.MetaTable("bpuigraphpin")

local TEXT_OFFSET = 4
local LITERAL_OFFSET = 10
local LITERAL_HEIGHT = 12
local PIN_SIZE = 12

function meta:Init(vnode, editor, pinID, sideIndex)

	self.x = 0
	self.y = 0
	self.pinID = pinID
	self.vnode = vnode
	self.pin = vnode:GetNode():GetPin(pinID)
	self.sideIndex = sideIndex
	self.font = "TargetID"
	self.titlePos = 0
	self.literalPos = 0

	return self

end

function meta:GetSideIndex()

	return self.sideIndex

end

function meta:GetPin()

	return self.pin

end

function meta:GetPos()

	return self.x, self.y

end

function meta:SetPos(x,y)

	self.x = x
	self.y = y

end

function meta:GetLiteralSize()

	if not self:ShouldDrawLiteral() then return 0,0 end

	local h = LITERAL_HEIGHT
	local literalType = self.pin:GetLiteralType()
	if literalType then
		if literalType == "enum" then return 100, h end
		if literalType == "string" then return 100, h end
		if literalType == "number" then return 50, h end
		if literalType == "bool" then return h, h end
		if literalType == "vector" then return 100, h end
	end
	return 0, h

end

function meta:ShouldDrawLiteral()

	if not self:IsConnected() and not self.pin:HasFlag(PNF_Table) then
		if self.pin:GetDir() == PD_In and self.pin:GetLiteralType() ~= nil then
			return true
		end
	end
	return false

end

function meta:GetSize()

	local width = PIN_SIZE
	local height = PIN_SIZE
	local node = self.vnode:GetNode()

	if not node:HasFlag(NTF_Compact) and not node:HasFlag(NTF_HidePinNames) then
		surface.SetFont( self.font )
		local title = self.pin:GetDisplayName()
		local titleWidth = surface.GetTextSize( title )
		width = width + titleWidth + TEXT_OFFSET
	end

	if self:ShouldDrawLiteral() then
		local lw, lh = self:GetLiteralSize()
		width = width + LITERAL_OFFSET + lw
		height = math.max(height, lh)
	end

	return width, height

end

function meta:Layout()

	local node = self.vnode:GetNode()
	local w,h = self:GetSize()
	local x = 0
	local d = 1
	if self.pin:IsOut() then
		x = w
		d = -1
	end

	x = x + PIN_SIZE * d

	surface.SetFont( self.font )

	if not node:HasFlag(NTF_Compact) and not node:HasFlag(NTF_HidePinNames) then
		local title = self.pin:GetDisplayName()
		local titleWidth = surface.GetTextSize( title )
		x = x + TEXT_OFFSET * d
		if self.pin:IsOut() then x = x + titleWidth * d end
		self.titlePos = x
		x = x + titleWidth * d
	end

	if not self:IsConnected() then
		self.literalPos = LITERAL_OFFSET + x
	end

end

function meta:GetHotspotOffset()

	local w,h = self:GetSize()
	if self.pin:IsIn() then
		return PIN_SIZE/2, PIN_SIZE/2 + (h - PIN_SIZE)/2
	else
		local w,h = self:GetSize()
		return w-PIN_SIZE/2, PIN_SIZE/2 + (h - PIN_SIZE)/2
	end

end

function meta:IsConnected()

	local node = self.vnode:GetNode()
	local graph = node.graph
	return graph:IsPinConnected( node.id, self.pinID )

end

function meta:DrawLiteral(x, y, str)

	local node = self.vnode:GetNode()
	local font = self.font
	if self.pin:GetDir() == PD_In and not self.pin:HasFlag(PNF_Table) then
		local literalType = self.pin:GetLiteralType()
		if literalType then
			self.literalType = literalType
			local literal = node:GetLiteral(self.pinID) or ""

			local w, h = self:GetLiteralSize()
			surface.SetDrawColor( Color(50,50,50,255) )
			surface.DrawRect(x + self.literalPos,y,w,h)

			draw.SimpleText(literal, font, x + self.literalPos, y+PIN_SIZE/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	--surface.SetDrawColor( Color(255,255,255) )
	--surface.DrawRect(x,y,10,10)

end

function meta:DrawHotspot(x,y)

	local ox, oy = self:GetHotspotOffset()

	surface.SetDrawColor( self.pin:GetColor() )
	surface.DrawRect(x+ox-PIN_SIZE/2,y+oy-PIN_SIZE/2,PIN_SIZE,PIN_SIZE)
	surface.SetDrawColor( Color(0,0,0,255) )

end

function meta:Draw(xOffset, yOffset)

	self:Layout()

	local x,y = self.x + xOffset, self.y + yOffset
	local w,h = self:GetSize()
	local ox, oy = self:GetHotspotOffset()
	local node = self.vnode:GetNode()
	local font = self.font

	self:DrawHotspot(x,y)
	if not self:IsConnected() then self:DrawLiteral(x,y) end

	--surface.SetDrawColor( Color(255,100,200,80) )
	--surface.DrawRect(x,y,w,h)

	surface.SetFont( font )

	local title = self.pin:GetDisplayName()
	local titleWidth = surface.GetTextSize( title )

	render.PushFilterMag( TEXFILTER.LINEAR )
	render.PushFilterMin( TEXFILTER.LINEAR )

	if not node:HasFlag(NTF_Compact) and not node:HasFlag(NTF_HidePinNames) then
		if self.pin:IsIn() then
			draw.SimpleText(title, font, x + self.titlePos, y+PIN_SIZE/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(title, font, x + self.titlePos, y+PIN_SIZE/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	render.PopFilterMag()
	render.PopFilterMin()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end