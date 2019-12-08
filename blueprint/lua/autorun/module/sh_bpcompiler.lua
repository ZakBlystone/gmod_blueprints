AddCSLuaFile()

module("bpcompiler", package.seeall, bpcommon.rescope(bpschema, bpcommon))

CF_None = 0
CF_Standalone = 1
CF_Comments = 2
CF_Debug = 4
CF_ILP = 8
CF_CodeString = 16

CF_Default = bit.bor(CF_Comments, CF_Debug, CF_ILP)

-- Context prefixes, a context stores lines of code
local CTX_SingleNode = "singlenode_"
local CTX_FunctionNode = "functionnode_"
local CTX_Graph = "graph_"
local CTX_JumpTable = "jumptable_"
local CTX_MetaTables = "metatables_"
local CTX_Vars = "vars_"
local CTX_Code = "code"
local CTX_MetaEvents = "metaevents_"
local CTX_Hooks = "hooks_"

local meta = bpcommon.MetaTable("bpcompiler")

function meta:Init( mod, flags )

	self.flags = flags or CF_Default
	self.module = mod
	self.indent = 0

	-- context control functions
	self.pushIndent = function() self.indent = self.indent + 1 end
	self.popIndent = function() self.indent = self.indent - 1 end
	self.begin = function(ctx)
		self.current_context = ctx
		self.buffer = {}
	end
	self.emit = function(text)
		if self.indent ~= 0 then text = string.rep("\t", self.indent) .. text end
		table.insert(self.buffer, text)
	end
	self.emitBlock = function(text)
		local lines = string.Explode("\n", text)
		local minIndent = nil
		for _, line in pairs(lines) do
			local _, num = string.find(line, "\t+")
			if num then minIndent = math.min(num, minIndent or 10) else minIndent = 0 end
		end
		local commonIndent = "^" .. string.rep("\t", minIndent)
		for k, line in pairs(lines) do
			line = minIndent == 0 and line or line:gsub(commonIndent, "")
			if line ~= "" or k ~= #lines then self.emit(line) end
		end
	end
	self.emitIndented = function(lines, tabcount)
		local t = string.rep("\t", tabcount or 0)
		for _, l in pairs(lines) do
			self.emit( t .. l )
		end
	end
	self.emitContext = function(context, tabcount)
		self.emitIndented( self.getContext( context ), tabcount )
	end
	self.finish = function()
		self.contexts[self.current_context] = self.buffer
		self.buffer = {}
		self.current_context = nil
	end
	self.getContext = function(ctx)
		if not self.contexts[ctx] then error("Compiler context not found: '" .. ctx .. "'") end
		return self.contexts[ctx]
	end
	self.getFilteredContexts = function(filter)
		local out = {}
		for k,v in pairs(self.contexts) do
			if string.find(k, filter) ~= nil then out[k] = v end
		end
		return out
	end

	return self

end

function meta:Setup()

	self.compiledNodes = {}
	self.graphs = {}
	self.vars = {}
	self.nodejumps = {}
	self.contexts = {}
	self.current_context = nil
	self.buffer = ""
	self.debug = bit.band(self.flags, CF_Debug) ~= 0
	self.debugcomments = bit.band(self.flags, CF_Comments) ~= 0
	self.ilp = bit.band(self.flags, CF_ILP) ~= 0
	self.ilpmax = 10000
	self.ilpmaxh = 4
	self.guidString = bpcommon.GUIDToString(self.module:GetUID(), true)

	return self

end

local codenames = {
	["!"] = "__CH~EX__",
	["@"] = "__CH~AT__",
	["%"] = "__CH~PE__",
	["$"] = "__CH~DO__",
	["^"] = "__CH~CA__",
	["#"] = "__CH~HA__",
	["\\n"] = "__CH~NL__",
}

local nodeTypeEnumerateData = {
	[NT_Pure] = { unique = false },
	[NT_Function] = { unique = true },
	[NT_Event] = { unique = true },
	[NT_Special] = { unique = true },
}

local function SanitizeString(str)

	local r = str:gsub("\\n", "__CH~NL__")
	r = r:gsub("\\", "\\\\")
	r = r:gsub("\"", "\\\"")
	r = r:gsub("[%%!@%^#]", function(x)
		return codenames[x] or "INVALID"
	end)
	return r

end

local function DesanitizeCodedString(str)

	for k,v in pairs(codenames) do
		str = str:gsub(v, k == "%" and "%%" or k)
	end
	return str

end

--[[
This function goes through all nodes of a certain type in the current graph and creates variable entries for them.
These variables are used to connect node outputs to inputs among other things

There are currently 3 types of vars:
	node-locals, return-values, and literals

Node-locals are internal variables scoped to a specific node.
The foreach node uses this to keep track of its iteration.

Return-values hold the output of non-pure function calls.

Literals are values stored on unconnected input pins.
]]

