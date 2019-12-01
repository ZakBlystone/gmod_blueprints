if SERVER then AddCSLuaFile() return end

module("bprenderutils", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local function CubicHermite(p0, p1, m0, m1, t)
	local tS = t*t;
	local tC = tS*t;

	return (2*tC - 3*tS + 1)*p0 + (tC - 2*tS + t)*m0 + (-2*tC + 3*tS)*p1 + (tC - tS)*m1
end

function ClosestDistanceToCubicHermite(k, p0, p1, m0, m1)

end

local vsamples = {}
for i=1, 100 do table.insert(vsamples, 
	{Vector(0,0,0), Color(0,0,0,0)}
) end

function DrawHermite(x0,y0,x1,y1,c0,c1,alpha,samples)

	--[[if x0 < 0 and x1 < 0 then return end
	if x0 > w and x1 > w then return end
	if y0 < 0 and y1 < 0 then return end
	if y0 > h and y1 > h then return end]]

	alpha = alpha or 1

	local width = 4
	local px = x0
	local py = y0
	local positions = vsamples

	samples = samples or 20

	local dx = (x1 - x0)
	local dy = (y1 - y0)

	local d = math.sqrt(math.max(dx*dx, 8000), dy*dy) * 2
	d = math.min(d, 400)

	positions[1][1]:SetUnpacked(x0,y0,0)
	positions[1][2] = c0

	for i=1, samples do

		local t = i/samples

		t = 1 - (.5 + math.cos(t * math.pi) * .5)

		local x = CubicHermite(x0, x1, d, d, t)
		local y = CubicHermite(y0, y1, 0, 0, t)

		positions[i+1][1]:SetUnpacked(x,y,0)
		positions[i+1][2]:SetUnpacked(Lerp(t, c0.r, c1.r), Lerp(t, c0.g, c1.g), Lerp(t, c0.b, c1.b), c0.a * alpha)

		px = x
		py = y

	end

	--render.SetMaterial(Material("cable/smoke.vmt"))
	render.SetColorMaterial()
	render.StartBeam(samples+1)
	local t = CurTime()
	local dist = 0
	local prev = positions[1][1]
	for i=1, samples+1 do
		local curr = positions[i][1]
		dist = dist + curr:Distance(prev)
		render.AddBeam(curr, width, dist/30 - t, positions[i][2])
		prev = curr
	end
	render.EndBeam()

end