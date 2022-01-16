AddCSLuaFile()

module("mod_graphmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = false
MODULE.Name = LOCTEXT("module_graph_name","Graph Module")
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
		self:Broadcast("graphAdded", graph)
		self:RecacheNodeTypes()
	end)
	self.graphs:BindRaw("removed", self, function(id, graph)
		self:RemoveNodeTypes({ graph:GetCallNodeType() })
		self:Broadcast("graphRemoved", graph)
		self:RecacheNodeTypes()
		graph:Destroy()
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
				v:PreModify()
			end
		end)

		list:BindRaw("postModify", self, function(action, id, e)
			if action ~= bplist.MODIFY_RENAME then return end
			for _, v in ipairs(bpcommon.Transform(t, {}, cv, e)) do
				v:PostModify()
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

	--print("SETUP GRAPH MODULE")

end

function MODULE:Destroy()

	BaseClass.Destroy(self)

	self.graphs:Destroy()

	if self.structs then self.structs:Destroy() end
	if self.events then self.events:Destroy() end
	if self.variables then self.variables:Destroy() end

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
function MODULE:GetLocalNodeTypes( collection, graph )

	BaseClass.GetLocalNodeTypes( self, collection, graph )

	local types = {}

	collection:Add( types )

	if self:CanHaveVariables() then

		for id, v in self:Variables() do

			local name = v:GetName()
			types["__VSet" .. id] = v:SetterNodeType()
			types["__VGet" .. id] = v:GetterNodeType()

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

function MODULE:GetNodeTypes( collection, graph )

	BaseClass.GetNodeTypes( self, collection )

	local types = {}

	collection:Add( types )

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

	for k,v in pairs(types) do v.name = k end

end

function MODULE:GetPinTypes( collection )

	BaseClass.GetPinTypes( self, collection )

	local types = {}

	collection:Add( types )

	if self:CanHaveStructs() then

		for id, v in self:Structs() do

			local pinType = bppintype.New(PN_Struct, PNF_Custom, v.name):WithOuter( v )
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
	graph:CreateDefaults()
	return id, graph

end

function MODULE:GetUsedPinTypes(used, noFlags)

	used = used or {}
	for graphID, graph in self:Graphs() do
		graph:GetUsedPinTypes(used, noFlags)
	end
	return BaseClass.GetUsedPinTypes(self, used, noFlags)

end

function MODULE:RequestGraphForCallback( callback )

	local id, graph = self:NewGraph(callback:GetName(), NT_Function)

	for _, v in ipairs(callback:GetPins()) do

		if v:IsType(PN_Exec) then continue end
		if v:IsIn() then
			graph.inputs:Add(v:Copy(), v:GetName())
		else
			graph.outputs:Add(v:Copy(), v:GetName())
		end

	end

	return graph

end

function MODULE:RequestGraphForEvent( nodeType )

	print("REQUEST GRAPH FOR: " .. nodeType:GetFullName())

	for _, graph in self:Graphs() do
		if graph:GetName() == nodeType:GetDisplayName() then return end
	end

	local id, graph = self:NewGraph(nodeType:GetDisplayName(), NT_Function)
	graph:SetFlag(bpgraph.FL_LOCK_PINS)
	graph:SetFlag(bpgraph.FL_LOCK_NAME)

	if not nodeType:HasFlag(NTF_NotHook) then
		graph:SetFlag(bpgraph.FL_HOOK)
	end

	graph:SetHookType( nodeType:GetFullName() )

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
function MODULE:RequiresNetCode() return true end

function MODULE:CanCast( outPinType, inPinType )

	return false

end

function MODULE:GetMenuItems( tab )

	tab[#tab+1] = {
		name = LOCTEXT("menu_configure", "Configure"),
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

function MODULE:SerializeData( stream )

	BaseClass.SerializeData( self, stream )

	self.suppressGraphNotify = true

	--print("Serialize graph module")

	if self:CanHaveVariables() then self.variables:Serialize( stream ) end

	if stream:GetVersion() >= 3 then
		if self:CanHaveStructs() then self.structs:Serialize( stream ) end
		if self:CanHaveEvents() then self.events:Serialize( stream ) end
	end

	self.graphs:Serialize( stream )

	if stream:GetVersion() < 3 then
		if self:CanHaveStructs() then self.structs:Serialize( stream ) end
		if self:CanHaveEvents() then self.events:Serialize( stream ) end
	end

	self.suppressGraphNotify = false

	return stream

end

function MODULE:CompileVariable( compiler, var )

	local def = var:GetDefault()
	local vtype = var:GetType()
	local id = compiler:GetID(var)

	if vtype:GetBaseType() == PN_String and bit.band(vtype:GetFlags(), PNF_Table) == 0 then def = "\"\"" end
	if vtype:GetBaseType() == PN_Asset and bit.band(vtype:GetFlags(), PNF_Table) == 0 then def = "\"\"" end

	--print("COMPILE VARIABLE: " .. vtype:ToString(true) .. " type: " .. type(def))

	local varName = var:GetName()
	if compiler.compactVars then varName = id end
	if type(def) == "string" then
		compiler.emit("self.__" .. varName .. " = " .. tostring(def))
	else
		print("Emit variable as non-string")
		local pt = bpvaluetype.FromPinType( vtype, function() return def end, function(v) def = v end )
		if def and pt then
			compiler.emit("self.__" .. varName .. " = " .. pt:ToString())
		end
	end

end

function MODULE:AddRequiredMetaTables( compiler )

	-- Collect all used types from module and write out the needed meta tables
	local types = self:GetUsedPinTypes(nil, true)
	for _, t in ipairs(types) do

		local baseType = t:GetBaseType()
		if baseType == PN_Ref then

			local class = bpdefs.Get():GetClass(t)
			if class then
				compiler:AddRequiredMetaTable( class.name )
			end

		elseif baseType == PN_Struct then

			local struct = bpdefs.Get():GetStruct(t)
			local metaTable = struct and struct:GetMetaTable() or nil
			if metaTable then
				compiler:AddRequiredMetaTable( metaTable )
			end

		elseif baseType == PN_Vector then

			compiler:AddRequiredMetaTable( "Vector" )

		elseif baseType == PN_Angles then

			compiler:AddRequiredMetaTable( "Angle" )

		elseif baseType == PN_Color then

			compiler:AddRequiredMetaTable( "Color" )

		end

	end

end

function MODULE:Compile( compiler, pass )

	local withinProject = self:FindOuter(bpmodule_meta) ~= nil

	if pass == CP_PREPASS then

		--print("MODULE PRE-COMPILE")
		-- make local copies of all module graphs so they can be edited without changing the module
		self.cgraphs = {}
		self.uniqueKeys = {}
		for id, graph in self:Graphs() do
			local cgraph = graph:CopyInto( bpgraph.New():WithOuter( self ), true )
			cgraph:PreCompile( compiler, self.uniqueKeys )
			self.cgraphs[#self.cgraphs+1] = cgraph
		end

		self:AddRequiredMetaTables( compiler )

	elseif pass == CP_MAINPASS then

		--print("MODULE COMPILE: " .. #self.cgraphs)
		for _, graph in ipairs(self.cgraphs) do
			graph:Compile( compiler, pass )
		end

	elseif pass == CP_MODULECODE then

		local bDebug = compiler.debug and 1 or 0
		local bILP = compiler.ilp and 1 or 0
		local args = bDebug .. ", " .. bILP

		compiler.emit("_FR_HEAD(" .. args .. ")")   -- script header

		if not withinProject then
			compiler.emit("_FR_UTILS()") -- utilities

			if self:RequiresNetCode() then
				compiler.emitContext( CTX_Network )         -- network boilerplate
			end
		end

		compiler.emit("_FR_MODHEAD(" .. bpcommon.EscapedGUID(self:GetUID()) .. ")")              -- header for module

		-- emit each graph's entry function
		for _, graph in ipairs(self.cgraphs) do
			local id = compiler:GetID(graph)
			compiler.emitContext( CTX_Graph .. id )
		end

		-- emit all meta events (functions with graph entry points)
		for k, _ in pairs( compiler.getFilteredContexts(CTX_MetaEvents) ) do
			compiler.emitContext( k )
		end

		-- network meta functions
		if self:RequiresNetCode() then compiler.emitContext( CTX_NetworkMeta ) end

		-- update function, runs delays and resets the ilp recursion value for hooks
		compiler.emit("_FR_UPDATE(" .. bILP .. ", " .. (self:RequiresNetCode() and "1" or "0") .. ")")

	elseif pass == CP_NETCODEMSG then

		for _, graph in ipairs(self.cgraphs) do
			for _, node in graph:Nodes() do
				compiler:RunNodeCompile(node, CP_NETCODEMSG)
			end
		end

	elseif pass == CP_MODULEGLOBALS then

		if self:CanHaveVariables() then

			for id, var in self:Variables() do
				self:CompileVariable( compiler, var )
			end

		end
		return true

	elseif pass == CP_MODULEDEBUG then

		for _, graph in ipairs(self.cgraphs) do compiler:AddGraphSymbols( graph ) end

	elseif pass == CP_MODULEBPM then

		-- event listing
		compiler.emit("__bpm.events = {")
		for k, _ in pairs( compiler.getFilteredContexts(CTX_Hooks) ) do
			compiler.emitContext( k, 1 )
		end
		compiler.emit("}")

		local errorHandler = bit.band(compiler.flags, CF_Standalone) ~= 0 and "1" or "0"

		-- infinite-loop-protection checker
		if compiler.ilp then
			compiler.emit("_FR_SUPPORT(1, " .. compiler.ilpmaxh .. ", " .. errorHandler .. ")")
		else
			compiler.emit("_FR_SUPPORT(0, 0, " .. errorHandler .. ")")
		end

	elseif pass == CP_MODULEFOOTER then

		if bit.band(compiler.flags, CF_Standalone) ~= 0 then


		else

			compiler.emit("return __bpm")

		end

	end

end

RegisterModuleClass("GraphModule", MODULE, "Configurable")