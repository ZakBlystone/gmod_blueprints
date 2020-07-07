AddCSLuaFile()

module("bpgraph", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

FL_NONE = 0
FL_LOCK_PINS = 1
FL_LOCK_NAME = 2
FL_HOOK = 4
FL_ROLE_SERVER = 8
FL_ROLE_CLIENT = 16
FL_SERIALIZE_NAME = 32

local meta = bpcommon.MetaTable("bpgraph")

New = nil

bpcommon.CreateIndexableListIterators(meta, "nodes")
bpcommon.CreateIndexableListIterators(meta, "inputs")
bpcommon.CreateIndexableListIterators(meta, "outputs")
bpcommon.AddFlagAccessors(meta)

function meta:Init(type)

	self.flags = FL_NONE
	self.type = type or GT_Event
	self.hookNodeType = nil

	-- Create lists for graph elements
	self.nodes = bplist.New(bpnode_meta):WithOuter(self)
	self.inputs = bplist.New(bppin_meta):NamedItems("Inputs"):WithOuter(self)
	self.outputs = bplist.New(bppin_meta):NamedItems("Outputs"):WithOuter(self)

	-- Listen for changes in the input variable list (function graph)
	self.inputs:Bind("preModify", self, self.PreModify)
	self.inputs:Bind("postModify", self, self.PostModify)

	-- Listen for changes in the output variable list (function graph)
	self.outputs:Bind("preModify", self, self.PreModify)
	self.outputs:Bind("postModify", self, self.PostModify)

	-- Listen for changes in the node list
	self.nodes:BindRaw("added", self, function(id, node) self:Broadcast("nodeAdded", node) end)
	self.nodes:BindRaw("removed", self, function(id, node)
		node:BreakAllLinks()
		self:Broadcast("nodeRemoved", node)
	end)

	local pinmeta = bpcommon.FindMetaTable("bppin")

	-- For function graphs
	-- Function to call graph entry point
	self.callNodeType = bpnodetype.New():WithOuter( self )
	self.callNodeType:AddFlag(NTF_Custom)
	self.callNodeType:SetCodeType(NT_Function)
	self.callNodeType:SetNodeClass("UserFuncCall")
	self.callNodeType.GetDisplayName = function() return self:GetName() end
	self.callNodeType.GetCategory = function() return self:GetModule() and self:GetModule():GetName() or self:GetName() end
	self.callNodeType.GetGraphThunk = function() return self end
	self.callNodeType.GetRole = function() return self:GetNetworkRole() end

	-- Entry point node
	self.callEntryNodeType = bpnodetype.New():WithOuter( self )
	self.callEntryNodeType:SetCodeType(NT_FuncInput)
	self.callEntryNodeType:SetName("__Entry")
	self.callEntryNodeType:AddFlag(NTF_NoDelete)
	self.callEntryNodeType:SetNodeClass("UserFuncEntry")
	self.callEntryNodeType.GetDisplayName = function() return self:GetName() end
	self.callEntryNodeType.GetRole = function() return self:GetNetworkRole() end

	-- Return node
	self.callExitNodeType = bpnodetype.New():WithOuter( self )
	self.callExitNodeType:SetCodeType(NT_FuncOutput)
	self.callExitNodeType:SetDisplayName("Return")
	self.callExitNodeType:SetName("__Exit")
	self.callExitNodeType:SetNodeClass("UserFuncExit")

	bpcommon.MakeObservable(self)

	return self

end

function meta:Destroy()

	self.callNodeType:Destroy()
	self.callEntryNodeType:Destroy()
	self.callExitNodeType:Destroy()

end

function meta:ToString()

	return self:GetName() or "unnamed"

end

function meta:GetModule()

	return self:FindOuter( bpmodule_meta )

end

function meta:CreateDefaults()

	-- Function graphs add entry and exit nodes on creation
	if self.type == GT_Function then

		self:AddNode(self.callEntryNodeType, 0, 200)
		self:AddNode(self.callExitNodeType, 400, 200)

	end

end

function meta:PreModify()

	self.callEntryNodeType:PreModify()
	self.callExitNodeType:PreModify()
	self.callNodeType:PreModify()

end

function meta:PostModify()

	self.callEntryNodeType:PostModify()
	self.callExitNodeType:PostModify()
	self.callNodeType:PostModify()

end

function meta:CanRename() return not self:HasFlag(FL_LOCK_NAME) end

function meta:SetHookType( nodeType )

	self.hookNodeType = nodeType

end

function meta:GetHookType()

	return self.hookNodeType

end

function meta:GetType()

	return self.type

end

function meta:SetName( name )

	self.name = name

end

function meta:GetName()

	return self.name

end

function meta:GetTitle()

	return self:GetName()

end

function meta:GetModule()

	return self:FindOuter( bpmodule_meta )

end

function meta:GetCallNodeType()

	return self.callNodeType

end

function meta:GetEntryNodeType()

	return self.callEntryNodeType

end

function meta:GetExitNodeType()

	return self.callExitNodeType

end

function meta:GetEntryNode()

	return self:FindNodeByType( self:GetEntryNodeType() )

end

function meta:GetExitNode()

	return self:FindNodeByType( self:GetExitNodeType() )

end

function meta:CacheNodeTypes()

	self.__cachedTypes = nil
	self.__cachedTypes = self:GetNodeTypes()

end

function meta:GetNetworkRole()

	local role = nil
	if self:HasFlag(FL_ROLE_CLIENT) and self:HasFlag(FL_ROLE_SERVER) then role = ROLE_Shared
	elseif self:HasFlag(FL_ROLE_SERVER) then role = ROLE_Server
	elseif self:HasFlag(FL_ROLE_CLIENT) then role = ROLE_Client end

	return role

end

function meta:GetNodeTypes()

	if self.__cachedTypes then return self.__cachedTypes end

	local collection = bpcollection.New()

	Profile("cache-node-types", function()
		self:GetModule():GetAllNodeTypes( collection, self )
		self:GetModule():GetLocalNodeTypes( collection, self )

		if self.type == GT_Function then
			local types = {}

			types["__Entry"] = self.callEntryNodeType
			types["__Exit"] = self.callExitNodeType

			collection:Add( types )
		end
	end)

	return collection

end

function meta:AllPins()

	local nodes = self.nodes:GetTable()
	local i = 1
	local j = 1
	local num = #nodes

	return function()
		if i > num then return end
		local n = nodes[i]
		local p = n:GetPins()
		local o
		if j >= #p then
			i = i + 1
			o = p[j]
			j = 1
			return o
		else
			o = p[j]
			j = j + 1
			return o
		end
	end

end

function meta:GetNodePin(nodeID, pinID)

	return self:GetNode(nodeID):GetPin(pinID)

end

function meta:GetUsedPinTypes(used, noFlags)

	used = used or {}
	for nodeID, node in self:Nodes() do
		for pinID, pin in node:Pins() do
			local pinType = pin:GetType()
			if noFlags then pinType = pinType:WithFlags(0) end
			if not table.HasValue(used, pinType) then
				used[#used+1] = pinType
			end
		end
	end
	return used

end

-- Starting at a given node, traverses connections in the graph which match a condition
function meta:NodeWalk(node, condition, visited)

	visited = visited or {}

	local max = 10000
	local stack = {}
	local connections = {}

	-- Add node connections to stack
	local function AddNodeConnections(node)
		if visited[node] then return end visited[node] = true
		for pinID, pin in node:Pins(nil, true) do
			for _, v in ipairs( pin:GetConnectedPins() ) do
				assert(v:GetNode() ~= nil)
				if not v:GetNode():IsFullyLoaded() then continue end
				-- Push connection onto stack if condition passes
				if condition(v:GetNode(), v.id) then stack[#stack+1] = {pin, v} end
			end
		end
	end

	-- Add current node's connections
	AddNodeConnections(node)

	while #stack > 0 and max > 0 do
		max = max - 1

		-- Pop connection from stack and insert it into output table
		local conn = stack[#stack]
		table.remove(stack, #stack)
		connections[#connections+1] = conn

		local node0 = conn[1]:GetNode()
		local node1 = conn[2]:GetNode()

		-- Recurse into the node that hasn't been visited yet
		AddNodeConnections(visited[node0] and node1 or node0)

	end

	if max == 0 then error("Infinite loop in graph") end
	return connections

end

function meta:BuildInformDirectionalCandidates(dir, candidateNodes)

	for id, node in self:Nodes() do
		for pinID, pin in node:SidePins(dir) do
			if node:IsInformPin(pinID) then
				for _, v in ipairs( pin:GetConnectedPins() ) do
					local other = v:GetNode()
					if other == nil then continue end
					if other:IsInformPin( v.id ) == false and v:GetBaseType() ~= PN_Any then
						if not table.HasValue(candidateNodes, other) then
							candidateNodes[#candidateNodes+1] = other
						end
					end
				end
			end
		end
	end

end

function meta:WalkInforms()

	Profile("walk-inform-exec", function()

		for pin in self:AllPins() do
			if pin:IsType(PN_Exec) then
				pin:SetInformedType(nil)
			end
		end


		self:ExecWalk( function(node)

			local infer = 0
			for _, pin in node:SidePins(PD_In, bpnode.PF_OnlyExec) do

				for _, other in ipairs(pin:GetConnectedPins()) do

					if other:HasFlag(PNF_Server) then infer = bit.bor(infer, PNF_Server) end
					if other:HasFlag(PNF_Client) then infer = bit.bor(infer, PNF_Client) end

				end

			end

			if infer == PNF_Server or infer == PNF_Client then
				for _, pin in node:Pins(bpnode.PF_OnlyExec) do
					if not pin:HasFlag(PNF_Server) and not pin:HasFlag(PNF_Client) then
						pin:SetInformedType( pin:GetType():WithFlags( infer ) )
					end
				end
			end

		end, true )

	end)

	Profile("walk-informs", function()

		local candidateNodes = {}
		local visited = {}

		if self.suppressInformWalk then return end

		-- Clear all informs on all nodes
		for id, node in self:Nodes() do node:ClearInforms() end

		self:BuildInformDirectionalCandidates(PD_In, candidateNodes)

		for _, v in ipairs(candidateNodes) do
			local connections = self:NodeWalk(v, function(node, pinID)
				return node:IsInformPin(pinID) and node:GetPin(pinID):GetDir() == PD_In
			end, visited)
			local pinType = nil
			for _,c in ipairs(connections) do
				if not c[1]:GetNode():IsInformPin(c[1].id) then pinType = c[1]:GetType(true) end
				c[2]:GetNode():SetInform(pinType)
			end
		end

		self:BuildInformDirectionalCandidates(PD_Out, candidateNodes)

		for _, v in ipairs(candidateNodes) do
			local connections = self:NodeWalk(v, function(node, pinID)
				return node:IsInformPin(pinID) and node:GetPin(pinID):GetDir() == PD_Out
			end, visited)
			local pinType = nil
			for _,c in ipairs(connections) do
				if not c[1]:GetNode():IsInformPin(c[1].id) then pinType = c[1]:GetType(true) end
				c[2]:GetNode():SetInform(pinType)
			end
		end

	end)

end

function meta:GetPinType(nodeID, pinID)

	local node = self:GetNode(nodeID)
	local pin = node:GetPin(pinID)
	return pin:GetType()

end

function meta:FindNodeByType(nodeType)

	for _, node in self:Nodes() do
		if node:GetType() == nodeType then return node end
	end
	return nil

end

function meta:NodePinToString(nodeID, pinID)

	return self:GetNode(nodeID):ToString(pinID)

end

function meta:Clear()

	self.nodes:Clear()
	self.inputs:Clear()
	self.outputs:Clear()

	self:Broadcast("cleared")

end

function meta:CanAddNode(nodeType)

	if not self:GetModule():CanAddNode(nodeType) then return false end

	if self.type == GT_Function then
		if nodeType:HasFlag(NTF_Latent) then return false end
		if nodeType:GetCodeType() == NT_Event then return false end
	end

	if nodeType:GetCodeType() == NT_Event and self:GetModule():NodeTypeInUse(nodeType:GetFullName()) then
		return false
	end

	if nodeType:GetCodeType() == NT_FuncInput or nodeType:GetCodeType() == NT_FuncOutput then
		if nodeType:FindOuter( bpgraph_meta ) ~= self then return false end
	end

	if nodeType:GetCodeType() == NT_FuncInput then
		for _, node in self:Nodes() do
			if node:GetCodeType() == NT_FuncInput then return false end
		end
	end

	return true

end

function meta:AddNode(nodeTypeName, ...)

	nodeType = type(nodeTypeName) == "table" and nodeTypeName or self:GetNodeTypes():Find(nodeTypeName)
	if nodeType == nil then error("Node type not found: " .. tostring(nodeTypeName)) end

	if not self:CanAddNode(nodeType) then return end

	if nodeType:GetCodeType() == NT_Event and nodeType:ReturnsValues() then
		local graph = self:GetModule():RequestGraphForEvent(nodeType)
		if graph then return graph end
	end

	local id, newNode = self.nodes:Construct( nodeType, ... )
	return id, newNode

end

function meta:CollapseSingleRerouteNode( node )

	local inputs = {}
	local outputs = {}

	for _, pin in ipairs(node:GetPin(1):GetConnectedPins()) do inputs[#inputs+1] = pin end
	for _, pin in ipairs(node:GetPin(2):GetConnectedPins()) do outputs[#outputs+1] = pin end

	node:BreakAllLinks()

	if #inputs == 0 or #outputs == 0 then return
	elseif #inputs == 1 then for _, pin in ipairs(outputs) do inputs[1]:MakeLink( pin ) end
	elseif #outputs == 1 then for _, pin in ipairs(inputs) do outputs[1]:MakeLink( pin ) end
	else error("Invalid state on reroute node: " .. #inputs .. " inputs, " .. #outputs .. " outputs") end

end

function meta:CollapseRerouteNodes()

	self.suppressInformWalk = true

	for _, node in self:Nodes(true) do
		if node:GetType():HasFlag(NTF_Collapse) then
			self:CollapseSingleRerouteNode( node )
		end
	end

	self.suppressInformWalk = false
	self:WalkInforms()

end

function meta:Serialize(stream)

	self:CacheNodeTypes()

	local external = {}
	for _, v in self.nodes:Items() do
		if stream:IsNetwork() or true then
			if v:GetType():FindOuter(bpdefpack_meta) ~= nil then
				external[#external+1] = v:GetType():GetFullName()
			end
		else
			external[#external+1] = v:GetType()
		end
	end

	if stream:IsNetwork() or true then
		local types = self:GetNodeTypes()
		for _, v in ipairs( stream:StringArray(external) ) do
			stream:Extern(types:Find(v), "\xE3\x01\x45\x7E\x79\x4E\xEE\x21\x80\x00\x00\x0B\x4F\xEF\x14\x26")
			--print("EXTERNAL NODE TYPE: " .. tostring(types:Find(v)) )
		end
	else
		-- TODO, reconstitute outer groups on external nodetypes
		external = stream:ObjectArray(external)
		self.strongNodeTypeRef = external
	end

	stream:Extern( self:GetCallNodeType(), "\xE3\x01\x45\x7E\x7A\x7A\x16\x2F\x80\x00\x00\x0C\x50\x2A\xF7\x62" )
	stream:Extern( self:GetEntryNodeType(), "\xE3\x01\x45\x7E\x4E\x7A\x49\x9F\x80\x00\x00\x0D\x50\x41\x15\x7A" )
	stream:Extern( self:GetExitNodeType(), "\xE3\x01\x45\x7E\xC5\x9C\x09\x94\x80\x00\x00\x0E\x50\x4C\x94\x86" )

	self.type = stream:UInt(self.type)
	self.flags = stream:UInt(self.flags)

	if self.type == GT_Function then

		self.inputs:SuppressAllEvents(true)
		self.outputs:SuppressAllEvents(true)
		self.inputs:Serialize(stream)
		self.outputs:Serialize(stream)
		self.inputs:SuppressAllEvents(false)
		self.outputs:SuppressAllEvents(false)

	end

	self.nodes:Serialize(stream)
	self.hookNodeType = stream:String(self.hookNodeType)

	if self:HasFlag(FL_SERIALIZE_NAME) then
		self.name = stream:String(self.name)
	end

	return stream

end

function meta:PostLoad()

	self:WalkInforms()

end

-- Quickly banging this out using existing tech
function meta:CopyInto(other)

	Profile("copy-graph", function()

		other:Clear()
		other.name = self.name
		other.type = self.type
		other.flags = self.flags
		other.hookNodeType = self.hookNodeType
		other.suppressPinEvents = true

		-- Store connections as indices
		local connections = {}
		local ids = bpindexer.New()
		for pin in self:AllPins() do ids:Get(pin) end
		for pin in self:AllPins() do
			if not pin:IsOut() then continue end
			for _, conn in ipairs(pin:GetConnections()) do
				if not conn:IsValid() then continue end
				connections[#connections+1] = {ids:Get(pin), ids:Get(conn())}
			end
		end

		Profile("copy-nodes", self.nodes.CopyInto, self.nodes, other.nodes )
		Profile("copy-inputs", self.inputs.CopyInto, self.inputs, other.inputs )
		Profile("copy-outputs", self.outputs.CopyInto, self.outputs, other.outputs )
		Profile("copy-init-nodes", function()
			for _, node in other:Nodes() do node:Initialize(true) node.nodeType():UnbindAll(node) end
		end)

		Profile("copy-restore-connections", function()

			-- Restore connections
			local ids = bpindexer.New()
			for pin in other:AllPins() do ids:Get(pin) end
			for _, conn in ipairs(connections) do
				local a = ids:FindByID(conn[1])
				local b = ids:FindByID(conn[2])
				if a and b then a:MakeLink(b, true) end
			end

		end)

		other.suppressPinEvents = false
		other:WalkInforms()

	end)

	return other

end

function meta:CreateSubGraph( subNodes )

	local pre = bpindexer.New()
	local discard = {}
	for _, node in self:Nodes() do pre:Get(node) end
	for _, node in ipairs(subNodes) do discard[pre:Get(node)] = true end

	local copy = self:CopyInto( New():WithOuter( self:GetModule() ) )
	local hold = {}

	local post = bpindexer.New()
	for _, node in copy:Nodes() do post:Get(node) end

	copy:CacheNodeTypes()
	copy:RemoveNodeIf( function(node) return not discard[post:Get(node)] end )
	copy:WalkInforms()

	local severedPins = {}
	-- TODO: Fix this
	--[[for _, v in ipairs(hold) do

		if table.HasValue(subNodeIds, v[1]) and not table.HasValue(subNodeIds, v[3]) then
			severedPins[#severedPins+1] = {v[1], v[2]}
		end

		if not table.HasValue(subNodeIds, v[1]) and table.HasValue(subNodeIds, v[3]) then
			severedPins[#severedPins+1] = {v[3], v[4]}
		end

	end]]

	copy.severedPins = severedPins

	return copy

end

function meta:AddSubGraph( subgraph, x, y )

	local connectionRemap = {}
	local copy = subgraph:CopyInto( New() )
	local nodeCount = 0
	local connectionCount = 0

	for id, node in copy:Nodes() do

		if self:CanAddNode(node:GetType()) then

			local nx, ny = node:GetPos()
			node:Move(nx + x, ny + y)
			node.id = nil
			node.BaseClass = bpcommon.MetaTable("bpnode")
			local newID = self.nodes:Add( node )
			connectionRemap[id] = newID
			nodeCount = nodeCount + 1

		end

	end

end

function meta:PreCompile( compiler, uniqueKeys )

	-- prepare graph
	self:CacheNodeTypes()
	self:CollapseRerouteNodes()

	-- mark all nodes reachable via execution
	self:ExecWalk( function(node)
		node.execReachable = true
	end )

	compiler:EnumerateGraphVars(self, uniqueKeys)
	compiler:CompileGraphJumpTable(self)
	compiler:CompileGraphVarListing(self)

	-- compile prepass on all nodes
	for id, node in self:Nodes() do
		if node:GetCodeType() == NT_Pure and node:WillExecute() then compiler:RunNodeCompile(node, CP_PREPASS) end
	end

	self:ExecWalk( function(node)
		compiler:RunNodeCompile( node, CP_PREPASS )
	end )

	return self

end

function meta:CompileEntrypoint( compiler )

	local graphID = compiler:GetID(self)

	compiler:CompileGraphNodeJumps( self )

	-- check if graph requires a callstack
	local requireCallStack = false
	local statics = {}
	self:ExecWalk( function(node)
		if node:HasFlag(NTF_CallStack) then requireCallStack = true end
		if node.GetGraphStatics then node:GetGraphStatics( compiler, statics ) end
	end )

	compiler.begin(CTX_Graph .. graphID)

	for _, v in ipairs(statics) do
		compiler.emitContext(v)
	end

	-- graph function header and callstack
	compiler.emit("local graph_" .. graphID .. "_entry = __graph( function( ip )\n")

	-- debugging info
	if compiler.debug then compiler.emit( "\t__dbggraph = " .. graphID) end

	-- emit graph-local variables, callstack, and jumptable
	compiler.emitContext( CTX_Vars .. graphID, 1 )
	if requireCallStack then compiler.emit( "\t_FR_CALLSTACK()") end
	compiler.emitContext( CTX_JumpTable .. graphID, 1 )

	-- emit all functions belonging to this graph
	--local code = compiler.getFilteredContexts( CTX_FunctionNode .. graphID )
	--for k, _ in pairs(code) do compiler.emitContext( k, 1 ) end

	self:ExecWalk( function(node)
		compiler.emitContext( CTX_FunctionNode .. graphID .. "_" .. compiler:GetID(node), 1 )
	end )

	-- emit terminus jump vector
	if not requireCallStack then
		compiler.emit("\n\t::popcall:: ::__terminus::\n")
	else
		compiler.emit("\n\t::__terminus::\n")
	end

	compiler.emit("end)")
	compiler.finish()

	--print("COMPILED GRAPH: " .. graphID)

end

function meta:ExecWalk( func, allNodes )

	local visited = {}
	local emitted = {}

	for _, node in self:Nodes() do

		local codeType = node:GetCodeType()
		if codeType == NT_Event or codeType == NT_FuncInput or allNodes then

			if allNodes then
				local hasIncoming = false
				for _, pin in node:SidePins(PD_In, bpnode.PF_OnlyExec) do
					if #pin:GetConnections() ~= 0 then hasIncoming = true break end
				end
				if hasIncoming then goto skip end
			end

			local connections = self:NodeWalk(node, function(node, pinID)
				assert(node:GetPin(pinID) ~= nil, tostring(node) .. " is missing pin " .. tostring(pinID))
				return node:GetPin(pinID):IsType(PN_Exec) and node:GetPin(pinID):GetDir() == PD_In
			end, visited)


			for k, v in ipairs(connections) do

				local nodeA = v[1]:GetNode()
				local nodeB = v[2]:GetNode()
				if not emitted[nodeA] then func(nodeA) emitted[nodeA] = true end
				if not emitted[nodeB] then func(nodeB) emitted[nodeB] = true end

			end

			if #connections == 0 and not emitted[node] then
				func(node) emitted[node] = true 
			end

			::skip::

		end

	end

end

function meta:CompileNodes( compiler )

	local graphID = compiler:GetID(self)

	--print("COMPILING NODES FOR GRAPH: " .. graphID)

	local prevNode = nil
	self:ExecWalk( function(node)
		if prevNode then prevNode.__nextExec = node end
		prevNode = node
	end )

	-- compile each single-node context in the graph
	for id, node in self:Nodes() do
		if node:GetCodeType() == NT_Pure and node:WillExecute() then
			Profile("single-node", compiler.CompileNodeSingle, compiler, node)
		end
	end

	self:ExecWalk( function(node)
		Profile("single-node", compiler.CompileNodeSingle, compiler, node)
	end )

	-- compile all non-pure function nodes in the graph (and events / special nodes)
	self:ExecWalk( function(node)
		Profile("functions", compiler.CompileNodeFunction, compiler, node)
	end )

	-- compile hook listing for this graph if it is an event hook
	compiler.begin(CTX_Hooks .. graphID)

	if self:HasFlag(bpgraph.FL_HOOK) then
		local nodeType = self:GetNodeTypes():Find(self:GetHookType())
		local hookName = nodeType and nodeType:GetName() or self:GetName()

		local args = {self:GetHookType() or self:GetName(), hookName, graphID, -1}
		compiler.emit("_FR_HOOK(" .. table.concat(args, ",") .. ")")
	end

	compiler.finish()

end

function meta:Compile( compiler, pass )

	--print("COMPILING GRAPH: " .. self:GetName())

	if pass == CP_MAINPASS then

		--print("COMPILING GRAPH MAIN-PASS: " .. self:GetName())

		self:CompileNodes( compiler )
		self:CompileEntrypoint( compiler )

	end

end

New = function(...) return bpcommon.MakeInstance(meta, ...) end