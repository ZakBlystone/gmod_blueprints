AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")
include("sh_bpgraph.lua")
include("sh_bpcompile.lua")

module("bpmodule", package.seeall, bpcommon.rescope(bpschema, bpnodedef)) --bpnodedef is temporary

bpcommon.CallbackList({
	"MODULE_CLEAR",
	"GRAPH_ADD",
	"GRAPH_REMOVE",
	"GRAPH_REMAP",
	"VARIABLE_ADD",
	"VARIABLE_REMOVE",
})

local fmtMagic = 0x42504D58
local fmtVersion = 1
local meta = {}
meta.__index = meta

nextModuleID = nextModuleID or 0
activeModules = activeModules or {}

function meta:Init()

	self.graphs = {}
	self.variables = {}
	self.id = nextModuleID

	bpcommon.MakeObservable(self)

	nextModuleID = nextModuleID + 1
	return self

end

function meta:GetNodeTypes( graph )

	return NodeTypes

end

function meta:Clear()

	self:FireListeners(CB_MODULE_CLEAR)

	self.graphs = {}

end

function meta:NewGraph(name)

	local graph = bpgraph.New()
	graph.name = name

	table.insert(self.graphs, graph)
	graph.id = #self.graphs

	self:FireListeners(CB_GRAPH_ADD, graph.id)

	return #self.graphs

end

function meta:RefreshGraphIds()

	for i, graph in pairs(self.graphs) do
		if graph.id ~= i then
			self:FireListeners(CB_GRAPH_REMAP, graph, graph.id, i)
			graph.id = i
		end
	end

end

function meta:RemoveGraph( graphID )

	local graph = self.graphs[graphID]
	if graph == nil then return end

	table.remove(self.graphs, graphID)

	self:RefreshGraphIds()
	self:FireListeners(CB_GRAPH_REMOVE, graphID)

end

function meta:GetGraph(id)

	return self.graphs[id]

end

function meta:GetNumGraphs()

	return #self.graphs

end

function meta:WriteToStream(stream)

	stream:WriteInt( fmtMagic, false )
	stream:WriteInt( fmtVersion, false )
	stream:WriteInt( #self.graphs, false )
	for k, v in pairs(self.graphs) do
		v:WriteToStream(stream)
	end

end

function meta:ReadFromStream(stream)

	self:Clear()

	if stream:ReadInt( false ) ~= fmtMagic then error("Invalid blueprint data") end
	if stream:ReadInt( false ) ~= fmtVersion then error("Blueprint data version mismatch") end
	for i=1, stream:ReadInt( false ) do
		local id = self:NewGraph()
		self:GetGraph(id):ReadFromStream(stream)
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

	for k,v in pairs(bp.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		hook.Remove(v.hook, v.key)
	end

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

	local b,e = pcall(bpcompile.Compile, self )
	if not b then
		if compileErrorHandler then compileErrorHandler(self, e) return end
		error("Failed to compile module: " .. tostring(e))
	else
		self.compiled = e
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