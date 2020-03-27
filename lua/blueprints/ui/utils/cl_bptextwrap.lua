if SERVER then AddCSLuaFile() return end

module("bptextwrap", package.seeall)

local surface_setFont = surface.SetFont
local surface_setDrawColor = surface.SetDrawColor
local surface_setTextPos = surface.SetTextPos
local surface_setTextColor = surface.SetTextColor
local surface_getTextSize = surface.GetTextSize
local surface_drawText = surface.DrawText
local surface_drawRect = surface.DrawRect

local meta = bpcommon.MetaTable("bptextwrap")

local mostChars = "abcdefghijklmnopqrstuvxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890|[]()!@#$%^&*~"

function meta:Init(...)

	self.font = "DermaLarge"
	self.text = ""
	self.maxWidth = 600
	self.metrics = {
		valid = false,
		lines = {},
	}

	return self

end

function meta:GetPattern()

	if self.pattern == nil then return "%s" end
	return self.pattern

end

function meta:GetFont()

	return self.font

end

function meta:GetText()

	return self.text

end

function meta:GetMaxWidth()

	return self.maxWidth

end

function meta:SetPattern( pattern )

	if pattern ~= self.pattern then
		self.pattern = pattern
		self:Invalidate()
	end
	return self

end

function meta:SetFont( font )

	if font ~= self.font then
		self.font = font
		self:Invalidate()
	end
	return self

end

function meta:SetText( text )

	if text ~= self.text then
		self.text = text
		self:Invalidate()
	end
	return self

end

function meta:SetMaxWidth( width )

	if width ~= self.maxWidth then
		self.maxWidth = width
		self:Invalidate()
	end
	return self

end

function meta:BreakSearch( m )

	local best = -1
	local p, x = m.s, m.e
	local pattern = self:GetPattern()

	for i=1, 1000 do
		x = m.t:find(pattern, p) or m.e
		local wide = self:MeasureSpan(m, m.s, x)
		if wide > m.w then break end
		m.tw = math.max(m.tw, wide)
		best = x
		p = x+1
	end

	if best ~= -1 then
		m.lines[#m.lines+1] = {m.s, best}
		m.s = best + 1
	else
		best = m.s
		for i=m.s, x do
			local wide = self:MeasureSpan(m, m.s, i)
			if wide > m.w then break end
			m.tw = math.max(m.tw, wide)
			best = i
		end

		m.lines[#m.lines+1] = {m.s, best}
		m.s = best + 1
	end

end

function meta:BreakLineToNextReturn( m )

	local p = m.t:find("\n", m.s) or -1
	local wide = self:MeasureSpan(m, m.s, p)
	if p and wide < m.w then
		m.tw = math.max(m.tw, wide)
		m.lines[#m.lines+1] = {m.s, p}
		m.s = p+1
		if p ~= -1 then return 1 end
		return 0
	end
	return -1

end

function meta:MeasureSpan( m, s, e )

	return surface_getTextSize( m.t:sub(s, e) )

end

function meta:Layout()

	local m = self.metrics
	if m.valid then return end
	m.lines = {}
	m.s = 0
	m.e = self.text:len()
	m.t = self.text
	m.w = self:GetMaxWidth()
	m.tw = 0

	surface_setFont(self.font)
	local pw, ph = surface_getTextSize(mostChars)

	for i=1, 1000 do
		local res = self:BreakLineToNextReturn( m )
		if res == 0 then break end

		if res == -1 then
			self:BreakSearch( m )
		end
	end

	m.lineHeight = ph
	m.th = #m.lines * ph
	m.valid = true

end

function meta:GetSize()

	self:Layout()
	local m = self.metrics
	return m.tw, m.th

end

function meta:Invalidate()

	self.metrics.valid = false

end

function meta:Draw( x, y, r, g, b, a )

	self:Layout()

	surface_setFont(self.font)
	surface_setTextColor( r, g, b, a )

	local m = self.metrics
	for _, v in ipairs(m.lines) do

		surface_setTextPos( x, y )
		surface_drawText(self.text:sub(v[1], v[2]))
		y = y + m.lineHeight

	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end