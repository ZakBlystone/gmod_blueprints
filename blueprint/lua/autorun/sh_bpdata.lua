AddCSLuaFile()

include("sh_bpcommon.lua")

module("bpdata", package.seeall, bpcommon.rescope(bit))

local ENTITY_BITS = 12

DT_NULL = 0
DT_BYTE = 1
DT_UBYTE = 2
DT_SHORT = 3
DT_USHORT = 4
DT_INT = 5
DT_UINT = 6
DT_FLOAT = 7
DT_COLOR = 8
DT_CVECTOR = 9
DT_ENTITY = 10
DT_STRING = 11
DT_KEYS = 12
DT_TABLE = 13
DT_ANGLE = 14

local typenames = {
	"DT_NULL",
	"DT_BYTE",
	"DT_UBYTE",
	"DT_SHORT",
	"DT_USHORT",
	"DT_INT",
	"DT_UINT",
	"DT_FLOAT",
	"DT_COLOR",
	"DT_CVECTOR",
	"DT_ENTITY",
	"DT_STRING",
	"DT_KEYS",
	"DT_TABLE",
	"DT_ANGLE",
}

local function DTName(d)
	return typenames[d+1] or "DT_UNKNOWN"
end

DT_STATUSBITS = 4

MIN_SIGNED_BYTE = -128
MAX_SIGNED_BYTE = 127
MAX_UNSIGNED_BYTE = 255

MIN_SIGNED_SHORT = -32768
MAX_SIGNED_SHORT = 32767
MAX_UNSIGNED_SHORT = 65535

MIN_SIGNED_LONG = -2147483648
MAX_SIGNED_LONG = 2147483647
MAX_UNSIGNED_LONG = 4294967295

FLOAT_ACCURACY = 0.0002

local WARNINGS_ENABLED = false
local FLOAT_ROUNDING_ACCURACY = 0.00001
local FLOAT_ROUNDING_FIX = 10000
local FLOAT_DO_ROUNDING = false

local function SBRSH(v, b) return string.char(band(rshift(v, b), 0xFF)) end
local function SBLSH(s, e, b) return lshift(s:byte(e), b) end

local function PrintBin(v, bits)
	local s = ""
	for i=1, bits do
		s = s .. band(v, 1)
		v = rshift(v, 1)
	end
	print(string.reverse(s))
end

local INF = 1/0
function Float2Str(value)
	local s=value<0 and 1 or 0
	if math.abs(value)==INF then return (s==1 and "\0\0\0\255" or "\0\0\0\127") end
	if value~=value then return "\170\170\170\255" end

	local fr, exp = 0, 0
	if value ~= 0.0 then
		fr,exp=math.frexp(math.abs(value))
		fr = math.floor(math.ldexp(fr, 24))
		exp = exp + 126
	end
	local ec = band(lshift(exp, 7), 0x80)
	local mc = band(rshift(fr, 16), 0x7f)

	local a = SBRSH(fr, 0)
	local b = SBRSH(fr, 8)
	local c = string.char( bor(ec, mc) )
	local d = string.char( bor(s==1 and 0x80 or 0x00, rshift(exp, 1)) )

	return a .. b .. c .. d
end

function Str2Float(str)
	local b4, b3 = str:byte(4), str:byte(3)
	local fr = lshift(band(b3, 0x7F), 16) + SBLSH(str, 2, 8) + SBLSH(str, 1, 0)
	local exp = band(b4, 0x7F) * 2 + rshift(b3, 7)
	if exp == 0 then return 0 end

	local s = (b4 > 127) and -1 or 1
	local n = math.ldexp((math.ldexp(fr, -23) + 1) * s, exp - 127)

	--fix wonky rounding
	if FLOAT_DO_ROUNDING and n - math.ceil(n) < FLOAT_ROUNDING_ACCURACY then
		n = n + FLOAT_ROUNDING_ACCURACY
		return math.floor(n*FLOAT_ROUNDING_FIX)/FLOAT_ROUNDING_FIX
	end

	return n
end

