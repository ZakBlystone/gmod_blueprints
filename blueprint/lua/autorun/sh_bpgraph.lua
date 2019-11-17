AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")
include("sh_bplist.lua")
include("sh_bpnode.lua")

module("bpgraph", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpnodedef)) --bpnodedef is temporary

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

NODE_MODIFY_RENAME = 1
NODE_MODIFY_SIGNATURE = 2

FL_NONE = 0
FL_LOCK_PINS = 1
FL_LOCK_NAME = 2
FL_HOOK = 4
FL_ROLE_SERVER = 8
FL_ROLE_CLIENT = 16

local meta = {}
meta.__index = meta

New = nil

bpcommon.CreateIndexableListIterators(meta, "nodes")
bpcommon.CreateIndexableListIterators(meta, "inputs")
bpcommon.CreateIndexableListIterators(meta, "outputs")

function meta:Init(module, type)

	self.nodeConstructor = function(...)
		local node = bpnode.New(...)
		node.graph = self
		return node
	end

	self.flags = FL_NONE
	self.type = type or GT_Event
	self.module = module
	self.deferredNodes = bplist.New():Constructor(self.nodeConstructor)
	self.nodes = bplist.New():Constructor(self.nodeConstructor)
	self.inputs = bplist.New():NamedItems("Inputs"):Constructor(bpvariable.New)
	self.outputs = bplist.New():NamedItems("Outputs"):Constructor(bpvariable.New)
	self.connections = {}
	self.heldConnections = {}

	self.inputs:AddListener(function(cb, action, id, var)

		if cb == bplist.CB_PREMODIFY then
			self.module:PreModifyNodeType( "__Call" .. self.id, NODE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType("__Entry", NODE_MODIFY_SIGNATURE, action)
			self:PreModifyNodeType("__Exit", NODE_MODIFY_SIGNATURE, action)
		elseif cb == bplist.CB_POSTMODIFY then
			self.module:PostModifyNodeType( "__Call" .. self.id, NODE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Entry", NODE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Exit", NODE_MODIFY_SIGNATURE, action )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.outputs:AddListener(function(cb, action, id, var)

		if cb == bplist.CB_PREMODIFY then
			self.module:PreModifyNodeType( "__Call" .. self.id, NODE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType("__Entry", NODE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType("__Exit", NODE_MODIFY_SIGNATURE, action )
		elseif cb == bplist.CB_POSTMODIFY then
			self.module:PostModifyNodeType( "__Call" .. self.id, NODE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Entry", NODE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Exit", NODE_MODIFY_SIGNATURE, action )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.nodes:AddListener(function(cb, id)

		if cb == bplist.CB_ADD then
			self:FireListeners(CB_NODE_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			for i, c in self:Connections() do
				if c[1] == id or c[3] == id then
					self:RemoveConnectionID(i)
				end
			end

			self:FireListeners(CB_NODE_REMOVE, id)
		end

	end, bplist.CB_ALL)

	bpcommon.MakeObservable(self)

	return self

end

function meta:PostInit()

	if self.type == GT_Function then

		self:AddNode("__Entry", 0, 200)
		self:AddNode("__Exit", 400, 200)

	end

	self:CacheNodeTypes()

	return self

end

function meta:SetFlag(fl) self.flags = bit.bor(self.flags, fl) end
function meta:HasFlag(fl) return bit.band(self.flags, fl) ~= 0 end
function meta:ClearFlag(fl) self.flags = bit.band(self.flags, bit.bnot(fl)) end
function meta:GetFlags() return self.flags end
function meta:CanRename() return not self:HasFlag(FL_LOCK_NAME) end

function meta:PreModifyNode( node, action, subaction )

	self:FireListeners(CB_PREMODIFY_NODE, node.id, action)

	self.heldConnections[node.id] = {}
	local held = self.heldConnections[node.id]
	local pins = node:GetPins()

	for i, c in self:Connections() do

		if c[1] == node.id then --output
			local other = self:GetNode(c[3])
			local pin = pins[c[2]]
			self:RemoveConnectionID(i)
			table.insert(held, {pin:GetDir(), pin:GetName(), c[3], PD_In, other:GetPin(c[4]):GetName()})
		elseif c[3] == node.id then --input
			local other = self:GetNode(c[1])
			local pin = pins[c[4]]
			self:RemoveConnectionID(i)
			table.insert(held, {pin:GetDir(), pin:GetName(), c[1], PD_Out, other:GetPin(c[2]):GetName()})
		end

	end

end

function meta:PostModifyNode( node, action, subaction )

	print("NODE MODIFICATION: " .. node:ToString() .. " " .. tostring(action) .. " " .. tostring(subaction))

	node:UpdatePins()
	self:FireListeners(CB_POSTMODIFY_NODE, node.id, action)

	local ntype = node:GetType()
	local held = self.heldConnections[node.id]
	self.heldConnections[node.id] = nil

	if ntype == nil then return end
	if held == nil then return end

	local pins = node:GetPins()

	for k, c in pairs(held) do
		local pinID = node:FindPin(c[1], c[2])
		if pinID then
			local other = self:GetNode(c[3])
			local otherPin = other:FindPin(c[4], c[5])
			if otherPin ~= nil then self:ConnectNodes(node.id, pinID, other.id, otherPin) end
		else
			print("Couldn't find pin: " .. tostring(c[2]))
		end
	end

end

function meta:PreModifyNodeType( nodeType, action, subaction )

	if action == NODE_MODIFY_SIGNATURE and subaction ~= bplist.MODIFY_RENAME then

		for id, node in self:Nodes() do
			if node:GetTypeName() ~= nodeType then continue end
			self:PreModifyNode( node, action, subaction )
		end

	end

end

function meta:PostModifyNodeType( nodeType, action, subaction )

	self:CacheNodeTypes()

	if action == NODE_MODIFY_SIGNATURE and subaction ~= bplist.MODIFY_RENAME then

		for id, node in self:Nodes() do
			if node:GetTypeName() ~= nodeType then continue end
			self:PostModifyNode( node, action, subaction )
		end

	end

end

function meta:PreModify(action, subaction)

	if action == bpmodule.GRAPH_MODIFY_RENAME then
		self:PreModifyNodeType("__Entry", NODE_MODIFY_RENAME, subaction)
		self:PreModifyNodeType("__Exit", NODE_MODIFY_RENAME, subaction)
	end

end

function meta:PostModify(action, subaction)

	if action == bpmodule.GRAPH_MODIFY_RENAME then
		self:PostModifyNodeType("__Entry", NODE_MODIFY_RENAME, subaction)
		self:PostModifyNodeType("__Exit", NODE_MODIFY_RENAME, subaction)
	end

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

function meta:GetFunctionType()

	if self.type ~= GT_Function then return end

	local pins = {}

	for id, var in self.inputs:Items() do table.insert(pins, var:CreatePin( PD_In )) end
	for id, var in self.outputs:Items() do table.insert(pins, var:CreatePin( PD_Out )) end

	return FUNCTION {
		pins = pins,
		displayName = self:GetName(),
		custom = true,
		graphThunk = self.id,
		meta = {},
	}

end

function meta:CacheNodeTypes()

	self.__cachedTypes = nil
	self.__cachedTypes = self:GetNodeTypes()

end

function meta:CreateFunctionNodeTypes( output )

	local inPins = { MakePin( PD_Out, "Exec", PN_Exec ) }
	local outPins = { MakePin( PD_In, "Exec", PN_Exec ) }

	for id, var in self.inputs:Items() do table.insert(inPins, var:CreatePin( PD_Out )) end
	for id, var in self.outputs:Items() do table.insert(outPins, var:CreatePin( PD_In )) end

	local role = nil
	if self:HasFlag(FL_ROLE_CLIENT) and self:HasFlag(FL_ROLE_SERVER) then role = ROLE_Shared
	elseif self:HasFlag(FL_ROLE_SERVER) then role = ROLE_Server
	elseif self:HasFlag(FL_ROLE_CLIENT) then role = ROLE_Client end

	output["__Entry"] = FUNC_INPUT {
		pins = inPins,
		displayName = self:GetName(),
		name = "__Entry",
		role = role,
		meta = {noDelete = true},
	}

	output["__Exit"] = FUNC_OUTPUT {
		pins = outPins,
		displayName = "Return",
		name = "__Exit",
		meta = {},
	}

end

function meta:GetNodeTypes()

	if self.__cachedTypes then return self.__cachedTypes end

	return Profile("cache-node-types", function()
		local types = {}
		local base = self:GetModule():GetNodeTypes( self.id )

		table.Merge(types, base)

		if self.type == GT_Function then
			self:CreateFunctionNodeTypes(types)

			-- blacklist invalid types in function graphs
			for k, v in pairs(types) do
				if v.meta and v.meta.latent then types[k] = nil end
				if v.type == NT_Event then types[k] = nil end
			end
		end
		return types
	end)

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
		table.insert(out, v)
	end
	return out

end

function meta:NodeWalk(nodeID, pinCondition, nodeCondition, visited)

	visited = visited or {}

	local max = 10000
	local stack = {}
	local nodes = {}
	local connections = {}

	table.insert(stack, nodeID)

	while #stack > 0 and max > 0 do

		max = max - 1

		local pnode = stack[#stack]
		table.remove(stack, #stack)

		local node = self:GetNode(pnode)
		for pinID, pin in node:Pins() do

			for _, v in pairs( self:GetPinConnections(pin:GetDir(), pnode, pinID) ) do

				local other = pin:GetDir() == PD_In and v[1] or v[3]
				local otherPin = pin:GetDir() == PD_In and v[2] or v[4]
				local node = self:GetNode( other )
				if not pinCondition(node, otherPin) then continue end

				if not visited[other] then
					table.insert(connections, v)

					visited[other] = true

					if nodeCondition(node) then
						visited[other] = true
						table.insert(stack, other)
						table.insert(nodes, node)
					end
				end

			end

		end

	end

	if max == 0 then
		error("Infinite loop in graph")
	end

	return nodes, connections

end

function meta:BuildInformDirectionalCandidates(dir, candidateNodes)

	for id, node in self:Nodes() do
		for pinID, pin in node:SidePins(dir) do
			if node:IsInformPin(pinID) then
				for _, v in pairs( self:GetPinConnections(dir, id, pinID) ) do
					local other = self:GetNode( dir == PD_In and v[1] or v[3] )
					if other:IsInformPin( dir == PD_In and v[2] or v[4] ) == false then
						if not table.HasValue(candidateNodes, other) then
							table.insert(candidateNodes, other)
						end
					end
				end
			end
		end
	end

end

function meta:WalkInforms()

	local candidateNodes = {}
	local visited = {}

	for id, node in self:Nodes() do
		node:ClearInforms()
	end

	self:BuildInformDirectionalCandidates(PD_In, candidateNodes)

	print("Forward Walk: ")
	for k,v in pairs(candidateNodes) do
		local nodes, connections = self:NodeWalk(v.id,
			function(node,pinID) return node:IsInformPin(pinID) and node:GetPin(pinID):GetDir() == PD_In end,
			function(node) return node:HasInformPins() end,
			visited )

		print(v:ToString())
		if #connections == 0 then continue end
		local pinType = self:GetNode(connections[1][1]):GetPin(connections[1][2]):GetType(true)
		print("Propagate pin type: " .. pinType:ToString())
		for _,c in pairs(connections) do
			print("\t" .. self:GetNode(c[1]):ToString(c[2]) .. " -> " .. self:GetNode(c[3]):ToString(c[4]))
			self:GetNode(c[3]):SetInform(pinType)
		end
	end

	self:BuildInformDirectionalCandidates(PD_Out, candidateNodes)

	print("Reverse Walk: ")
	for k,v in pairs(candidateNodes) do
		local nodes, connections = self:NodeWalk(v.id,
			function(node,pinID) return node:IsInformPin(pinID) and node:GetPin(pinID):GetDir() == PD_Out end,
			function(node) return node:HasInformPins() end,
			visited )

		print(v:ToString())
		if #connections == 0 then continue end
		local pinType = self:GetNode(connections[1][3]):GetPin(connections[1][4]):GetType(true)
		print("Propagate pin type: " .. pinType:ToString())
		for _,c in pairs(connections) do
			print("\t" .. self:GetNode(c[1]):ToString(c[2]) .. " -> " .. self:GetNode(c[3]):ToString(c[4]))
			self:GetNode(c[1]):SetInform(pinType)
			print("\t \\-> " .. self:GetNode(c[1]):ToString(c[2]))
		end
	end

	print("Visited Nodes:")
	for k,v in pairs(visited) do
		print("\t" .. self:GetNode(k):ToString())
	end

end

function meta:GetPinType(nodeID, pinID)

	local node = self:GetNode(nodeID)
	local pin = node:GetPin(pinID)
	return pin:GetType()

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

function meta:IsPinConnected(nodeID, pinID)

	for _, connection in self:Connections() do

		if connection[1] == nodeID and connection[2] == pinID then return true, connection end
		if connection[3] == nodeID and connection[4] == pinID then return true, connection end

	end

end

function meta:CheckConversion(pin0, pin1)

	if pin0:GetBaseType() == PN_Ref and pin1:GetBaseType() == PN_Ref then
		if pin0:GetSubType() == "Player" and pin1:GetSubType() == "Entity" then
			return true
		end
		if pin0:GetSubType() == "Entity" and pin1:GetSubType() == "Player" then
			return true
		end
	end

	local cv = NodePinImplicitConversions[pin0:GetBaseType()]
	if cv then
		for k,v in pairs(cv) do
			if type(v) == "table" then
				if v[1] == pin1:GetBaseType() and v[2] == pin1:GetSubType() then return true end
			else
				if v == pin1:GetBaseType() then return true end
			end
		end
	end
	return false

end

function meta:NodePinToString(nodeID, pinID)

	return self:GetNode(nodeID):ToString(pinID)

end

function meta:CanConnect(nodeID0, pinID0, nodeID1, pinID1)

	if self:FindConnection(nodeID0, pinID0, nodeID1, pinID1) ~= nil then return false, "Already connected" end

	local p0 = self:GetNodePin(nodeID0, pinID0) --always PD_Out
	local p1 = self:GetNodePin(nodeID1, pinID1) --always PD_In

	if p0:IsType(PN_Exec) and self:IsPinConnected(nodeID0, pinID0) then return false, "Only one connection outgoing for exec pins" end
	if not p1:IsType(PN_Exec) and self:IsPinConnected(nodeID1, pinID1) then return false, "Only one connection for inputs" end

	if p0:GetDir() == p1:GetDir() then return false, "Can't connect " .. (p0:IsOut() and "m/m" or "f/f") .. " pins" end

	if self:GetNode(nodeID0):GetTypeName() == "Pin" or self:GetNode(nodeID1):GetTypeName() == "Pin" then return true end

	if p0:HasFlag(PNF_Table) ~= p1:HasFlag(PNF_Table) then return false, "Can't connect table to non-table pin" end

	if not p0:GetType():Equal(p1:GetType(), 0) then

		if p0:IsType(PN_Any) and not p1:IsType(PN_Exec) then return true end
		if p1:IsType(PN_Any) and not p0:IsType(PN_Exec) then return true end

		-- Does not work properly, take into account pin directions to determine what conversion is being attempted
		-- Maybe rectify pin ordering so pin0 is always PD_Out, and pin1 is always PD_In
		if self:CheckConversion(p0, p1) or self:CheckConversion(p1, p0) then
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

	table.insert(self.connections, { nodeID0, pinID0, nodeID1, pinID1 })

	print("CONNECTED: " .. self:GetNode(nodeID0):ToString(pinID0) .. " -> " .. self:GetNode(nodeID1):ToString(pinID1))

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

function meta:AddNode(nodeTypeName, ...)

	local nodeType = self:GetNodeTypes()[nodeTypeName]
	if nodeType.type == NT_Event and nodeType.returns then
		self.module:RequestGraphForEvent(nodeType)
		return
	end

	local node = self.nodeConstructor(nodeTypeName, ...)
	return self.nodes:Add( node )

end

function meta:RemoveConnectionID(id)

	local c = self.connections[id]
	if c ~= nil then
		table.remove(self.connections, id)
		self:WalkInforms()
		self:FireListeners(CB_CONNECTION_REMOVE, id, c)
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
			table.insert(insert, {c[3],c[4]})
			self:RemoveConnectionID(i)
		elseif c[3] == nodeID then --input
			input = {c[1],c[2]}
			self:RemoveConnectionID(i)
		end

	end	

	if input == nil then print("Reroute node did not have input connection") return end

	for _, c in pairs(insert) do
		if not self:ConnectNodes(input[1], input[2], c[1], c[2]) then 
			error("Unable to reconnect re-route nodes: " .. 
				self:NodePinToString(input[1], input[2]) .. " -> " .. 
				self:NodePinToString(c[1], c[2])) 
		end
	end

	self:RemoveNode( nodeID )

end

function meta:CollapseRerouteNodes()

	for _, node in self:Nodes(true) do
		if node:GetType().collapse then
			self:CollapseSingleRerouteNode( node.id )
		end
	end	

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
			local connnectionMeta = {}
			for id, c in self:Connections(true) do

				local n0 = self:GetNode(c[1])
				local n1 = self:GetNode(c[3])
				local pin0 = n0:GetPins()[c[2]]
				local pin1 = n1:GetPins()[c[4]]
				connnectionMeta[id] = {n0:GetTypeName(), pin0:GetName(), n1:GetTypeName(), pin1:GetName()}

			end

			bpdata.WriteValue( connnectionMeta, stream )
		end

	end)

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

			self.connectionMeta = bpdata.ReadValue( stream )

		end

	end)

end

function meta:ResolveConnectionMeta()

	if self.connectionMeta ~= nil then

		for _, c in pairs(self.connectionMeta) do
			local rdir = NodePinRedirectors[c[1]]
			if rdir then c[2] = rdir[c[2]] or c[2] end
			local rdir = NodePinRedirectors[c[3]]
			if rdir then c[4] = rdir[c[4]] or c[4] end
		end

		print("Resolving connection meta...")
		for i, c in self:Connections(true) do
			local meta = self.connectionMeta[i]
			local nt0 = self:GetNode(c[1])
			local nt1 = self:GetNode(c[3])
			local pin0 = nt0:GetPin(c[2])
			local pin1 = nt1:GetPin(c[4])

			meta[2] = nt0:RemapPin(meta[2])
			meta[4] = nt1:RemapPin(meta[4])

			--print("Check Connection: " .. nt0:ToString(c[2]) .. " -> " .. nt1:ToString(c[4]))

			if meta == nil then continue end
			if pin0 == nil or pin0:GetName():lower() ~= meta[2]:lower() then
				MsgC( Color(255,100,100), " -Pin[OUT] not valid: " .. c[2] .. ", was " .. meta[1] .. "." .. meta[2] .. ", resolving...")
				c[2] = nt0:FindPin( PD_Out, meta[2] )
				MsgC( c[2] ~= nil and Color(100,255,100) or Color(255,100,100), c[2] ~= nil and " Resolved\n" or " Not resolved\n" )
			end

			if pin1 == nil or pin1:GetName():lower() ~= meta[4]:lower() then
				MsgC( Color(255,100,100), " -Pin[IN] not valid: " .. c[4] .. ", was " .. meta[3] .. "." .. meta[4] .. ", resolving...")
				c[4] = nt0:FindPin( PD_In, meta[4] )
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
			self:FireListeners(CB_CONNECTION_ADD, connection, i)
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

		-- Deep copy will copy all members including graph which includes module etc...
		-- So clear graph variable and set it on the other side of the deep copy
		for _, node in self:Nodes() do node.graph = nil end

		Profile("copy-nodes", self.nodes.CopyInto, self.nodes, other.nodes, true )
		Profile("copy-inputs", self.inputs.CopyInto, self.inputs, other.inputs, true )
		Profile("copy-outputs", self.outputs.CopyInto, self.outputs, other.outputs, true )

		for _, node in other:Nodes() do node.graph = other tostring(other) end
		for _, node in self:Nodes() do node.graph = self end

		for _, c in self:Connections() do
			table.insert(other.connections, {c[1], c[2], c[3], c[4]})
		end

	end)

	return other

end

function meta:CreateTestGraph()

	local graph = self
	local n1 = graph:AddNode("If", 700, 10)
	local n2 = graph:AddNode("Crouching", 350, 150 )
	local n4 = graph:AddNode("SetVelocity", 1000, 100)
	local n5 = graph:AddNode("Vector", 750, 200, {0,0,800})
	local n6 = graph:AddNode("Alive", 350, 350)
	local n7 = graph:AddNode("And", 600, 300)
	local n8 = graph:AddNode("ToString", 650, 500)
	local n9 = graph:AddNode("Print", 1000, 500)
	local n10 = graph:AddNode("PlayerTick", 10, 10)
	local n11 = graph:AddNode("GetVelocity", 350, 500)

	graph:ConnectNodes(n10, 1, n1, 1)
	graph:ConnectNodes(n10, 2, n2, 1)
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