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

DEBUG_MODE = true


function meta:Init(context, mode, file)

	self.context = context
	self.mode = mode
	self.io = IO_None
	self.file = file
	self.flags = 0
	return self

end

function meta:Version(v)

	self.version = v

	if v < 5 then self:AddFlag(FL_NoObjectLinker) end

	return self

end

function meta:Magic(v)

	self.magic = v
	return self

end

function meta:SerializeHeader()

	self.magic = self:UInt(self.magic)
	self.version = self:UInt(self.version)

end

function meta:Out()

	if DEBUG_MODE then self:ClearFlag( FL_Compressed ) end
	if DEBUG_MODE then self:ClearFlag( FL_Base64 ) end
	if DEBUG_MODE then self:ClearFlag( FL_Checksum ) end

	self.io = IO_Out
	self.stream = bpdata.OutStream(
		self:HasFlag(FL_BitStream),
		self:HasFlag(FL_Checksum),
		self:HasFlag(FL_FileBacked)
	)

	if self.version >= 5 then
		self.dataStream = bpdata.OutStream(false, false, self:HasFlag(FL_FileBacked))
		
		if not self:HasFlag(FL_NoObjectLinker) then self.linker = bpobjectlinker.New():WithOuter(self) end
		if not self:HasFlag(FL_NoStringTable) then self.stringTable = bpstringtable.New():WithOuter(self) end
	else
		if not self:HasFlag(FL_NoStringTable) then self.stream:UseStringTable() end
	end

	self:MetaState( true )
	if not self:HasFlag(FL_NoHeader) then print("Write Header") self:SerializeHeader() else print("Skip Header") end
	self:MetaState( false )

	return self

end

function meta:Data()

	if self.metaState then return self.stream end
	return self.dataStream or self.stream

end

function meta:MetaState( state )

	self.metaState = state

end

function meta:In( noRead )

	if DEBUG_MODE then self:ClearFlag( FL_Compressed ) end
	if DEBUG_MODE then self:ClearFlag( FL_Base64 ) end
	if DEBUG_MODE then self:ClearFlag( FL_Checksum ) end

	self.io = IO_In
	self.stream = bpdata.InStream(
		self:HasFlag(FL_BitStream),
		self:HasFlag(FL_Checksum)
	)

	if self.version < 5 then
		if not self:HasFlag(FL_NoStringTable) then self.stream:UseStringTable() end
	end

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

	if not self:HasFlag(FL_NoHeader) then print("Write Header") self:SerializeHeader() else print("Skip Header") end
	if not self:HasFlag(FL_NoObjectLinker) then
		self.linker = bpobjectlinker.New():WithOuter(self)
		self.linker:Serialize(self)
	end
	if not self:HasFlag(FL_NoStringTable) then
		self.stringTable = bpstringtable.New():WithOuter(self)
		self.stringTable:ReadFromStream(self)
	end

	return self

end

function meta:Finish( noWrite )

	local out = nil

	if self:IsWriting() then

		self:MetaState(true)
		if self.linker then self.linker:Serialize(self) end
		if self.stringTable then self.stringTable:WriteToStream(self) end
		if self.dataStream then self.stream:WriteStr( self.dataStream:GetString(false, false) ) end
		self:MetaState(false)

		if not noWrite then

			if self.mode == MODE_File then

				assert(self.file)
				self.stream:WriteToFile(self.file, self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) )

			elseif self.mode == MODE_String or self.mode == MODE_NetworkString then

				out = self:GetString()

			elseif self.mode == MODE_Network then

				self:WriteToNet( self:HasFlag(FL_Compressed) )

			else

				error("Invalid mode for writing")

			end

		end

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
function meta:GetContext() return self.context end
function meta:GetMode() return self.mode end
function meta:GetMagic() return self.magic end
function meta:GetVersion() return self.version end

function meta:GetString()

	assert( self:IsWriting() )
	return self.stream:GetString( self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) )

end

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

	if self.version >= 5 then

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

	if self:IsReading() then
		local usingStringTable = self:Data().stringTable
		if usingStringTable and not raw then
			return self:Data():ReadStr()
		else
			local n = self:UInt()
			return self:Data():ReadStr(n, true)
		end
	end
	if self:IsWriting() then
		local usingStringTable = self:Data().stringTable
		if usingStringTable and not raw then
			self:Data():WriteStr(v)
		else
			self:UInt(string.len(v))
			self:Data():WriteStr(v, true)
		end
		return v 
	end
	error("Tried to use closed stream")

end

function meta:Value(v)

	if self:IsReading() then return bpdata.ReadValue(self:Data()) end
	if self:IsWriting() then bpdata.WriteValue(v, self:Data()) return v end
	error("Tried to use closed stream")

end

function meta:GUID(v)

	if self:IsReading() then return self:Data():ReadStr(16) end
	if self:IsWriting() then self:Data():WriteStr(v) return v end
	error("Tried to use closed stream")

end

function meta:Object(v, noLinker)

	if self:IsWriting() then

		if v == nil then self:UInt(0) return v end
		if not type(v) == "table" then error("Tried to write non-table object") end
		if v.__hash == nil then error("Object is not a metatype") end

		if noLinker or self.linker == nil then
			if self.linker then self.linker:RecordObject(v) end
			v:Serialize(self)
		else
			self.linker:WriteObject(v, self)
		end
		return v

	end
	if self:IsReading() then

		if noLinker or self.linker == nil then
			v:Serialize(self)
		else
			v = self.linker:ReadObject(self)
		end
		return v

	end
	error("Tried to use closed stream")

end

function meta:ObjectArray(v)

	if self:IsWriting() then

		self:UInt(#v)
		if #v == 0 then return end
		for i=1, #v do self:Object(v[i]) end
		return v

	end
	if self:IsReading() then

		local v = {}
		local n = self:UInt()
		for i=1, n do
			v[#t+1] = self:Object(nil)
		end
		return v

	end
	error("Tried to use closed stream")

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