local function Num2Str(value, signed, bytes)
	local x = ""
	local sig = (bytes * 8)

	if WARNINGS_ENABLED then
		local min, max, m
		if signed then
			min = -(2 ^ (sig - 1))
			max = -min - 1
			m = "signed"
		else
			min = 0
			max = (2 ^ sig) - 1
			m = "unsigned"
		end

		if value > max then ErrorNoHalt( "WARNING: overflow for " .. m .. " value " .. value .. " > " .. max .. "\n" ) end
		if value < min then ErrorNoHalt( "WARNING: underflow for " .. m .. " value " .. value .. " < " .. min .. "\n" ) end
	end

	for i=1, bytes do
		x = x .. SBRSH(value,(i-1) * 8)
	end
	return x
end

local function Str2Num(str, signed, bytes)
	local value = 0
	local sig = (bytes * 8)
	for i=1, bytes do
		value = value + SBLSH(str, i, (i-1) * 8)
	end
	
	if value < 0 then value = (2 ^ sig) - 1 - bnot(value) end
	if signed and band( value, lshift( 1, sig - 1 ) ) ~= 0 then
		value = -(2 ^ sig) + value
	end
	return value
end

function Int2Str(value, signed) return Num2Str( value, signed, 4 ) end
function Str2Int(str, signed) return Str2Num( str, signed, 4 ) end
function Short2Str(value, signed) return Num2Str( value, signed, 2 ) end
function Str2Short(str, signed) return Str2Num( str, signed, 2 ) end
function Byte2Str(value, signed) return Num2Str( value, signed, 1 ) end
function Str2Byte(str, signed) return Str2Num( str, signed, 1 ) end

function EnableWarnings( enabled )
	WARNINGS_ENABLED = enabled
end

function EnableFloatRounding( enabled )
	FLOAT_DO_ROUNDING = enabled
end


