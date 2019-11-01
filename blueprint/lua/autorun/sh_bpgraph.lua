AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")
include("sh_bplist.lua")
include("sh_bpnode.lua")

module("bpgraph", package.seeall, bpcommon.rescope(bpschema, bpnodedef)) --bpnodedef is temporary

bpcommon.CallbackList({
	"NODE_ADD",
	"NODE_REMOVE",
	"NODE_MOVE",
	"PIN_EDITLITERAL",
	"CONNECTION_ADD",
	"CONNECTION_REMOVE",
	"GRAPH_CLEAR",
	"PREMODIFY_NODETYPE",
	"POSTMODIFY_NODETYPE",
})

NODETYPE_MODIFY_RENAME = 1
NODETYPE_MODIFY_SIGNATURE = 2

FL_NONE = 0
FL_LOCK_PINS = 1
FL_LOCK_NAME = 2
FL_HOOK = 4

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
			self.module:PreModifyNodeType( "__Call" .. self.id, NODETYPE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType("__Entry", NODETYPE_MODIFY_SIGNATURE, action)
			self:PreModifyNodeType("__Exit", NODETYPE_MODIFY_SIGNATURE, action)
		elseif cb == bplist.CB_POSTMODIFY then
			self.module:PostModifyNodeType( "__Call" .. self.id, NODETYPE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Entry", NODETYPE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Exit", NODETYPE_MODIFY_SIGNATURE, action )
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	self.outputs:AddListener(function(cb, action, id, var)

		if cb == bplist.CB_PREMODIFY then
			self.module:PreModifyNodeType( "__Call" .. self.id, NODETYPE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType("__Entry", NODETYPE_MODIFY_SIGNATURE, action )
			self:PreModifyNodeType("__Exit", NODETYPE_MODIFY_SIGNATURE, action )
		elseif cb == bplist.CB_POSTMODIFY then
			self.module:PostModifyNodeType( "__Call" .. self.id, NODETYPE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Entry", NODETYPE_MODIFY_SIGNATURE, action )
			self:PostModifyNodeType("__Exit", NODETYPE_MODIFY_SIGNATURE, action )
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

function meta:PreModifyNodeType( nodeType, action, subaction )

	self:FireListeners(CB_PREMODIFY_NODETYPE, nodeType, action)

	if action == NODETYPE_MODIFY_SIGNATURE and subaction ~= bplist.MODIFY_RENAME then

		self.heldConnections[nodeType] = {}
		local held = self.heldConnections[nodeType]
		local ntype = self:GetNodeTypes()[nodeType]
		if ntype == nil then return end

		for id, node in self:Nodes() do
			if node.nodeType ~= nodeType then continue end

			for i, c in self:Connections() do

				if c[1] == id then --output
					local pin = ntype.pins[c[2]]
					self:RemoveConnectionID(i)
					table.insert(held, {id, pin[1], pin[3], c[3], c[4]})
				elseif c[3] == id then --input
					local pin = ntype.pins[c[4]]
					self:RemoveConnectionID(i)
					table.insert(held, {id, pin[1], pin[3], c[1], c[2]})
				end

			end

		end

	end

end

function meta:PostModifyNodeType( nodeType, action, subaction )

	self:CacheNodeTypes()
	self:FireListeners(CB_POSTMODIFY_NODETYPE, nodeType, action)

	if action == NODETYPE_MODIFY_SIGNATURE and subaction ~= bplist.MODIFY_RENAME then

		local ntype = self:GetNodeTypes()[nodeType]
		local held = self.heldConnections[nodeType]
		if ntype == nil then return end
		if held == nil then return end

		local function findPin( dir, name )
			for i=1, #ntype.pins do
				if ntype.pins[i][1] == dir and ntype.pins[i][3] == name then return i end
			end
			return nil
		end

		for _, c in pairs(held) do

			local pinID = findPin( c[2], c[3] )
			if pinID then
				self:ConnectNodes(c[1], pinID, c[4], c[5])
			else
				print("Couldn't find pin: " .. tostring(c[3]))
			end

		end

		self.heldConnections[nodeType] = nil

	end

end

function meta:PreModify(action, subaction)

	if action == bpmodule.GRAPH_MODIFY_RENAME then
		self:PreModifyNodeType("__Entry", NODETYPE_MODIFY_RENAME, subaction)
		self:PreModifyNodeType("__Exit", NODETYPE_MODIFY_RENAME, subaction)
	end

end

function meta:PostModify(action, subaction)

	if action == bpmodule.GRAPH_MODIFY_RENAME then
		self:PostModifyNodeType("__Entry", NODETYPE_MODIFY_RENAME, subaction)
		self:PostModifyNodeType("__Exit", NODETYPE_MODIFY_RENAME, subaction)
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
	}

end

function meta:CacheNodeTypes()

	self.__cachedTypes = nil
	self.__cachedTypes = self:GetNodeTypes()

end

function meta:CreateFunctionNodeTypes( output )

	local inPins = { { PD_Out, PN_Exec, "Exec" } }
	local outPins = { { PD_In, PN_Exec, "Exec" } }

	for id, var in self.inputs:Items() do table.insert(inPins, var:CreatePin( PD_Out )) end
	for id, var in self.outputs:Items() do table.insert(outPins, var:CreatePin( PD_In )) end

	output["__Entry"] = FUNC_INPUT {
		pins = inPins,
		displayName = self:GetName(),
		name = "__Entry",
		noDelete = true,
	}

	output["__Exit"] = FUNC_OUTPUT {
		pins = outPins,
		displayName = "Return",
		name = "__Exit",
	}

end

function meta:GetNodeTypes()

	if self.__cachedTypes then return self.__cachedTypes end

	local types = {}
	local base = self:GetModule():GetNodeTypes( self.id )

	table.Merge(types, base)
	self:CreateFunctionNodeTypes(types)

	-- blacklist invalid types in function graphs
	if self.type == GT_Function then
		for k, v in pairs(types) do
			if v.latent then types[k] = nil end
			if v.type == NT_Event then types[k] = nil end
		end
	end

	return types

end

function meta:GetNodeType(node)

	if node == nil then error("Tried to get nodetype of nil") end

	local types = self:GetNodeTypes()
	return types[ node.nodeType ]

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

function meta:GetPinType(nodeID, pinID)

	local ntype = self:GetNode(nodeID):GetType()

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

	return ntype.pins[pinID][2], ntype.pins[pinID][5]

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

function meta:CheckConversion(pin0, pin1)

	if pin0[2] == PN_Ref and pin1[2] == PN_Ref then
		if pin0[5] == "Player" and pin1[5] == "Entity" then
			return true
		end
		if pin0[5] == "Entity" and pin1[5] == "Player" then
			return true
		end
	end

	local cv = NodePinImplicitConversions[pin0[2]]
	if cv then
		for k,v in pairs(cv) do
			if type(v) == "table" then
				if v[1] == pin1[2] and v[2] == pin1[5] then return true end
			else
				if v == pin1[2] then return true end
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

	if p0[2] == PN_Exec and self:IsPinConnected(nodeID0, pinID0) then return false, "Only one connection outgoing for exec pins" end
	if p1[2] ~= PN_Exec and self:IsPinConnected(nodeID1, pinID1) then return false, "Only one connection for inputs" end

	if p0[1] == p1[1] then return false, "Can't connect " .. (p0[1] == PD_Out and "m/m" or "f/f") .. " pins" end
	if bit.band(p0[4], PNF_Table) ~= bit.band(p1[4], PNF_Table) then return false, "Can't connect table to non-table pin" end

	local p0Type = p0[2]
	local p1Type = p1[2]
	if (p0Type ~= p1Type) or (p0Type == PN_Ref and p0[5] ~= p1[5]) then

		if p0Type == PN_Any and p1Type ~= PN_Exec then return true end
		if p1Type == PN_Any and p0Type ~= PN_Exec then return true end

		-- Does not work properly, take into account pin directions to determine what conversion is being attempted
		-- Maybe rectify pin ordering so pin0 is always PD_Out, and pin1 is always PD_In
		if self:CheckConversion(p0, p1) or self:CheckConversion(p1, p0) then
			return true
		else
			return false, "No explicit conversion between " .. self:NodePinToString(nodeID0, pinID0) .. " and " .. self:NodePinToString(nodeID1, pinID1)
		end

	end

	if p0[5] ~= p1[5] then return false, "Can't connect " .. self:NodePinToString(nodeID0, pinID0) .. " to " .. self:NodePinToString(nodeID1, pinID1) end

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

function meta:GetPinLiteral(nodeID, pinID)

	local node = self:GetNode(nodeID)
	return node:GetLiteral(pinID)

end

function meta:SetPinLiteral(nodeID, pinID, value)

	local node = self:GetNode(nodeID)
	if node == nil then error("Tried to set literal on null node") end

	node:SetLiteral(pinID, value)

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

function meta:MoveNode(nodeID, x, y)

	self:GetNode(nodeID):Move(x,y)

end

function meta:RemoveConnectionID(id)

	local c = self.connections[id]
	if c ~= nil then
		table.remove(self.connections, id)
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
		if not self:GetNode(c[1]) or not self:GetNode(c[3]) then
			print("Removed invalid connection: " .. i)
			table.remove(connections, i)
		end

	end	

end

function meta:CollapseSingleRerouteNode(nodeID)

	local node = self:GetNode( nodeID )

	--print("COLLAPSING REROUTE NODE: " .. nodeID)

	local insert = {}
	local connections = self.connections
	local input = nil
	for i, c in self:Connections() do

		if c[1] == nodeID then --output
			--print(" -output on " .. c[2] .. " => " .. c[3] .. "[" .. c[4] .. "]")
			table.insert(insert, {c[3],c[4]})
			self:RemoveConnectionID(i)
		elseif c[3] == nodeID then --input
			--print(" -input on " .. c[4] .. " <= " .. c[1] .. "[" .. c[2] .. "]")
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
		if self:GetNodeType(node).collapse then
			self:CollapseSingleRerouteNode( node.id )
		end
	end	

end

function meta:WriteToStream(stream, mode, version)

	local namelookup = {}
	local nametable = {}
	local nodeentries = {}

	stream:WriteInt( self.type, false )
	stream:WriteInt( self.flags, false )

	if self.type == GT_Function then
		self.inputs:WriteToStream(stream, mode, version)
		self.outputs:WriteToStream(stream, mode, version)
	end

	self.nodes:WriteToStream(stream, mode, version)

	bpdata.WriteValue( self.connections, stream )

	if version >= 5 then

		if mode == bpmodule.STREAM_FILE then
			local connnectionMeta = {}
			for id, c in self:Connections(true) do

				local nt0 = self:GetNodeType(self:GetNode(c[1]))
				local nt1 = self:GetNodeType(self:GetNode(c[3]))
				local pin0 = nt0.pins[c[2]]
				local pin1 = nt1.pins[c[4]]
				connnectionMeta[id] = {nt0.name, pin0[3], nt1.name, pin1[3]}

			end

			bpdata.WriteValue( connnectionMeta, stream )
		end

	end

end

function meta:ReadFromStream(stream, mode, version)

	self:Clear()

	if version >= 3 then
		self.type = stream:ReadInt( false )
	else
		self.type = GT_Event
	end

	if version >= 10 then self.flags = stream:ReadInt( false ) end

	if self.type == GT_Function then
		if version >= 7 then
			self.inputs:ReadFromStream(stream, mode, version)
			self.outputs:ReadFromStream(stream, mode, version)
		else
			local numInputs = stream:ReadInt( false )
			local numOutputs = stream:ReadInt( false )
			for i=1, numInputs do
				local v = bpvariable.New()
				v:ReadFromStream( stream, mode, version )
				self.inputs:Add(v)
			end
			for i=1, numOutputs do
				local v = bpvariable.New()
				v:ReadFromStream( stream, mode, version )
				self.outputs:Add(v)
			end
		end
	end

	if version >= 7 then
		self.deferredNodes:ReadFromStream(stream, mode, version)
	else
		local nametable = {}
		local count = stream:ReadInt( false )
		for i=1, count do 
			local size = stream:ReadByte( false ) 
			table.insert(nametable, stream:ReadStr( size ) )
		end

		self.deferred = {}

		local count = stream:ReadInt( false )
		for i=1, count do

			local nodeTypeName = nametable[stream:ReadInt( false )]
			local nodeX = stream:ReadFloat()
			local nodeY = stream:ReadFloat()
			local literals = bpdata.ReadValue( stream )
			local redirect = NodeRedirectors[ nodeTypeName ]
			if redirect then nodeTypeName = redirect end

			table.insert(self.deferred, {
				nodeType = nodeTypeName,
				x = nodeX,
				y = nodeY,
				literals = literals,
			})

		end
	end

	self.connections = bpdata.ReadValue( stream )

	if version >= 5 then

		if mode == bpmodule.STREAM_FILE then

			self.connectionMeta = bpdata.ReadValue( stream )

		end

	end

end

function meta:RemapNodeTypes( func )

	if self.deferred then
		for _, node in pairs(self.deferred) do
			node.nodeType = func(node.nodeType)
		end
	else
		for id, node in self:Nodes() do
			node.nodeType = func(node.nodeType)
		end
	end

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
			local nt0 = self:GetNodeType(self:GetNode(c[1]))
			local nt1 = self:GetNodeType(self:GetNode(c[3]))
			local pin0 = nt0.pins[c[2]]
			local pin1 = nt1.pins[c[4]]

			if meta == nil then continue end
			if pin0 == nil or pin0[3]:lower() ~= meta[2]:lower() then
				MsgC( Color(255,100,100), " -Pin[OUT] not valid: " .. c[2] .. ", was " .. meta[1] .. "." .. meta[2] .. ", resolving...")
				c[2] = nil
				for k, p in pairs(nt0.pins) do
					if p[1] == PD_Out and p[3]:lower() == meta[2]:lower() then c[2] = k break end
				end
				MsgC( c[2] ~= nil and Color(100,255,100) or Color(255,100,100), c[2] ~= nil and " Resolved\n" or " Not resolved\n" )
			end

			if pin1 == nil or pin1[3]:lower() ~= meta[4]:lower() then
				MsgC( Color(255,100,100), " -Pin[IN] not valid: " .. c[4] .. ", was " .. meta[3] .. "." .. meta[4] .. ", resolving...")
				c[4] = nil
				for k, p in pairs(nt0.pins) do
					if p[1] == PD_In and p[3]:lower() == meta[4]:lower() then c[4] = k break end
				end
				MsgC( c[4] ~= nil and Color(100,255,100) or Color(255,100,100), c[4] ~= nil and " Resolved\n" or " Not resolved\n" )
			end
		end
		self.connectionMeta = nil
	end

end

function meta:CreateDeferredData()

	--print("CREATE DEFERRED NODES: " .. #self.deferred)

	self.deferredNodes:CopyInto(self.nodes)
	self.deferredNodes:Clear()

	self:CacheNodeTypes()

	if self.deferred then

		self:SuppressEvents( true )

		for _, v in pairs(self.deferred) do

			local id = self:AddNode( v.nodeType, v.x, v.y )
			if id ~= nil then
				for k, v in pairs(v.literals) do
					--print("LOAD LITERAL[" .. id .. "|" .. nodeTypeName .. "]: " .. tostring(k) .. " = " .. tostring(v))
					self:SetPinLiteral( id, k, v )
				end
			end

		end

		self:SuppressEvents( false )

		for id, node in self:Nodes() do
			local nodeType = self:GetNodeType(node) --TODO create impromptu nodetypes for missing nodes to satisfy connections
			if nodeType ~= nil then
				self:FireListeners(CB_NODE_ADD, id)
			end
		end

		self.deferred = nil

	else

		for id, node in self:Nodes() do
			if node:PostInit() then self:FireListeners(CB_NODE_ADD, id) end
		end

		self:RemoveNodeIf( function(node) return node:GetType() == nil end )

	end

	self:ResolveConnectionMeta()
	self:RemoveInvalidConnections()
	for i, connection in self:Connections() do
		self:FireListeners(CB_CONNECTION_ADD, connection, i)
	end

end

-- Quickly banging this out using existing tech
function meta:CopyInto(other)

	other:Clear()
	other.module = self.module
	other.id = self.id
	other.name = self.name
	other.type = self.type
	other.flags = self.flags

	self.nodes:CopyInto( other.nodes, true )
	self.inputs:CopyInto( other.inputs, true )
	self.outputs:CopyInto( other.outputs, true )

	for _, c in self:Connections() do
		table.insert(other.connections, {c[1], c[2], c[3], c[4]})
	end

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