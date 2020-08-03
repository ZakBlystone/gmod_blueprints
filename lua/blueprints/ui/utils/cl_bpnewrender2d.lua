if SERVER then AddCSLuaFile() return end

module("bpnewrender2d", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local meta = bpcommon.MetaTable("bpnewrender2d")

function meta:Init(parent)

	self.parent = parent
	self.scrollX = 0
	self.scrollY = 0
	self.zoom = 0
	self.viewport = {0,0,0,0}
	self.ratio = 1
	self.mtx = Matrix()
	self.mtx:Identity()
	self.invMtx = self.mtx:GetInverse()
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

function meta:PointToWorld(x,y)

	local px, py = self.parent:LocalToScreen(0,0)
	local v = self.invMtx * Vector(x + px,y + py,0)
	return v.x,v.y

end

function meta:PointToScreen(x,y)

	local v = self.mtx * Vector(x,y,0)
	local px, py = self.parent:LocalToScreen(0,0)
	return v.x-px,v.y-py

end

function meta:Calculate()

	self.mtx:Identity()
	self.mtx:Translate(Vector(self.viewport[1], self.viewport[2], 0))
	self.mtx:Scale(Vector(self.zoom,self.zoom,1))
	self.mtx:Translate(Vector(self.scrollX, self.scrollY, 0))
	self.invMtx = self.mtx:GetInverse()

end

function meta:ViewCalculate(x,y,w,h)

	self.viewport = {x,y,w,h}
	self.ratio = w/h
	self:Calculate()

end

function meta:Draw(x,y,w,h)

	local rx = x
	local ry = y

	self:ViewCalculate(x,y,w,h)

	local vx,vy,vw,vh = unpack(self.viewport)
	
	render.SetScissorRect(vx, vy, vx + vw, vy + vh, true)
	cam.PushModelMatrix(self.mtx)

	render.PushFilterMag( TEXFILTER.NONE )
	render.PushFilterMin( TEXFILTER.NONE )

	local b,e = pcall(self.Draw2D, self)

	render.PopFilterMag()
	render.PopFilterMin()

	cam.PopModelMatrix()
	render.SetScissorRect(0,0,0,0, false)

end

function New(...) return bpcommon.MakeInstance(meta, ...) end