AddCSLuaFile()

module("bpstream", package.seeall)

local meta = bpcommon.MetaTable("bpstream")

bpcommon.AddFlagAccessors(meta)

-- Stream modes
MODE_File = 0
MODE_Network = 1
MODE_String = 2
MODE_NetworkString = 3

-- Flags
FL_None = 0
FL_Compressed = 1
FL_Base64 = 2
FL_Checksum = 4
FL_FileBacked = 8
FL_BitStream = 16
FL_NoStringTable = 32
FL_NoObjectLinker = 64
FL_NoHeader = 128

-- IO
IO_None = 0
IO_Out = 1
IO_In = 2

DEBUG_MODE = false
CATCH_UNFINISHED = true

fmtMagic = 0x314D5042
fmtVersion = 3


function meta:Init(context, mode, file)

	self.context = context
	self.mode = mode
	self.io = IO_None
	self.file = file
	self.flags = 0
	self.version = fmtVersion
	self.magic = fmtMagic

	if mode == MODE_Network or mode == MODE_NetworkString then
		self:AddFlag(FL_NoHeader)
		self:AddFlag(FL_Compressed)
		self:AddFlag(FL_Checksum)
	end

	if mode == MODE_File then
		self:AddFlag(FL_Compressed)
		self:AddFlag(FL_Checksum)
	end

	--self:AddFlag(FL_NoObjectLinker)

	return self

end

function meta:SerializeHeader()

	self.magic = self:UInt(self.magic)
	self.version = self:UInt(self.version)

	if self:IsReading() then
		if self.magic ~= fmtMagic then error("Invalid blueprint data: " .. fmtMagic .. " != " .. tostring(self.magic)) end
		if self.version > fmtVersion then error("Blueprint data version is newer") end
	end

	--print("HEADER: " .. self.magic .. " | " .. self.version)

end

function meta:Out()

	if DEBUG_MODE then self:ClearFlag( FL_Compressed ) end
	if DEBUG_MODE then self:ClearFlag( FL_Base64 ) end

	self.io = IO_Out
	self.stream = bpdata.OutStream( self:HasFlag(FL_BitStream), self:HasFlag(FL_FileBacked) )
	self.dataStream = bpdata.OutStream( false, self:HasFlag(FL_FileBacked) )

	if not self:HasFlag(FL_NoObjectLinker) then self.linker = bpobjectlinker.New():WithOuter(self) end
	if not self:HasFlag(FL_NoStringTable) then self.stringTable = bpstringtable.New():WithOuter(self) end

	self:MetaState( self.stream )
	if not self:HasFlag(FL_NoHeader) then self:SerializeHeader() end
	self:MetaState( nil )

	if CATCH_UNFINISHED then
		local site = debug.traceback()
		self.finishCheck = bpcommon.GCHandle( function()
			if not self:IsClosed() then print("****Unfinished output stream at: " .. site) end
		end )
	end

	return self

end

function meta:Data()

	if self.metaState then return self.metaState end
	return self.dataStream or self.stream

end

function meta:MetaState( state )

	self.metaState = state

end

function meta:GetLinker()

	return self.linker

end

function meta:In( noRead )

	if DEBUG_MODE then self:ClearFlag( FL_Compressed ) end
	if DEBUG_MODE then self:ClearFlag( FL_Base64 ) end

	self.io = IO_In
	self.stream = bpdata.InStream( self:HasFlag(FL_BitStream) )

	if not noRead then

		if self.mode == MODE_File then

			assert(self.file)
			assert(self.stream:LoadFile( self.file, self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) ))

		elseif self.mode == MODE_String or self.mode == MODE_NetworkString then

			assert(self.file)
			assert(self.stream:LoadString( self.file, self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) ))

		elseif self.mode == MODE_Network then

			self.stream:ReadFromNet( self:HasFlag(FL_Compressed) )

		else

			error("Invalid mode for reading")

		end

	end

	if not self:HasFlag(FL_NoHeader) then self:SerializeHeader() else end
	if self:HasFlag(FL_Checksum) then
		local signed = self:UInt()
		local test = self.stream:GetCRC( self.stream:Position() )
		if test ~= signed then error("Corrupted data!") end
	end
	if not self:HasFlag(FL_NoObjectLinker) then
		self.linker = bpobjectlinker.New():WithOuter(self)
		self.linker:Serialize(self)
	end
	if not self:HasFlag(FL_NoStringTable) then
		self.stringTable = bpstringtable.New():WithOuter(self)
		self.stringTable:Serialize(self)
	end

	if CATCH_UNFINISHED then
		local site = debug.traceback()
		self.finishCheck = bpcommon.GCHandle( function()
			if not self:IsClosed() then print("****Unfinished input stream at: " .. site) end
		end )
	end

	return self

