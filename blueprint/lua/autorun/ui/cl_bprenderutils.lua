if SERVER then AddCSLuaFile() return end

module("bprenderutils", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local function CubicHermite(p0, p1, m0, m1, t)
	local tS = t*t;
	local tC = tS*t;

	return (2*tC - 3*tS + 1)*p0 + (tC - 2*tS + t)*m0 + (-2*tC + 3*tS)*p1 + (tC - tS)*m1
end

function ClosestDistanceToCubicHermite(k, p0, p1, m0, m1)

end

function DrawHermite(x0,y0,x1,y1,c0,c1,samples)

	--[[if x0 < 0 and x1 < 0 then return end
	if x0 > w and x1 > w then return end
	if y0 < 0 and y1 < 0 then return end
	if y0 > h and y1 > h then return end]]

	--print(x0)

	--[[render.SetMaterial(Material("cable/physbeam"))
	--render.SetColorMaterial()
	render.SetColorModulation(255,255,255)
	local positions = {
		Vector(0,0,0),
		Vector(w - 50,h - 50,0),
	}

	--render.DrawSprite( positions[1], 10, 10, Color( 255, 255, 255 ) )
	render.StartBeam(#positions)
	local dist = 0
	local prev = positions[1]
	for i=1, #positions do
		local curr = positions[i]
		dist = dist + curr:Distance(prev)
		render.AddBeam(curr, 20, dist/100, Color(255,255,255))
		prev = curr
	end
	render.EndBeam()]]

	local px = x0
	local py = y0
	local positions = {}

	samples = samples or 20

	local dx = (x1 - x0)
	local dy = (y1 - y0)

	local d = math.sqrt(math.max(dx*dx, 8000), dy*dy) * 2
	d = math.min(d, 400)

	table.insert(positions, {Vector(x0,y0,0), c0})

	for i=1, samples do

		local t = i/samples

		t = CubicHermite(0, 1, .01, .01, t)

		local c = Color(
			Lerp(t, c0.r, c1.r),
			Lerp(t, c0.g, c1.g), 
			Lerp(t, c0.b, c1.b), 
		c0.a)

		local x = CubicHermite(x0, x1, d, d, t)
		local y = CubicHermite(y0, y1, 0, 0, t)
		x = math.Round(x)
		y = math.Round(y)

		table.insert(positions, {Vector(x,y,0), c})

		px = x
		py = y

	end

	render.SetColorMaterial()
	render.StartBeam(#positions)
	local dist = 0
	local prev = positions[1][1]
	for i=1, #positions do
		local curr = positions[i][1]
		dist = dist + curr:Distance(prev)
		render.AddBeam(curr, 2, dist/100, positions[i][2])
		prev = curr
	end
	render.EndBeam()

end