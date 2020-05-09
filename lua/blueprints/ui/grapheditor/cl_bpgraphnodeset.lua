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
	for id, node in self:GetGraph():Nodes() do self:NodeAdded(id, node) count = count + 1 end

	--print("Created " .. count .. " VNodes")

end

function meta:NodeAdded( id, node )

	if self:GetGraph() == nil then return end

	local graph = self:GetGraph()
	local vnode = bpuigraphnode.New( graph:GetNode(id), graph, self.editor )
	self.vnodes[node] = vnode

end

function meta:NodeRemoved( id, node )

	self.vnodes[node] = nil

end

function meta:PostModifyNode( id, node )

	if self.vnodes[node] ~= nil then
		self.vnodes[node]:CreatePins()
		self.vnodes[node]:Invalidate(true)
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end