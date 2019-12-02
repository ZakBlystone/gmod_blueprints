AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")
include("sh_bpgraph.lua")
include("sh_bpvariable.lua")
include("sh_bpstruct.lua")
include("sh_bpevent.lua")
include("sh_bplist.lua")

module("bpmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpnodedef)) --bpnodedef is temporary

bpcommon.CallbackList({
	"MODULE_CLEAR",
	"GRAPH_ADD",
	"GRAPH_REMOVE",
})

STREAM_FILE = 1
STREAM_NET = 2

GRAPH_MODIFY_RENAME = 1
GRAPH_MODIFY_SIGNATURE = 2
GRAPH_NODETYPE_ACTIONS = {
	[GRAPH_MODIFY_RENAME] = bpgraph.NODE_MODIFY_RENAME,
	[GRAPH_MODIFY_SIGNATURE] = bpgraph.NODE_MODIFY_SIGNATURE,
}


fmtMagic = 0x42504D30
fmtVersion = 3

local meta = bpcommon.MetaTable("bpmodule")

nextModuleID = nextModuleID or 0
activeModules = activeModules or {}

bpcommon.CreateIndexableListIterators(meta, "graphs")
bpcommon.CreateIndexableListIterators(meta, "variables")
bpcommon.CreateIndexableListIterators(meta, "structs")
bpcommon.CreateIndexableListIterators(meta, "events")

function meta:Init(type)

	self.graphConstructor = function()
		local graph = bpgraph.New(self)
		return graph
	end

	self.structConstructor = function(...)
		local struct = bpstruct.New(...):MarkAsCustom()
		struct.module = self
		return struct
	end

	self.eventConstructor = function(...)
		local event = bpevent.New(...)
		event.module = self
		return event
	end

	self.version = fmtVersion
	self.graphs = bplist.New():NamedItems("Graph"):Constructor(self.graphConstructor)
	self.structs = bplist.New():NamedItems("Struct"):Constructor(self.structConstructor)
	self.variables = bplist.New():NamedItems("Var"):Constructor(bpvariable.New)
	self.events = bplist.New():NamedItems("Event"):Constructor(self.eventConstructor)
	self.id = nextModuleID
	self.type = self.type or MT_Game
	self.revision = 1
	self.uniqueID = bpcommon.GUID()

	self.graphs:AddListener(function(cb, id)

		if cb == bplist.CB_ADD then
			self:FireListeners(CB_GRAPH_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			self:RemoveNodeTypes({"__Call" .. id})
			self:FireListeners(CB_GRAPH_REMOVE, id)
			self:RecacheNodeTypes()
		end

	end, bplist.CB_ALL)

	self.graphs:AddListener(function(cb, action, id, graph)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyGraph( GRAPH_MODIFY_RENAME, id, graph )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyGraph( GRAPH_MODIFY_RENAME, id, graph )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.structs:AddListener(function(cb, id)
		if cb == bplist.CB_REMOVE then self:RemoveNodeTypes({"__Make" .. id, "__Break" .. id}) end
		self:RecacheNodeTypes()
	end, bit.bor(bplist.CB_REMOVE, bplist.CB_ADD))

	self.structs:AddListener(function(cb, action, id, graph)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyNodeType( "__Make" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PreModifyNodeType( "__Break" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PreModifyNodeType( "__Make" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType( "__Break" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyNodeType( "__Make" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PostModifyNodeType( "__Break" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PostModifyNodeType( "__Make" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType( "__Break" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.events:AddListener(function(cb, id)
		if cb == bplist.CB_REMOVE then self:RemoveNodeTypes({"__Event" .. id, "__EventCall" .. id}) end
		self:RecacheNodeTypes()
	end, bit.bor(bplist.CB_REMOVE, bplist.CB_ADD))

	self.events:AddListener(function(cb, action, id, graph)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyNodeType( "__Event" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PreModifyNodeType( "__EventCall" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PreModifyNodeType( "__Event" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType( "__EventCall" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyNodeType( "__Event" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PostModifyNodeType( "__EventCall" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PostModifyNodeType( "__Event" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType( "__EventCall" .. id, bpgraph.NODE_MODIFY_SIGNATURE, action )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.variables:AddListener(function(cb, id, var)
		if cb == bplist.CB_REMOVE then self:RemoveNodeTypes({"__VSet" .. id, "__VGet" .. id}) end
		self:RecacheNodeTypes()
	end, bit.bor(bplist.CB_REMOVE, bplist.CB_ADD))

	self.variables:AddListener(function(cb, action, id, graph)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyNodeType( "__VGet" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PreModifyNodeType( "__VSet" .. id, bpgraph.NODE_MODIFY_RENAME, action )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyNodeType( "__VGet" .. id, bpgraph.NODE_MODIFY_RENAME, action )
			self:PostModifyNodeType( "__VSet" .. id, bpgraph.NODE_MODIFY_RENAME, action )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	bpcommon.MakeObservable(self)

	nextModuleID = nextModuleID + 1
	return self

end

function meta:PreModifyNodeType( nodeType, action, subaction )

	for _, graph in self:Graphs() do
		graph:PreModifyNodeType( nodeType, action, subaction )
	end

end

function meta:PostModifyNodeType( nodeType, action, subaction )

	for _, graph in self:Graphs() do
		graph:PostModifyNodeType( nodeType, action, subaction )
	end

end

function meta:PreModifyGraph( action, id, graph, subaction )

	if graph:GetType() ~= GT_Function then return end

	graph:PreModify(action, subaction)
	self:PreModifyNodeType( "__Call" .. id, GRAPH_NODETYPE_ACTIONS[action], subaction )

end

function meta:PostModifyGraph( action, id, graph )

	if graph:GetType() ~= GT_Function then return end

	graph:PostModify(action, subaction)
	self:PostModifyNodeType( "__Call" .. id, GRAPH_NODETYPE_ACTIONS[action], subaction )

end

function meta:RemoveNodeTypes( nodeTypes )

	for _, graph in self:Graphs() do
		graph.nodes:RemoveIf( function(node) return table.HasValue( nodeTypes, node:GetTypeName() ) end )
	end

end

function meta:RecacheNodeTypes()

	for _, graph in self:Graphs() do
		graph:CacheNodeTypes()
	end

end

function meta:GetUID()

	return self.uniqueID

end

function meta:NodeTypeInUse( nodeType )

	for id, v in self:Graphs() do

		for _, node in v:Nodes() do

			if node:GetTypeName() == nodeType then return true end

		end

	end

	return false

end

function meta:GetNodeTypes( graphID )

	local types = {}
	local base = bpdefs.Get():GetNodeTypes()

	for id, v in self:Variables() do

		local name = v:GetName()
		types["__VSet" .. id] = v:SetterNodeType()
		types["__VGet" .. id] = v:GetterNodeType()

	end

	for id, v in self:Graphs() do

		if v:GetType() == GT_Function and id ~= graphID then

			types["__Call" .. id] = v:GetFunctionType()

		end

	end

	for id, v in self:Structs() do

		types["__Make" .. id] = v:MakerNodeType()
		types["__Break" .. id] = v:BreakerNodeType()

	end

	for id, v in self:Events() do

		types["__EventCall" .. id] = v:CallNodeType()
		types["__Event" .. id] = v:EventNodeType()

	end

	for k,v in pairs(types) do v.name = k end
	for k,v in pairs(base) do
		if not types[k] then types[k] = v end
	end

	return types

end

function meta:Clear()

	self.graphs:Clear()
	self.variables:Clear()

	self:FireListeners(CB_MODULE_CLEAR)

end

function meta:NewVariable(name, type, default, flags, ex)

	return self.variables:Add( bpvariable.New(type, default, flags, ex), name )

end

function meta:NewGraph(name, type)

	local id, graph = self.graphs:Add( bpgraph.New(self, type), name )
	return id, graph

end

function meta:CopyGraph( graphID )

	local graph = self:GetGraph( graphID )
	if graph == nil then return end

	local copy = self:GetGraph( self:NewGraph( "graphproxy_" .. self.nextGraphID ) )
	graph:CopyInto(copy)

	return copy

end

function meta:GetUsedPinTypes(used, noFlags)

	used = used or {}
	for graphID, graph in self:Graphs() do
		graph:GetUsedPinTypes(used, noFlags)
	end
	return used

end

function meta:RequestGraphForEvent( nodeType )

	for _, graph in self:Graphs() do
		if graph:GetName() == nodeType:GetDisplayName() then return end
	end

	local id, graph = self:NewGraph(nodeType:GetDisplayName(), NT_Function)
	graph:SetFlag(bpgraph.FL_LOCK_PINS)
	graph:SetFlag(bpgraph.FL_LOCK_NAME)
	graph:SetFlag(bpgraph.FL_HOOK)

	if nodeType:GetRole() == ROLE_Server or nodeType:GetRole() == ROLE_Shared then
		graph:SetFlag(bpgraph.FL_ROLE_SERVER)
	end
	if nodeType:GetRole() == ROLE_Client or nodeType:GetRole() == ROLE_Shared then
		graph:SetFlag(bpgraph.FL_ROLE_CLIENT)
	end

	for k,v in pairs(nodeType:GetPins()) do

		if v:IsType(PN_Exec) then continue end
		if v:IsOut() then
			graph.inputs:Add(bpvariable.New( v:GetBaseType(), nil, v:GetFlags(), v:GetSubType() ), v:GetName())
		else
			graph.outputs:Add(bpvariable.New( v:GetBaseType(), nil, v:GetFlags(), v:GetSubType() ), v:GetName())
		end

	end

end

function meta:NetSend()

	bpcommon.ProfileStart("module:NetSend")
	bpcommon.Profile("module-net-write", function()
		local outStream = bpdata.OutStream()
		bpcommon.Profile( "write-module", self.WriteToStream, self, outStream, STREAM_NET )
		bpcommon.Profile( "write-net-stream", outStream.WriteToNet, outStream, true )
	end)
	bpcommon.ProfileEnd()

end

function meta:NetRecv()

	bpcommon.ProfileStart("module:NetRecv")
	bpcommon.Profile("module-net-read", function()
	local inStream = bpdata.InStream()
		bpcommon.Profile( "read-net-stream", inStream.ReadFromNet, inStream, true )
		bpcommon.Profile( "read-module", self.ReadFromStream, self, inStream, STREAM_NET )
	end)
	bpcommon.ProfileEnd()

end

function meta:Load(filename)

	local inStream = bpdata.InStream(false, true)
	if not inStream:LoadFile(filename, true, true) then
		error("Failed to load blueprint, try using 'Convert'")
	end
	self:ReadFromStream( inStream, STREAM_FILE )

end

function meta:Save(filename)

	local outStream = bpdata.OutStream(false, true)
	self:WriteToStream( outStream, STREAM_FILE )
	outStream:WriteToFile(filename, true, true)

end

function meta:WriteToStream(stream, mode)

	-- each save to disk is a revision on the loaded original
	if mode == bpmodule.STREAM_FILE then
		self.revision = self.revision + 1
	end

	stream:WriteInt( fmtMagic, false )
	stream:WriteInt( fmtVersion, false )
	stream:WriteInt( self.type, false )
	stream:WriteInt( self.revision, false )
	stream:WriteStr( self.uniqueID )

	Profile("write-variables", self.variables.WriteToStream, self.variables, stream, mode, fmtVersion)
	Profile("write-graphs", self.graphs.WriteToStream, self.graphs, stream, mode, fmtVersion)
	Profile("write-structs", self.structs.WriteToStream, self.structs, stream, mode, fmtVersion)
	Profile("write-events", self.events.WriteToStream, self.events, stream, mode, fmtVersion)

end

function meta:ReadFromStream(stream, mode)

	self:Clear()

	local magic = stream:ReadInt( false )
	local version = stream:ReadInt( false )

	if magic ~= fmtMagic then error("Invalid blueprint data") end
	if version > fmtVersion then error("Blueprint data version is newer") end

	self.version = version
	self.type = stream:ReadInt( false )
	self.revision = stream:ReadInt( false )
	self.uniqueID = stream:ReadStr( 16 )
	print( bpcommon.GUIDToString( self.uniqueID ) .. " v" .. self.revision  )

	Profile("read-variables", self.variables.ReadFromStream, self.variables, stream, mode, version)
	Profile("read-graphs", self.graphs.ReadFromStream, self.graphs, stream, mode, version)
	Profile("read-structs", self.structs.ReadFromStream, self.structs, stream, mode, version)

	if version >= 3 then
		Profile("read-events", self.events.ReadFromStream, self.events, stream, mode, version)
	end

	for _, graph in self:Graphs() do
		graph:CreateDeferredData()
	end

end

function meta:CreateTestModule()

	local a = self:GetGraph( self:NewGraph("Function") )
	local b = self:GetGraph( self:NewGraph("EventGraph") )

	a:CreateTestGraph()
	b:CreateTestGraph()

	return self

end

local imeta = {}

function imeta:__GetModule()

	return self.__module

end

function imeta:__GetUID()

	return self.__guid

end

function imeta:__BindGamemodeHooks()

	local meta = getmetatable(self)

	if self.CORE_Init then self:CORE_Init() end
	local bpm = self.__bpm

	for k,v in pairs(bpm.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local function call(...) return self[k](self, ...) end
		local key = "bphook_" .. GUIDToString(self:__GetUID(), true)
		--print("BIND KEY: " .. v.hook .. " : " .. key)
		hook.Add(v.hook, key, call)
	end

end

function imeta:__UnbindGamemodeHooks()

	local meta = getmetatable(self)

	if self.shuttingDown then ErrorNoHalt("!!!!!Recursive shutdown!!!!!") return end
	local bpm = self.__bpm

	for k,v in pairs(bpm.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local key = "bphook_" .. GUIDToString(self:__GetUID(), true)
		--print("UNBIND KEY: " .. v.hook .. " : " .. key)
		hook.Remove(v.hook, key, false)
	end

	self.shuttingDown = true
	if self.CORE_Shutdown then self:CORE_Shutdown() end
	self.shuttingDown = false

end

function imeta:__SetEnabled( enable )

	local modID = self.__module:GetUID()
	local guid = self:__GetUID()

	activeModules[modID] = activeModules[modID] or {}

	local activeList = activeModules[modID]
	local isEnabled = activeList[guid] ~= nil
	if isEnabled == false and enable == true then
		--print("BINDING GAMEMODE HOOKS")
		self:__BindGamemodeHooks()
		activeList[guid] = self
		return
	end

	if isEnabled == true and enable == false then
		--print("UN-BINDING GAMEMODE HOOKS")
		self:__UnbindGamemodeHooks()
		activeList[guid] = nil
		return
	end

end

function meta:SetEnabled( enable )

	local modID = self:GetUID()
	activeModules[modID] = activeModules[modID] or {}
	local activeList = activeModules[modID]

	if enable then
		self:GetSingleton():__SetEnabled( enable )
	else
		for k,v in pairs(activeList) do
			v:__SetEnabled(false)
		end
		activeModules[modID] = {}
	end

end

function meta:Instantiate(guid)

	local instance = self:Get().new()
	local meta = table.Copy(getmetatable(instance))
	for k,v in pairs(imeta) do meta[k] = v end
	setmetatable(instance, meta)
	instance.__guid = guid or GUID()
	instance.__module = self
	return instance

end

function meta:GetSingleton()

	self.singleton = self.singleton or (self:IsValid() and self:Instantiate() or nil)
	if not self.singleton then return end

	self.singleton.__guid = self.uniqueID
	return self.singleton

end

function meta:Compile(flags, compileErrorHandler)

	local compiler = bpcompiler.New(self, flags)
	local ok, res = compiler:Compile()

	if ok then
		self.compiled = res
		self:AttachErrorHandler()
	else
		print("Blueprint Code Error: " .. tostring(res))
	end

	return ok, res

end

function meta:AttachErrorHandler()

	if self.errorHandler ~= nil then
		self:Get().onError = function(msg, mod, graph, node)
			self.errorHandler(self, msg, graph, node)
		end
	end

end

function meta:IsValid()

	return self.compiled ~= nil

end

function meta:Get()

	return self.compiled

end

function meta:SetErrorHandler(errorHandler)

	self.errorHandler = errorHandler

	if self:IsValid() then
		self:AttachErrorHandler()
	end

end

function meta:ToString()

	return GUIDToString(self:GetUID())

end

function New(...)
	return setmetatable({}, meta):Init(...)
end

function CreateTestModule()
	return New():CreateTestModule()
end

hook.Add("Think", "__updatebpmodules", function()

	for _, m in pairs(activeModules) do
		for _, instance in pairs(m) do
			instance:update()
		end
	end

end)