function meta:CreateFunctionGraphVars(uniqueKeys)

	local unique = uniqueKeys
	local name = self.graph:GetName()
	local key = bpcommon.CreateUniqueKey(unique, "func_" .. name .. "_returned")
	table.insert(self.vars, {
		var = key,
		type = PN_Bool,
		init = "false",
		node = nil,
		pin = nil,
		graph = self.graph.id,
		isFunc = true,
	})

	for nodeID, node in self.graph:Nodes() do
		local codeType = node:GetCodeType()
		if codeType == NT_FuncInput then

			for pinID, pin in node:SidePins(PD_Out) do
				local pinType = self.graph:GetPinType( nodeID, pinID )
				if pinType:IsType(PN_Exec) then continue end

				local pinName = pin:GetName()
				local key = bpcommon.CreateUniqueKey(unique, "func_" .. name .. "_in_" .. (pinName ~= "" and pinName or "pin"))
				--print(" " .. key)

				table.insert(self.vars, {
					var = key,
					init = pinType:GetDefault(),
					type = pinType,
					node = nodeID,
					pin = pinID,
					graph = self.graph.id,
					isFunc = true,
				})
			end

		elseif codeType == NT_FuncOutput then

			for pinID, pin in node:SidePins(PD_In) do
				local pinType = self.graph:GetPinType( nodeID, pinID )
				if pinType:IsType(PN_Exec) then continue end

				-- TODO, multiple return nodes access the same variables, make these graph-scope instead.
				local pinName = pin:GetName()
				local key = bpcommon.CreateUniqueKey({}, "func_" .. name .. "_out_" .. (pinName ~= "" and pinName or "pin"))

				if node.literals and node.literals[pinID] ~= nil then

					local l = tostring(node.literals[pinID])

					-- string literals need to be surrounded by quotes
					-- TODO: Sanitize these
					if pinType:IsType(PN_String) then l = "\"" .. SanitizeString(l) .. "\"" end

					table.insert(self.vars, {
						var = l,
						type = pinType,
						literal = true,
						node = nodeID,
						pin = pinID,
						graph = self.graph.id,
						isFunc = true,
					})

				end

				table.insert(self.vars, {
					var = key,
					init = pinType:GetDefault(),
					type = pinType,
					node = nodeID,
					pin = pinID,
					graph = self.graph.id,
					output = true,
					isFunc = true,
				})
			end

		end
	end

end

function meta:EnumerateGraphVars(uniqueKeys)

	local localScopeUnique = {}
	for nodeID, node in self.graph:Nodes() do
		local codeType = node:GetCodeType()
		local e = nodeTypeEnumerateData[codeType]
		if not e then continue end

		local unique = e.unique and uniqueKeys or localScopeUnique

		-- some nodetypes have local variables exclusive to themselves
		for _, l in pairs(node:GetLocals()) do

			local key = bpcommon.CreateUniqueKey(unique, "local_" .. node:GetTypeName() .. "_v_" .. l)

			table.insert(self.vars, {
				var = key,
				localvar = l,
				node = nodeID,
				graph = self.graph.id,
			})

		end

		-- some nodetypes have local variables exclusive to themselves
		for _, l in pairs(node:GetGlobals()) do

			local key = bpcommon.CreateUniqueKey(unique, "local_" .. node:GetTypeName() .. "_v_" .. l)

			table.insert(self.vars, {
				var = key,
				localvar = l,
				node = nodeID,
				graph = self.graph.id,
				keyAsGlobal = true,
			})

		end

		-- unconnected pins can contain literals, make internal variables for them
		for pinID, pin in node:SidePins(PD_In) do
			local pinType = self.graph:GetPinType( nodeID, pinID )

			if node.literals and node.literals[pinID] ~= nil then

				local l = tostring(node.literals[pinID])

				-- string literals need to be surrounded by quotes
				-- TODO: Sanitize these
				if pinType:IsType(PN_String) then l = "\"" .. SanitizeString(l) .. "\"" end

				table.insert(self.vars, {
					var = l,
					type = pinType,
					literal = true,
					node = nodeID,
					pin = pinID,
					graph = self.graph.id,
				})

			end

		end

		-- output pins create local variables, if the function is non-pure, the variable is global
		for pinID, pin in node:SidePins(PD_Out) do
			local pinType = self.graph:GetPinType( nodeID, pinID )

			if pinType:IsType(PN_Exec) then continue end

			local pinName = pin:GetName()
			local key = bpcommon.CreateUniqueKey(unique, "fcall_" .. node:GetTypeName() .. "_ret_" .. (pinName ~= "" and pinName or "pin"))

			table.insert(self.vars, {
				var = key,
				type = pinType,
				init = pinType:GetDefault(),
				global = codeType ~= NT_Pure,
				node = nodeID,
				pin = pinID,
				graph = self.graph.id,
			})

		end
	end

end

-- find a node-local variable by name for a given node
function meta:FindLocalVarForNode(nodeID, vname)

	for k,v in pairs(self.vars) do

		if not v.localvar then continue end
		if v.graph ~= self.graph.id then continue end
		if v.node == nodeID and v.localvar == vname then return v end

	end

