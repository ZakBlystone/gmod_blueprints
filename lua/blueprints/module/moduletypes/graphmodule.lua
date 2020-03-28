AddCSLuaFile()

module("mod_graphmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = false
MODULE.Name = LOCTEXT"GraphModule"
MODULE.HasSelfPin = false
MODULE.EditorClass = "graphmodule"

bpcommon.CreateIndexableListIterators(MODULE, "graphs")
bpcommon.CreateIndexableListIterators(MODULE, "variables")
bpcommon.CreateIndexableListIterators(MODULE, "structs")
bpcommon.CreateIndexableListIterators(MODULE, "events")

function MODULE:Setup()

	BaseClass.Setup(self)

	self.graphs = bplist.New(bpgraph_meta):NamedItems("Graph"):WithOuter(self)
	self.suppressGraphNotify = false

	-- Graphs
	self.graphs:BindRaw("added", self, function(id, graph)
		graph:BindAny(self, function() self:PostModifyGraph(graph) end)
		self:Broadcast("graphAdded", id)
	end)
	self.graphs:BindRaw("removed", self, function(id, graph)
		self:RemoveNodeTypes({ graph:GetCallNodeType() })
		self:Broadcast("graphRemoved", id)
		self:RecacheNodeTypes()
	end)
	self.graphs:BindRaw("preModify", self, function(action, id, graph)
		if action == bplist.MODIFY_RENAME then graph:PreModify() end
	end)
	self.graphs:BindRaw("postModify", self, function(action, id, graph)
		if action == bplist.MODIFY_RENAME then graph:PostModify() end
	end)

	local function BindNodeTypeEvents( list, t )

		local cv =  function(v, e) return e[v](e) end 
		list:BindRaw("added", self, function(id, e)
			self:RecacheNodeTypes()
		end)

		list:BindRaw("removed", self, function(id, e)
			self:RemoveNodeTypes(bpcommon.Transform(t, {}, cv, e))
			self:RecacheNodeTypes()
		end)

		list:BindRaw("preModify", self, function(action, id, e)
			if action ~= bplist.MODIFY_RENAME then return end
			for _, v in ipairs(bpcommon.Transform(t, {}, cv, e)) do
				self:PreModifyNodeType( v )
			end
		end)

		list:BindRaw("postModify", self, function(action, id, e)
			if action ~= bplist.MODIFY_RENAME then return end
			for _, v in ipairs(bpcommon.Transform(t, {}, cv, e)) do
				self:PostModifyNodeType( v )
			end
		end)

	end

	-- Structs
	if self:CanHaveStructs() then
		
		self.structs = bplist.New(bpstruct_meta):NamedItems("Struct"):WithOuter(self)
		BindNodeTypeEvents( self.structs, {"MakerNodeType", "BreakerNodeType"} )

	end

	-- Events
	if self:CanHaveEvents() then

		self.events = bplist.New(bpevent_meta):NamedItems("Event"):WithOuter(self)
		BindNodeTypeEvents( self.events, {"EventNodeType", "CallNodeType"} )

	end

	-- Variables
	if self:CanHaveVariables() then

		self.variables = bplist.New(bpvariable_meta):NamedItems("Var"):WithOuter(self)
		BindNodeTypeEvents( self.variables, {"SetterNodeType", "GetterNodeType"} )

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
		self:Broadcast("graphModified", graph)
	end

end

function MODULE:AutoFillsPinType( pinType )

	return false

end

function MODULE:GetModulePinType() return nil end
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

			local pinType = PinType(PN_Struct, PNF_Custom, v.name):WithOuter( v )
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

function MODULE:CanCast( outPinType, inPinType )

	return bpschema.CanCast( outPinType, inPinType )

end

function MODULE:GetMenuItems( tab )

	tab[#tab+1] = {
		name = "Set Defaults",
		func = function(...) self:OpenVGUI(...) end,
		color = Color(60,120,200),
	}

end

function MODULE:BuildCosmeticVars( values )

	local varDefaults = bpvaluetype.FromValue({}, function() return {} end)

	for _,v in self:Variables() do
		--local b,e = pcall( function()
			local value = nil
			local vt = bpvaluetype.FromPinType(
				v:GetType():Copy(v.module),
				function() return value end,
				function(newValue) value = newValue end
			)

			if vt == nil then continue end
			
			print( v:GetName() .. " = " .. tostring(v:GetDefault()) )

			vt:SetFromString( tostring(v:GetDefault()) )
			vt:BindRaw( "valueChanged", self, function(old, new, k)
				v:SetDefault( vt:ToString() )
			end )

			varDefaults:AddCosmeticChild( v:GetName(), vt )
		--end)
		--if not b then print("Failed to add pintype: " .. tostring(e)) end
	end

	values:AddCosmeticChild("defaults", varDefaults)

end

function MODULE:WriteData( stream, mode, version )

	if self:CanHaveVariables() then Profile("write-variables", self.variables.WriteToStream, self.variables, stream, mode, version) end
	Profile("write-graphs", self.graphs.WriteToStream, self.graphs, stream, mode, version)
	if self:CanHaveStructs() then Profile("write-structs", self.structs.WriteToStream, self.structs, stream, mode, version) end
	if self:CanHaveEvents() then Profile("write-events", self.events.WriteToStream, self.events, stream, mode, version) end

	BaseClass.WriteData( self, stream, mode, version )

end

function MODULE:ReadData( stream, mode, version )

	self.suppressGraphNotify = true

	if self:CanHaveVariables() then Profile("read-variables", self.variables.ReadFromStream, self.variables, stream, mode, version) end
	Profile("read-graphs", self.graphs.ReadFromStream, self.graphs, stream, mode, version)
	if self:CanHaveStructs() then Profile("read-structs", self.structs.ReadFromStream, self.structs, stream, mode, version) end
	if self:CanHaveEvents() then Profile("read-events", self.events.ReadFromStream, self.events, stream, mode, version) end

	BaseClass.ReadData( self, stream, mode, version )

	for _, graph in self:Graphs() do
		graph:CreateDeferredData()
	end

	self.suppressGraphNotify = false

end

function MODULE:CompileVariable( compiler, id, var )

	local def = var:GetDefault()
	local vtype = var:GetType()

	if vtype:GetBaseType() == PN_String and bit.band(vtype:GetFlags(), PNF_Table) == 0 then def = "\"\"" end

	print("COMPILE VARIABLE: " .. vtype:ToString(true) .. " type: " .. type(def))

	local varName = var:GetName()
	if compiler.compactVars then varName = id end
	if type(def) == "string" then
		compiler.emit("instance.__" .. varName .. " = " .. tostring(def))
	else
		print("Emit variable as non-string")
		local pt = bpvaluetype.FromPinType( vtype, function() return def end, function(v) def = v end )
		if def then
			compiler.emit("instance.__" .. varName .. " = " .. pt:ToString())
		else
			compiler.emit("instance.__" .. varName .. " = nil")
		end
	end

end

function MODULE:Compile( compiler, pass )

	if pass == CP_MODULEGLOBALS then

		if self:CanHaveVariables() then

			for id, var in self:Variables() do

				self:CompileVariable( compiler, id, var )

			end

		end

	end

end

RegisterModuleClass("GraphModule", MODULE, "Configurable")