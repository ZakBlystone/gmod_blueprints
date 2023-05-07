AddCSLuaFile()

module("bpmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpstream))


STREAM_FILE = 1
STREAM_NET = 2

local meta = bpcommon.MetaTable("bpmodule")
local moduleClasses = bpclassloader.Get("Module", "blueprints/module/moduletypes/", "BPModuleClassRefresh", meta)

function GetClassLoader() return moduleClasses end

meta.Name = LOCTEXT("module_default_name","unnamed")
meta.Description = LOCTEXT("module_default_desc","description")
meta.EditorClass = ""

function meta:Init(type)

	self.version = bpstream.fmtVersion
	self.type = type or "mod"
	self.revision = 1
	self.uniqueID = bpcommon.GUID()

	bpcommon.MakeObservable(self)

	moduleClasses:Install( self:GetType(), self )
	return self

end

function meta:Destroy()

	self:Broadcast("destroyed")

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

	local outerModule = self:FindOuter( bpmodule_meta )
	if outerModule then return outerModule:GetModuleName(self) end

	local outerFile = self:FindOuter( bpfile_meta )
	if outerFile then return outerFile:GetName() end

	return "unnamed"

end

function meta:CanCast( outPinType, inPinType )

	return false

end

function meta:CanAddNode(nodeType)

	local filter = nodeType:GetModFilter()
	if filter and filter ~= self:GetType() then return false end

	return true

end

function meta:NodeTypeInUse( nodeType )

	return false

end

function meta:GetAllNodeTypes( collection, graph )

	collection:Add( bpdefs.Get():GetNodeTypes() )
	local outerModule = self:FindOuter(bpmodule_meta)
	if outerModule and outerModule.EnumerateAllNodeTypes then
		outerModule:EnumerateAllNodeTypes( collection, graph )
	else
		self:GetNodeTypes( collection, graph )
	end

end

function meta:GetAllPinTypes( collection )

	collection:Add( bpdefs.Get():GetPinTypes() )
	local outerModule = self:FindOuter(bpmodule_meta)
	if outerModule and outerModule.EnumerateAllPinTypes then
		outerModule:EnumerateAllPinTypes( collection )
	else
		self:GetPinTypes( collection )
	end

end

function meta:GetLocalNodeTypes( collection, graph ) end

function meta:GetNodeTypes( collection, graph ) end
function meta:GetPinTypes( collection ) end

function meta:GetMenuItems( tab )

end

function meta:IsVariableRepModeAllowed( repmode )

	return repmode == REP_None

end

function meta:GetNetworkedVariables( tab ) end

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

function LoadHeader(filename)

	local stream = bpstream.New("module-head", MODE_File, filename):AddFlags(FL_Base64):In()
	local modtype = stream:String()
	local header = {
		magic = stream:GetMagic(),
		version = stream:GetVersion(),
		type = modtype,
		revision = stream:ReadInt( false ),
		uid = stream:GUID(),
		envVersion = stream:Value(),
	}

	stream:Finish( true )
	return header

end

function Load(filename)

	bpcommon.ProfileStart("bpmodule:Load")

	local stream = bpstream.New("module-file", MODE_File, filename):AddFlag(FL_Base64):In()
	local mod = stream:Object() stream:Finish()

	bpcommon.ProfileEnd()

	assert( isbpmodule(mod) )
	return mod

end

function LoadFromText(text)

	bpcommon.ProfileStart("bpmodule:Load")

	local mod = nil
	local b,e = pcall( function()

		local stream = bpstream.New("module-text", MODE_String, text):AddFlag(FL_Base64):In()
		mod = stream:Object() stream:Finish()

	end )

	if not b then 
		print("Failed to load, trying old string specification...")
		local stream = bpstream.New("module-text", MODE_String, text):AddFlag(FL_Base64):ClearFlag(FL_Compressed):ClearFlag(FL_Checksum):In()
		mod = stream:Object() stream:Finish()
	end

	bpcommon.ProfileEnd()

	assert( isbpmodule(mod) )
	return mod

end

function Save(filename, mod)

	assert( isbpmodule(mod) )
	bpcommon.ProfileStart("bpmodule:Save")
	
	local stream = bpstream.New("module-file", MODE_File, filename):AddFlag(FL_Base64):Out()
	stream:Object(mod)
	stream:Finish()

	bpcommon.ProfileEnd()

end

function SaveToText(mod)

	assert( isbpmodule(mod) )
	bpcommon.ProfileStart("bpmodule:Save")

	local stream = bpstream.New("module-text", MODE_String, filename):AddFlag(FL_Base64):Out()
	stream:Object(mod)
	local out = stream:Finish()

	bpcommon.ProfileEnd()
	return out

end

function meta:SerializeData(stream) end
function meta:Serialize(stream)

	local magic = stream:GetMagic()
	local version = stream:GetVersion()

	self.type = stream:String( self.type )
	self.revision = stream:UInt( self.revision )
	self.uniqueID = stream:GUID( self.uniqueID )

	--print("MODULE: " .. magic .. " | " .. version .. " | " .. self.revision .. " | " .. self.type)
	--print(bpcommon.GUIDToString(self.uniqueID))

	if stream:IsFile() or stream:IsString() then
		self.envVersion = stream:Value( self.envVersion or bpcommon.ENV_VERSION )
	end

	if stream:IsReading() then

		--print("INSTALL CLASS FOR: " .. tostring(self:GetType()))
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

function meta:ContainsProtectedElements()

	local compiler = bpcompiler.New(self, bpcompiler.CF_None)
	compiler:Setup()
	compiler:RunModuleCompile( bpcompiler.CP_PREPASS )
	return compiler.containsProtected

end

function meta:ToString()

	return GUIDToString(self:GetUID())

end

function New(...)
	return bpcommon.MakeInstance(meta, ...)
end