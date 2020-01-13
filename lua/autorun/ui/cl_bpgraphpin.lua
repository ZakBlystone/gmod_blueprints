if SERVER then AddCSLuaFile() return end

module("bpuigraphpin", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local meta = bpcommon.MetaTable("bpuigraphpin")

local TEXT_OFFSET = 8
local LITERAL_OFFSET = 10
local LITERAL_HEIGHT = 24
local LITERAL_MIN_WIDTH = 40
local LITERAL_MAX_WIDTH = 300
local PIN_SIZE = 24
local PIN_HITBOX_EXPAND = 8
local PIN_LITERAL_HITBOX_EXPAND = 8

function meta:Init(vnode, pinID, sideIndex)

	self.x = 0
	self.y = 0
	self.currentPinType = nil
	self.pinID = pinID
	self.vnode = vnode
	self.pin = vnode:GetNode():GetPin(pinID)
	self.sideIndex = sideIndex
	self.font = "NodePinFont"
	self.titlePos = nil
	self.literalPos = nil
	self.cacheWidth = nil
	self.cacheHeight = nil
	self.connections = self.pin:GetConnectedPins()

	return self

end

function meta:GetConnections()

	return self.connections

end

function meta:GetVNode()

	return self.vnode

end

function meta:GetSideIndex()

	return self.sideIndex

end

function meta:GetPinID()

	return self.pinID

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

	local font = self.font
	surface.SetFont(font)

	local literalType = self.pin:GetLiteralType()
	local value = self:GetLiteralValue()
	local h = LITERAL_HEIGHT
	local w = surface.GetTextSize(value)
	if literalType then
		if literalType == "enum" then return math.Clamp( w, LITERAL_MIN_WIDTH, LITERAL_MAX_WIDTH ), h end
		if literalType == "string" then return math.Clamp( w, LITERAL_MIN_WIDTH, LITERAL_MAX_WIDTH ), h end
		if literalType == "number" then return math.Clamp( w, LITERAL_MIN_WIDTH, LITERAL_MAX_WIDTH ), h end
		if literalType == "bool" then return h, h end
		--if literalType == "vector" then return 100, h end
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

function meta:Invalidate()

	self.cacheWidth = nil
	self.cacheHeight = nil
	self.titlePos = nil
	self.literalPos = nil
	self.connections = self.pin:GetConnectedPins()

end

function meta:GetSize()

	if self.cacheWidth and self.cacheHeight then 
		return self.cacheWidth, self.cacheHeight 
	end

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

	self.cacheWidth = width
	self.cacheHeight = height

	return width, height

end

function meta:Layout()

	if self.titlePos and self.literalPos then return end

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

function meta:GetHitBox()

	local nx,ny = self.vnode:GetPos()
	local x,y = self:GetPos()
	local w,h = PIN_SIZE, PIN_SIZE
	local hx,hy = self:GetHotspotOffset()
	local ex = PIN_HITBOX_EXPAND
	return nx+x+hx-PIN_SIZE/2-ex/2,ny+y+hy-PIN_SIZE/2-ex/2,w+ex,h+ex

end

function meta:GetLiteralHitBox()

	if self:ShouldDrawLiteral() then
		local ex = PIN_LITERAL_HITBOX_EXPAND
		local nx,ny = self.vnode:GetPos()
		local x,y = self:GetPos()
		local lw, lh = self:GetLiteralSize()

		return x+nx+self.literalPos-ex/2,y+ny-ex/2,lw+ex,lh+ex
	end

	return 0,0,0,0

end

function meta:IsConnected()

	local node = self.vnode:GetNode()
	local graph = node.graph
	return graph:IsPinConnected( node.id, self.pinID )

end

function meta:GetLiteralValue()

	local node = self.vnode:GetNode()
	local literalType = self.pin:GetLiteralType()
	if not literalType then return "" end

	local literal = node:GetLiteral(self.pinID) or "!!!UNASSIGNED LITERAL!!!"

	if literalType == "bool" then
		literal = (literal == "true") and "X" or ""
	elseif literalType == "enum" then
		local enum = bpdefs.Get():GetEnum( self:GetPin() )
		if enum then
			local key = enum.lookup[literal]
			if key then literal = enum.entries[key].shortkey end
		end
	end

	return literal

end

function meta:DrawLiteral(x, y, alpha)

	local node = self.vnode:GetNode()
	local font = self.font
	if self.pin:GetDir() == PD_In and not self.pin:HasFlag(PNF_Table) then
		local literalType = self.pin:GetLiteralType()
		if literalType then
			local literal = self:GetLiteralValue()

			local w, h = self:GetLiteralSize()
			surface.SetDrawColor( Color(50,50,50,150*alpha) )
			surface.DrawRect(x + self.literalPos,y,w,h)

			draw.SimpleText(literal, font, x + self.literalPos, y+PIN_SIZE/2, Color(255,255,255,255*alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	--surface.SetDrawColor( Color(255,255,255) )
	--surface.DrawRect(x,y,10,10)

end

function meta:DrawHotspot(x,y,alpha)

	local ox, oy = self:GetHotspotOffset()
	local isTable = self.pin:HasFlag(PNF_Table)

	local col = self.pin:GetColor()

	surface.SetDrawColor( Color(col.r, col.g, col.b, 255 * alpha) )
	surface.DrawRect(x+ox-PIN_SIZE/2,y+oy-PIN_SIZE/2,PIN_SIZE,PIN_SIZE)
	surface.SetDrawColor( Color(0,0,0,255) )

	if isTable then
		surface.DrawRect(x+ox - 2,y+oy-PIN_SIZE/2,4,PIN_SIZE)
		surface.DrawRect(x+ox+PIN_SIZE*.25 - 2,y+oy-PIN_SIZE/2,4,PIN_SIZE)
		surface.DrawRect(x+ox-PIN_SIZE*.25 - 2,y+oy-PIN_SIZE/2,4,PIN_SIZE)
	end

end

function meta:DrawHitBox()

	surface.SetDrawColor( Color(255,100,200,80) )
	local hx,hy,hw,hh = self:GetLiteralHitBox()
	surface.DrawRect(hx,hy,hw,hh)

end

function meta:Draw(xOffset, yOffset, alpha)

	if self.currentPinType == nil or not self.currentPinType:Equal(self.pin:GetType()) then
		self:Invalidate()
		self.currentPinType = table.Copy( self.pin:GetType() )
		self.vnode:Invalidate()
		--print("PIN TYPE CHANGED")
	end

	self:Layout()

	local x,y = self:GetPos()
	local w,h = self:GetSize()
	local ox, oy = self:GetHotspotOffset()
	local node = self.vnode:GetNode()
	local font = self.font

	x = x + xOffset
	y = y + yOffset

	self:DrawHotspot(x,y,alpha)

	--render.PushFilterMag( TEXFILTER.LINEAR )
	--render.PushFilterMin( TEXFILTER.LINEAR )

	if not self:IsConnected() then self:DrawLiteral(x,y,alpha) end

	--self:DrawHitBox()

	surface.SetFont( font )

	local title = self.pin:GetDisplayName()
	local titleWidth = surface.GetTextSize( title )

	if not node:HasFlag(NTF_Compact) and not node:HasFlag(NTF_HidePinNames) then
		if self.pin:IsIn() then
			draw.SimpleText(title, font, x + self.titlePos, y+PIN_SIZE/2, Color(255,255,255,255*alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(title, font, x + self.titlePos, y+PIN_SIZE/2, Color(255,255,255,255*alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	--render.PopFilterMag()
	--render.PopFilterMin()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end