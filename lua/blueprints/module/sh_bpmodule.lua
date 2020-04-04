AddCSLuaFile()

module("bpmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpstream))


STREAM_FILE = 1
STREAM_NET = 2

fmtMagic = 0x42504D31
fmtVersion = 4

local meta = bpcommon.MetaTable("bpmodule")
local moduleClasses = bpclassloader.Get("Module", "blueprints/module/moduletypes/", "BPModuleClassRefresh", meta)

function GetClassLoader() return moduleClasses end

nextModuleID = nextModuleID or 0

meta.Name = LOCTEXT"module_default_name","unnamed"
meta.Description = LOCTEXT"module_default_desc","description"
meta.EditorClass = ""

function meta:Init(type)

	self.version = fmtVersion
	self.id = nextModuleID
	self.type = type or "mod"
	self.revision = 1
	self.uniqueID = bpcommon.GUID()

	bpcommon.MakeObservable(self)

	moduleClasses:Install( self:GetType(), self )

	nextModuleID = nextModuleID + 1
	return self

end

function meta:GenerateNewUID()

	self.uniqueID = bpcommon.GUID()

end

function meta:GetUID()

	return self.uniqueID

end

function meta:GetType()

	return self.type

end

function meta:GetName()

	local outerFile = self:FindOuter( bpfile_meta )
	if outerFile then return outerFile:GetName() end
	return "unnamed"

end

function meta:IsConstructable()

	return true

end

function meta:CanAddNode(nodeType)

	local filter = nodeType:GetModFilter()
	if filter and filter ~= self:GetType() then return false end

	return true

end

function meta:PreModifyNodeType( nodeType )

end

function meta:PostModifyNodeType( nodeType )

	self:Broadcast("nodetypeModified", nodeType)

end

function meta:NodeTypeInUse( nodeType )

	return false

end

function meta:GetNodeTypes( collection )

	collection:Add( bpdefs.Get():GetNodeTypes() )

end

function meta:GetPinTypes( collection )

	collection:Add( bpdefs.Get():GetPinTypes() )

end

function meta:GetMenuItems( tab )

end

function meta:Clear()

	self:Broadcast("cleared")

end

function meta:CreateDefaults()

end

function meta:GetUsedPinTypes(used, noFlags)

	return used or {}

end

function meta:ResolveModuleUID( uid )

	if uid == self:GetUID() then return self end
	return nil

end

function meta:GetAllModules()

	return { self }

end

function meta:CreateStream(mode, file)

	return bpstream.New("module", mode, file):Version( fmtVersion ):AddFlags(FL_Compressed + FL_Checksum)

end

function meta:NetSend()

	bpcommon.ProfileStart("module:NetSend")
	bpcommon.Profile("module-net-write", function()
		local stream = self:CreateStream(MODE_Network):Out()
		bpcommon.Profile( "write-module", self.WriteToStream, self, stream, STREAM_NET )
		stream:Finish()
	end)
	bpcommon.ProfileEnd()

end

function meta:NetRecv()

	bpcommon.ProfileStart("module:NetRecv")
	bpcommon.Profile("module-net-read", function()
		local stream = self:CreateStream(MODE_Network):In()
		bpcommon.Profile( "read-module", self.ReadFromStream, self, stream, STREAM_NET )
		stream:Finish()
	end)
	bpcommon.ProfileEnd()

end

function LoadHeader(filename)

	local stream = bpstream.New("module", MODE_File, filename):AddFlags(FL_Compressed + FL_Checksum + FL_Base64):In()
	local magic = stream:ReadInt( false )
	local version = stream:ReadInt( false )

	-- Compat for pre-release blueprints
	if magic == 0x42504D30 then
		magic = 0x42504D31
		version = 1
	end

	local modtype = version < 2 and stream:ReadInt( false ) or bpdata.ReadValue( stream )
	if type(modtype) == "number" then modtype = "Mod" end

	local header = {
		magic = magic,
		version = version,
		type = modtype,
		revision = stream:ReadInt( false ),
		uid = stream:ReadStr( 16 ),
		envVersion = bpdata.ReadValue( stream ),
	}

	stream:Finish()
	return header

end

function meta:LoadFromText(text)

	bpcommon.ProfileStart("bpmodule:Load")

	local stream = self:CreateStream(MODE_String, text):AddFlag(FL_Base64):In()
	self:ReadFromStream( stream, STREAM_FILE )
	stream:Finish()

	bpcommon.ProfileEnd()

end

function meta:Load(filename)

	bpcommon.ProfileStart("bpmodule:Load")

	local head = LoadHeader(filename)
	local magic = head.magic
	local version = head.version

	local stream = self:CreateStream(MODE_File, filename):AddFlag(FL_Base64):In()
	self:ReadFromStream( stream, STREAM_FILE )
	stream:Finish()

	bpcommon.ProfileEnd()

end

function meta:SaveToText()

	bpcommon.ProfileStart("bpmodule:Save")

	local stream = self:CreateStream(MODE_String, text):AddFlag(FL_Base64):Out()
	self:WriteToStream( stream, STREAM_FILE )
	local out = stream:Finish()

	bpcommon.ProfileEnd()
	return out

end

function meta:Save(filename)

	bpcommon.ProfileStart("bpmodule:Save")

	local stream = self:CreateStream(MODE_File, filename):AddFlag(FL_Base64):Out()
	self:WriteToStream( stream, STREAM_FILE )
	stream:Finish()

	bpcommon.ProfileEnd()

end

function meta:WriteData( stream, mode, version ) end
function meta:WriteToStream(stream, mode)

	stream:WriteInt( fmtMagic, false )
	stream:WriteInt( fmtVersion, false )
	bpdata.WriteValue( self.type, stream )
	stream:WriteInt( self.revision, false )
	stream:WriteStr( self.uniqueID )

	if mode == STREAM_FILE then
		bpdata.WriteValue( bpcommon.ENV_VERSION, stream )
	end

	self:WriteData(stream, mode, fmtVersion )

end

function meta:ReadData( stream, mode, version ) end
function meta:ReadFromStream(stream, mode)

	local magic = stream:ReadInt( false )
	local version = stream:ReadInt( false )

	-- Compat for pre-release blueprints
	if magic == 0x42504D30 and version == 7 then
		magic = 0x42504D31
		version = 1
	end

	if magic ~= fmtMagic then error("Invalid blueprint data: " .. fmtMagic .. " != " .. magic) end
	if version > fmtVersion then error("Blueprint data version is newer") end

	self.version = version
	if version < 2 then
		stream:ReadInt( false ) self.type = "Mod"
	else
		self.type = bpdata.ReadValue( stream )
	end
	self.revision = stream:ReadInt( false )
	self.uniqueID = stream:ReadStr( 16 )

	if mode == STREAM_FILE then
		self.envVersion = bpdata.ReadValue( stream )
	else
		self.envVersion = ""
	end

	print("INSTALL CLASS FOR: " .. tostring(self:GetType()))

	moduleClasses:Install( self:GetType(), self )

	self:Clear()

	--print( bpcommon.GUIDToString( self.uniqueID ) .. " v" .. self.revision  )

	self:ReadData(stream, mode, version )

	return self

end

function meta:Build(flags)

	local compiler = bpcompiler.New(self, flags)
	return compiler:Compile()

end

function meta:TryBuild(flags)

	local errStr = nil
	local compiler = bpcompiler.New(self, flags)
	local b, e = xpcall(compiler.Compile, function(err)
		errStr = tostring(err) .. "\n" .. debug.traceback()
	end, compiler)
	return errStr == nil, errStr or e

end

function meta:ToString()

	return GUIDToString(self:GetUID())

end

function New(...)
	return setmetatable({}, meta):Init(...)
end