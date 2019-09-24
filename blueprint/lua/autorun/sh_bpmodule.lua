AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")
include("sh_bpgraph.lua")

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
local nextModuleID = 0
local meta = {}
meta.__index = meta

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

function New(...)
	return setmetatable({}, meta):Init(...)
end

function CreateTestModule()

	return New():CreateTestModule()

end