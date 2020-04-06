AddCSLuaFile()

module("bpmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpstream))


STREAM_FILE = 1
STREAM_NET = 2

local meta = bpcommon.MetaTable("bpmodule")
local moduleClasses = bpclassloader.Get("Module", "blueprints/module/moduletypes/", "BPModuleClassRefresh", meta)

function GetClassLoader() return moduleClasses end

nextModuleID = nextModuleID or 0

meta.Name = LOCTEXT"module_default_name","unnamed"
meta.Description = LOCTEXT"module_default_desc","description"
meta.EditorClass = ""

function meta:Init(type)

	self.version = bpstream.fmtVersion
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

	return bpstream.New("module", mode, file)

end

function meta:NetSend()

	bpcommon.ProfileStart("module:NetSend")
	bpcommon.Profile("module-net-write", function()
		local stream = self:CreateStream(MODE_Network):Out()
		bpcommon.Profile( "write-module", self.Serialize, self, stream )
		stream:Finish()
	end)
	bpcommon.ProfileEnd()

end

function meta:NetRecv()

	bpcommon.ProfileStart("module:NetRecv")
	bpcommon.Profile("module-net-read", function()
		local stream = self:CreateStream(MODE_Network):In()
		bpcommon.Profile( "read-module", self.Serialize, self, stream )
		stream:Finish()
	end)
	bpcommon.ProfileEnd()

end

function LoadHeader(filename)

	local stream = bpstream.New("module", MODE_File, filename)
		:AddFlags( FL_Compressed + FL_Checksum + FL_Base64 ):In()

	local modtype = stream:GetVersion() < 2 and stream:ReadInt( false ) or stream:Value()
	if type(modtype) == "number" then modtype = "Mod" end

	local header = {
		magic = stream:GetMagic(),
		version = stream:GetVersion(),
		type = modtype,
		revision = stream:ReadInt( false ),
		uid = stream:GUID(),
		envVersion = stream:Value(),
	}

	stream:Finish()
	return header

end

function meta:LoadFromText(text)

	bpcommon.ProfileStart("bpmodule:Load")

	local stream = self:CreateStream(MODE_String, text):AddFlag(FL_Base64):In()
	self:Serialize( stream )
	stream:Finish()

	bpcommon.ProfileEnd()

end

function meta:Load(filename)

	bpcommon.ProfileStart("bpmodule:Load")

	local head = LoadHeader(filename)
	local magic = head.magic
	local version = head.version

	local stream = self:CreateStream(MODE_File, filename):AddFlag(FL_Base64):In()
	self:Serialize( stream )
	stream:Finish()

	bpcommon.ProfileEnd()

end

function meta:SaveToText()

	bpcommon.ProfileStart("bpmodule:Save")

	local stream = self:CreateStream(MODE_String, text):AddFlag(FL_Base64):Out()
	self:Serialize( stream )
	local out = stream:Finish()

	bpcommon.ProfileEnd()
	return out

end

function meta:Save(filename)

	bpcommon.ProfileStart("bpmodule:Save")

	local stream = self:CreateStream(MODE_File, filename):AddFlag(FL_Base64):Out()
	self:Serialize( stream )
	stream:Finish()

	bpcommon.ProfileEnd()

end

function meta:SerializeData(stream) end
function meta:Serialize(stream)

	local magic = stream:GetMagic()
	local version = stream:GetVersion()

	if version < 2 and stream:IsReading() then
		stream:UInt() self.type = "Mod"
	else
		self.type = stream:Value( self.type )
	end

	self.revision = stream:UInt( self.revision )
	self.uniqueID = stream:GUID( self.uniqueID )

	print("MODULE: " .. magic .. " | " .. version .. " | " .. self.revision .. " | " .. self.type)
	print(bpcommon.GUIDToString(self.uniqueID))

	if stream:IsFile() or stream:IsString() then
		self.envVersion = stream:Value( self.envVersion or bpcommon.ENV_VERSION )
	end

	if stream:IsReading() then

		print("INSTALL CLASS FOR: " .. tostring(self:GetType()))
		moduleClasses:Install( self:GetType(), self )
		self:Clear()

	end

	local mode = STREAM_FILE
	if stream:IsNetwork() then mode = STREAM_NET end

	self:SerializeData( stream )

	return stream

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