end

function meta:Finish()

	local out = nil

	if self:IsWriting() then

		local contents = bpdata.OutStream( false, self:HasFlag(FL_FileBacked) )

		self:MetaState( contents )
		if self.linker then self.linker:PostLink(self) end
		if self.linker then self.linker:Serialize(self) end
		if self.stringTable then self.stringTable:Serialize(self) end
		contents:WriteStr( self.dataStream:GetString(false, false) )

		self:MetaState( self.stream )
		if self:HasFlag(FL_Checksum) then self:UInt( contents:GetCRC() ) end

		self.stream:WriteStr( contents:GetString(false, false) )
		self:MetaState( nil )

		if self.mode == MODE_File then

			assert(self.file)
			out = self.stream:WriteToFile(self.file, self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) )

		elseif self.mode == MODE_String or self.mode == MODE_NetworkString then

			out = self.stream:GetString( self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) )

		elseif self.mode == MODE_Network then

			local s, p = self.stream:WriteToNet( self:HasFlag(FL_Compressed) )
			out = p

		else

			error("Invalid mode for writing")

		end

	elseif self:IsReading() then

		if self.linker then self.linker:PostLink(self) end

	end

	self.io = IO_None
	self.stream = nil
	return out

end

function meta:IsFile() return self.mode == MODE_File end
function meta:IsNetwork() return self.mode == MODE_Network or self.mode == MODE_NetworkString end
function meta:IsString() return self.mode == MODE_String end
function meta:IsReading() return self.io == IO_In end
function meta:IsWriting() return self.io == IO_Out end
function meta:IsClosed() return self.io == IO_None end
function meta:GetContext() return self.context end
function meta:GetMode() return self.mode end
function meta:GetMagic() return self.magic end
function meta:GetVersion() return self.version end

function meta:UByte(v)

	if self:IsReading() then return self:Data():ReadByte(false) end
	if self:IsWriting() then self:Data():WriteByte(v, false) return v end
	error("Tried to use closed stream")

end

function meta:Byte(v)

	if self:IsReading() then return self:Data():ReadByte(true) end
	if self:IsWriting() then self:Data():WriteByte(v, true) return v end
	error("Tried to use closed stream")

end

function meta:Bits(v, num)

	if self:IsReading() then return self:Data():ReadBits(num) end
	if self:IsWriting() then self:Data():WriteBits(v, num) return v end
	error("Tried to use closed stream")

end

function meta:Float(v)

	if self:IsReading() then return self:Data():ReadFloat() end
	if self:IsWriting() then self:Data():WriteFloat(v) return v end
	error("Tried to use closed stream")

end

function meta:UInt(v)

	if self:IsReading() then return self:Data():ReadInt(false) end
	if self:IsWriting() then self:Data():WriteInt(v, false) return v end
	error("Tried to use closed stream")

end

function meta:Int(v)

	if self:IsReading() then return self:Data():ReadInt(true) end
	if self:IsWriting() then self:Data():WriteInt(v, true) return v end
	error("Tried to use closed stream")

end

function meta:UShort(v)

	if self:IsReading() then return self:Data():ReadShort(false) end
	if self:IsWriting() then self:Data():WriteShort(v, false) return v end
	error("Tried to use closed stream")

end

function meta:Short(v)

	if self:IsReading() then return self:Data():ReadShort(true) end
	if self:IsWriting() then self:Data():WriteShort(v, true) return v end
	error("Tried to use closed stream")

end

function meta:Bool(v)

	if self:IsReading() then return self:Data():ReadBool() end
	if self:IsWriting() then self:Data():WriteBool(v) return v end
	error("Tried to use closed stream")

end

function meta:String(v, raw, n)

	assert(type(v) == "string" or v == nil, "Expected string, got " .. type(v))
	if self:IsReading() then
		if self.stringTable and not raw then
			return self.stringTable:Get(self:Bits(nil, 24))
		end
		n = n or self:UInt()
		return self:Data():ReadStr(n, true)
	end
	if self:IsWriting() then
		if self.stringTable and not raw then
			self:Bits( self.stringTable:Add(v), 24 ) return v
		end
		if not n then self:UInt(string.len(v)) end
		self:Data():WriteStr(v, true)
		return v
	end
	error("Tried to use closed stream")

