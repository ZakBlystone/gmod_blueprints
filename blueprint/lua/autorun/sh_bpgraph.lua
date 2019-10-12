AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")

module("bpgraph", package.seeall, bpcommon.rescope(bpschema, bpnodedef)) --bpnodedef is temporary

bpcommon.CallbackList({
	"NODE_ADD",
	"NODE_REMOVE",
	"NODE_MOVE",
	"PIN_EDITLITERAL",
	"CONNECTION_ADD",
	"CONNECTION_REMOVE",
	"GRAPH_CLEAR",
})

local meta = {}
meta.__index = meta

local nextGraphID = 0
New = nil

bpcommon.CreateIndexableListIterators(meta, "nodes")

function meta:Init(...)

	self.nodes = {}
	self.connections = {}
	self.id = nextGraphID
	self.nextNodeID = 1

	bpcommon.MakeObservable(self)

	nextGraphID = nextGraphID + 1
	return self

end

function meta:SetName( name )

	self.name = name

end

function meta:GetName()

	return self.name or "Graph_" .. self.id

end

function meta:GetTitle()

	return self:GetName()

end

function meta:GetModule()

	return self.module

end

function meta:GetNodeTypes()

	local types = {}
	local base = self:GetModule():GetNodeTypes( self.id )

	for k,v in pairs(base) do
		if not types[k] then types[k] = v end
	end

	return types

end

function meta:GetNodeType(node)

	local types = self:GetNodeTypes()
	return types[ node.nodeType ]

end

function meta:Connections()

	local i = #self.connections + 1
	return function() 
		i = i - 1
		if i > 0 then return i, self.connections[i] end
	end

end

function meta:NodeIDToIndex( nodeID )

	local n = 1
	for id in self:NodeIDs() do
		if id == nodeID then return n end
		n = n + 1
	end

end

function meta:GetNodePin(nodeID, pinID)

	return self:GetNodeType(self:GetNode(nodeID)).pins[pinID]

end

function meta:GetPinType(nodeID, pinID)

	local node = self:GetNode(nodeID)
	local ntype = self:GetNodeType(node)

	if ntype.meta and ntype.meta.informs then

		local hasInform = false
		for i = 1, #ntype.meta.informs do
			local t = ntype.meta.informs[i]
			if t == pinID then hasInform = true end
		end

		if hasInform then
			for i = 1, #ntype.meta.informs do

				local t = ntype.meta.informs[i]

				local isConnected, connection = self:IsPinConnected(nodeID, t)
				if isConnected and connection ~= nil then

					if connection[1] == nodeID and self:GetNodePin(connection[3], connection[4])[2] ~= PN_Any then return self:GetPinType(connection[3], connection[4]) end
					if connection[3] == nodeID and self:GetNodePin(connection[1], connection[2])[2] ~= PN_Any then return self:GetPinType(connection[1], connection[2]) end

				end

			end
		end

	end

	return ntype.pins[pinID][2]

end

function meta:FindConnection(nodeID0, pinID0, nodeID1, pinID1)

	local p0 = self:GetNodePin( nodeID0, pinID0 )
	local dir = p0[1]

	if dir == PD_Out then

		for _, connection in self:Connections() do

			if connection[1] ~= nodeID0 or connection[2] ~= pinID0 then continue end
			if connection[3] == nodeID1 and connection[4] == pinID1 then return connection end

		end

	else

		for _, connection in self:Connections() do

			if connection[3] ~= nodeID0 or connection[4] ~= pinID0 then continue end
			if connection[1] == nodeID1 and connection[2] == pinID1 then return connection end

		end

	end

end

function meta:IsPinConnected(nodeID, pinID)

	for _, connection in self:Connections() do

		if connection[1] == nodeID and connection[2] == pinID then return true, connection end
		if connection[3] == nodeID and connection[4] == pinID then return true, connection end

	end

end

