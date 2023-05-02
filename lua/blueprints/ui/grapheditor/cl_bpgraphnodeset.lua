if SERVER then AddCSLuaFile() return end

module("bpgraphnodeset", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local meta = bpcommon.MetaTable("bpgraphnodeset")

function meta:Init( graph, editor )

	self.vnodes = setmetatable({}, {__mode = "k"})
	self.graph = graph
	self.editor = editor
	return self

end

function meta:SetGraph( graph ) self.graph = graph end
function meta:GetGraph() return self.graph end
function meta:GetVNodes() return self.vnodes end

function meta:CreateAllNodes()

	if self:GetGraph() == nil then return end
	local count = 0

	self.vnodes = {}
	for id, node in self:GetGraph():Nodes() do self:NodeAdded(node) count = count + 1 end

	--print("Created " .. count .. " VNodes")

end

function meta:NodeAdded( node )

	if self:GetGraph() == nil then return end

	local graph = self:GetGraph()
	local vnode = bpuigraphnode.New( node, graph, self.editor )
	self.vnodes[node] = vnode

end

function meta:NodeRemoved( node )

	self.vnodes[node] = nil

end

function New(...) return bpcommon.MakeInstance(meta, ...) end