--BASE64 ENCODING / DECODING
--Code from http://lua-users.org/wiki/BaseSixtyFour
--Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
--licensed under the terms of the LGPL2

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64_encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64_decode(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end


-- Input / Output streams


local OUT = {} OUT.__index = OUT
local IN = {} IN.__index = IN

function OUT:Init(bitstream, crc)
	if bitstream then
		self.bit = 0
		self.buffer = {}
	else
		self.buffer = ""
	end
	self.signedCRC = crc
	self.bitstream = bitstream
	return self
end

function OUT:GetString(compressed, base64encoded)
	local str = nil
	if self.bitstream then
		str = ""
		for i=1, #self.buffer do
			str = str .. string.char(self.buffer[i])
		end
	else
		str = self.buffer
	end

	if self.signedCRC then
		local crc = util.CRC(str)
		str = Int2Str( crc, false ) .. str
	end

	local buf = compressed and util.Compress(str) or str
	if base64encoded then buf = base64_encode(buf) end
	return buf, string.len(buf)
end

function OUT:WriteToFile(name, compressed, base64encoded)
	if type(name) == "string" then
		file.Write( name, self:GetString(compressed, base64encoded) )
	else
		name:Write( self:GetString(compressed, base64encoded) )
	end
end

function OUT:WriteToNet(compressed)

	local str, len = self:GetString(compressed, false)
	net.WriteUInt(len, 32)
	for i=1, len do
		net.WriteUInt(string.byte(str[i]), 8)
	end

end

function OUT:WriteBit(v)
	if not self.bitstream then error("buffer is not a bitstream") end
	local byte = rshift(self.bit, 3) + 1
	local bcmp = band(self.bit, 7)
	if bcmp == 0 then self.buffer[byte] = 0 end
	self.buffer[byte] = bor(self.buffer[byte], bit.lshift(v, bcmp))
	self.bit = self.bit + 1
end

function OUT:WriteBits(v, bits)
	if not self.bitstream then
		if bits > 0 then self.buffer = self.buffer .. string.char(band(v, 0xFF)) end
		if bits > 8 then self.buffer = self.buffer .. string.char(band(rshift(v,8), 0xFF)) end
		if bits > 16 then self.buffer = self.buffer .. string.char(band(rshift(v,16), 0xFF)) end
		if bits > 24 then self.buffer = self.buffer .. string.char(band(rshift(v,24), 0xFF)) end
		return
	end
	if bits > 32 or bits <= 0 then return end
	while bits > 0 do
		self:WriteBit(band(v, 1))
		v = rshift(v, 1)
		bits = bits - 1
	end
end

function OUT:WriteBool(b)
	if self.bitstream then
		self:WriteBit(b == true and 1 or 0)
	else
		self:WriteByte(b == true and 1 or 0, false)
	end
end

function OUT:WriteStr(str) 
	if self.bitstream then
		for i=1, string.len(str) do self:WriteBits(str:byte(i), 8) end
	else
		self.buffer = self.buffer .. str
	end
end
function OUT:WriteByte(v, signed) self:WriteStr(Byte2Str(v, signed)) end
function OUT:WriteShort(v, signed) self:WriteStr(Short2Str(v, signed)) end
function OUT:WriteInt(v, signed) self:WriteStr(Int2Str(v, signed)) end
function OUT:WriteFloat(v) self:WriteStr(Float2Str(v)) end

--for compatibility
OUT.Write = OUT.WriteStr
OUT.WriteLong = OUT.WriteInt

function IN:Init(bitstream, crc)
	if bitstream then
		self.bit = 0
		self.buffer = {}
	else
		self.buffer = ""
		self.byte = 1
	end
	self.signedCRC = crc
	self.bitstream = bitstream
	return self
end

function IN:Reset()
	self.byte = 1
end

function IN:LoadString(str, compressed, base64encoded)
	if base64encoded then str = base64_decode(str) end
	if compressed then str = util.Decompress(str, 0x4000000) end --64 megs max

	if self.signedCRC then
		local remain = str:sub(5,-1)
		local signed = Str2Int( str:sub(1,4), false )
		local test = math.floor( util.CRC( remain ) ) --weird bug where not exactly equal
		if test ~= signed then return false end
		str = remain
	end

	if self.bitstream then
		self.buffer = {}
		self.bit = 0
		for i=1, string.len(str) do self.buffer[i] = str:byte(i) end
	else
		self.buffer = str
	end
	return true
end

function IN:LoadFile(name, compressed, base64encoded)
	if type(name) == "string" then
		return self:LoadString( file.Read(name), compressed, base64encoded )
	else
		return self:LoadString( name:Read(name:Size()), compressed, base64encoded )
	end
end

function IN:ReadFromNet(compressed)

	local str = ""
	local len = net.ReadUInt(32)
	for i=1, len do
		str = str .. string.char(net.ReadUInt(8))
	end
	self:LoadString(str, compressed, false)

end

function IN:ReadBit()
	if not self.bitstream then error("buffer is not a bitstream") end
	local byte = rshift(self.bit, 3) + 1
	local bcmp = band(self.bit, 7)
	local v = self.buffer[byte] or 0
	v = band(rshift(v, bcmp), 1)
	self.bit = self.bit + 1
	return v
end

function IN:ReadBits(bits)
	if not self.bitstream then 
		local v = 0
		if bits > 0 then v = v + self:ReadStr(1):byte(1) end
		if bits > 8 then v = v + lshift(self:ReadStr(1):byte(1),8) end
		if bits > 16 then v = v + lshift(self:ReadStr(1):byte(1),16) end
		if bits > 24 then v = v + lshift(self:ReadStr(1):byte(1),24) end
		return v
	end
	if bits > 32 or bits <= 0 then return 0 end

	local m = bits
	local value = 0
	while bits > 0 do
		value = bor(value, lshift(self:ReadBit(), m-bits))
		bits = bits - 1
	end

	return value
end

function IN:ReadBool()
	if self.bitstream then
		return self:ReadBit() ~= 0
	else
		return self:ReadByte(false) ~= 0
	end
end

function IN:ReadStr(n)
	if self.bitstream then
		local s = ""
		for i=1, n do s = s .. string.char(self:ReadBits(8)) end
		return s
	else
		local r = string.sub(self.buffer, self.byte, self.byte+(n-1))
		self.byte = self.byte + n
		return r
	end
end
function IN:ReadByte(signed) return Str2Byte(self:ReadStr(1), signed) end
function IN:ReadShort(signed) return Str2Short(self:ReadStr(2), signed) end
function IN:ReadInt(signed) return Str2Int(self:ReadStr(4), signed) end
function IN:ReadFloat() return Str2Float(self:ReadStr(4)) end

--for compatibility
IN.Read = IN.ReadStr
IN.ReadLong = IN.ReadInt

function InStream(bitstream, crc) return setmetatable({}, IN):Init(bitstream, crc) end
function OutStream(bitstream, crc) return setmetatable({}, OUT):Init(bitstream, crc) end



local function Test( t, bytes )
	print( "Testing Signed: " .. t )
	for i=zdata["MAX_SIGNED_" .. t] - 100, zdata["MAX_SIGNED_" .. t] do
		local byte = Str2Num( Num2Str( i, true, bytes ), true, bytes )
		if i ~= byte then print( i .. " ~= " .. byte ) break end
	end

	for i=zdata["MIN_SIGNED_" .. t], zdata["MIN_SIGNED_" .. t] + 100 do
		local byte = Str2Num( Num2Str( i, true, bytes ), true, bytes )
		if i ~= byte then print( i .. " ~= " .. byte ) break end
	end

	print( "Testing Unsigned: " .. t )
	for i=0, 100 do
		local byte = Str2Num( Num2Str( i, false, bytes ), false, bytes )
		if i ~= byte then print( i .. " ~= " .. byte ) break end
	end

	for i=zdata["MAX_UNSIGNED_" .. t] - 100, zdata["MAX_UNSIGNED_" .. t] do
		local byte = Str2Num( Num2Str( i, false, bytes ), false, bytes )
		if i ~= byte then print( i .. " ~= " .. byte ) break end
	end
end

local function TestFloats()
	print( "Testing Floats" )

	for i=-30000,30000 do
		local f = i / 100
		local f2 = Str2Float( Float2Str( f ) )
		if math.abs(f - f2) > FLOAT_ACCURACY then print( f .. " ~= " .. f2 ) break end
	end
end

local function TestAll()
	Test("BYTE", 1)
	Test("SHORT", 2)
	Test("LONG", 4)
	TestFloats()
end

function WriteValue(t, buf, thread)
	local ttype = type(t)

	if thread then
		buf.__counter = buf.__counter or 0
		buf.__counter = buf.__counter + 1
		if (buf.__counter % 20) == 0 then
			coroutine.yield() 
		end
	end

	local function numtype(t, v)
		buf:WriteBits(t, DT_STATUSBITS)
		if t == DT_BYTE then buf:WriteByte(v, true)
		elseif t == DT_UBYTE then buf:WriteByte(v, false)
		elseif t == DT_SHORT then buf:WriteShort(v, true)
		elseif t == DT_USHORT then buf:WriteShort(v, false)
		elseif t == DT_INT then buf:WriteInt(v, true)
		elseif t == DT_UINT then buf:WriteInt(v, false)
		elseif t == DT_FLOAT then buf:WriteFloat(v)
		else print("UNKNOWN TYPE: " .. tostring(t) .. " [" .. v .. "]") end
	end

	if IsColor( t ) then
		buf:WriteBits(DT_COLOR, DT_STATUSBITS)
		buf:WriteByte(t.r)
		buf:WriteByte(t.g)
		buf:WriteByte(t.b)
		buf:WriteByte(t.a or 255)
	elseif ttype == "table" then
		buf:WriteBits(DT_TABLE, DT_STATUSBITS)
		local keys = false
		local n = 0 for k,v in pairs(t) do n = n + 1 end
		WriteValue(n, buf, thread)

		local mrk = {}
		for k,v in ipairs(t) do
			WriteValue(v, buf, thread)
			mrk[k] = true
		end
		
		for k,v in pairs(t) do
			if not mrk[k] and not keys then buf:WriteBits(DT_KEYS, DT_STATUSBITS) keys = true end
			if not mrk[k] then WriteValue(k, buf, thread) WriteValue(v, buf, thread) end
		end
	elseif ttype == "number" then
		local int = math.floor(t) == t
		if int then
			if t <= MAX_SIGNED_BYTE and t >= MIN_SIGNED_BYTE then numtype(DT_BYTE, t)
			elseif t >= 0 and t <= MAX_UNSIGNED_BYTE then numtype(DT_UBYTE, t)
			elseif t <= MAX_SIGNED_SHORT and t >= MIN_SIGNED_SHORT then numtype(DT_SHORT, t)
			elseif t >= 0 and t <= MAX_UNSIGNED_SHORT then numtype(DT_USHORT, t)
			elseif t <= MAX_SIGNED_LONG and t >= MIN_SIGNED_LONG then numtype(DT_INT, t)
			elseif t >= 0 and t <= MAX_UNSIGNED_LONG then numtype(DT_UINT, t)
			else numtype(DT_FLOAT, t)
			end
		else
			return numtype(DT_FLOAT, t)
		end
	elseif ttype == "Vector" then
			buf:WriteBits(DT_CVECTOR, DT_STATUSBITS)
			WriteValue(t.x, buf, thread)
			WriteValue(t.y, buf, thread)
			WriteValue(t.z, buf, thread)
	elseif ttype == "Angle" then
			buf:WriteBits(DT_ANGLE, DT_STATUSBITS)
			WriteValue(t.p, buf, thread)
			WriteValue(t.y, buf, thread)
			WriteValue(t.r, buf, thread)
	elseif ttype == "Entity" then
		if IsValid(t) and t:EntIndex() >= 0 then
			buf:WriteBits(DT_ENTITY, DT_STATUSBITS)
			buf:WriteBits(t:EntIndex(), ENTITY_BITS)
		else
			buf:WriteBits(DT_NULL, DT_STATUSBITS)
		end
	elseif ttype == "string" then
		buf:WriteBits(DT_STRING, DT_STATUSBITS)
		buf:WriteInt( t:len(), false )
		buf:WriteStr( t )
	else
		buf:WriteBits(DT_NULL, DT_STATUSBITS)
	end
end

function ReadValue(buf, thread)
	local ttype = buf:ReadBits(DT_STATUSBITS)

	--print("TYPE: " .. DTName(ttype))

	if thread then
		buf.__counter = buf.__counter or 0
		buf.__counter = buf.__counter + 1
		if (buf.__counter % 2500) == 0 then
			coroutine.yield() 
		end
	end

	local function numtype(t)
		if t == DT_BYTE then return buf:ReadByte(true) end
		if t == DT_UBYTE then return buf:ReadByte(false) end
		if t == DT_SHORT then return buf:ReadShort(true) end
		if t == DT_USHORT then return buf:ReadShort(false) end
		if t == DT_INT then return buf:ReadInt(true) end
		if t == DT_UINT then return buf:ReadInt(false) end
		if t == DT_FLOAT then return buf:ReadFloat() end
	end

	if ttype == DT_TABLE then
		local t = {}
		local n = ReadValue(buf, thread)
		local keys = false
		for i=1, n do
			if not keys then
				local v,f = ReadValue(buf, thread)
				if f == 'K' then keys = true
				else table.insert(t, v) end
			end
			if keys then
				local key = ReadValue(buf, thread)
				t[key] = ReadValue(buf, thread)
			end
		end
		return t, data
	elseif ttype == DT_KEYS then return nil, 'K'
	elseif ttype == DT_NULL then return nil
	elseif ttype >= DT_BYTE and ttype <= DT_FLOAT then return numtype(ttype)
	elseif ttype == DT_CVECTOR then
		local x = ReadValue(buf, thread)
		local y = ReadValue(buf, thread)
		local z = ReadValue(buf, thread)
		return Vector(x,y,z)
	elseif ttype == DT_ANGLE then
		local p = ReadValue(buf, thread)
		local y = ReadValue(buf, thread)
		local r = ReadValue(buf, thread)
		return Angle(p,y,r)
	elseif ttype == DT_COLOR then
		return Color( buf:ReadByte(), buf:ReadByte(), buf:ReadByte(), buf:ReadByte() )
	--[[elseif ttype == DT_VECTOR then
		return Vector(buf:ReadFloat(), buf:ReadFloat(), buf:ReadFloat())]]
	elseif ttype == DT_ENTITY then
		local index = buf:ReadBits(ENTITY_BITS)
		return ents.GetByIndex(index)
	elseif ttype == DT_STRING then
		local len = buf:ReadInt(false)
		return buf:ReadStr( len )
	end
end


--TestAll()