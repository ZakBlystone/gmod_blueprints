AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")
include("sh_bpgraph.lua")
include("sh_bpvariable.lua")
include("sh_bplist.lua")

module("bpmodule", package.seeall, bpcommon.rescope(bpschema, bpnodedef)) --bpnodedef is temporary

bpcommon.CallbackList({
	"MODULE_CLEAR",
	"GRAPH_ADD",
	"GRAPH_REMOVE",
	"VARIABLE_ADD",
	"VARIABLE_REMOVE",
})

GRAPH_MODIFY_RENAME = 1
GRAPH_MODIFY_SIGNATURE = 2
GRAPH_NODETYPE_ACTIONS = {
	[GRAPH_MODIFY_RENAME] = bpgraph.NODETYPE_MODIFY_RENAME,
	[GRAPH_MODIFY_SIGNATURE] = bpgraph.NODETYPE_MODIFY_SIGNATURE,
}


fmtMagic = 0x42504D58
fmtVersion = 4

local meta = {}
meta.__index = meta

nextModuleID = nextModuleID or 0
activeModules = activeModules or {}

bpcommon.CreateIndexableListIterators(meta, "graphs")
bpcommon.CreateIndexableListIterators(meta, "variables")

function meta:Init(type)

	self.version = fmtVersion
	self.graphs = bplist.New():NamedItems("Graph")
	self.variables = bplist.New():NamedItems("Var")
	self.id = nextModuleID
	self.type = self.type or MT_Game

	self.graphs:AddListener(function(cb, id)

		if cb == bplist.CB_ADD then
			self:FireListeners(CB_GRAPH_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			self:FireListeners(CB_GRAPH_REMOVE, id)
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

	self.variables:AddListener(function(cb, id, var)

		if cb == bplist.CB_ADD then
			self:FireListeners(CB_VARIABLE_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			local match = {["__VSet" .. id] = 1, ["__VGet" .. id] = 1}
			for _, graph in self:Graphs() do
				graph:RemoveNodeIf( function( node )
					return match[node.nodeType]
				end )
			end

			self:FireListeners(CB_VARIABLE_REMOVE, id)
		end

	end, bplist.CB_ALL)

	self.variables:AddListener(function(cb, action, id, graph)

		if action ~= bplist.MODIFY_RENAME then return end
		if cb == bplist.CB_PREMODIFY then
			self:PreModifyNodeType( "__VGet" .. id, bpgraph.NODETYPE_MODIFY_RENAME, action )
			self:PreModifyNodeType( "__VSet" .. id, bpgraph.NODETYPE_MODIFY_RENAME, action )
		elseif cb == bplist.CB_POSTMODIFY then
			self:PostModifyNodeType( "__VGet" .. id, bpgraph.NODETYPE_MODIFY_RENAME, action )
			self:PostModifyNodeType( "__VSet" .. id, bpgraph.NODETYPE_MODIFY_RENAME, action )
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

function meta:GetNodeTypes( graphID )

	local types = {}
	local base = NodeTypes

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

function meta:NewVariable(name, type, default, flags)

	return self.variables:Add( bpvariable.New(type, default, flags), name )

end

function meta:NewGraph(name, type)

	local id, graph = self.graphs:Add( bpgraph.New(self, type), name )
	graph:PostInit()
	return id, graph

end

function meta:CopyGraph( graphID )

	local graph = self:GetGraph( graphID )
	if graph == nil then return end

	local copy = self:GetGraph( self:NewGraph( "graphproxy_" .. self.nextGraphID ) )
	graph:CopyInto(copy)

	return copy

end

function meta:WriteToStream(stream)

	print("--WRITE MODULE TYPE: " .. self.type .. " [" .. self.version .. "]")

	stream:WriteInt( fmtMagic, false )
	stream:WriteInt( fmtVersion, false )
	stream:WriteInt( self.type, false )

	bpdata.WriteValue( self.variables:GetTable(), stream )

	stream:WriteInt( self.graphs:Size(), false )
	for id, graph in self:Graphs() do
		local name = graph:GetName()
		stream:WriteInt( name:len(), false )
		stream:WriteStr( name )
		graph:WriteToStream(stream, fmtVersion)
	end

end

function meta:ReadFromStream(stream)

	self:Clear()

	local magic = stream:ReadInt( false )
	local version = stream:ReadInt( false )

	if magic ~= fmtMagic then error("Invalid blueprint data") end
	if version > fmtVersion then error("Blueprint data version is newer") end

	self.version = version

	print("--LOAD STREAM VERSION IS: " .. version)

	if version >= 4 then
		self.type = stream:ReadInt( false )
		print("MODULE TYPE: " .. self.type)
	end

	if version >= 2 then
		local vars = bpdata.ReadValue( stream )
		for _, v in pairs(vars) do
			self:NewVariable(v.name, v.type, v.default, v.flags)
		end
	end

	local count = stream:ReadInt( false )
	for i=1, count do
		local id = self:NewGraph( stream:ReadStr(stream:ReadInt(false)) )
		local graph = self:GetGraph(id)
		graph:ReadFromStream(stream, version)
	end

	if version < 4 then

		print("Blueprint uses old variable schema, remapping node types...")
		local remaps = {}
		for id, var in self:Variables() do
			remaps["Set" .. var:GetName()] = "__VSet" .. id
			remaps["Get" .. var:GetName()] = "__VGet" .. id
		end

		for _, graph in self:Graphs() do
			graph:RemapNodeTypes( function(nodeType) 
				local r = remaps[nodeType]
				if r then
					print(" " .. nodeType .. " => " .. r)
					return r
				end
				return nodeType
			end )
		end

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

function meta:BindGamemodeHooks()

	if not self:IsValid() then return end

	local bp = self:Get()
	local meta = bp.meta
	local instance = self:GetSingleton()

	if instance.Init then instance:Init() end

	for k,v in pairs(bp.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local function call(...) return instance[k](instance, ...) end
		hook.Add(v.hook, v.key, call)
	end

end

function meta:UnbindGamemodeHooks()

	if not self:IsValid() then return end

	local bp = self:Get()
	local meta = bp.meta
	local instance = self:GetSingleton()

	if instance.shuttingDown then ErrorNoHalt("!!!!!Recursive shutdown!!!!!") return end

	for k,v in pairs(bp.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		hook.Remove(v.hook, v.key)
	end

	instance.shuttingDown = true
	if instance.Shutdown then instance:Shutdown() end
	instance.shuttingDown = false

end

function meta:SetEnabled( enable )

	if not self:IsValid() then return end

	local isEnabled = activeModules[self.id] ~= nil
	if isEnabled == false and enable == true then
		self:BindGamemodeHooks()
		activeModules[self.id] = self
		return
	end

	if isEnabled == true and enable == false then
		self:UnbindGamemodeHooks()
		activeModules[self.id] = nil
		return
	end

end

function meta:GetSingleton()

	self.singleton = self.singleton or (self:IsValid() and self:Get().new() or nil)
	return self.singleton

end

function meta:Compile(compileErrorHandler)

	local ok, res = false, nil
	if compileErrorHandler then
		ok, res = xpcall(bpcompile.Compile, function(err)
			if compileErrorHandler then compileErrorHandler(self, debug.traceback()) return end
		end, self)
	else
		ok, res = true, bpcompile.Compile(self)
	end

	if ok then
		self.compiled = res
		self:AttachErrorHandler()
	end

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

function New(...)
	return setmetatable({}, meta):Init(...)
end

function CreateTestModule()
	return New():CreateTestModule()
end

hook.Add("Think", "__updatebpmodules", function()

	for _, m in pairs(activeModules) do
		m:Get().update()
	end

end)