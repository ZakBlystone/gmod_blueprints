AddCSLuaFile()

module("bpgraph", package.seeall, bpcommon.rescope(bpcommon, bpschema))

bpcommon.CallbackList({
	"NODE_ADD",
	"NODE_REMOVE",
	"NODE_MOVE",
	"PIN_EDITLITERAL",
	"CONNECTION_ADD",
	"CONNECTION_REMOVE",
	"GRAPH_CLEAR",
	"PREMODIFY_NODE",
	"POSTMODIFY_NODE",
})

FL_NONE = 0
FL_LOCK_PINS = 1
FL_LOCK_NAME = 2
FL_HOOK = 4
FL_ROLE_SERVER = 8
FL_ROLE_CLIENT = 16

local meta = bpcommon.MetaTable("bpgraph")

New = nil

bpcommon.CreateIndexableListIterators(meta, "nodes")
bpcommon.CreateIndexableListIterators(meta, "inputs")
bpcommon.CreateIndexableListIterators(meta, "outputs")
bpcommon.AddFlagAccessors(meta)

function meta:Init(type)

	self.flags = FL_NONE
	self.type = type or GT_Event
	self.hookNodeType = nil

	-- Create lists for graph elements
	self.deferredNodes = bplist.New(bpnode_meta, self, "graph")
	self.nodes = bplist.New(bpnode_meta, self, "graph")
	self.inputs = bplist.New(bppin_meta):NamedItems("Inputs")
	self.outputs = bplist.New(bppin_meta):NamedItems("Outputs")
	self.connections = {}
	self.heldConnections = {}

	-- Listen for changes in the input variable list (function graph)
	self.inputs:AddListener(function(cb, action, id, var)

		if cb == bplist.CB_PREMODIFY then self:PreModify()
		elseif cb == bplist.CB_POSTMODIFY then self:PostModify() end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	-- Listen for changes in the output variable list (function graph)
	self.outputs:AddListener(function(cb, action, id, var)

		if cb == bplist.CB_PREMODIFY then self:PreModify()
		elseif cb == bplist.CB_POSTMODIFY then self:PostModify() end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	-- Listen for changes in the node list
	self.nodes:AddListener(function(cb, id)

		if cb == bplist.CB_ADD then
			self:FireListeners(CB_NODE_ADD, id)
		elseif cb == bplist.CB_REMOVE then

			-- Remove connections to the node that is being removed
			for i, c in self:Connections() do
				if c[1] == id or c[3] == id then
					self:RemoveConnectionID(i)
				end
			end

			self:FireListeners(CB_NODE_REMOVE, id)
		end

	end, bplist.CB_ALL)

	local pinmeta = bpcommon.FindMetaTable("bppin")

	-- For function graphs
	-- Function to call graph entry point
	self.callNodeType = bpnodetype.New()
	self.callNodeType:AddFlag(NTF_Custom)
	self.callNodeType:SetCodeType(NT_Function)
	self.callNodeType:SetNodeClass("FuncCall")
	self.callNodeType.GetDisplayName = function() return self:GetName() end
	self.callNodeType.GetGraphThunk = function() return self end
	self.callNodeType.GetRole = function() return self:GetNetworkRole() end
	self.callNodeType.graph = self

	-- Entry point node
	self.callEntryNodeType = bpnodetype.New()
	self.callEntryNodeType:SetCodeType(NT_FuncInput)
	self.callEntryNodeType:SetName("__Entry")
	self.callEntryNodeType:AddFlag(NTF_NoDelete)
	self.callEntryNodeType:SetNodeClass("FuncEntry")
	self.callEntryNodeType.GetDisplayName = function() return self:GetName() end
	self.callEntryNodeType.GetRole = function() return self:GetNetworkRole() end
	self.callEntryNodeType.graph = self

	-- Return node
	self.callExitNodeType = bpnodetype.New()
	self.callExitNodeType:SetCodeType(NT_FuncOutput)
	self.callExitNodeType:SetDisplayName("Return")
	self.callExitNodeType:SetName("__Exit")
	self.callExitNodeType:SetNodeClass("FuncExit")
	self.callExitNodeType.graph = self

	bpcommon.MakeObservable(self)

	return self

end

function meta:PostInit()

	-- Function graphs add entry and exit nodes on creation
	if self.type == GT_Function then

		self:AddNode(self.callEntryNodeType, 0, 200)
		self:AddNode(self.callExitNodeType, 400, 200)

	end

	self:CacheNodeTypes()

	return self

end

function meta:PreModify()

	self.module:PreModifyNodeType( self.callNodeType )
	self:PreModifyNodeType( self.callEntryNodeType )
	self:PreModifyNodeType( self.callExitNodeType )

end

function meta:PostModify()

	self.module:PostModifyNodeType( self.callNodeType )
	self:PostModifyNodeType( self.callEntryNodeType )
	self:PostModifyNodeType( self.callExitNodeType )

end

function meta:CanRename() return not self:HasFlag(FL_LOCK_NAME) end

function meta:PreModifyNode( node, action, subaction )

	self:FireListeners(CB_PREMODIFY_NODE, node.id, action)

	self.heldConnections[node.id] = {}
	local held = self.heldConnections[node.id]
	local pins = node:GetPins()

	node.holdPinCount = #pins

	for i, c in self:Connections() do

		if c[1] == node.id then --output
			local other = self:GetNode(c[3])
			local pin = pins[c[2]]
			self:RemoveConnectionID(i)
			held[#held+1] = {pin:GetDir(), pin:GetName(), c[3], PD_In, other:GetPin(c[4]):GetName(), c[2]}
		elseif c[3] == node.id then --input
			local other = self:GetNode(c[1])
			local pin = pins[c[4]]
			self:RemoveConnectionID(i)
			held[#held+1] = {pin:GetDir(), pin:GetName(), c[1], PD_Out, other:GetPin(c[2]):GetName(), c[4]}
		end

	end

end

function meta:PostModifyNode( node )

	--print("NODE MODIFICATION: " .. node:ToString() )

	node:UpdatePins()
	self:FireListeners(CB_POSTMODIFY_NODE, node.id)

	local ntype = node:GetType()
	local held = self.heldConnections[node.id]
	self.heldConnections[node.id] = nil

	if ntype == nil then return end
	if held == nil then return end

	local pins = node:GetPins()
	local pinCountSame = node.holdPinCount == #pins

	for _, c in ipairs(held) do
		local found = node:FindPin(c[1], c[2])
		local pinID = found and found.id
		if pinID == nil and pinCountSame then pinID = c[6] end
		if pinID then
			local other = self:GetNode(c[3])
			local otherPin = other:FindPin(c[4], c[5]).id
			if otherPin ~= nil then self:ConnectNodes(node.id, pinID, other.id, otherPin) end
		else
			print("Couldn't find pin: " .. tostring(c[2]))
		end
	end

end

function meta:PreModifyNodeType( nodeType)

	if type(nodeType) == "table" then

		for id, node in self:Nodes() do
			if node:GetType() ~= nodeType then continue end
			self:PreModifyNode( node, action, subaction )
		end

	else

		for id, node in self:Nodes() do
			if node:GetTypeName() ~= nodeType then continue end
			self:PreModifyNode( node, action, subaction )
		end

	end

end

function meta:PostModifyNodeType( nodeType )

	self:CacheNodeTypes()

	if type(nodeType) == "table" then

		for id, node in self:Nodes() do
			if node:GetType() ~= nodeType then continue end
			self:PostModifyNode( node, action, subaction )
		end

	else

		for id, node in self:Nodes() do
			if node:GetTypeName() ~= nodeType then continue end
			self:PostModifyNode( node, action, subaction )
		end

	end

end

function meta:SetHookType( nodeType )

	self.hookNodeType = nodeType

end

function meta:GetHookType()

	return self.hookNodeType

end

function meta:GetType()

	return self.type

end

function meta:SetName( name )

	self.name = name

end

function meta:GetName()

	return self.name

end

function meta:GetTitle()

	return self:GetName()

end

function meta:GetModule()

	return self.module

end

function meta:GetCallNodeType()

	return self.callNodeType

end

function meta:GetEntryNodeType()

	return self.callEntryNodeType

end

function meta:GetExitNodeType()

	return self.callExitNodeType

end

function meta:GetEntryNode()

	return self:FindNodeByType( self:GetEntryNodeType() )

end

function meta:GetExitNode()

	return self:FindNodeByType( self:GetExitNodeType() )

end

function meta:CacheNodeTypes()

	self.__cachedTypes = nil
	self.__cachedTypes = self:GetNodeTypes()

end

function meta:GetNetworkRole()

	local role = nil
	if self:HasFlag(FL_ROLE_CLIENT) and self:HasFlag(FL_ROLE_SERVER) then role = ROLE_Shared
	elseif self:HasFlag(FL_ROLE_SERVER) then role = ROLE_Server
	elseif self:HasFlag(FL_ROLE_CLIENT) then role = ROLE_Client end

	return role

end

function meta:GetNodeTypes()

	if self.__cachedTypes then return self.__cachedTypes end

	local collection = bpcollection.New()

	Profile("cache-node-types", function()
		self:GetModule():GetNodeTypes( collection, self )

		if self.type == GT_Function then
			local types = {}

			types["__Entry"] = self.callEntryNodeType
			types["__Exit"] = self.callExitNodeType

			collection:Add( types )
		end
	end)

	return collection

end

function meta:Connections(forward)

	if forward then
		local i, n = 0, #self.connections
		return function()
			i = i + 1
			if i <= n then return i, self.connections[i] end
		end
	end

	local i = #self.connections + 1
	return function() 
		i = i - 1
		if i > 0 then return i, self.connections[i] end
	end

end

function meta:GetNodePin(nodeID, pinID)

	return self:GetNode(nodeID):GetPin(pinID)

end

function meta:GetPinConnections(pinDir, nodeID, pinID)

	local out = {}
	for k, v in self:Connections() do
		if pinDir == PD_In and (v[3] ~= nodeID or v[4] ~= pinID) then continue end
		if pinDir == PD_Out and (v[1] ~= nodeID or v[2] ~= pinID) then continue end
		out[#out+1] = v
	end
	return out

end

function meta:GetUsedPinTypes(used, noFlags)

	used = used or {}
	for nodeID, node in self:Nodes() do
		for pinID, pin in node:Pins() do
			local pinType = pin:GetType()
			if noFlags then pinType = pinType:WithFlags(0) end
			if not table.HasValue(used, pinType) then
				used[#used+1] = pinType
			end
		end
	end
	return used

end

-- Starting at a given node, traverses connections in the graph which match a condition
function meta:NodeWalk(nodeID, condition, visited)

	visited = visited or {}

	local max = 10000
	local stack = {}
	local connections = {}

	-- Add node connections to stack
	local function AddNodeConnections(node)
		if visited[node] then return end visited[node] = true
		for pinID, pin in node:Pins() do
			for _, v in ipairs( self:GetPinConnections(pin:GetDir(), node.id, pinID) ) do
				local other = pin:GetDir() == PD_In and v[1] or v[3]
				local otherPin = pin:GetDir() == PD_In and v[2] or v[4]
				local otherNode = self:GetNode( other )

				-- Push connection onto stack if condition passes
				if condition(otherNode, otherPin) then stack[#stack+1] = v end
			end
		end
	end

	-- Add current node's connections
	AddNodeConnections(self:GetNode(nodeID))

	while #stack > 0 and max > 0 do
		max = max - 1

		-- Pop connection from stack and insert it into output table
		local conn = stack[#stack]
		table.remove(stack, #stack)
		connections[#connections+1] = conn

		local node0 = self:GetNode(conn[1])
		local node1 = self:GetNode(conn[3])

		-- Recurse into the node that hasn't been visited yet
		AddNodeConnections(visited[node0] and node1 or node0)

	end

	if max == 0 then error("Infinite loop in graph") end
	return connections

end

function meta:BuildInformDirectionalCandidates(dir, candidateNodes)

	for id, node in self:Nodes() do
		for pinID, pin in node:SidePins(dir) do
			if node:IsInformPin(pinID) then
				for _, v in ipairs( self:GetPinConnections(dir, id, pinID) ) do
					local other = self:GetNode( dir == PD_In and v[1] or v[3] )
					if other == nil then continue end

					local otherPin = dir == PD_In and v[2] or v[4]
					if other:GetPin( otherPin ) == nil then continue end

					if other:IsInformPin( otherPin ) == false and other:GetPin( otherPin ):GetBaseType() ~= PN_Any then
						if not table.HasValue(candidateNodes, other) then
							candidateNodes[#candidateNodes+1] = other
						end
					end
				end
			end
		end
	end

end

function meta:WalkInforms()

	Profile("walk-informs", function()

		local candidateNodes = {}
		local visited = {}

		if self.suppressInformWalk then return end

		-- Clear all informs on all nodes
		for id, node in self:Nodes() do node:ClearInforms() end

		self:BuildInformDirectionalCandidates(PD_In, candidateNodes)

		for _, v in ipairs(candidateNodes) do
			local connections = self:NodeWalk(v.id, function(node, pinID)
				return node:IsInformPin(pinID) and node:GetPin(pinID):GetDir() == PD_In
			end, visited)
			local pinType = nil
			for _,c in ipairs(connections) do
				if not self:GetNode(c[1]):IsInformPin(c[2]) then pinType = self:GetNode(c[1]):GetPin(c[2]):GetType(true) end
				self:GetNode(c[3]):SetInform(pinType)
			end
		end

		self:BuildInformDirectionalCandidates(PD_Out, candidateNodes)

		for _, v in ipairs(candidateNodes) do
			local connections = self:NodeWalk(v.id, function(node, pinID)
				return node:IsInformPin(pinID) and node:GetPin(pinID):GetDir() == PD_Out
			end, visited)
			local pinType = nil
			for _,c in ipairs(connections) do
				if not self:GetNode(c[3]):IsInformPin(c[4]) then pinType = self:GetNode(c[3]):GetPin(c[4]):GetType(true) end
				self:GetNode(c[1]):SetInform(pinType)
			end
		end

	end)

end

function meta:GetPinType(nodeID, pinID)

	local node = self:GetNode(nodeID)
	local pin = node:GetPin(pinID)
	return pin:GetType()

end

function meta:FindNodeByType(nodeType)

	for _, node in self:Nodes() do
		if node:GetType() == nodeType then return node end
	end
	return nil

end

function meta:FindConnection(nodeID0, pinID0, nodeID1, pinID1)

	local p0 = self:GetNodePin( nodeID0, pinID0 )
	local dir = p0:GetDir()

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

function meta:IsPinConnected(nodeID, pinID, killConnections)

	for i, connection in self:Connections() do

		if connection[1] == nodeID and connection[2] == pinID then
			if killConnections then self:RemoveConnectionID(i) continue end
			return true, connection
		end
		if connection[3] == nodeID and connection[4] == pinID then
			if killConnections then self:RemoveConnectionID(i) continue end
			return true, connection
		end

	end

end

function meta:NodePinToString(nodeID, pinID)

	return self:GetNode(nodeID):ToString(pinID)

end

function meta:CanConnect(nodeID0, pinID0, nodeID1, pinID1)

	if self:FindConnection(nodeID0, pinID0, nodeID1, pinID1) ~= nil then return false, "Already connected" end

	local p0 = self:GetNodePin(nodeID0, pinID0) --always PD_Out
	local p1 = self:GetNodePin(nodeID1, pinID1) --always PD_In

	if p0:IsType(PN_Exec) and self:IsPinConnected(nodeID0, pinID0, true) then return false, "Only one connection outgoing for exec pins" end
	if not p1:IsType(PN_Exec) and self:IsPinConnected(nodeID1, pinID1, true) then return false, "Only one connection for inputs" end

	if p0:GetDir() == p1:GetDir() then return false, "Can't connect " .. (p0:IsOut() and "m/m" or "f/f") .. " pins" end

	if self:GetNode(nodeID0):GetTypeName() == "CORE_Pin" and p0:IsType(PN_Any) then return true end
	if self:GetNode(nodeID1):GetTypeName() == "CORE_Pin" and p1:IsType(PN_Any) then return true end

	if p0:HasFlag(PNF_Table) ~= p1:HasFlag(PNF_Table) then return false, "Can't connect table to non-table pin" end

	if not p0:GetType():Equal(p1:GetType(), 0) then

		if p0:IsType(PN_Any) and not p1:IsType(PN_Exec) then return true end
		if p1:IsType(PN_Any) and not p0:IsType(PN_Exec) then return true end

		if bpschema.CanCast(p0:GetType(), p1:GetType()) then
			return true
		else
			return false, "No explicit conversion between " .. self:NodePinToString(nodeID0, pinID0) .. " and " .. self:NodePinToString(nodeID1, pinID1)
		end

	end

	if p0:GetSubType() ~= p1:GetSubType() then 
		return false, "Can't connect " .. self:NodePinToString(nodeID0, pinID0) .. " to " .. self:NodePinToString(nodeID1, pinID1)
	end

	return true

end

function meta:ConnectNodes(nodeID0, pinID0, nodeID1, pinID1)

	local p0 = self:GetNodePin(nodeID0, pinID0)
	local p1 = self:GetNodePin(nodeID1, pinID1)

	if p0 == nil then print("P0 pin not found: " .. nodeID0 .. " -> " .. pinID0) return false end
	if p1 == nil then print("P1 pin not found: " .. nodeID1 .. " -> " .. pinID1) return false end

	-- swap connection to ensure first is output and second is input
	if p0:IsIn() and p1:IsOut() then
		local t = nodeID0 nodeID0 = nodeID1 nodeID1 = t
		local t = pinID0 pinID0 = pinID1 pinID1 = t
	end

	local cc, m = self:CanConnect(nodeID0, pinID0, nodeID1, pinID1)
	if not cc then print(m) return false end

	self.connections[#self.connections+1] = { nodeID0, pinID0, nodeID1, pinID1 }

	--print("CONNECTED: " .. self:GetNode(nodeID0):ToString(pinID0) .. " -> " .. self:GetNode(nodeID1):ToString(pinID1))

	self:WalkInforms()
	self:FireListeners(CB_CONNECTION_ADD, #self.connections, self.connections[#self.connections])

	return true

end

function meta:Clear()

	self:FireListeners(CB_GRAPH_CLEAR)

	self.nodes:Clear()
	self.inputs:Clear()
	self.outputs:Clear()
	self.connections = {}

end

function meta:CanAddNode(nodeType)

	if not self.module:CanAddNode(nodeType) then return false end

	if self.type == GT_Function then
		if nodeType:HasFlag(NTF_Latent) then return false end
		if nodeType:GetCodeType() == NT_Event then return false end
	end

	if nodeType:GetCodeType() == NT_Event and self.module:NodeTypeInUse(nodeType:GetName()) then
		return false
	end

	if nodeType:GetCodeType() == NT_FuncInput or nodeType:GetCodeType() == NT_FuncOutput then
		if nodeType.graph ~= self then return false end
	end

	if nodeType:GetCodeType() == NT_FuncInput then
		for _, node in self:Nodes() do
			if node:GetCodeType() == NT_FuncInput then return false end
		end
	end

	return true

end

function meta:AddNode(nodeTypeName, ...)

	nodeType = type(nodeTypeName) == "table" and nodeTypeName or self:GetNodeTypes():Find(nodeTypeName)
	if nodeType == nil then error("Node type not found: " .. tostring(nodeTypeName)) end

	if not self:CanAddNode(nodeType) then return end

	if nodeType:GetCodeType() == NT_Event and nodeType:ReturnsValues() then
		return self.module:RequestGraphForEvent(nodeType)
	end

	return self.nodes:Construct( nodeType, ... )

end

function meta:RemoveConnectionID(id)

	local c = self.connections[id]
	if c ~= nil then
		table.remove(self.connections, id)
		self:WalkInforms()
		self:FireListeners(CB_CONNECTION_REMOVE, id, c)
	else
		print("Could not find connection: " .. tostring(id))
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
		local node1 = self:GetNode(c[1])
		local node2 = self:GetNode(c[3])
		if not node1 then
			print("Removed invalid connection: " .. i .. " [output node not found : " .. tostring(c[1]) .. "]")
			table.remove(connections, i)
		elseif not node2 then
			print("Removed invalid connection: " .. i .. " [input node not found : " .. tostring(c[3]) .. "]")
			table.remove(connections, i)
		elseif not node1:GetPin(c[2]) then
			print("Removed invalid connection: " .. i .. " [output pin not found : " .. node1:ToString() .. " : " .. tostring(c[2]) .. "]")
			table.remove(connections, i)
			PrintTable(c)
		elseif not node2:GetPin(c[4]) then
			print("Removed invalid connection: " .. i .. " [input pin not found : " .. node2:ToString() .. " : " .. tostring(c[4]) .. "]")
			table.remove(connections, i)
			PrintTable(c)
		end

	end	

end

function meta:CollapseSingleRerouteNode(nodeID)

	local node = self:GetNode( nodeID )

	local insert = {}
	local connections = self.connections
	local input = nil
	for i, c in self:Connections() do

		if c[1] == nodeID then --output
			insert[#insert+1] = {c[3],c[4]}
			self:RemoveConnectionID(i)
		elseif c[3] == nodeID then --input
			input = {c[1],c[2]}
			self:RemoveConnectionID(i)
		end

	end	

	if input == nil then print("Reroute node did not have input connection") return end

	for _, c in ipairs(insert) do
		if not self:ConnectNodes(input[1], input[2], c[1], c[2]) then 
			error("Unable to reconnect re-route nodes: " .. 
				self:NodePinToString(input[1], input[2]) .. " -> " .. 
				self:NodePinToString(c[1], c[2])) 
		end
	end

	self:RemoveNode( nodeID )

end

function meta:CollapseRerouteNodes()

	self.suppressInformWalk = true

	for _, node in self:Nodes(true) do
		if node:GetType():HasFlag(NTF_Collapse) then
			self:CollapseSingleRerouteNode( node.id )
		end
	end

	self.suppressInformWalk = false
	self:WalkInforms()

end

function meta:WriteToStream(stream, mode, version)

	Profile("write-single-graph", function()

		stream:WriteInt( self.type, false )
		stream:WriteInt( self.flags, false )

		if self.type == GT_Function then
			Profile("write-inputs", self.inputs.WriteToStream, self.inputs, stream, mode, version)
			Profile("write-outputs", self.outputs.WriteToStream, self.outputs, stream, mode, version)
		end

		Profile("write-nodes", self.nodes.WriteToStream, self.nodes, stream, mode, version)
		Profile("write-connections", bpdata.WriteValue, self.connections, stream )

		if mode == bpmodule.STREAM_FILE then

			Profile("write-connection-meta", self.WriteConnectionMeta, self, stream, version)

		end

		bpdata.WriteValue( self.hookNodeType, stream )

	end)

end

function meta:WriteConnectionMeta(stream, version)

	local connnectionMeta = {}
	local n = 0
	local maxid = 0

	local newver = true
	local idf = stream.WriteInt
	if newver then
		for id, c in self:Connections(true) do n = n + 1 maxid = math.max(maxid, id) end
		local bits = 24
		if maxid < 65536 then bits = 16 end
		if maxid < 256 then bits = 8 end
		stream:WriteBits( bits, 8 )
		for id, c in self:Connections(true) do stream:WriteBits( id, bits ) end
		stream:WriteBits( 0, bits )
	end

	for id, c in self:Connections(true) do

		local n0 = self:GetNode(c[1])
		local n1 = self:GetNode(c[3])
		local pin0 = n0:GetPins()[c[2]]
		local pin1 = n1:GetPins()[c[4]]
		if newver then
			stream:WriteStr( n0:GetTypeName() )
			stream:WriteStr( pin0:GetName() )
			stream:WriteStr( n1:GetTypeName() )
			stream:WriteStr( pin1:GetName() )
		else
			connnectionMeta[id] = {n0:GetTypeName(), pin0:GetName(), n1:GetTypeName(), pin1:GetName()}
		end

	end

	if not newver then
		bpdata.WriteValue( connnectionMeta, stream )
	end

end

function meta:ReadFromStream(stream, mode, version)

	Profile("read-single-graph", function()

		self:Clear()

		self.type = stream:ReadInt( false )
		self.flags = stream:ReadInt( false )

		if self.type == GT_Function then

			self.inputs:SuppressEvents(true)
			self.outputs:SuppressEvents(true)
			self.inputs:ReadFromStream(stream, mode, version)
			self.outputs:ReadFromStream(stream, mode, version)
			self.inputs:SuppressEvents(false)
			self.outputs:SuppressEvents(false)
		end

		self.deferredNodes:ReadFromStream(stream, mode, version)
		self.connections = bpdata.ReadValue( stream )

		if mode == bpmodule.STREAM_FILE then

			self:ReadConnectionMeta(stream, version)

		end

		if version >= 3 then self.hookNodeType = bpdata.ReadValue( stream ) end

	end)

end

function meta:ReadConnectionMeta(stream, version)

	if version >= 4 then
		local cmeta = {}
		local ids = {}
		local bits = stream:ReadBits(8)
		local id = stream:ReadBits(bits)
		local k = 0
		while id ~= 0 and k ~= 100000 do
			k = k + 1
			ids[#ids+1] = id
			id = stream:ReadBits(bits)
		end
		if k == 100000 then error("NO STOP BIT!!!") end
		for i=1, #ids do
			cmeta[ids[i]] = {stream:ReadStr(), stream:ReadStr(), stream:ReadStr(), stream:ReadStr()}
		end
		self.connectionMeta = cmeta

	else
		self.connectionMeta = bpdata.ReadValue( stream )
	end

end

function meta:ResolveConnectionMeta()

	if self.connectionMeta ~= nil then

		--print("Resolving connection meta...")
		for i, c in self:Connections(true) do
			local meta = self.connectionMeta[i]
			local nt0 = self:GetNode(c[1])
			local nt1 = self:GetNode(c[3])

			if nt0 == nil then continue end
			if nt1 == nil then continue end

			local pin0 = nt0:GetPin(c[2])
			local pin1 = nt1:GetPin(c[4])
			local ignorePin0 = false
			local ignorePin1 = false

			meta[2] = nt0:RemapPin(meta[2])
			meta[4] = nt1:RemapPin(meta[4])

			-- Reroute pins don't require fixup
			if nt0:GetTypeName() == "CORE_Pin" then ignorePin0 = true end
			if nt1:GetTypeName() == "CORE_Pin" then ignorePin1 = true end

			--print("Check Connection: " .. nt0:ToString(c[2]) .. " -> " .. nt1:ToString(c[4]))

			if meta == nil then continue end
			if (pin0 == nil or pin0:GetName():lower() ~= meta[2]:lower()) and not ignorePin0 then
				MsgC( Color(255,100,100), " -Pin[OUT] not valid: " .. c[2] .. ", was " .. meta[1] .. "." .. meta[2] .. ", resolving...")
				local found = nt0:FindPin( PD_Out, meta[2] )
				c[2] = found and found.id or nil
				MsgC( c[2] ~= nil and Color(100,255,100) or Color(255,100,100), c[2] ~= nil and " Resolved\n" or " Not resolved\n" )
			end

			if (pin1 == nil or pin1:GetName():lower() ~= meta[4]:lower()) and not ignorePin1 then
				MsgC( Color(255,100,100), " -Pin[IN] not valid: " .. c[4] .. ", was " .. meta[3] .. "." .. meta[4] .. ", resolving...")
				local found = nt0:FindPin( PD_In, meta[4] )
				c[4] = found and found.id or nil
				MsgC( c[4] ~= nil and Color(100,255,100) or Color(255,100,100), c[4] ~= nil and " Resolved\n" or " Not resolved\n" )
			end
		end
		self.connectionMeta = nil
	end

end

function meta:CreateDeferredData()

	--print("CREATE DEFERRED NODES: " .. #self.deferred)

	Profile("create-deferred", function()

		self.deferredNodes:CopyInto(self.nodes)
		self.deferredNodes:Clear()

		self:CacheNodeTypes()
		self:RemoveNodeIf( function(node) return not node:PostInit() end )

		for id, node in self:Nodes() do
			self:FireListeners(CB_NODE_ADD, id)
		end

		self:ResolveConnectionMeta()
		self:WalkInforms()
		self:RemoveInvalidConnections()
		for i, connection in self:Connections() do
			self:FireListeners(CB_CONNECTION_ADD, i, connection)
		end

	end)

end

-- Quickly banging this out using existing tech
function meta:CopyInto(other)

	Profile("copy-graph", function()

		other:Clear()
		other.module = self.module
		other.id = self.id
		other.name = self.name
		other.type = self.type
		other.flags = self.flags
		other.hookNodeType = self.hookNodeType

		-- Deep copy will copy all members including graph which includes module etc...
		-- So clear graph variable and set it on the other side of the deep copy
		for _, node in self:Nodes() do node.graph = nil end

		Profile("copy-nodes", self.nodes.CopyInto, self.nodes, other.nodes, true )
		Profile("copy-inputs", self.inputs.CopyInto, self.inputs, other.inputs, true )
		Profile("copy-outputs", self.outputs.CopyInto, self.outputs, other.outputs, true )

		for _, node in other:Nodes() do node.graph = other node:PostInit() end
		for _, node in self:Nodes() do node.graph = self end

		for _, c in self:Connections() do
			other.connections[#other.connections+1] = {c[1], c[2], c[3], c[4]}
		end

	end)

	return other

end

function meta:CreateSubGraph(subNodeIds)

	local copy = self:CopyInto( New() )
	local hold = {}

	for i, c in self:Connections() do
		hold[#hold+1] = c
	end

	copy:CacheNodeTypes()
	copy:RemoveNodeIf( function(node) return not table.HasValue(subNodeIds, node.id) end )
	copy:WalkInforms()
	copy:RemoveInvalidConnections()

	local severedPins = {}
	for _, v in ipairs(hold) do

		if table.HasValue(subNodeIds, v[1]) and not table.HasValue(subNodeIds, v[3]) then
			severedPins[#severedPins+1] = {v[1], v[2]}
		end

		if not table.HasValue(subNodeIds, v[1]) and table.HasValue(subNodeIds, v[3]) then
			severedPins[#severedPins+1] = {v[3], v[4]}
		end

	end

	copy.severedPins = severedPins

	return copy

end

function meta:AddSubGraph( subgraph, x, y )

	local connectionRemap = {}
	local copy = subgraph:CopyInto( New() )
	local nodeCount = 0
	local connectionCount = 0

	for id, node in copy:Nodes() do

		if self:CanAddNode(node:GetType()) then

			local nx, ny = node:GetPos()
			node:Move(nx + x, ny + y)
			node.id = nil
			node.BaseClass = bpcommon.MetaTable("bpnode")
			local newID = self.nodes:Add( node )
			node.graph = self
			connectionRemap[id] = newID
			nodeCount = nodeCount + 1

		end

	end

	for _, c in copy:Connections() do

		connectionCount = connectionCount + 1
		local nodeID0 = connectionRemap[c[1]]
		local nodeID1 = connectionRemap[c[3]]
		local pinID0 = c[2]
		local pinID1 = c[4]

		if nodeID0 and nodeID1 then
			self:ConnectNodes(nodeID0, pinID0, nodeID1, pinID1)
		end

	end

	--print("Added " .. nodeCount .. " nodes and " .. connectionCount .. " connections.")

end

New = function(...) return bpcommon.MakeInstance(meta, ...) end