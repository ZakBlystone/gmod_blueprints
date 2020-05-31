if SERVER then AddCSLuaFile() return end

module("bpuigraphnode", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local surface_setFont = surface.SetFont
local surface_setDrawColor = surface.SetDrawColor
local surface_setTextPos = surface.SetTextPos
local surface_setTextColor = surface.SetTextColor
local surface_drawText = surface.DrawText
local surface_drawRect = surface.DrawRect
local draw_simpleText = draw.SimpleText
local render_PushFilterMag = render.PushFilterMag
local render_PushFilterMin = render.PushFilterMin
local render_PopFilterMag = render.PopFilterMag
local render_PopFilterMin = render.PopFilterMin
local roundedBox = bprenderutils.RoundedBoxFast

local drawNode = GWEN.CreateTextureBorder( 64, 0, 64, 64, 12, 48, 12, 12, G_BPGraphAtlas )
local drawNodeHighlight = GWEN.CreateTextureBorder( 0, 0, 48, 48, 16, 16, 16, 16, G_BPGraphAtlas )
local drawCompact = GWEN.CreateTextureBorder( 144, 0, 64, 64, 18, 18, 18, 18, G_BPGraphAtlas )
local drawRoles = {
	[ROLE_Server] = GWEN.CreateTextureNormal( 0, 64, 32, 32, G_BPGraphAtlas ),
	[ROLE_Client] = GWEN.CreateTextureNormal( 32, 64, 32, 32, G_BPGraphAtlas ),
	[ROLE_Shared] = GWEN.CreateTextureNormal( 0, 96, 32, 32, G_BPGraphAtlas ),
}

local meta = bpcommon.MetaTable("bpuigraphnode")

local NODE_MINIMUM_WIDTH = 80
local NODE_PINSIDE_SPACING = 40
local NODE_HEADER_HEIGHT = 40
local NODE_HEADER_SPACING = 25
local NODE_FOOTER_HEIGHT = 40
local NODE_COMPACT_HEADER_SPACING = 25
local NODE_COMPACT_HEADER_HEIGHT = 40
local NODE_COMPACT_FOOTER_HEIGHT = 0
local NODE_COMPACT_OFFSET = 45
local PIN_SPACING = 8
local PIN_EDGE_SPACING = 8
local COMMENT_FONT = "NodePinFont"
local COMMENT_MAXWIDTH = 300
local NO_HIDDEN_FILTER = function(pin) return not pin:ShouldBeHidden() end

function meta:Init(node, graph, editor)

	self.highlight = 0
	self.highlighting = false
	self.editor = editor
	self.node = node
	self.graph = graph
	self.width = nil
	self.height = nil
	self.pins = {}
	self.commentWrap = bptextwrap.New():SetFont(COMMENT_FONT):SetMaxWidth(COMMENT_MAXWIDTH)
	self:CreatePins()
	self:LayoutPins()
	self.node:BindRaw("postModify", self, function()
		self:CreatePins()
		self:LayoutPins()
		self:Invalidate(true)
	end)
	return self

end

function meta:Invalidate(invalidatePins)

	self.compact = nil
	self.width = nil
	self.height = nil
	self.displayName = nil
	self.pinsNeedLayout = true

	if invalidatePins then
		for _, v in pairs(self.pins) do
			v:Invalidate()
		end
	end

end

function meta:ShouldBeCompact()

	if self.compact ~= nil then return self.compact end

	for _, v in pairs(self.pins) do
		if v.pin:IsIn() and v.pin:GetLiteralType() == "string" and #v.pin:GetConnections() == 0 then
			self.compact = false
			return self.compact
		end
	end
	self.compact = self.node:HasFlag(NTF_Compact) or ( #self.node:GetPins() <= 2 and self.node:GetCodeType() == NT_Pure )
	return self.compact

end

function meta:GetSize()

	if self.width and self.height then
		return self.width, self.height
	end

	local node = self.node
	local name = self:GetDisplayName()

	surface.SetFont( "Default" )
	local inPinWidth = 0
	local outPinWidth = 0
	local padPin = 50

	local totalPinHeightIn = 0
	local totalPinHeightOut = 0
	local maxPinWidthIn = 0
	local maxPinWidthOut = 0
	local width = 0
	local headHeight = NODE_HEADER_HEIGHT
	local footHeight = NODE_FOOTER_HEIGHT
	local pinSideSpacing = NODE_PINSIDE_SPACING

	for pinID, pin, pos in node:SidePins(PD_In, NO_HIDDEN_FILTER) do
		local vpin = self.pins[pinID]
		local w,h = vpin:GetSize()
		maxPinWidthIn = math.max(maxPinWidthIn, w)
		totalPinHeightIn = totalPinHeightIn + h + PIN_SPACING
	end
	if totalPinHeightIn ~= 0 then totalPinHeightIn = totalPinHeightIn - PIN_SPACING end

	for pinID, pin, pos in node:SidePins(PD_Out, NO_HIDDEN_FILTER) do
		local vpin = self.pins[pinID]
		local w,h = vpin:GetSize()
		maxPinWidthOut = math.max(maxPinWidthOut, w)
		totalPinHeightOut = totalPinHeightOut + h + PIN_SPACING
	end
	if totalPinHeightOut ~= 0 then totalPinHeightOut = totalPinHeightOut - PIN_SPACING end

	surface.SetFont("NodeTitleFont")
	local titleWidth, titleHeight = surface.GetTextSize( name )

	self.titleWidth = titleWidth
	self.titleHeight = titleHeight

	if self:ShouldBeCompact() then
		width = math.max(titleWidth+40, 0)
		headHeight = NODE_COMPACT_HEADER_HEIGHT
		footHeight = NODE_COMPACT_FOOTER_HEIGHT
	else
		width = math.max(inPinWidth + outPinWidth, math.max(NODE_MINIMUM_WIDTH, titleWidth+20))
	end

	self.width = math.max(width, maxPinWidthIn + maxPinWidthOut) + pinSideSpacing
	self.height = footHeight + headHeight + math.max(totalPinHeightIn, totalPinHeightOut)

	if maxPinWidthIn ~= 0 then self.width = self.width + PIN_EDGE_SPACING end
	if maxPinWidthOut ~= 0 then self.width = self.width + PIN_EDGE_SPACING end

	if node:GetTypeName() == "CORE_Pin" then
		self.width = 80
	end

	return self.width, self.height

end

function meta:CalculatePinLocation(vpin)

	local nw, nh = self:GetSize()
	local pin = vpin:GetPin()
	local id = vpin:GetSideIndex()
	local dir = pin:GetDir()
	local w,h = vpin:GetSize()
	local ox, oy = vpin:GetHotspotOffset()
	local x = 0
	local y = 10
	if self:ShouldBeCompact() then y = -5 end
	if dir == PD_In then
		return x, y + id * 15
	else
		return x + nw - w, y + id * 15
	end

end

function meta:CreatePins()

	self.pins = {}

	local node = self.node
	for pinID, pin, pos in node:SidePins(PD_In, NO_HIDDEN_FILTER) do
		self.pins[pinID] = bpuigraphpin.New(self, pinID, pos)
	end

	for pinID, pin, pos in node:SidePins(PD_Out, NO_HIDDEN_FILTER) do
		self.pins[pinID] = bpuigraphpin.New(self, pinID, pos)
	end

end

function meta:LayoutPins()

	if not self.pinsNeedLayout then return end

	local nw, nh = self:GetSize()

	local function LayoutSide(s)
		local y = NODE_HEADER_HEIGHT + NODE_HEADER_SPACING
		if self:ShouldBeCompact() then y = NODE_COMPACT_HEADER_HEIGHT + NODE_COMPACT_HEADER_SPACING end

		local node = self.node
		for pinID, pin, pos in node:SidePins(s, NO_HIDDEN_FILTER) do
			local vpin = self.pins[pinID]
			local w,h = vpin:GetSize()
			vpin:SetPos(s == PD_In and PIN_EDGE_SPACING or (nw - w - PIN_EDGE_SPACING), y)
			y = y + h + PIN_SPACING
		end
	end

	LayoutSide(PD_In)
	LayoutSide(PD_Out)

	self.pinsNeedLayout = false


	--[[for _, vpin in pairs(self.pins) do
		local x,y = self:CalculatePinLocation(vpin)
		vpin:SetPos(x,y)
	end]]

end

function meta:GetDisplayName()

	if self.displayName then return self.displayName end

	local name = self:GetNode():GetDisplayName()
	local sub = string.find(name, "[:.]")
	if sub then
		name = name:sub(sub+1, -1)
	end

	--name = name:gsub("%u%l+", function(x) print(x) return " " .. x end):Trim()

	self.displayName = name

	return name

end

function meta:GetVPin(pinID)

	return self.pins[pinID]

end

function meta:GetVPins()

	return self.pins

end

function meta:GetNode()

	return self.node

end

function meta:GetPos()

	local x,y = self.node:GetPos()

	local scale = 2 -- HARD CODE FOR NOW, FIX LATER
	x = x * scale
	y = y * scale

	return x,y

end

function meta:IsSelected()

	if not self.editor then return false end
	return self.editor:IsNodeSelected(self)

end

function meta:GetHitBox()

	local x,y = self:GetPos()
	local w,h = self:GetSize()

	if self.compact then
		y = y + NODE_COMPACT_OFFSET
	end

	return x,y,w,h

end

function meta:DrawPins(xOffset, yOffset, alpha, textPass)

	local x,y = self:GetPos()
	for k,v in pairs(self.pins) do
		if textPass then
			v:DrawTitle(x+xOffset, y+yOffset, alpha)
		else
			v:Draw(x+xOffset, y+yOffset, alpha)
		end
	end

end

function meta:GetPinSpotLocation(pinID)

	local x,y = self:GetPos()
	local vpin = self.pins[pinID]
	if not vpin then return x,y end

	local px, py = vpin:GetPos()
	local ox, oy = vpin:GetHotspotOffset()

	return x + ox + px, y + py + oy

end

function meta:DrawBanner(x, y, alpha)

	local deprecated = self.node:HasFlag(NTF_Deprecated)
	local shouldDraw = self.node:HasFlag(NTF_Experimental) or deprecated
	if not shouldDraw then return end

	-- Node banner
	local bannerW = 200
	local bannerH = NODE_HEADER_HEIGHT - 5
	local bannerX = x + 10
	local bannerY = y - bannerH
	local cr, cg, cb = 255,190,60

	if deprecated then cg = 60 bannerW = 150 end

	--surface_drawRect(bannerX,bannerY,w,NODE_HEADER_HEIGHT)
	roundedBox(12, bannerX, bannerY, bannerW, bannerH, cr,cg,cb, 255*alpha, true, true, false, false)
	surface_setDrawColor(cr/2, cg/2, cb/2, 255*alpha)
	surface_drawRect(bannerX,bannerY + bannerH,bannerW,2)

	surface_setFont( "NodeTitleFont" )
	surface_setTextPos( bannerX + 10, bannerY )
	surface_setTextColor( 0, 0, 0, 255*alpha )
	surface_drawText( deprecated and "Obsolete" or "Experimental" )

end

function meta:SetHighlighting(highlight) self.highlighting = highlight end
function meta:GetHighlight() return self.highlight end

function meta:Think( dt )

	local t = self.highlighting and 1 or 0
	local rate = 5
	self.highlight = Lerp(1 - math.exp(dt * -rate), self.highlight, t)
	if t == 0 and self.highlight < 0.01 then self.highlight = 0 end

end

local col = Color(0,0,0)
function meta:Draw(xOffset, yOffset, alpha)

	--self:Invalidate(true)

	local x,y = self:GetPos()
	local w,h = self:GetSize()

	x = x + xOffset
	y = y + yOffset

	if self.compact then
		y = y + NODE_COMPACT_OFFSET
	end

	local node = self.node
	local ntc = node:GetColor()
	local outline = 8


	local highlight = self:GetHighlight()
	if highlight > 0 then
		col:SetUnpacked(ntc.r, ntc.g, ntc.b, 255*highlight*alpha)
		drawNodeHighlight(x-outline,y-outline,w+outline*2,h+outline*2,col)
	end

	local selected = self:IsSelected()
	if selected then
		col:SetUnpacked(200,150,80,255*alpha)
		drawNodeHighlight(x-outline,y-outline,w+outline*2,h+outline*2,col)
	end

	-- TODO restructure error handling
	--[[local err = _G.G_BPError
	if err ~= nil and err.nodeID == self.node.id and err.graphID == self.graph.id then
		col:SetUnpacked(200,80,80,255*alpha)
		drawNodeHighlight(x-4,y-4,w+8,h+8,col)
	end]]

	if node:GetComment() ~= self.commentWrap:GetText() then
		self.commentWrap:SetText( node:GetComment() )
	end

	if node:GetComment() ~= "" then
		local tw, th = self.commentWrap:GetSize()
		draw.RoundedBox(6, x - 5, y - 25 - th, tw + 10, th + 10, Color(0,0,0,200 * alpha))
		self.commentWrap:Draw(x, y - 20 - th, 255, 255, 255, 255 * alpha)
	end


	local isCompact = self.compact
	local role = node:GetRole()
	if not isCompact then
		col:SetUnpacked(ntc.r, ntc.g, ntc.b, 255*alpha)
		drawNode(x,y,w,h,col)
		if drawRoles[role] then drawRoles[role](x + w - 35,y + 10,24,24) end
	else
		local r,g,b = 0,0,0
		if role == ROLE_Server then r,g,b = 64,182,255 end
		if role == ROLE_Client then r,g,b = 255,184,68 end
		col:SetUnpacked(r, g, b, 255*alpha)
		drawCompact(x,y,w,h,col)
	end

	self:LayoutPins()
	self:DrawBanner(x, y, alpha)
	self:DrawPins(xOffset, yOffset, alpha, false)

	surface_setFont("NodePinFont")
	self:DrawPins(xOffset, yOffset, alpha, true)

	local name = self:GetDisplayName()

	if not isCompact then

		surface_setFont( "NodeTitleFontShadow" )
		surface_setTextPos( math.ceil( x+10 ), math.ceil( y+6 ) )
		surface_setTextColor( 0, 0, 0, 255*alpha )
		surface_drawText( name )

		surface_setFont( "NodeTitleFont" )
		surface_setTextPos( math.ceil( x+7 ), math.ceil( y+4 ) )
		surface_setTextColor( 255, 255, 255, 255*alpha )
		surface_drawText( name )

	else
		-- HACK
		if node:GetTypeName() ~= "CORE_Pin" then

			surface_setFont( "NodeTitleFont" )
			surface_setTextPos( math.ceil( x+(w - self.titleWidth)/2 ), math.ceil( y+(h - self.titleHeight)/2 ) )
			surface_setTextColor( 255, 255, 255, 255*alpha )
			surface_drawText( name )
		end
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end