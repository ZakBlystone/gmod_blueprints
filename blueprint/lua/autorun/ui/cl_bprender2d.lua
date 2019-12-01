if SERVER then AddCSLuaFile() return end

module("bprender2d", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local meta = bpcommon.MetaTable("bprender2d")

function meta:Init(parent)

	self.parent = parent
	self.scrollX = 0
	self.scrollY = 0
	self.zoom = 0
	self.fov = 40
	self.angle = Angle(-90,0,90)
	self.mtx = {1,0,0,0,0,1,0,0,0,0,1,0}
	self.offset = Vector(0,0,0)
	self.viewport = {0,0,0,0}
	self.invHalfFOVTan = 1/math.tan(math.rad(self.fov/2))
	self.ratio = 1
	self.clipX = 0
	self.clipY = 0
	return self

end

function meta:SetScroll(x,y)

	self.scrollX = x
	self.scrollY = y

end

function meta:SetZoom(zoom)

	self.zoom = zoom

end

function meta:GetZoom()

	return self.zoom

end

function meta:GetScroll()

	return self.scrollX, self.scrollY

end

function meta:DebugPoint(vec)

	render.SetColorMaterial()
	render.DrawBox( vec, Angle(0,0,0), Vector(-4,-4,-4), Vector(4,4,4), Color( 100, 255, 100 ) )

end

function meta:PointToWorld(x,y)

	local hw = self.viewport[3]/2
	local hh = self.viewport[4]/2
	x = x - hw - self.clipX
	y = y - hh - self.clipY

	local a = self.mtx
	local z = hw*self.invHalfFOVTan
	local m = 1/math.sqrt(x*x+y*y+z*z)
	local nx = (x * a[1] + y * a[5] + z * a[9]) * m
	local ny = (x * a[2] + y * a[6] + z * a[10]) * m
	local nz = (x * a[3] + y * a[7] + z * a[11]) * m
	if nz == 0 then return 0,0 end

	local t = a[12]/-nz
	local px = a[4] + nx * t
	local py = a[8] + ny * t
	local pz = a[12] + nz * t
	return px, py

end

function meta:PointToScreen(x,y)

	local hw = self.viewport[3]/2
	local hh = self.viewport[4]/2

	local a = self.mtx
	local vx = a[9]
	local vy = a[10]
	local vz = a[11]
	local llx = a[4] - x
	local lly = a[8] - y
	local llz = a[12]
	local llm = 1/math.sqrt(llx*llx + lly*lly + llz*llz)
	llx = llx * llm
	lly = lly * llm
	llz = llz * llm

	local denom = vx*llx + vy*lly + vz*llz
	if denom == 0 then return 0,0 end

	local t = (vx*((a[4] + vx)-x) + vy*((a[8] + vy)-y) + vz*(a[12] + vz)) / denom

	local cx = a[4] - x - llx * t
	local cy = a[8] - y - lly * t
	local cz = a[12] - llz * t

	local q = self.invHalfFOVTan
	local x = -(cx * a[1] + cy * a[2] + cz * a[3]) * q * hw
	local y = -(cx * a[5] + cy * a[6] + cz * a[7]) * q * hh * self.ratio

	return x+hw + self.clipX, y+hh + self.clipY

end

function meta:Calculate()

	local sx = -self.scrollX
	local sy = -self.scrollY
	local z = -self.zoom * 100
	local fov = self.fov

	sx = sx + self.clipX/2
	sy = sy + self.clipY/2
	
	self.invHalfFOVTan = 1/math.tan(math.rad(fov/2))
	self.angle = Angle(-90,0,90)
	self.offset.x = sx
	self.offset.y = sy
	self.offset.z = z - (self.viewport[3] * self.invHalfFOVTan) / 2

	local f,r,u = self.angle:Forward(), self.angle:Right(), self.angle:Up()
	self.mtx = {
		r.x,r.y,r.z,self.offset.x,
		-u.x,-u.y,-u.z,self.offset.y,
		f.x,f.y,f.z,self.offset.z,
	}

end

function meta:ViewCalculate(x,y,w,h)

	self.clipX = 0
	self.clipY = 0
	if x < 0 then w = w + x self.clipX = -x x = 0 end
	if y < 0 then h = h + y self.clipY = -y y = 0 end

	self.viewport = {x,y,w,h}
	self.ratio = w/h
	self:Calculate()

end

function meta:Draw(x,y,w,h)

	local rx = x
	local ry = y

	self:ViewCalculate(x,y,w,h)

	local vx,vy,vw,vh = unpack(self.viewport)

	-- De-compensate for panel shenanigans
	local OldDrawLine = surface.DrawLine
	surface.DrawLine = function(x0,y0,x1,y1) OldDrawLine(x0-rx,y0-ry,x1-rx,y1-ry) end
	local OldSetTextPos = surface.SetTextPos
	surface.SetTextPos = function(x,y) OldSetTextPos(x-rx, y-ry) end
	local OldDrawRect = surface.DrawRect
	surface.DrawRect = function(x,y,...) OldDrawRect(x-rx, y-ry,...) end
	local OldDrawTexturedRect = surface.DrawTexturedRect
	surface.DrawTexturedRect = function(x,y,...) OldDrawTexturedRect(x-rx, y-ry,...) end
	local OldDrawTexturedRectRotated = surface.DrawTexturedRectRotated
	surface.DrawTexturedRectRotated = function(x,y,...) OldDrawTexturedRectRotated(x-rx, y-ry,...) end
	local OldDrawTexturedRectUV = surface.DrawTexturedRectUV
	surface.DrawTexturedRectUV = function(x,y,...) OldDrawTexturedRectUV(x-rx, y-ry,...) end

	cam.Start3D( self.offset, self.angle, self.fov, vx,vy,vw,vh, 1, 10000 )

	render.SuppressEngineLighting( true )
	--render.PushFilterMag( TEXFILTER.ANISOTROPIC )
	--render.PushFilterMin( TEXFILTER.ANISOTROPIC )

	render.PushFilterMag( TEXFILTER.NONE )
	render.PushFilterMin( TEXFILTER.NONE )

	local b,e = pcall(function()

		self:Draw2D()

		--local mx,my = self:PointToWorld(gui.MouseX() - rx, gui.MouseY() - ry)
		--self:DebugPoint(Vector(mx,my,0))

		--draw.SimpleText("<-origin", "Trebuchet18", 0, 0)

	end)

	if not b then print(e) end

	render.PopFilterMag()
	render.PopFilterMin()
	render.SuppressEngineLighting( false )
	cam.End3D()

	surface.DrawLine = OldDrawLine
	surface.SetTextPos = OldSetTextPos
	surface.DrawRect = OldDrawRect
	surface.DrawTexturedRect = OldDrawTexturedRect
	surface.DrawTexturedRectRotated = OldDrawTexturedRectRotated
	surface.DrawTexturedRectUV = OldDrawTexturedRectUV

	local vx,vy = self:PointToScreen(0,0)
	--draw.SimpleText("<-origin", "Trebuchet18", vx, vy)

end

function New(...) return bpcommon.MakeInstance(meta, ...) end