end

-- find the variable that is assigned to the given node/pin
function meta:FindVarForPin(nodeID, pinID, noLiteral)

	for k,v in pairs(self.vars) do

		if v.literal == true and noLiteral then continue end
		if v.localvar then continue end
		if v.graph ~= self.graph.id then continue end
		if v.node == nodeID and v.pin == pinID then return v end

	end

end

-- basically just adds a self prefix for global variables to scope them into the module
function meta:GetVarCode(var, jump)

	if var == nil then
		error("Failed to get var for " .. self.currentNode:ToString() .. " ``" .. self.currentCode .. "``" )
	end

	local s = ""
	if jump and var.jump then s = "goto jmp_" end
	if var.literal then return s .. var.var end
	if var.global or var.isFunc or var.keyAsGlobal then return "__self." .. var.var end
	return s .. var.var

end

-- returns all connections to a given node's pin
function meta:GetPinConnections(pinDir, nodeID, pinID)

	local out = {}
	for k, v in self.graph:Connections() do
		if pinDir == PD_In and (v[3] ~= nodeID or v[4] ~= pinID) then continue end
		if pinDir == PD_Out and (v[1] ~= nodeID or v[2] ~= pinID) then continue end
		table.insert(out, v)
	end
	return out

end

-- finds or creates a jump table for the current graph
function meta:GetGraphJumpTable()

	local graphID = self.graph.id
	self.nodejumps[graphID] = self.nodejumps[graphID] or {}
	return self.nodejumps[graphID]

end

-- replaces meta-code in the node type (see top of defspec.txt) with references to actual variables
function meta:CompileVars(code, inVars, outVars, nodeID)

	local str = code
	local node = self.graph:GetNode(nodeID)
	local inBase = 0
	local outBase = 0

	self.currentNode = node
	self.currentCode = str

	if node:GetCodeType() == NT_Function then
		inBase = 1
		outBase = 1
	end

	-- replace macros
	str = string.Replace( str, "@graph", "graph_" .. self.graph.id .. "_entry" )
	str = string.Replace( str, "!node", tostring(nodeID))
	str = string.Replace( str, "!graph", tostring(self.graph.id))
	str = string.Replace( str, "!module", tostring(self.guidString))

	-- replace input pin codes
	str = str:gsub("$(%d+)", function(x) return self:GetVarCode(inVars[tonumber(x) + inBase]) end)

	-- replace output pin codes
	str = str:gsub("#_(%d+)", function(x) return self:GetVarCode(outVars[tonumber(x) + outBase]) end)
	str = str:gsub("#(%d+)", function(x) return self:GetVarCode(outVars[tonumber(x) + outBase], true) end)

	local lmap = {}
	for k,v in pairs(node:GetLocals()) do
		local var = self:FindLocalVarForNode(nodeID, v)
		if var == nil then error("Failed to find internal variable: " .. tostring(v)) end
		lmap[v] = var
	end

	for k,v in pairs(node:GetGlobals()) do
		local var = self:FindLocalVarForNode(nodeID, v)
		if var == nil then error("Failed to find internal variable: " .. tostring(v)) end
		lmap[v] = var
	end

	str = str:gsub("%%([%w_]+)", function(x)
		if not lmap[x] then error("FAILED TO FIND LOCAL: " .. tostring(x)) end
		return self:GetVarCode(lmap[x]) end
	)

	-- replace jumps
	local jumpTable = self:GetGraphJumpTable()[nodeID] or {}
	str = str:gsub("%^_([%w_]+)", function(x) return tostring(jumpTable[x]) end)
	str = str:gsub("%^([%w_]+)", function(x) return "jmp_" .. jumpTable[x] end)
	str = DesanitizeCodedString(str)

	if node:GetCodeType() == NT_Function then
		str = str .. "\n" .. self:GetVarCode(outVars[1], true)
	end

	return str

end

