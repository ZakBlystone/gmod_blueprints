AddCSLuaFile()

module("bpstream", package.seeall)

local meta = bpcommon.MetaTable("bpstream")

bpcommon.AddFlagAccessors(meta)

-- Stream modes
MODE_File = 0
MODE_Network = 1
MODE_String = 2

-- Flags
FL_None = 0
FL_Compressed = 1
FL_Base64 = 2
FL_Checksum = 4
FL_FileBacked = 8
FL_BitStream = 16
FL_NoStringTable = 32

-- IO
IO_None = 0
IO_Out = 1
IO_In = 2


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
	return self

end

function meta:Out()

	self.io = IO_Out
	self.stream = bpdata.OutStream(
		self:HasFlag(FL_BitStream),
		self:HasFlag(FL_Checksum),
		self:HasFlag(FL_FileBacked)
	)

	if not self:HasFlag(FL_NoStringTable) then
		self.stream:UseStringTable()
	end

	return self

end

function meta:In()

	self.io = IO_In
	self.stream = bpdata.InStream(
		self:HasFlag(FL_BitStream),
		self:HasFlag(FL_Checksum)
	)

	if not self:HasFlag(FL_NoStringTable) then
		self.stream:UseStringTable()
	end

	if self.mode == MODE_File then

		assert(self.file)
		assert(self.stream:LoadFile( self.file, self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) ))

	elseif self.mode == MODE_String then

		assert(self.file)
		assert(self.stream:LoadString( self.file, self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) ))

	elseif self.mode == MODE_Network then

		self.stream:ReadFromNet( self:HasFlag(FL_Compressed) )

	else

		error("Invalid mode for reading")

	end

	return self

end

function meta:Finish()

	local out = nil
	if self:IsWriting() then

		if self.mode == MODE_File then

			assert(self.file)
			self.stream:WriteToFile(self.file, self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) )

		elseif self.mode == MODE_String then

			out = self:GetString()

		elseif self.mode == MODE_Network then

			self:WriteToNet( self:HasFlag(FL_Compressed) )

		else

			error("Invalid mode for writing")

		end

	end

	self.io = IO_None
	self.stream = nil
	return out

end

function meta:IsFile() return self.mode == MODE_File end
function meta:IsNetwork() return self.mode == MODE_Network end
function meta:IsString() return self.mode == MODE_String end
function meta:IsReading() return self.io == IO_In end
function meta:IsWriting() return self.io == IO_Out end
function meta:GetContext() return self.context end
function meta:GetMode() return self.mode end
function meta:GetVersion() return self.version end

function meta:GetString()

	assert( self:IsWriting() )
	return self.stream:GetString( self:HasFlag(FL_Compressed), self:HasFlag(FL_Base64) )

end

function meta:UByte(v)

	if self:IsReading() then return self.stream:ReadByte(false) end
	if self:IsWriting() then self.stream:WriteByte(v, false) return v end
	error("Tried to use closed stream")

end

function meta:Byte(v)

	if self:IsReading() then return self.stream:ReadByte(true) end
	if self:IsWriting() then self.stream:WriteByte(v, true) return v end
	error("Tried to use closed stream")

end

function meta:Bits(v, num)

	if self:IsReading() then return self.stream:ReadBits(num) end
	if self:IsWriting() then self.stream:WriteBits(v, num) return v end
	error("Tried to use closed stream")

end

function meta:Float(v)

	if self:IsReading() then return self.stream:ReadFloat() end
	if self:IsWriting() then self.stream:WriteFloat(v) return v end
	error("Tried to use closed stream")

end

function meta:UInt(v)

	if self:IsReading() then return self.stream:ReadInt(false) end
	if self:IsWriting() then self.stream:WriteInt(v, false) return v end
	error("Tried to use closed stream")

end

function meta:Int(v)

	if self:IsReading() then return self.stream:ReadInt(true) end
	if self:IsWriting() then self.stream:WriteInt(v, true) return v end
	error("Tried to use closed stream")

end

function meta:UShort(v)

	if self:IsReading() then return self.stream:ReadShort(false) end
	if self:IsWriting() then self.stream:WriteShort(v, false) return v end
	error("Tried to use closed stream")

end

function meta:Short(v)

	if self:IsReading() then return self.stream:ReadShort(true) end
	if self:IsWriting() then self.stream:WriteShort(v, true) return v end
	error("Tried to use closed stream")

end

function meta:Bool(v)

	if self:IsReading() then return self.stream:ReadBool() end
	if self:IsWriting() then self.stream:WriteBool(v) return v end
	error("Tried to use closed stream")

end

function meta:String(v, raw)

	if self:IsReading() then
		local usingStringTable = self.stream.stringTable
		if usingStringTable and not raw then
			return self.stream:ReadStr()
		else
			local n = self:UInt()
			return self.stream:ReadStr(n, true)
		end
	end
	if self:IsWriting() then
		local usingStringTable = self.stream.stringTable
		if usingStringTable and not raw then
			self.stream:WriteStr(v)
		else
			self:UInt(string.len(v))
			self.stream:WriteStr(v, true)
		end
		return v 
	end
	error("Tried to use closed stream")

end

function meta:Value(v)

	if self:IsReading() then return bpdata.ReadValue(self.stream) end
	if self:IsWriting() then bpdata.WriteValue(v, self.stream) return v end
	error("Tried to use closed stream")

end

local function Forward(name, t)

	meta[name] = function(s, ...)
		if not s.stream then error("Tried to use closed stream") end
		return t[name](s.stream, ...)
	end

end

Forward("IsUsingStringTable", bpdata.OUT)
Forward("WriteBits", bpdata.OUT)
Forward("WriteBool", bpdata.OUT)
Forward("WriteStr", bpdata.OUT)
Forward("WriteByte", bpdata.OUT)
Forward("WriteShort", bpdata.OUT)
Forward("WriteInt", bpdata.OUT)
Forward("WriteFloat", bpdata.OUT)

Forward("ReadBits", bpdata.IN)
Forward("ReadBool", bpdata.IN)
Forward("ReadStr", bpdata.IN)
Forward("ReadByte", bpdata.IN)
Forward("ReadShort", bpdata.IN)
Forward("ReadInt", bpdata.IN)
Forward("ReadFloat", bpdata.IN)

function New(...) return bpcommon.MakeInstance(meta, ...) end