function meta:CanConnect(nodeID0, pinID0, nodeID1, pinID1)

	if self:FindConnection(nodeID0, pinID0, nodeID1, pinID1) ~= nil then return false, "Already connected" end

	local p0 = self:GetNodePin(nodeID0, pinID0) --always PD_Out
	local p1 = self:GetNodePin(nodeID1, pinID1) --always PD_In

	if p0[2] == PN_Exec and self:IsPinConnected(nodeID0, pinID0) then return false, "Only one connection outgoing for exec pins" end
	if p1[2] ~= PN_Exec and self:IsPinConnected(nodeID1, pinID1) then return false, "Only one connection for inputs" end

	if p0[1] == p1[1] then return false, "Can't connect " .. (p0[1] == PD_Out and "m/m" or "f/f") .. " pins" end
	if bit.band(p0[4], PNF_Table) ~= bit.band(p1[4], PNF_Table) then return false, "Can't connect table to non-table pin" end

	local p0Type = p0[2]
	local p1Type = p1[2]
	if p0Type ~= p1Type then

		if p0Type == PN_Any and p1Type ~= PN_Exec then return true end
		if p1Type == PN_Any and p0Type ~= PN_Exec then return true end

		-- Does not work properly, take into account pin directions to determine what conversion is being attempted
		-- Maybe rectify pin ordering so pin0 is always PD_Out, and pin1 is always PD_In
		if NodePinImplicitConversions[p0Type] and table.HasValue(NodePinImplicitConversions[p0Type], p1Type) then
			return true
		else
			return false, "No explicit conversion between " .. p0Type .. " and " .. p1Type
		end

	end
	return true

end

