if SERVER then AddCSLuaFile() return end

module("bprenderutils", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local function CubicHermite(p0, p1, m0, m1, t)
	local tS = t*t;
	local tC = tS*t;

	return (2*tC - 3*tS + 1)*p0 + (tC - 2*tS + t)*m0 + (-2*tC + 3*tS)*p1 + (tC - tS)*m1
end

function ClosestDistanceToCubicHermite(k, p0, p1, m0, m1)

end

local vsamples = {}
for i=1, 100 do vsamples[#vsamples+1] = {Vector(0,0,0), Color(0,0,0,0)} end

local math_sqrt = math.sqrt
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_cos = math.cos
local math_pi = math.pi

local mtVector =  FindMetaTable("Vector")
local mtColor = FindMetaTable("Color")
local render_setColorMaterial = render.SetColorMaterial
local render_startBeam = render.StartBeam
local render_endBeam = render.EndBeam
local render_addBeam = render.AddBeam
local setVecUnpacked = mtVector.SetUnpacked
local setColUnpacked = mtColor.SetUnpacked
local colUnpack = mtColor.Unpack

function DrawHermite(x0,y0,x1,y1,c0,c1,alpha,samples)

	--[[if x0 < 0 and x1 < 0 then return end
	if x0 > w and x1 > w then return end
	if y0 < 0 and y1 < 0 then return end
	if y0 > h and y1 > h then return end]]

	local r0,g0,b0,a0 = colUnpack(c0)
	local r1,g1,b1,a1 = colUnpack(c1)

	alpha = alpha or 1

	local width = 4
	local px = x0
	local py = y0
	local positions = vsamples

	samples = samples or 20

	local dx = (x1 - x0)
	local dy = (y1 - y0)

	local d = math_sqrt(math_max(dx*dx, 8000), dy*dy) * 1.5
	d = math_max(d, math_abs(dy))
	d = math_min(d, 1000)

	setVecUnpacked(positions[1][1],x0,y0,0)
	positions[1][2] = c0

	for i=1, samples do

		local t = i/samples

		t = 1 - (.5 + math_cos(t * math_pi) * .5)

		local x = CubicHermite(x0, x1, d, d, t)
		local y = CubicHermite(y0, y1, 0, 0, t)

		setVecUnpacked(positions[i+1][1],x,y,0)
		setColUnpacked(positions[i+1][2],Lerp(t, r0, r1), Lerp(t, g0, g1), Lerp(t, b0, b1), a0 * alpha)

		px = x
		py = y

	end

	--render.SetMaterial(Material("cable/smoke.vmt"))
	render_setColorMaterial()
	render_startBeam(samples+1)
	local t = CurTime()
	local dist = 0
	local prev = positions[1][1]
	for i=1, samples+1 do
		local curr = positions[i][1]
		--dist = dist + curr:Distance(prev)
		render_addBeam(curr, width, dist/30 - t, positions[i][2])
		prev = curr
	end
	render_endBeam()

end

local tex_corner8	= surface.GetTextureID( "gui/corner8" )
local tex_corner16	= surface.GetTextureID( "gui/corner16" )
local tex_corner32	= surface.GetTextureID( "gui/corner32" )
local tex_corner64	= surface.GetTextureID( "gui/corner64" )
local tex_corner512	= surface.GetTextureID( "gui/corner512" )

local _drawRect = surface.DrawRect
local _drawTexturedRectUV = surface.DrawTexturedRectUV
local _setTexture = surface.SetTexture
local _setDrawColor = surface.SetDrawColor

function RoundedBoxFast( bordersize, x, y, w, h, _r, _g, _b, _a, tl, tr, bl, br )

	_setDrawColor( _r, _g, _b, _a )

	-- Draw as much of the rect as we can without textures
	_drawRect( x + bordersize, y, w - bordersize * 2, h )
	_drawRect( x, y + bordersize, bordersize, h - bordersize * 2 )
	_drawRect( x + w - bordersize, y + bordersize, bordersize, h - bordersize * 2 )

	local tex = tex_corner8
	if ( bordersize > 8 ) then tex = tex_corner16 end
	if ( bordersize > 16 ) then tex = tex_corner32 end
	if ( bordersize > 32 ) then tex = tex_corner64 end
	if ( bordersize > 64 ) then tex = tex_corner512 end

	_setTexture( tex )

	if ( tl ) then
		_drawTexturedRectUV( x, y, bordersize, bordersize, 0, 0, 1, 1 )
	else
		_drawRect( x, y, bordersize, bordersize )
	end

	if ( tr ) then
		_drawTexturedRectUV( x + w - bordersize, y, bordersize, bordersize, 1, 0, 0, 1 )
	else
		_drawRect( x + w - bordersize, y, bordersize, bordersize )
	end

	if ( bl ) then
		_drawTexturedRectUV( x, y + h -bordersize, bordersize, bordersize, 0, 1, 1, 0 )
	else
		_drawRect( x, y + h - bordersize, bordersize, bordersize )
	end

	if ( br ) then
		_drawTexturedRectUV( x + w - bordersize, y + h - bordersize, bordersize, bordersize, 1, 1, 0, 0 )
	else
		_drawRect( x + w - bordersize, y + h - bordersize, bordersize, bordersize )
	end

end