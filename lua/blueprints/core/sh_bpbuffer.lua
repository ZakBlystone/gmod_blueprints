AddCSLuaFile()

local cacheDirectory = "blueprints/__cache"
file.CreateDir(cacheDirectory)

local function GCHandle(func)

	local prx = newproxy(true)
	local meta = getmetatable(prx)
	function meta.__gc( self ) pcall( func ) end
	return prx

end


local meta = {}
meta.__index = meta

function meta:Init( fileBacked )
	self.instance = tostring(self):gmatch("0x(%w+)")()
	self.fileBacked = fileBacked

	if self.fileBacked then
		self.filePath = cacheDirectory .. "/" .. self.instance .. ".txt"
		self.file = file.Open(self.filePath, "wb", "DATA")
		self.gc = GCHandle( function() self:Close() end )
	else
		self.buffer = ""
	end
	self.open = true
	return self
end

function meta:GetCacheFilename()

	return self.filePath

end

function meta:Write(data)
	if self.fileBacked then
		self.file:Write(data)
	else
		self.buffer = self.buffer .. data
	end
end

function meta:Flush()
	if self.fileBacked then
		self.file:Flush()
	end
end

function meta:GetString()
	if self.fileBacked then
		self:Flush()
		return file.Read(self.filePath, "DATA")
	else
		return self.buffer
	end
end

function meta:Close()
	if not self.open then return end
	if self.fileBacked and self.file then
		--print("Close Buffer: " .. tostring(self))
		self.file:Close()
		file.Delete(self.filePath)
	end
	self.open = false
end

function NewBuffer(...)
	return setmetatable({}, meta):Init(...)
end

if SERVER then
	--[[print("Make Buffer")
	local buf = NewBuffer()
	buf:Write("test")

	print(buf:GetString())]]
end