AddCSLuaFile()

module("mod_graphmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = false
MODULE.Name = "GraphModule"

bpcommon.CreateIndexableListIterators(MODULE, "graphs")
bpcommon.CreateIndexableListIterators(MODULE, "variables")
bpcommon.CreateIndexableListIterators(MODULE, "structs")
bpcommon.CreateIndexableListIterators(MODULE, "events")

function MODULE:Setup()

	self.graphs = bplist.New(bpgraph_meta, self, "module"):NamedItems("Graph")
	if self:CanHaveStructs() then self.structs = bplist.New(bpstruct_meta, self, "module"):NamedItems("Struct") end
	if self:CanHaveVariables() then self.variables = bplist.New(bpvariable_meta, self, "module"):NamedItems("Var") end
	if self:CanHaveEvents() then self.events = bplist.New(bpevent_meta, self, "module"):NamedItems("Event") end
	self.suppressGraphNotify = false

	self.graphs:AddListener(function(cb, id, graph)

		if cb == bplist.CB_ADD then
			graph:AddListener(function() self:PostModifyGraph(graph) end)
			self:FireListeners(bpmodule.CB_GRAPH_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			self:RemoveNodeTypes({ graph:GetCallNodeType() })
			self:FireListeners(bpmodule.CB_GRAPH_REMOVE, id)
			self:RecacheNodeTypes()
		end

	end, bplist.CB_ALL)

	-- Structs
	if self:CanHaveStructs() then
		
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

	end

	-- Events
	if self:CanHaveEvents() then

		self.events:AddListener(function(cb, id, event)
			if cb == bplist.CB_REMOVE then self:RemoveNodeTypes({ event:EventNodeType(), event:CallNodeType() }) end
			self:RecacheNodeTypes()
		end, bit.bor(bplist.CB_REMOVE, bplist.CB_ADD))

		self.events:AddListener(function(cb, action, id, event)

			if action ~= bplist.MODIFY_RENAME then return end
			if cb == bplist.CB_PREMODIFY then
				self:PreModifyNodeType( event:EventNodeType() )
				self:PreModifyNodeType( event:CallNodeType() )
			elseif cb == bplist.CB_POSTMODIFY then
				self:PostModifyNodeType( event:EventNodeType() )
				self:PostModifyNodeType( event:CallNodeType() )
			end

		end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	end

	-- Variables
	if self:CanHaveVariables() then

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

	end

	print("SETUP GRAPH MODULE")

end

function MODULE:PreModifyNodeType( nodeType )

	for _, graph in self:Graphs() do
		graph:PreModifyNodeType( nodeType )
	end

	BaseClass.PreModifyNodeType( self, nodeType )

end

function MODULE:PostModifyNodeType( nodeType )

	for _, graph in self:Graphs() do
		graph:PostModifyNodeType( nodeType )
	end

	BaseClass.PostModifyNodeType( self, nodeType )

end

function MODULE:RemoveNodeTypes( nodeTypes )

	for _, graph in self:Graphs() do
		graph.nodes:RemoveIf( function(node) return table.HasValue( nodeTypes, node:GetType() ) end )
	end

end

function MODULE:RecacheNodeTypes()

	for _, graph in self:Graphs() do
		graph:CacheNodeTypes()
	end

end

function MODULE:NodeTypeInUse( nodeType )

	for id, v in self:Graphs() do

		for _, node in v:Nodes() do

			if node:GetTypeName() == nodeType then return true end

		end

	end

	return BaseClass.NodeTypeInUse( self, nodeType )

end

function MODULE:PostModifyGraph( graph )

	if not self.suppressGraphNotify then
		self:FireListeners(bpmodule.CB_GRAPH_MODIFIED, graph)
	end

end

function MODULE:GetNodeTypes( collection, graph )

	BaseClass.GetNodeTypes( self, collection )

	local types = {}

	collection:Add( types )

	if self:CanHaveVariables() then

		for id, v in self:Variables() do

			local name = v:GetName()
			types["__VSet" .. id] = v:SetterNodeType()
			types["__VGet" .. id] = v:GetterNodeType()

		end

	end

	for id, v in self:Graphs() do

		if v:GetType() == GT_Function and v ~= graph then

			types["__Call" .. id] = v:GetCallNodeType()
			if not types["__Call" .. id] then print("FUNCTION GRAPH WITHOUT CALL NODE: " .. id) end

		end

	end

	if self:CanHaveStructs() then

		for id, v in self:Structs() do

			types["__Make" .. id] = v:MakerNodeType()
			types["__Break" .. id] = v:BreakerNodeType()

		end

	end

	if self:CanHaveEvents() then

		for id, v in self:Events() do

			types["__EventCall" .. id] = v:CallNodeType()
			types["__Event" .. id] = v:EventNodeType()

		end

	end

	for k,v in pairs(types) do v.name = k end

end

function MODULE:GetPinTypes( collection )

	BaseClass.GetPinTypes( self, collection )

	local types = {}

	collection:Add( types )

	if self:CanHaveStructs() then

		for id, v in self:Structs() do

			local pinType = PinType(PN_Struct, PNF_Custom, v.name)
			types[#types+1] = pinType

		end

	end

end

function MODULE:NodeTypeInUse( nodeType )

	for id, v in self:Graphs() do

		for _, node in v:Nodes() do

			if node:GetTypeName() == nodeType then return true end

		end

	end

	return false

end

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	graph:AddNode("CORE_Init", 120, 100)
	graph:AddNode("GM_Think", 120, 300)
	graph:AddNode("CORE_Shutdown", 120, 500)

	BaseClass.CreateDefaults( self )

end

function MODULE:Clear()

	self.graphs:Clear()
	if self:CanHaveVariables() then self.variables:Clear() end

	BaseClass.Clear( self )

end

function MODULE:NewVariable(name, ...)

	if not self:CanHaveVariables() then return end
	return self.variables:ConstructNamed( name, ... )

end

function MODULE:NewGraph(name, type)

	local id, graph = self.graphs:ConstructNamed( name, type )
	return id, graph

end

function MODULE:GetUsedPinTypes(used, noFlags)

	used = used or {}
	for graphID, graph in self:Graphs() do
		graph:GetUsedPinTypes(used, noFlags)
	end
	return BaseClass.GetUsedPinTypes(self, used, noFlags)

end

function MODULE:RequestGraphForEvent( nodeType )

	print("REQUEST GRAPH FOR: " .. nodeType:GetName())

	for _, graph in self:Graphs() do
		if graph:GetName() == nodeType:GetDisplayName() then return end
	end

	local id, graph = self:NewGraph(nodeType:GetDisplayName(), NT_Function)
	graph:SetFlag(bpgraph.FL_LOCK_PINS)
	graph:SetFlag(bpgraph.FL_LOCK_NAME)

	if not nodeType:HasFlag(NTF_NotHook) then
		graph:SetFlag(bpgraph.FL_HOOK)
	end

	graph:SetHookType( nodeType:GetName() )

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

	return graph

end

function MODULE:CanHaveVariables() return true end
function MODULE:CanHaveStructs() return true end
function MODULE:CanHaveEvents() return true end

function MODULE:WriteData( stream, mode, version )

	BaseClass.WriteData( self, stream, mode, version )

	if self:CanHaveVariables() then Profile("write-variables", self.variables.WriteToStream, self.variables, stream, mode, version) end
	Profile("write-graphs", self.graphs.WriteToStream, self.graphs, stream, mode, version)
	if self:CanHaveStructs() then Profile("write-structs", self.structs.WriteToStream, self.structs, stream, mode, version) end
	if self:CanHaveEvents() then Profile("write-events", self.events.WriteToStream, self.events, stream, mode, version) end

end

function MODULE:ReadData( stream, mode, version )

	BaseClass.ReadData( self, stream, mode, version )

	self.suppressGraphNotify = true

	if self:CanHaveVariables() then Profile("read-variables", self.variables.ReadFromStream, self.variables, stream, mode, version) end
	Profile("read-graphs", self.graphs.ReadFromStream, self.graphs, stream, mode, version)
	if self:CanHaveStructs() then Profile("read-structs", self.structs.ReadFromStream, self.structs, stream, mode, version) end
	if self:CanHaveEvents() then Profile("read-events", self.events.ReadFromStream, self.events, stream, mode, version) end

	for _, graph in self:Graphs() do
		graph:CreateDeferredData()
	end

	self.suppressGraphNotify = false

end

function MODULE:CompileVariable( compiler, var )

	local def = var:GetDefault()
	local vtype = var:GetType()

	if vtype:GetBaseType() == PN_String and bit.band(vtype:GetFlags(), PNF_Table) == 0 then def = "\"\"" end

	local varName = var:GetName()
	if compiler.compactVars then varName = id end
	if type(def) == "string" then
		compiler.emit("instance.__" .. varName .. " = " .. tostring(def))
	else
		print("Emit variable as non-string")
		local pt = bpvaluetype.FromPinType( vtype, function() return def end )
		if pt then
			compiler.emit("instance.__" .. varName .. " = " .. pt:ToString())
		else
			compiler.emit("instance.__" .. varName .. " = " .. tostring(def))
		end
	end

end

function MODULE:Compile( compiler, pass )

	if pass == CP_MODULEGLOBALS then

		if self:CanHaveVariables() then

			for id, var in self:Variables() do

				self:CompileVariable( compiler, var )

			end

		end

	end

end

RegisterModuleClass("GraphModule", MODULE)