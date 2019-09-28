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
	self.nextGraphID = 1

	bpcommon.MakeObservable(self)

	nextModuleID = nextModuleID + 1
	return self

end

function meta:GetNextGraphID()

	return self.nextGraphID

end

function meta:GetNodeTypes( graphID )

	return NodeTypes

end

function meta:Clear()

	self:FireListeners(CB_MODULE_CLEAR)

	self.graphs = {}

end

function meta:NewGraph(name)

	local graph = bpgraph.New()
	if name ~= "" then graph.name = name end

	table.insert(self.graphs, graph)
	graph.id = self.nextGraphID
	graph.module = self

	self.nextGraphID = self.nextGraphID + 1

	self:FireListeners(CB_GRAPH_ADD, graph.id)

	return graph.id

end

function meta:RemoveGraph( graphID )

	local graph = self:GetGraph( graphID )
	if graph == nil then return end

	table.RemoveByValue(self.graphs, graph)

	self:FireListeners(CB_GRAPH_REMOVE, graphID)

end

function meta:Graphs()

	local i = 0
	local n = #self.graphs
	return function() 
		i = i + 1
		if i <= n then return self.graphs[i].id, self.graphs[i] end
	end

end

function meta:GraphIDs()

	local i = 0
	local n = #self.graphs
	return function() 
		i = i + 1
		if i <= n then return self.graphs[i].id end
	end

end

function meta:GetGraph( graphID )

	for id, graph in self:Graphs() do
		if graph.id == graphID then return graph end
	end

end

function meta:WriteToStream(stream)

	stream:WriteInt( fmtMagic, false )
	stream:WriteInt( fmtVersion, false )
	stream:WriteInt( #self.graphs, false )
	for id, graph in self:Graphs() do
		local name = graph:GetName()
		stream:WriteInt( name:len(), false )
		stream:WriteStr( name )
		graph:WriteToStream(stream)
	end

end

function meta:ReadFromStream(stream)

	self:Clear()

	if stream:ReadInt( false ) ~= fmtMagic then error("Invalid blueprint data") end
	if stream:ReadInt( false ) ~= fmtVersion then error("Blueprint data version mismatch") end
	local count = stream:ReadInt( false )
	for i=1, count do
		local id = self:NewGraph( stream:ReadStr(stream:ReadInt(false)) )
		local graph = self:GetGraph(id)
		graph:ReadFromStream(stream)
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