-- compiles a single node
function meta:CompileNodeSingle(nodeID)

	local node = self.graph:GetNode(nodeID)
	local code = node:GetCode()
	local codeType = node:GetCodeType()
	local graphThunk = node:GetGraphThunk()

	self.currentNode = node
	self.currentCode = str

	-- TODO: Instead of building these strings, find a more direct approach of compiling these
	-- generate code based on function graph inputs and outputs
	if graphThunk ~= nil then
		local target = self.module:GetGraph( graphThunk )
		--print("---------------GRAPH THUNK: " .. ntype.graphThunk .. "---------------------------")
		code = ""
		local n = target.outputs:Size()
		for i=1, n do
			code = code .. "#" .. i .. (i~=n and ", " or " ")
		end
		if n ~= 0 then code = code .. "= " end
		code = code .. "__self:" .. target:GetName() .. "("
		local n = target.inputs:Size()
		for i=1, n do
			code = code .. "$" .. i .. (i~=n and ", " or "")
		end
		code = code .. ")"
		--print(code)
	end

	-- tie function input pins
	if codeType == NT_FuncInput then
		code = ""
		local ipin = 2
		for k, v in node:SidePins(PD_Out) do
			if v:IsType(PN_Exec) then continue end
			code = code .. "#" .. k .. " = arg[" .. ipin-1 .. "]\n"
			ipin = ipin + 1
		end

		if code:len() > 0 then code = code:sub(0, -2) end
	end

	if codeType == NT_FuncOutput then
		code = ""
		local ipin = 2
		for k, v in node:SidePins(PD_In) do
			if v:IsType(PN_Exec) then continue end
			code = code .. "#" .. k .. " = $" .. k .. "\n"
			ipin = ipin + 1
		end

		local ret = self:FindVarForPin(nil, nil, true)
		code = code .. self:GetVarCode(ret) .. " = true\n"
		code = code .. "goto __terminus\n"

		if code:len() > 0 then code = code:sub(0, -2) end
	end

	if not code then
		ErrorNoHalt("No code for node: " .. node:ToString() .. "\n")
		return
	end

	-- the context to emit (singlenode_graph#_node#)
	self.begin(CTX_SingleNode .. self.graph.id .. "_" .. nodeID)

	-- list of inputs/outputs to compile
	local inVars = {}
	local outVars = {}

	-- iterate through all input pins
	for pinID, pin, pos in node:SidePins(PD_In) do
		local pinType = self.graph:GetPinType( nodeID, pinID )
		if pinType:IsType(PN_Exec) then continue end

		if codeType == NT_FuncOutput then
			outVars[pos] = self:FindVarForPin(nodeID, pinID, true)
		end


		-- iterate through all of this pin's connections, and find variables on the pins it's connected to.
		local connections = self:GetPinConnections(PD_In, nodeID, pinID)
		for _, v in pairs(connections) do

			local var = self:FindVarForPin(v[1], v[2])
			if var then
				inVars[pos] = var
			else
				error("COULDN'T FIND INPUT VAR FOR " .. node:ToString(pinID))
			end

		end

		-- if there are no connections, try to assign literals on this pin
		if #connections == 0 then

			local literalVar = self:FindVarForPin(nodeID, pinID)
			if literalVar ~= nil then
				inVars[pos] = literalVar
			else
				-- unconnected nullable pins just have their value set to nil
				local nullable = pin:HasFlag(PNF_Nullable)
				if nullable then
					inVars[pos] = { var = "nil" }
				else
					error("Pin must be connected: " .. node:ToString(pinID))
				end
			end
		end

	end

	-- iterate through all output pins
	for pinID, pin, pos in node:SidePins(PD_Out) do
		
		local pinType = self.graph:GetPinType( nodeID, pinID )
		local connections = self:GetPinConnections(PD_Out, nodeID, pinID)
		if codeType == NT_Event then

			-- assign return values for all event pins
			outVars[pos] = self:FindVarForPin(nodeID, pinID)
			--if outVars[lookupID] ~= nil then PrintTable(outVars[lookupID]) end

		else

			if pinType:IsType(PN_Exec) then

				-- unconnect exec pins jump to ::jmp_0:: which just pops the stack
				outVars[pos] = {
					var = #connections == 0 and "0" or connections[1][3],
					jump = true,
				}

			else

				-- find output variable to write to on this pin
				local var = self:FindVarForPin(nodeID, pinID)
				if var then 
					outVars[pos] = var
				else
					error("Unable to find var for pin " .. node:ToString(pinID))
				end

			end

		end

	end	

	-- grab code off node type and remove tabs
	code = string.Replace(code, "\t", "")

	-- take all the mapped variables and place them in the code string
	code = Profile("vct", self.CompileVars, self, code, inVars, outVars, nodeID)

	-- emit some infinite-loop-protection code
	if self.ilp and (codeType == NT_Function or codeType == NT_Special or codeType == NT_FuncOutput) then
		self.emit("__ilp = __ilp + 1 if __ilp > " .. self.ilpmax .. " then __ilptrip = true goto __terminus end")
	end

	-- and debugging info
	if self.debug then
		self.emit("__dbgnode = " .. nodeID)
	end

	-- break the code apart and emit each line
	for _, l in pairs(string.Explode("\n", code)) do
		self.emit(l)
	end

	self.finish()

end

-- given a non-pure function, walk back through the tree of pure nodes that contribute to its inputs
-- traversal order follows proceedural execution of nodes (inputs traversed, then node)
function meta:WalkBackPureNodes(nodeID, call)

	local max = 10000
	local stack = {}
	local output = {}

	table.insert(stack, nodeID)

	while #stack > 0 and max > 0 do

		max = max - 1

		local pnode = stack[#stack]
		table.remove(stack, #stack)

		for pinID, pin in self.graph:GetNode(pnode):SidePins(PD_In) do

			local connections = self:GetPinConnections(PD_In, pnode, pinID)
			for _, v in pairs(connections) do

				local node = self.graph:GetNode( v[1] )
				if node:GetCodeType() == NT_Pure then
					table.insert(stack, v[1])
					table.insert(output, v[1])
				end

			end

		end

	end

	if max == 0 then
		error("Infinite pure-node loop in graph")
	end

	for i=#output, 1, -1 do
		call(output[i])
	end

end

-- compiles a non-pure function by collapsing all connected pure nodes into it and emitting labels/jumps
function meta:CompileNodeFunction(nodeID)

	local node = self.graph:GetNode(nodeID)
	local codeType = node:GetCodeType()

	self.begin(CTX_FunctionNode .. self.graph.id .. "_" .. nodeID)
	if self.debugcomments then self.emit("-- " .. node:ToString()) end
	self.emit("::jmp_" .. nodeID .. "::")

	-- event nodes are really just jump stubs
	if codeType == NT_Event or codeType == NT_FuncInput then 

		for pinID, pin in node:SidePins(PD_Out) do
			local pinType = self.graph:GetPinType( nodeID, pinID )
			if not pinType:IsType(PN_Exec) then continue end

			-- get the exec pin's connection and jump to the node it's connected to
			local connection = self:GetPinConnections(PD_Out, nodeID, pinID)[1]
			if connection ~= nil then
				self.emit("\tgoto jmp_" .. connection[3])
				self.finish()
				return
			end
		end
		
		-- unconnected exec pins just pop the callstack
		self.emit("\tgoto popcall")
		self.finish()
		return

	end

	-- walk through all connected pure nodes, emit each node's code context once
	local emitted = {}
	self:WalkBackPureNodes(nodeID, function(pure)
		if emitted[pure] then return end
		emitted[pure] = true
		self.emitContext( CTX_SingleNode .. self.graph.id .. "_" .. pure, 1 )
	end)

	-- emit this non-pure node's code
	self.emitContext( CTX_SingleNode .. self.graph.id .. "_" .. nodeID, 1 )

	self.finish()

end

-- emits some boilerplate code for indexing gmod's metatables
function meta:CompileMetaTableLookup()

	self.begin(CTX_MetaTables)

	local tables = {}

	-- Collect all used types from module and write out the needed meta tables
	local types = self.module:GetUsedPinTypes(nil, true)
	for _, t in pairs(types) do

		local baseType = t:GetBaseType()
		if baseType == PN_Ref then

			local class = bpdefs.Get():GetClass(t)
			table.insert(tables, class.name)

		elseif baseType == PN_Struct then

			local struct = bpdefs.Get():GetStruct(t)
			local metaTable = struct and struct:GetMetaTable() or nil
			if metaTable then
				table.insert(tables, metaTable)
			end

		elseif baseType == PN_Vector then

			table.insert(tables, "Vector")

		elseif baseType == PN_Angles then

			table.insert(tables, "Angle")

		elseif baseType == PN_Color then

			table.insert(tables, "Color")

		end

	end

	-- Some nodes require access to additional metatables, process them here
	for _, graph in self.module:Graphs() do
		for _, node in graph:Nodes() do
			local rm = node:GetRequiredMeta()
			if not rm then continue end
			for _, m in pairs(rm) do
				if not table.HasValue(tables, m) then table.insert(tables, m) end
			end
		end
	end

	for k, v in pairs(tables) do
		self.emit("local " .. v ..  "_ = FindMetaTable(\"" .. v .. "\")")
	end

	self.finish()

end

-- lua doesn't have a switch/case construct, so build a massive 'if' bank to jump to each section of the code.
function meta:CompileGraphJumpTable()

	self.begin(CTX_JumpTable .. self.graph.id)

	local nextJumpID = 0

	-- jmp_0 just pops the call stack
	self.emit( "if ip == 0 then goto jmp_0 end" )

	-- emit jumps for all non-pure functions
	for id, node in self.graph:Nodes() do
		if node:GetCodeType() ~= NT_Pure then
			self.emit( "if ip == " .. id .. " then goto jmp_" .. id .. " end" )
		end
		nextJumpID = math.max(nextJumpID, id+1)
	end

	-- some nodes have internal jump symbols to control program flow (delay / sequence)
	-- create jump vectors for each of those
	local jumpTable = self:GetGraphJumpTable()
	for id, node in self.graph:Nodes() do
		for _, j in pairs(node:GetJumpSymbols()) do

			jumpTable[id] = jumpTable[id] or {}
			jumpTable[id][j] = nextJumpID
			self.emit( "if ip == " .. nextJumpID .. " then goto jmp_" .. nextJumpID .. " end" )
			nextJumpID = nextJumpID + 1

		end
	end

	self.finish()

end

-- builds global variable initializer code for module construction
function meta:CompileGlobalVarListing()

	self.begin(CTX_Vars .. "global")

	for k, v in pairs(self.vars) do
		if not v.literal and v.global then
			self.emit("instance." .. v.var .. " = nil")
		end
		if v.localvar and v.keyAsGlobal then
			self.emit("instance." .. v.var .. " = nil")
		end
	end

	for id, var in self.module:Variables() do
		local def = var.default
		if var:GetType() == PN_String and bit.band(var:GetFlags(), PNF_Table) == 0 then def = "\"\"" end
		self.emit("instance.__" .. var.name .. " = " .. tostring(def))
	end

	self.finish()

end

-- builds local variable initializer code for graph entry function
function meta:CompileGraphVarListing()

	self.begin(CTX_Vars .. self.graph.id)

	for k, v in pairs(self.vars) do
		if v.graph ~= self.graph.id then continue end
		if not v.literal and not v.global and not v.isFunc and not v.keyAsGlobal then
			self.emit("local " .. v.var .. " = nil")
		end
	end

	self.finish()

end

-- compiles the graph entry function
function meta:CompileGraphEntry()

	local graphID = self.graph.id

	self.begin(CTX_Graph .. graphID)

	-- graph function header and callstack
	self.emit("\nlocal function graph_" .. graphID .. "_entry( ip )\n")
	self.emit("\tlocal cs = {}")

	-- debugging info
	if self.debug then
		self.emit( "\t__dbggraph = " .. graphID)
	end

	-- emit graph-local variables
	self.emitContext( CTX_Vars .. graphID, 1 )

	-- emit jump table
	self.emit( "\tlocal function pushjmp(i) table.insert(cs, 1, i) end")
	self.emit( "\tgoto jumpto" )
	self.emit( "\n\t::jmp_0:: ::popcall::\n\tif #cs > 0 then ip = cs[1] table.remove(cs, 1) else goto __terminus end" )
	self.emit( "\n\t::jumpto::" )

	self.emitContext( CTX_JumpTable .. graphID, 1 )

	-- emit all functions belonging to this graph
	local code = self.getFilteredContexts( CTX_FunctionNode .. self.graph.id )
	for k, _ in pairs(code) do
		self.emitContext( k, 1 )
	end

	-- emit terminus jump vector
	self.emit("\n\t::__terminus::\n")
	self.emit("end")

	self.finish()

	--print(table.concat( self.getContext( CTX_Graph .. self.graph.id ), "\n" ))

end

-- glues all the code together
function meta:CompileCodeSegment()

	self.begin(CTX_Code)

	if bit.band(self.flags, CF_Standalone) ~= 0 then
		self.emit("AddCSLuaFile()")
	end

	--self.emit("if SERVER then util.AddNetworkString(\"bphandshake\") end")
	--self.emit("if SERVER then util.AddNetworkString(\"bpmessage\") end\n")

	self.emitContext( CTX_MetaTables )
	self.emit("local __guid = \"" .. bpcommon.GUIDToString(self.module:GetUID(), true) .. "\"")
	self.emit("local __self = nil")

	-- debugging and infinite-loop-protection
	if self.debug then
		self.emitBlock [[
		local __dbgnode = -1
		local __dbggraph = -1
		]]
	end

	if self.ilp then
		self.emitBlock [[
		local __ilptrip = false
		local __ilp = 0
		local __ilph = 0
		]]
	end

	-- __bpm is the module table, it contains utilities and listings for module functions
	self.emit("local __bpm = {}")

	-- emit each graph's entry function
	for id in self.module:GraphIDs() do
		self.emitContext( CTX_Graph .. id )
	end

	-- infinite-loop-protection checker
	if self.ilp then
		self.emitBlock ([[
		__bpm.checkilp = function()
			if __ilph > ]] .. self.ilpmaxh .. [[ then __bpm.onError("Infinite loop in hook", ]] .. self.module.id .. [[, __dbggraph or -1, __dbgnode or -1) return true end
			if __ilptrip then __bpm.onError("Infinite loop", ]] .. self.module.id .. [[, __dbggraph or -1, __dbgnode or -1) return true end
		end
		]])
	end

	-- metatable for the module
	self.emitBlock [[
	local meta = BLUEPRINT_OVERRIDE_META or {}
	if BLUEPRINT_OVERRIDE_META == nil then meta.__index = meta end
	__bpm.meta = meta
	__bpm.guid = __guid
	__bpm.hexBytes = function(str) return str:gsub("%w%w", function(x) return string.char(tonumber(x[1],16) * 16 + tonumber(x[2],16)) end) end
	__bpm.genericIsValid = function(x) return type(x) == 'number' or type(x) == 'boolean' or IsValid(x) end
	]]

	-- delay manager (so that delays can be cancelled when a module is unloaded)
	self.emitBlock [[
	__bpm.delayExists = function(key)
		for i=#__self.delays, 1, -1 do if __self.delays[i].key == key then return true end end
		return false
	end
	__bpm.delay = function(key, delay, func)
		for i=#__self.delays, 1, -1 do if __self.delays[i].key == key then table.remove(__self.delays, i) end end
		table.insert( __self.delays, { key = key, func = func, time = delay })
	end
	]]


	-- error management, allows for custom error handling with debug info about which node / graph the error happened in
	self.emit("__bpm.onError = function(msg, mod, graph, node) end")

	-- update function, runs delays and resets the ilp recursion value for hooks
	self.emit("function meta:update()")
	self.pushIndent()

	if self.ilp then self.emit("__ilph = 0") end
	self.emitBlock [[
	for i=#self.delays, 1, -1 do
		self.delays[i].time = self.delays[i].time - FrameTime()
		if self.delays[i].time <= 0 then
			local s,e = pcall(self.delays[i].func)
			if not s then self.delays = {} __bpm.onError(e:sub(e:find(':', 11)+2, -1), " .. self.module.id .. ", __dbggraph or -1, __dbgnode or -1) end
			table.remove(self.delays, i)
		end
	end
	]]

	self.popIndent()
	self.emit("end")

	-- emit all meta events (functions with graph entry points)
	for k, _ in pairs( self.getFilteredContexts(CTX_MetaEvents) ) do
		self.emitContext( k )
	end

	-- constructor
	self.emit("__bpm.new = function()")
	self.emit("\tlocal instance = setmetatable({}, meta)")
	self.emit("\tinstance.delays = {}")
	self.emit("\tinstance.__bpm = __bpm")
	if bit.band(self.flags, CF_Standalone) ~= 0 then
		self.emit("\tinstance.__guid = __guid")
	end
	self.emitContext( CTX_Vars .. "global", 1 )
	self.emit("\treturn instance")
	self.emit("end")

	-- event listing
	self.emit("__bpm.events = {")
	for k, _ in pairs( self.getFilteredContexts(CTX_Hooks) ) do
		self.emitContext( k, 1 )
	end
	self.emit("}")

	-- assign local to _G.__BPMODULE so we can grab it from RunString
	self.emit("__BPMODULE = __bpm")

	if bit.band(self.flags, CF_Standalone) ~= 0 then

		self.emitBlock [[
		local instance = __bpm.new()
		if instance.CORE_Init then instance:CORE_Init() end
		local bpm = instance.__bpm

		for k,v in pairs(bpm.events) do
			if not v.hook or type(meta[k]) ~= "function" then continue end
			local function call(...) return instance[k](instance, ...) end
			local key = "bphook_" .. instance.__guid
			hook.Add(v.hook, key, call)
		end
		]]

	end

	self.finish()

end

-- called on all graphs before main compile pass, generates all potentially shared data between graphs
function meta:PreCompileGraph(graph, uniqueKeys)

	self.graph = graph

	Profile("cache-node-types", function()
		self.graph:CacheNodeTypes()
	end)

	Profile("collapse-reroutes", function()
		self.graph:CollapseRerouteNodes()
	end)

	Profile("enumerate-graph-vars", function()

		-- 'uniqueKeys' is a table for keeping keys distinct, global variables must be distinct when each graph generates them.
		-- pure node variables do not need exclusive keys between graphs because they are local
		self:EnumerateGraphVars(uniqueKeys)

	end)

	if self.graph.type == GT_Function then
		Profile("create-function-vars", self.CreateFunctionGraphVars, self, uniqueKeys)
	end

	-- compile jump table and variable listing for this graph
	Profile("jump-table", self.CompileGraphJumpTable, self)
	Profile("var-listing", self.CompileGraphVarListing, self)

end

-- compiles a metamethod for a given event
function meta:CompileGraphMetaHook(graph, nodeID, name)

	local node = self.graph:GetNode(nodeID)

	self.currentNode = node
	self.currentCode = ""

	self.begin(CTX_MetaEvents .. name)

	self.emit("function meta:" .. name .. "(...)")
	self.pushIndent()

	-- build argument table and store reference to 'self'
	self.emit("local arg = {...}")
	self.emit("__self = self")

	-- emit the code for the event node
	self.emitContext( CTX_SingleNode .. self.graph.id .. "_" .. nodeID )

	-- infinite-loop-protection, prevents a loop case where an event calls a function which in turn calls the event.
	-- a counter is incremented and as recursion happens, the counter increases.
	if self.ilp then
		
		self.emitBlock [[
		if __bpm.checkilp() then return end
		__ilptrip = false
		__ilp = 0
		__ilph = __ilph + 1
		]]

	end

	if self.graph.type == GT_Function then
		self.emit(self:GetVarCode(self:FindVarForPin(nil, nil)) .. " = false")
	end

	-- protected call into graph entrypoint, calls error handler on error
	self.emit("local b,e = pcall(graph_" .. self.graph.id .. "_entry, " .. nodeID .. ")")
	self.emit("if not b then __bpm.onError(tostring(e), " .. self.module.id .. ", __dbggraph or -1, __dbgnode or -1) end")

	-- infinite-loop-protection, after calling the event the counter is decremented.
	if self.ilp then
		self.emit("if __bpm.checkilp() then return end")
		self.emit("__ilph = __ilph - 1")
	end

	if self.graph.type == GT_Function then
		self.emit("if " .. self:GetVarCode(self:FindVarForPin(nil, nil)) .. " == true then")
		self.emit("return")

		local out = {}

		local emitted = {}
		for k,v in pairs(self.vars) do
			if emitted[v.var] then continue end
			if v.graph == self.graph.id and v.isFunc and v.output then
				table.insert(out, v)
				emitted[v.var] = true
			end
		end

		for k, v in pairs(out) do
			self.emit("\t" .. self:GetVarCode(v) .. (k == #out and "" or ","))
		end

		self.emit("end")
	end

	self.popIndent()
	self.emit("end")

	self.finish()

end

-- compile a full graph
function meta:CompileGraph(graph)

	self.graph = graph

	-- compile each single-node context in the graph
	for id in self.graph:NodeIDs() do
		Profile("single-node", self.CompileNodeSingle, self, id)
	end

	-- compile all non-pure function nodes in the graph (and events / special nodes)
	for id, node in self.graph:Nodes() do
		if node:GetCodeType() ~= NT_Pure then
			Profile("functions", self.CompileNodeFunction, self, id)
		end
	end

	-- compile all events nodes in the graph
	for id, node in self.graph:Nodes() do
		local codeType = node:GetCodeType()
		if codeType == NT_Event then
			self:CompileGraphMetaHook(graph, id, node:GetTypeName())
		elseif codeType == NT_FuncInput then
			self:CompileGraphMetaHook(graph, id, graph:GetName())
		end
	end

	-- compile graph's entry function
	Profile("graph-entries", self.CompileGraphEntry, self)

	--print("COMPILING GRAPH: " .. graph:GetName() .. " [" .. graph:GetFlags() .. "]")

	-- compile hook listing for each event (only events that have hook designations)
	self.begin(CTX_Hooks .. self.graph.id)

	for id, node in self.graph:Nodes() do
		local codeType = node:GetCodeType()
		local hook = node:GetHook()
		if codeType == NT_Event and hook then

			self.emit("[\"" .. node:GetTypeName() .. "\"] = {")

			self.pushIndent()
			self.emit("hook = \"" .. hook .. "\",")
			self.emit("graphID = " .. self.graph.id .. ",")
			self.emit("nodeID = " .. id .. ",")
			self.emit("moduleID = " .. self.module.id .. ",")
			self.popIndent()
			--self.emit("\t\tfunc = nil,")

			self.emit("},")

		end
	end

	if graph:HasFlag(bpgraph.FL_HOOK) then
		self.emit("[\"" .. graph:GetName() .. "\"] = {")

		self.pushIndent()
		self.emit("hook = \"" .. graph:GetName() .. "\",")
		self.emit("graphID = " .. graph.id .. ",")
		self.emit("nodeID = -1,")
		self.emit("moduleID = " .. self.module.id .. ",")
		self.emit("key = \"__bphook_" .. self.module.id .. "\"")
		self.popIndent()
		--self.emit("\t\tfunc = nil,")

		self.emit("},")
	end

	self.finish()

end

function meta:Compile()

	print("COMPILING MODULE...")

	ProfileStart("bpcompiler:Compile")

	self:Setup()

	Profile("meta-lookup", self.CompileMetaTableLookup, self)
	Profile("copy-graphs", function()

		-- make local copies of all module graphs so they can be edited without changing the module
		for id, graph in self.module:Graphs() do
			table.insert( self.graphs, graph:CopyInto( bpgraph.New() ) )
		end

	end)

	-- pre-compile all graphs in the module
	-- each graph shares a unique key table to ensure global variable names are distinct
	local uniqueKeys = {}
	for _, graph in pairs( self.graphs ) do
		Profile("pregraph", self.PreCompileGraph, self, graph, uniqueKeys )
	end

	-- compile the global variable listing (contains all global variables accross all graphs)
	Profile( "global-var-listing", self.CompileGlobalVarListing, self)

	-- compile each graph
	for _, graph in pairs( self.graphs ) do
		Profile("graph", self.CompileGraph, self, graph )
	end

	-- compile main code segment
	Profile("code-segment", self.CompileCodeSegment, self)

	self.compiled = table.concat( self.getContext( CTX_Code ), "\n" )

	ProfileEnd()

	-- write compiled output to file for debugging
	file.Write("blueprints/last_compile.txt", self.compiled)

	-- if set, just return the compiled string, don't try to run the module
	if bit.band(self.flags, CF_CodeString) ~= 0 then return true, self.compiled end

	-- run the code and grab the __BPMODULE global
	local errorString = RunString(self.compiled, "", false)
	if errorString then return false, errorString end

	local x = __BPMODULE
	__BPMODULE = nil

	return true, x

end

if SERVER and bpdefs ~= nil then

	local mod = bpmodule.New()
	local funcid, graph = mod:NewGraph("MyFunction", GT_Function)

	graph.outputs:Add( bpvariable.New(), "retvar" )
	graph.outputs:Add( bpvariable.New(), "retvar2" )
	graph.inputs:Add( bpvariable.New(), "testVar" )

	local graphid, graph = mod:NewGraph("Events", GT_Event)
	graph:AddNode("__Call" .. funcid)

	mod:Compile()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end