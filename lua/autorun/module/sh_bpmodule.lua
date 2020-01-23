AddCSLuaFile()

module("bpmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema))

bpcommon.CallbackList({
	"MODULE_CLEAR",
	"GRAPH_ADD",
	"GRAPH_REMOVE",
	"NODETYPE_MODIFIED",
	"GRAPH_MODIFIED",
})

STREAM_FILE = 1
STREAM_NET = 2

fmtMagic = 0x42504D30
fmtVersion = 6

local meta = bpcommon.MetaTable("bpmodule")

nextModuleID = nextModuleID or 0

bpcommon.CreateIndexableListIterators(meta, "graphs")
bpcommon.CreateIndexableListIterators(meta, "variables")
bpcommon.CreateIndexableListIterators(meta, "structs")
bpcommon.CreateIndexableListIterators(meta, "events")

function meta:Init(type)

	self.version = fmtVersion
	self.graphs = bplist.New(bpgraph_meta, self, "module"):NamedItems("Graph")
	self.structs = bplist.New(bpstruct_meta, self, "module"):NamedItems("Struct")
	self.variables = bplist.New(bpvariable_meta):NamedItems("Var")
	self.events = bplist.New(bpevent_meta, self, "module"):NamedItems("Event")
	self.id = nextModuleID
	self.type = self.type or MT_Game
	self.revision = 1
	self.uniqueID = bpcommon.GUID()
	self.suppressGraphNotify = false

	self.graphs:AddListener(function(cb, id, graph)

		if cb == bplist.CB_ADD then
			graph:AddListener(function() self:PostModifyGraph(graph) end)
			self:FireListeners(CB_GRAPH_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			self:RemoveNodeTypes({ graph:GetCallNodeType() })
			self:FireListeners(CB_GRAPH_REMOVE, id)
			self:RecacheNodeTypes()
		end

	end, bplist.CB_ALL)

	self.structs:AddListener(function(cb, id, struct)
		if cb == bplist.CB_REMOVE then self:RemoveNodeTypes({ struct:MakerNodeType(), struct:BreakerNodeType() }) end
		self:RecacheNodeTypes()
	end, bit.bor(bplist.CB_REMOVE, bplist.CB_ADD))

	self.structs:AddListener(function(cb, action, id, struct)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyNodeType( struct:MakerNodeType() )
			self:PreModifyNodeType( struct:BreakerNodeType() )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyNodeType( struct:MakerNodeType() )
			self:PostModifyNodeType( struct:BreakerNodeType() )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.events:AddListener(function(cb, id, event)
		if cb == bplist.CB_REMOVE then self:RemoveNodeTypes({ event:EventNodeType(), event:CallNodeType() }) end
		self:RecacheNodeTypes()
	end, bit.bor(bplist.CB_REMOVE, bplist.CB_ADD))

	self.events:AddListener(function(cb, action, id, graph)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyNodeType( event:EventNodeType() )
			self:PreModifyNodeType( event:CallNodeType() )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyNodeType( event:EventNodeType() )
			self:PostModifyNodeType( event:CallNodeType() )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.variables:AddListener(function(cb, id, var)
		if cb == bplist.CB_REMOVE then self:RemoveNodeTypes({ var:SetterNodeType(), var:GetterNodeType() }) end
		self:RecacheNodeTypes()
	end, bit.bor(bplist.CB_REMOVE, bplist.CB_ADD))

	self.variables:AddListener(function(cb, action, id, var)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyNodeType( var:SetterNodeType() )
			self:PreModifyNodeType( var:GetterNodeType() )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyNodeType( var:SetterNodeType() )
			self:PostModifyNodeType( var:GetterNodeType() )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	bpcommon.MakeObservable(self)

	nextModuleID = nextModuleID + 1
	return self

end

function meta:PreModifyNodeType( nodeType )

	for _, graph in self:Graphs() do
		graph:PreModifyNodeType( nodeType )
	end

end

function meta:PostModifyNodeType( nodeType )

	for _, graph in self:Graphs() do
		graph:PostModifyNodeType( nodeType )
	end

	self:FireListeners(CB_NODETYPE_MODIFIED, nodeType)

end

function meta:RemoveNodeTypes( nodeTypes )

	for _, graph in self:Graphs() do
		graph.nodes:RemoveIf( function(node) return table.HasValue( nodeTypes, node:GetType() ) end )
	end

end

function meta:RecacheNodeTypes()

	for _, graph in self:Graphs() do
		graph:CacheNodeTypes()
	end

end

function meta:PostModifyGraph( graph )

	if not self.suppressGraphNotify then
		self:FireListeners(CB_GRAPH_MODIFIED, graph)
	end

end

function meta:GetUID()

	return self.uniqueID

end

function meta:GetType()

	return self.type

end

function meta:NodeTypeInUse( nodeType )

	for id, v in self:Graphs() do

		for _, node in v:Nodes() do

			if node:GetTypeName() == nodeType then return true end

		end

	end

	return false

end

function meta:GetNodeTypes( graph )

	local types = {}
	local base = bpdefs.Get():GetNodeTypes()

	for id, v in self:Variables() do

		local name = v:GetName()
		types["__VSet" .. id] = v:SetterNodeType()
		types["__VGet" .. id] = v:GetterNodeType()

	end

	for id, v in self:Graphs() do

		if v:GetType() == GT_Function and v ~= graph then

			types["__Call" .. id] = v:GetCallNodeType()
			if not types["__Call" .. id] then print("FUNCTION GRAPH WITHOUT CALL NODE: " .. id) end

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

function meta:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	graph:AddNode("CORE_Init", 120, 100)
	graph:AddNode("GM_Think", 120, 300)
	graph:AddNode("CORE_Shutdown", 120, 500)

end

function meta:NewVariable(name, type, default, flags, ex)

	return self.variables:Add( bpvariable.New(type, default, flags, ex), name )

end

function meta:NewGraph(name, type)

	local id, graph = self.graphs:ConstructNamed( name, type )
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

	for _, v in ipairs(nodeType:GetPins()) do

		if v:IsType(PN_Exec) then continue end
		if v:IsOut() then
			graph.inputs:Add(v:Copy(), v:GetName())
		else
			graph.outputs:Add(v:Copy(), v:GetName())
		end

	end

end

function meta:NetSend()

	bpcommon.ProfileStart("module:NetSend")
	bpcommon.Profile("module-net-write", function()
		local outStream = bpdata.OutStream()
		outStream:UseStringTable()
		bpcommon.Profile( "write-module", self.WriteToStream, self, outStream, STREAM_NET )
		bpcommon.Profile( "write-net-stream", outStream.WriteToNet, outStream, true )
	end)
	bpcommon.ProfileEnd()

end

function meta:NetRecv()

	bpcommon.ProfileStart("module:NetRecv")
	bpcommon.Profile("module-net-read", function()
		local inStream = bpdata.InStream()
		inStream:UseStringTable()
		bpcommon.Profile( "read-net-stream", inStream.ReadFromNet, inStream, true )
		bpcommon.Profile( "read-module", self.ReadFromStream, self, inStream, STREAM_NET )
	end)
	bpcommon.ProfileEnd()

end

function LoadHeader(filename)

	local inStream = bpdata.InStream(false, true)
	if not inStream:LoadFile(filename, true, true) then
		error("Failed to load blueprint, try using 'Convert'")
	end

	local magic = inStream:ReadInt( false )

	if magic ~= fmtMagic then
		--print("Probably using string table, try that")
		inStream:Reset()
		inStream:UseStringTable()
		inStream:LoadFile(filename, true, true)
		magic = inStream:ReadInt( false )
	end

	return {
		magic = magic,
		version = inStream:ReadInt( false ),
		type = inStream:ReadInt( false ),
		revision = inStream:ReadInt( false ),
		uid = inStream:ReadStr( 16 ),
	}

end

function meta:Load(filename)

	local head = LoadHeader(filename)
	local magic = head.magic
	local version = head.version

	print("MAGIC: " .. magic)
	print("VERSION: " .. version)

	local inStream = bpdata.InStream(false, true)
	if version >= 4 then inStream:UseStringTable() end
	if not inStream:LoadFile(filename, true, true) then
		error("Failed to load blueprint, try using 'Convert'")
	end

	self:ReadFromStream( inStream, STREAM_FILE )

end

function meta:Save(filename)

	local outStream = bpdata.OutStream(false, true)
	outStream:UseStringTable()
	self:WriteToStream( outStream, STREAM_FILE )
	outStream:WriteToFile(filename, true, true)

end

function meta:WriteToStream(stream, mode)

	-- each save to disk is a revision on the loaded original

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

	self.suppressGraphNotify = true

	local magic = stream:ReadInt( false )
	local version = stream:ReadInt( false )

	if magic ~= fmtMagic then error("Invalid blueprint data: " .. fmtMagic .. " != " .. magic) end
	if version > fmtVersion then error("Blueprint data version is newer") end

	print("MODULE VERSION: " .. version)

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

	self.suppressGraphNotify = false

	return self

end

function meta:CreateTestModule()

	local a = self:GetGraph( self:NewGraph("Function") )
	local b = self:GetGraph( self:NewGraph("EventGraph") )

	a:CreateTestGraph()
	b:CreateTestGraph()

	return self

end

function meta:Compile(flags)

	local compiler = bpcompiler.New(self, flags)
	return compiler:Compile()

end

function meta:TryCompile(flags)

	local compiler = bpcompiler.New(self, flags)
	local b, e = pcall(compiler.Compile, compiler)
	if not b then
		return false, e
	else
		return true, e
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