function meta:ConnectNodes(nodeID0, pinID0, nodeID1, pinID1)

	local p0 = self:GetNodePin(nodeID0, pinID0)
	local p1 = self:GetNodePin(nodeID1, pinID1)

	-- swap connection to ensure first is output and second is input
	if p0[1] == PD_In and p1[1] == PD_Out then
		local t = nodeID0 nodeID0 = nodeID1 nodeID1 = t
		local t = pinID0 pinID0 = pinID1 pinID1 = t
	end

	local cc, m = self:CanConnect(nodeID0, pinID0, nodeID1, pinID1)
	if not cc then print(m) return false end

	table.insert(self.connections, { nodeID0, pinID0, nodeID1, pinID1 })

	self:FireListeners(CB_CONNECTION_ADD, self.connections[#self.connections], #self.connections)

	return true

end

function meta:GetNodeCount()

	return #self.nodes

end

function meta:Clear()

	self:FireListeners(CB_GRAPH_CLEAR)

	self.nodes = {}
	self.connections = {}

end

function meta:GetPinLiteral(nodeID, pinID)

	local node = self:GetNode(nodeID)
	return node.literals[pinID]

end

function meta:SetPinLiteral(nodeID, pinID, value)

	local node = self:GetNode(nodeID)
	if node == nil then error("Tried to set literal on null node") end

	value = tostring(value)

	node.literals[pinID] = value
	self:FireListeners(CB_PIN_EDITLITERAL, nodeID, pinID, value)

end

function meta:AddNode(node)

	local ntype = self:GetNodeType(node)
	if ntype == nil then
		ErrorNoHalt("Failed to create node type: " .. tostring(node.nodeType))
		self.nextNodeID = self.nextNodeID + 1
		return
	end

	table.insert(self.nodes, node)

	local id = self.nextNodeID
	self.nextNodeID = self.nextNodeID + 1

	node.id = id
	node.graphID = self.id
	node.literals = node.literals or {}

	node.x = math.Round(node.x / 15) * 15
	node.y = math.Round(node.y / 15) * 15

	self:FireListeners(CB_NODE_ADD, node, id)

	
	local defaults = ntype.defaults or {}

	for pinID, pin in pairs(ntype.pins) do

		local default = defaults[ntype.pinlookup[pinID][2]]

		if pin[1] == PD_In then

			local literal = NodeLiteralTypes[pin[2]]
			if literal then

				if self:GetPinLiteral(id, pinID) == nil then
					self:SetPinLiteral(id, pinID, default or Defaults[pin[2]])
				end

			end

		end

	end

	return id

end

function meta:MoveNode(nodeID, x, y)

	local node = self:GetNode(nodeID)

	x = math.Round(x / 15) * 15
	y = math.Round(y / 15) * 15

	node.x = x
	node.y = y

	self:FireListeners(CB_NODE_MOVE, node, nodeID, x, y)

end

function meta:RemoveConnectionID(id)

	local c = self.connections[id]
	if c ~= nil then
		table.remove(self.connections, id)
		self:FireListeners(CB_CONNECTION_REMOVE, c, id)
	end

end

function meta:RemoveConnection(nodeID0, pinID0, nodeID1, pinID1)

	for i, c in self:Connections() do

		if (c[1] == nodeID0 and c[3] == nodeID1) and (c[2] == pinID0 and c[4] == pinID1) then
			self:RemoveConnectionID(i)
		elseif (c[1] == nodeID1 and c[3] == nodeID0) and (c[2] == pinID1 and c[4] == pinID0) then
			self:RemoveConnectionID(i)
		end

	end

end

function meta:RemoveInvalidConnections()

	local connections = self.connections
	for i=#connections, 1, -1 do

		local c = connections[i]
		if not self:GetNode(c[1]) or not self:GetNode(c[3]) then
			print("Removed invalid connection: " .. i)
			table.remove(connections, i)
		end

	end	

end

function meta:RemoveNode(nodeID)

	local node = self:GetNode( nodeID )
	
	table.RemoveByValue(self.nodes, node)

	self:FireListeners(CB_NODE_REMOVE, node, nodeID)

	for i, c in self:Connections() do
		if c[1] == nodeID or c[3] == nodeID then
			self:RemoveConnectionID(i)
		end
	end

end

function meta:CollapseSingleRerouteNode(nodeID)

	local node = self:GetNode( nodeID )

	print("COLLAPSING REROUTE NODE: " .. nodeID)

	local insert = {}
	local connections = self.connections
	local input = nil
	for i, c in self:Connections() do

		if c[1] == nodeID then --output
			print(" -output on " .. c[2] .. " => " .. c[3] .. "[" .. c[4] .. "]")
			table.insert(insert, {c[3],c[4]})
			self:RemoveConnectionID(i)
		elseif c[3] == nodeID then --input
			print(" -input on " .. c[4] .. " <= " .. c[1] .. "[" .. c[2] .. "]")
			input = {c[1],c[2]}
			self:RemoveConnectionID(i)
		end

	end	

	if input == nil then print("Reroute node did not have input connection") return end

	for _, c in pairs(insert) do
		if not self:ConnectNodes(input[1], input[2], c[1], c[2]) then error("Unable to reconnect re-route nodes") end
	end

	self:RemoveNode( nodeID )

end

function meta:CollapseRerouteNodes()

	for _, node in self:Nodes() do
		if self:GetNodeType(node).collapse then
			self:CollapseSingleRerouteNode( node.id )
		end
	end	

end

function meta:WriteToStream(stream, version)

	print("WRITE GRAPH TO STREAM")

	local namelookup = {}
	local nametable = {}
	local nodeentries = {}

	for id, node in self:Nodes() do
		local name = self:GetNodeType(node).name
		if not namelookup[name] then 
			table.insert(nametable, name)
			namelookup[name] = #nametable
		end
	end

	stream:WriteInt( #nametable, false )
	for _, str in pairs(nametable) do stream:WriteByte( str:len(), false ) stream:WriteStr(str) end

	stream:WriteInt( #self.nodes, false )
	for id, node in self:Nodes() do
		local name = self:GetNodeType(node).name
		stream:WriteInt( namelookup[name], false )
		stream:WriteFloat( node.x or 0 )
		stream:WriteFloat( node.y or 0 )
		bpdata.WriteValue( node.literals or {}, stream )
	end

	local remappedConnections = {}
	for id, connection in self:Connections() do
		table.insert(remappedConnections, {
			self:NodeIDToIndex(connection[1]),
			connection[2],
			self:NodeIDToIndex(connection[3]),
			connection[4],
		})
	end

	bpdata.WriteValue( remappedConnections, stream )

end

function meta:ReadFromStream(stream, version)

	print("READ GRAPH FROM STREAM")

	self:Clear()

	local nametable = {}
	for i=1, stream:ReadInt( false ) do 
		local size = stream:ReadByte( false ) 
		table.insert(nametable, stream:ReadStr( size ) )
	end

	local count = stream:ReadInt( false )
	for i=1, count do

		local nodeTypeName = nametable[stream:ReadInt( false )]
		local nodeX = stream:ReadFloat()
		local nodeY = stream:ReadFloat()
		local literals = bpdata.ReadValue( stream )
		
		local id = self:AddNode({
			nodeType = nodeTypeName,
			x = nodeX,
			y = nodeY,
			literals = literals,
		})

		if id ~= nil then
			for k, v in pairs(literals) do
				--print("LOAD LITERAL[" .. id .. "|" .. self.nodes[id].nodeType.name .. "]: " .. tostring(k) .. " = " .. tostring(v))
				self:SetPinLiteral( id, k, v )
			end
		end

	end

	self.connections = bpdata.ReadValue( stream )

	self:RemoveInvalidConnections()
	for i, connection in self:Connections() do
		self:FireListeners(CB_CONNECTION_ADD, connection, i)
	end

end

-- Quickly banging this out using existing tech
function meta:CopyInto(other)

	local outStream = bpdata.OutStream()
	self:WriteToStream(outStream)

	other.module = self.module
	other.id = self.id
	other.name = self.name

	local inStream = bpdata.InStream()
	inStream:LoadString(outStream:GetString(false, false), false, false)
	other:ReadFromStream( inStream )

	return other

end

function meta:CreateTestGraph()

	local graph = self
	local n1 = graph:AddNode({
		nodeType = "If",
		x = 700,
		y = 10,
	})

	local n2 = graph:AddNode({
		nodeType = "Crouching",
		x = 350,
		y = 150,
	})

	local n4 = graph:AddNode({
		nodeType = "SetVelocity",
		x = 1000,
		y = 100,
	})

	local n5 = graph:AddNode({
		nodeType = "Vector",
		x = 750,
		y = 200,
		literals = {0,0,800}
	})

	local n6 = graph:AddNode({
		nodeType = "Alive",
		x = 350,
		y = 350,
	})

	local n7 = graph:AddNode({
		nodeType = "And",
		x = 600,
		y = 300,
	})

	local n8 = graph:AddNode({
		nodeType = "ToString",
		x = 650,
		y = 500,
	})

	local n9 = graph:AddNode({
		nodeType = "Print",
		x = 1000,
		y = 500,
	})

	local n10 = graph:AddNode({
		nodeType = "PlayerTick",
		x = 10,
		y = 10,
	})

	local n11 = graph:AddNode({
		nodeType = "GetVelocity",
		x = 350,
		y = 500,
	})

	--[[local n6 = graph:AddNode({
		nodeType = NodeTypes["Crouching"],
		x = 250,
		y = 350,
	})]]

	graph:ConnectNodes(n10, 1, n1, 1)
	graph:ConnectNodes(n10, 2, n2, 1)
	--graph:ConnectNodes(n2, 2, n1, 2)
	graph:ConnectNodes(n1, 3, n4, 1)
	graph:ConnectNodes(n10, 2, n4, 3)
	graph:ConnectNodes(n5, 4, n4, 4)
	graph:ConnectNodes(n2, 2, n7, 1)
	graph:ConnectNodes(n6, 2, n7, 2)
	graph:ConnectNodes(n6, 1, n10, 2)
	graph:ConnectNodes(n7, 3, n1, 2)
	graph:ConnectNodes(n4, 2, n9, 1)
	graph:ConnectNodes(n8, 2, n9, 3)
	graph:ConnectNodes(n10, 2, n11, 1)
	graph:ConnectNodes(n11, 2, n8, 1)

end

New = function(...)
	return setmetatable({}, meta):Init(...)
end

--[[function CreateTestGraph()

	local graph = New()
	graph:CreateTestGraph()

	-- Serialize Test
	local compress = true
	local base64 = true
	local outStream = bpdata.OutStream()

	graph:WriteToStream(outStream)
	outStream:WriteToFile("bpgraph.txt", compress, base64)

	local inStream = bpdata.InStream()

	inStream:LoadFile("bpgraph.txt", compress, base64)
	local lgraph = New()
	lgraph:ReadFromStream( inStream )

	graph = lgraph

	return graph

end

CreateTestGraph()]]