end

function meta:SValueCompat(v)

	return self:String(v)

end

function meta:Value(v)

	if self:IsReading() then return bpdata.ReadValue(self) end
	if self:IsWriting() then bpdata.WriteValue(v, self) return v end
	error("Tried to use closed stream")

end

function meta:GUID(v)

	if self:IsReading() then return self:Data():ReadStr(16) end
	if self:IsWriting() then self:Data():WriteStr(v) return v end
	error("Tried to use closed stream")

end

function meta:Extern(v, uid)

	assert(uid ~= nil, "Each 'Extern' callsite must have its own unique ID (GUID)")

	if self.linker == nil then return end
	if self:IsReading() then self.linker:ReadExtern(self, v, uid) return v end
	if self:IsWriting() then self.linker:WriteExtern(self, v, uid) return v end

end

function meta:Object(v, outer, noLinker)

	if self:IsWriting() then

		if noLinker or self.linker == nil then
			if not type(v) == "table" then error("Tried to write non-table object") end
			if v.__hash == nil then error("Object is not a metatype") end
			v:Serialize(self)
		else
			self.linker:WriteObject(self, v)
		end
		return v

	end
	if self:IsReading() then

		if noLinker or self.linker == nil then
			v:Serialize(self)
		else
			v = self.linker:ReadObject(self, outer)
		end
		return v

	end
	error("Tried to use closed stream")

end

function meta:ObjectArray(v, outer)

	if self:IsWriting() then

		self:Length(#v)
		if #v == 0 then return v end
		for i=1, #v do self:Object(v[i], outer) end
		return v

	end
	if self:IsReading() then

		local v = {}
		local n = self:Length()
		for i=1, n do
			v[#v+1] = self:Object(nil, outer)
		end
		return v

	end
	error("Tried to use closed stream")

end

function meta:Length(v)

	if self:IsWriting() then

		local t = v
		for i=1, 4 do
			local b = bit.band(t, 0x7F)
			t = bit.rshift(t, 7)
			if t ~= 0 then b = bit.bor(b, 0x80) end
			self:UByte(b)
			if t == 0 then break end
		end
		return v

	end
	if self:IsReading() then

		v = 0
		for i=1, 4 do
			local b = self:UByte()
			v = v + bit.lshift(bit.band(b, 0x7F), (i-1)*7)
			if bit.band(b, 0x80) == 0 then break end
		end
		return v

	end
	error("Tried to use closed stream")

end

function meta:StringArray(t)

	if self:IsClosed() then error("Tried to use closed stream") end
	if self:IsReading() and #t ~= 0 then t = {} end
	for i=1, self:Length(#t) do
		t[i] = self:String(t[i])
	end
	return t

end

function meta:StringMap(t)

	if self:IsClosed() then error("Tried to use closed stream") end
	if self:IsWriting() then

		local n = 0
		for k,v in pairs(t) do n = n + 1 end
		self:Length(n)
		for k,v in pairs(t) do self:String(k) self:String(v) end
		return t

	end
	if self:IsReading() then

		t = {}
		local n = self:Length()
		for i=1, n do t[self:String()] = self:String() end
		return t

	end

end

local function Forward(name, t)

	meta[name] = function(s, ...)
		local stream = s:Data()
		if not stream then error("Tried to use closed stream") end
		return t[name](stream, ...)
	end

end

Forward("IsUsingStringTable", bpdata.OUT)
Forward("WriteBits", bpdata.OUT)
Forward("WriteBool", bpdata.OUT)
Forward("WriteByte", bpdata.OUT)
Forward("WriteShort", bpdata.OUT)
Forward("WriteInt", bpdata.OUT)
Forward("WriteFloat", bpdata.OUT)

Forward("ReadBits", bpdata.IN)
Forward("ReadBool", bpdata.IN)
Forward("ReadByte", bpdata.IN)
Forward("ReadShort", bpdata.IN)
Forward("ReadInt", bpdata.IN)
Forward("ReadFloat", bpdata.IN)

function meta:WriteStr(str, raw) self:String(str, raw, 0) end
function meta:ReadStr(n, raw) return self:String(nil, raw, n) end

function New(...) return bpcommon.MakeInstance(meta, ...) end