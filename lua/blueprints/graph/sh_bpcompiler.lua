AddCSLuaFile()

module("bpcompiler", package.seeall, bpcommon.rescope(bpschema, bpcommon))

CF_None = 0
CF_Standalone = 1
CF_Comments = 2
CF_Debug = 4
CF_ILP = 8
CF_CompactVars = 16
CF_AllowProtected = 32

CF_Default = bit.bor(CF_Comments, CF_Debug, CF_ILP)

CP_PREPASS = 0
CP_MAINPASS = 1
CP_NETCODEMSG = 2
CP_ALLOCVARS = 3
CP_METAPASS = 4
CP_MODULEMETA = 5
CP_MODULEBPM = 6
CP_MODULEGLOBALS = 7
CP_MODULECODE = 8
CP_MODULEDEBUG = 9
CP_MODULEFOOTER = 10

TK_GENERIC = 0
TK_NETCODE = 1

-- Context prefixes, a context stores lines of code
CTX_SingleNode = "singlenode_"
CTX_FunctionNode = "functionnode_"
CTX_Graph = "graph_"
CTX_JumpTable = "jumptable_"
CTX_MetaTables = "metatables_"
CTX_Vars = "vars_"
CTX_Code = "code"
CTX_MetaEvents = "metaevents_"
CTX_Hooks = "hooks_"
CTX_Network = "network"
CTX_NetworkMeta = "networkmeta"
CTX_Thunk = "thunk"

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
		self.buffer[#self.buffer+1] = text
	end
	self.emitBlock = function(text)
		local lines = string.Explode("\n", text)
		local minIndent = nil
		for _, line in ipairs(lines) do
			local _, num = string.find(line, "\t+")
			if num then minIndent = math.min(num, minIndent or 10) else minIndent = 0 end
		end
		local commonIndent = "^" .. string.rep("\t", minIndent)
		for k, line in ipairs(lines) do
			line = minIndent == 0 and line or line:gsub(commonIndent, "")
			if line ~= "" or k ~= #lines then self.emit(line) end
		end
	end
	self.emitIndented = function(lines, tabcount)
		local t = string.rep("\t", tabcount or 0)
		for _, l in ipairs(lines) do
			self.emit( t .. l )
		end
	end
	self.emitContext = function(context, tabcount)
		self.emitIndented( self.getContext( context ), tabcount )
	end
	self.finish = function()
		local c = self.contexts[self.current_context]
		if c ~= nil then
			for _, v in ipairs(self.buffer) do c[#c+1] = v end
		else
			self.contexts[self.current_context] = self.buffer
		end
		self.buffer = {}
		self.current_context = nil
	end
	self.getContext = function(ctx, noError)
		if not self.contexts[ctx] and not noError then error("Compiler context not found: '" .. ctx .. "'") end
		return self.contexts[ctx]
	end
	self.getFilteredContexts = function(filter)
		local out = {}
		for k,v in pairs(self.contexts) do
			if string.find(k, filter) ~= nil then out[k] = v end
		end
		return out
	end

	self.metaClasses = {
		[bpcommon.FindMetaTable("bpgraph")] = 0,
		[bpcommon.FindMetaTable("bpnode")] = 1,
		[bpcommon.FindMetaTable("bpnodetype")] = 2,
		[bpcommon.FindMetaTable("bppin")] = 3,
		[bpcommon.FindMetaTable("bppintype")] = 4,
		[bpcommon.FindMetaTable("bpmodule")] = 5,
		[bpcommon.FindMetaTable("bpvariable")] = 6,
		[bpcommon.FindMetaTable("bpevent")] = 7,
		[bpcommon.FindMetaTable("bpdermanode")] = 8,
	}


	return self

end

function meta:Setup()

	self.idents = {}
	self.nodeIdents = {}
	self.thunks = {}
	self.vars = {}
	self.nodejumps = {}
	self.contexts = {}
	self.current_context = nil
	self.buffer = ""
	self.compactVars = bit.band(self.flags, CF_CompactVars) ~= 0
	self.debug = bit.band(self.flags, CF_Debug) ~= 0
	self.debugcomments = bit.band(self.flags, CF_Comments) ~= 0
	self.allowProtected = bit.band(self.flags, CF_AllowProtected) ~= 0
	self.ilp = bit.band(self.flags, CF_ILP) ~= 0
	self.ilpmax = 10000
	self.ilpmaxh = 100
	self.guidString = bpcommon.GUIDToString(self.module:GetUID(), true)
	self.varscope = nil
	self.pinRouters = {}
	self.jumpsRequired = {}
	self.containsProtected = false
	self.protectedElements = {}

	return self

end

function meta:AllocThunk(type)
	
	self.thunks[type] = self.thunks[type] or {}
	local t = self.thunks[type]

	local id = #t + 1
	t[id] = {
		context = CTX_Thunk .. "_" .. type .. "_" .. id,
		begin = function()
			self.begin(CTX_Thunk .. "_" .. type .. "_" .. id)
		end,
		emit = self.emit,
		emitBlock = self.emitBlock,
		finish = function()
			self.finish()
		end,
		id = id,
	}
	return t[id]

end

function meta:GetThunk(type, id)

	return self.thunks[type][id]

end

-- builds localized ids for objects used during compilation
function meta:GetID(tbl, allowExternal)

	-- nodes are indexed on a per-graph basis
	if isbpnode(tbl) then
		local id = self.nodeIdents
		local graph = tbl:GetGraph()
		id[graph] = id[graph] or bpindexer.New()
		return id[graph](tbl)
	end

	local identTable = self.idents
	local outer = self:GetOuter()
	if outer and isbpcompiler(outer) and allowExternal then
		identTable = outer.idents
	end

	local mt = getmetatable(tbl)
	mt = bpcommon.GetMetaTableFromHash( mt.__hash )
	local classID = self.metaClasses[mt]
	if not classID then error("Tried to ID invalid class: " .. tostring(mt) .. " -> " .. bpcommon.GetMetaTableName(mt)) end

	identTable[classID] = identTable[classID] or bpindexer.New()
	return identTable[classID](tbl)

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
	[NT_FuncInput] = { unique = true },
	[NT_FuncOutput] = { unique = true },
}

function SanitizeString(str)

	local r = str:gsub("\\n", "__CH~NL__")
	r = r:gsub("\\", "\\\\")
	r = r:gsub("\"", "\\\"")
	r = r:gsub("[%%!@%^#]", function(x)
		return codenames[x] or "INVALID"
	end)
	return r

end

function DesanitizeCodedString(str)

	for k,v in pairs(codenames) do
		str = str:gsub(v, k == "%" and "%%" or k)
	end
	return str

end

function meta:CreateNodeVar(node, identifier, isGlobal)

	local key = bpcommon.CreateUniqueKey(self.varscope, self.compactVars and "l" or "local_" .. node:GetTypeName() .. "_v_" .. identifier)
	local v = {
		var = key,
		localvar = identifier,
		node = node,
		graph = node:GetGraph(),
		keyAsGlobal = isGlobal,
	}

	self.vars[#self.vars+1] = v
	return v

end

function meta:CreatePinRouter(pin, func)

	self.pinRouters[pin] = func

end

-- creates a variable for the specified pin
function meta:CreatePinVar(pin)

	local node = pin:GetNode()
	local graph = node:GetGraph()
	local graphName = graph:GetName()
	local pinName = pin:GetName()
	local codeType = node:GetCodeType()
	local isFunctionPin = codeType == NT_FuncInput or codeType == NT_FuncOutput
	local unique = self.varscope
	local pinStr = node:ToString(pin)
	local compactVars = self.compactVars

	pinName = (pinName ~= "" and pinName or "pin")

	if pin:IsType(PN_Exec) then return nil end
	if pin:IsIn() then

		if isFunctionPin then

			local graphID = self:GetID(graph)
			local key = bpcommon.CreateUniqueKey({}, compactVars and ("r" .. graphID .. "_" .. pin.id) or "func_" .. graphName .. "_out_" .. pinName)
			self.vars[#self.vars+1] = {
				var = key,
				pin = pin,
				graph = graph,
				output = true,
				isFunc = true,
			}
			return self.vars[#self.vars]

		end

	elseif pin:IsOut() then

		if not isFunctionPin then

			local key = bpcommon.CreateUniqueKey(unique, compactVars and "f" or "fcall_" .. node:GetSanitizedTypeName() .. "_ret_" .. pinName)
			self.vars[#self.vars+1] = {
				var = key,
				global = codeType ~= NT_Pure,
				pin = pin,
				graph = graph,
				isFunc = isFunctionPin,
			}
			return self.vars[#self.vars]

		else

			local key = bpcommon.CreateUniqueKey(unique, compactVars and "f" or "func_" .. graphName .. "_in_" .. pinName)
			self.vars[#self.vars+1] = {
				var = key,
				pin = pin,
				graph = graph,
				isFunc = isFunctionPin,
			}
			return self.vars[#self.vars]

		end

	end

end

--[[
This function goes through all nodes of a certain type in the current graph and creates variable entries for them.
These variables are used to connect node outputs to inputs among other things

There are currently 2 types of vars:
	node-locals and return-values

Node-locals are internal variables scoped to a specific node.
The foreach node uses this to keep track of its iteration.

Return-values hold the output of non-pure function calls.
]]

function meta:CreateFunctionGraphVars(graph, uniqueKeys)

	local unique = uniqueKeys
	local name = graph:GetName()
	local key = bpcommon.CreateUniqueKey(unique, self.compactVars and "f" or "func_" .. name .. "_returned")

	self.vars[#self.vars+1] = {
		var = key,
		graph = graph,
		isFunc = true,
	}

end

function meta:EnumerateGraphVars(graph, uniqueKeys)

	local localScopeUnique = {}
	for nodeID, node in graph:Nodes() do

		local e = nodeTypeEnumerateData[node:GetCodeType()]
		if not e then continue end

		local unique = e.unique and uniqueKeys or localScopeUnique
		self.varscope = unique

		if not self:RunNodeCompile(node, CP_ALLOCVARS) then

			for _, l in ipairs(node:GetLocals()) do self:CreateNodeVar(node, l, false) end
			for _, l in ipairs(node:GetGlobals()) do self:CreateNodeVar(node, l, true) end
			for pinID, pin in node:Pins() do self:CreatePinVar(pin) end

		end

		self.varscope = nil

	end

	if graph.type == GT_Function then
		self:CreateFunctionGraphVars(graph, uniqueKeys)
	end

end

-- find a node-local variable by name for a given node
function meta:FindVarForNode(node, vname)

	local nodeGraph = node:GetGraph()
	for _, v in ipairs(self.vars) do

		if not v.localvar then continue end
		if v.graph ~= nodeGraph then continue end
		if v.node == node and v.localvar == vname then return v end

	end

end

function meta:FindGraphReturnVar(graph)

	if graph == nil then error("Graph is nil") end

	for _, v in ipairs(self.vars) do

		if v.localvar then continue end
		if v.graph ~= graph then continue end
		if v.pin == nil then return v end

	end

	error("Return var not found for graph: " .. tostring(graph:GetName()))

end

-- find the variable that is assigned to the given node/pin
function meta:FindVarForPin(pin, noLiteral)

	assert(pin ~= nil)

	if self.pinRouters[pin] then
		return self.pinRouters[pin](pin)
	end

	local nodeGraph = pin:GetNode():GetGraph()
	for _, v in ipairs(self.vars) do

		if v.localvar then continue end
		if v.graph ~= nodeGraph then continue end
		if v.pin == pin then return v end

	end

	--if pin then error("Var not found for pin: " .. pin:GetNode():ToString(pin)) end

end

function meta:GetPinLiteral(pin, sanitize)

	if pin and pin:GetLiteral() and not noLiteral then
		if pin.GetCode then
			return { var = pin:GetCode(self) } 
		end

		local l = tostring(pin:GetLiteral())
		if l == "{}" then l = "__emptyTable()"
		elseif l == "__emptyTable" then l = "__emptyTable()" end

		if pin:IsType(PN_BPClass) then l = EscapedGUID(l) end
		if sanitize then l = SanitizeString(l) end
		if pin:IsType(PN_String) and not pin:HasFlag(PNF_Table) then l = "\"" .. l .. "\"" end
		if pin:IsType(PN_Asset) then l = "\"" .. l .. "\"" end

		--print("LITERAL FOR NODEPIN: " .. node:ToString(pin.id) .. " [" .. l .. "]")

		return { var = l }
	else
		local def = pin:GetDefault()
		--print("DEFAULT FOR NODEPIN: " .. node:ToString(pin.id))
		return def and { var = def } or { var = "nil" }
	end

end


-- basically just adds a self prefix for global variables to scope them into the module
function meta:GetVarCode(var, jump)

	if var == nil then
		error("Failed to get var for " .. self.currentNode:ToString() .. " ``" .. tostring(self.currentCode) .. "``" )
	end

	local s = ""

	if jump and var.jump and var.pin then
		local execCount = 0
		for _, p in var.pin:GetNode():SidePins(PD_In) do
			if p:IsType(PN_Exec) then execCount = execCount + 1 end
		end
		if execCount > 1 then s = "__targetPin = " .. var.pin.id .. " " end
	end

	if jump and var.term then return s .. "goto popcall"
	elseif jump and var.jump then s = s .. "goto jmp_" end
	if var.literal then return s .. var.var end
	if var.global or var.isFunc or var.keyAsGlobal then return "__self." .. var.var end
	return s .. var.var

end

function meta:GetPinCode(pin, ...)

	if pin.GetCode then
		local r = pin:GetCode(self, ...)
		if r then return r end
	end

	local var = self:GetPinVar(pin, true)
	return self:GetVarCode(var, ...)

end

-- finds or creates a jump table for the current graph
function meta:GetGraphJumpTable(graph)

	self.nodejumps[graph] = self.nodejumps[graph] or {}
	return self.nodejumps[graph]

end

-- replaces meta-code in the node type (see top of defspec.txt) with references to actual variables
function meta:CompileVars(code, inVars, outVars, node)

	local str = code
	local inBase = 0
	local outBase = 0
	local graph = node:GetGraph()
	local graphID = self:GetID(graph)
	local nodeID = self:GetID(node)

	self.currentNode = node
	self.currentCode = str

	if node:GetCodeType() == NT_Function then
		inBase = 1
		outBase = 1
	end

	-- replace macros
	str = string.Replace( str, "!node", tostring(nodeID))
	str = string.Replace( str, "!graph", tostring(graphID))
	str = string.Replace( str, "!module", tostring(self.guidString))

	-- replace input pin codes
	str = str:gsub("$(%d+)", function(x) return self:GetVarCode(inVars[tonumber(x) + inBase]) end)

	-- replace output pin codes
	str = str:gsub("#_(%d+)", function(x) return self:GetVarCode(outVars[tonumber(x) + outBase]) end)
	str = str:gsub("#(%d+)", function(x) return self:GetVarCode(outVars[tonumber(x) + outBase], true) end)

	local lmap = {}
	for k,v in ipairs(node:GetLocals()) do
		local var = self:FindVarForNode(node, v)
		if var == nil then error("Failed to find internal variable: " .. tostring(v)) end
		lmap[v] = var
	end

	for k,v in ipairs(node:GetGlobals()) do
		local var = self:FindVarForNode(node, v)
		if var == nil then error("Failed to find internal variable: " .. tostring(v)) end
		lmap[v] = var
	end

	str = str:gsub("%%([%w_]+)", function(x)
		if not lmap[x] then error("FAILED TO FIND LOCAL: " .. tostring(x)) end
		return self:GetVarCode(lmap[x]) end
	)

	-- replace jumps
	local jumpTable = self:GetGraphJumpTable(graph)[nodeID] or {}
	str = str:gsub("%^_([%w_]+)", function(x) return tostring(jumpTable[x] or 0) end)
	str = str:gsub("%^([%w_]+)", function(x) return "jmp_" .. (jumpTable[x] or 0) end)
	str = DesanitizeCodedString(str)

	return str

end

function meta:CompileReturnPin( node )

	if node:GetCodeType() == NT_Function then
		local thruPin = node:FindPin(PD_Out, "Thru")
		local connected = thruPin:GetConnectedPins()
		if #connected == 0 then
			self.emit( self:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) )
		elseif #connected[1]:GetConnectedPins() > 1 then
			self.emit( self:GetPinCode( node:FindPin(PD_Out, "Thru"), true ) )
		end
	end

end

-- If pin is connected, gets the connected var. Otherwise creates a literal if applicable
function meta:GetPinVar(pin, sanitize)

	local node = pin:GetNode()
	local codeType = node:GetCodeType()

	if pin:IsIn() then

		local pins = pin:GetConnectedPins()
		if #pins == 1 then

			local var = self:FindVarForPin(pins[1])
			if var == nil then error("COULDN'T FIND INPUT VAR FOR " .. pins[1]:GetNode():ToString(pins[1]) .. " -> " .. pin:GetNode():ToString(pin)) end
			return var

		-- if there are no connections, try to assign literals on this pin
		elseif #pins == 0 then

			local literalVar = self:GetPinLiteral(pin, sanitize)
			if literalVar ~= nil then
				return literalVar
			else
				-- unconnected nullable pins just have their value set to nil
				local nullable = pin:HasFlag(PNF_Nullable)
				if nullable then
					return { var = "nil" }
				else
					error("Pin must be connected: " .. node:ToString(pin))
				end
			end
		else
			error("No handler for multiple input pins")
		end

	elseif pin:IsOut() then

		if codeType == NT_Event then
			return self:FindVarForPin(pin)
		else

			if pin:IsType(PN_Exec) then

				-- unconnected exec pins jump to ::jmp_0:: which just pops the stack
				local pins = pin:GetConnectedPins()
				return {
					var = #pins ~= 0 and self:GetID(pins[1]:GetNode()) or "0",
					term = #pins == 0,
					jump = true,
					pin = #pins > 0 and pins[1],
				}

			else

				-- find output variable to write to on this pin
				local var = self:FindVarForPin(pin)
				if var == nil then error("Unable to find var for pin " .. node:ToString(pin)) end
				return var

			end

		end

	end

end

-- compiles a single node
function meta:CompileNodeSingle(node)

	local nodeID = self:GetID(node)
	local codeType = node:GetCodeType()
	local graphThunk = node:GetGraphThunk()

	-- the context to emit (singlenode_graph#_node#)
	self.begin(CTX_SingleNode .. self:GetID(node:GetGraph()) .. "_" .. nodeID)

	local roleCode = node:GetRole()
	if roleCode == nil then
		--print("NO ROLE CODE FOR NODE: " .. node:GetTypeName())
		roleCode = 0
	end

	-- emit some infinite-loop-protection code
	if self.ilp and (codeType == NT_Function or codeType == NT_Special or codeType == NT_FuncOutput) then
		if roleCode == 0 then
			self.emit((self.debug and "_FR_ILPD" or "_FR_ILP") .. "(" .. self.ilpmax .. ", " .. nodeID .. ")")
		else
			self.emit((self.debug and "_FR_ILPD" or "_FR_ILP") .. "(" .. self.ilpmax .. ", " .. nodeID .. ", " .. roleCode .. ")")
		end
	elseif self.debug then
		if roleCode == 0 then
			self.emit("_FR_DBG(" .. nodeID .. ")")
		else
			self.emit("_FR_DBG(" .. nodeID .. ", " .. roleCode ..  ")")
		end
	end

	-- if node can compile itself, stop here
	if self:RunNodeCompile(node, CP_MAINPASS) then self.finish() self:RunNodeCompile( node, CP_METAPASS ) return end


	local code = node:GetCode()

	self.currentNode = node
	self.currentCode = code

	-- list of inputs/outputs to compile
	local inVars = {}
	local outVars = {}

	-- iterate through all input pins
	for pinID, pin, pos in node:SidePins(PD_In) do
		if pin:IsType(PN_Exec) then continue end

		if codeType == NT_FuncOutput then
			outVars[pos] = self:FindVarForPin(pin, true)
		end

		inVars[pos] = self:GetPinVar(pin, true)

	end

	-- iterate through all output pins
	for pinID, pin, pos in node:SidePins(PD_Out) do

		outVars[pos] = self:GetPinVar(pin, true)

	end

	if not code then
		ErrorNoHalt("No code for node: " .. node:ToString() .. "\n")
		return
	end

	code = code:gsub("pushjmp%(([^%)]+)%)", function(x)
		return "sp=sp+1 cs[sp]=" .. x
	end)

	-- grab code off node type and remove tabs
	code = string.Replace(code, "\t", "")

	-- take all the mapped variables and place them in the code string
	code = Profile("vct", self.CompileVars, self, code, inVars, outVars, node)

	if string.find(code, "[^%s]") ~= nil then

		-- break the code apart and emit each line
		for _, l in ipairs(string.Explode("\n", code)) do
			self.emit(l)
		end

	end

	self:CompileReturnPin( node )

	self.finish()

	self:RunNodeCompile( node, CP_METAPASS )

end

-- given a non-pure function, walk back through the tree of pure nodes that contribute to its inputs
-- traversal order follows proceedural execution of nodes (inputs traversed, then node)
function meta:WalkBackPureNodes(node, call)

	local max = 10000
	local stack = {}
	local output = {}

	table.insert(stack, node)

	while #stack > 0 and max > 0 do

		max = max - 1

		local pnode = stack[#stack]
		table.remove(stack, #stack)

		for pinID, pin in pnode:SidePins(PD_In) do

			local connections = pin:GetConnectedPins()
			for _, v in ipairs(connections) do

				local node = v:GetNode()
				if node:GetCodeType() == NT_Pure then

					stack[#stack+1] = node
					output[#output+1] = node

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
function meta:CompileNodeFunction(node)

	local codeType = node:GetCodeType()
	local graphID = self:GetID(node:GetGraph())
	local nodeID = self:GetID(node)

	self.jumpsRequired[graphID] = self.jumpsRequired[graphID] or {}

	--print("COMPILE NODE: " .. node:ToString())

	self.begin(CTX_FunctionNode .. graphID .. "_" .. nodeID)
	if self.debugcomments and (codeType == NT_Event or codeType == NT_FuncInput) then self.emit("-- " .. node:ToString()) end

	local needsJump = (codeType == NT_Event or codeType == NT_FuncInput)
	if not needsJump then
		for pinID, pin in node:SidePins(PD_In) do
			if not pin:IsType(PN_Exec) then continue end
			local pins = pin:GetConnectedPins()
			if #pins == 1 then
				local other = pins[1]:GetNode()
				--needsJump = node.__nextExec ~= nil and (node.__nextExec ~= other)
				local n, pos = 0, 0
				for _, pin in other:SidePins(PD_Out) do
					if pin:IsType(PN_Exec) and #pin:GetConnectedPins() ~= 0 then n = n + 1 end
					if pin == pins[1] then pos = n break end
				end
				--print(node:ToString() .. " CONNECTED TO EXEC # " .. pos)
				if other:GetCodeType() == NT_Special then
					if other:HasFlag(NTF_FallThrough) then
						needsJump = (pos ~= 1)
					else 
						needsJump = true
					end
				end
			elseif #pins > 1 then
				needsJump = true
			end
		end
	end

	if needsJump then self.emit("::jmp_" .. nodeID .. "::") self.jumpsRequired[graphID][nodeID] = true end
	--print("Mark for jump: " .. nodeID .. " : " .. node:ToString())

	-- event nodes are really just jump stubs
	if codeType == NT_Event or codeType == NT_FuncInput then 

		for pinID, pin in node:SidePins(PD_Out) do
			if not pin:IsType(PN_Exec) then continue end

			-- get the exec pin's connection and jump to the node it's connected to
			local connection = pin:GetConnectedPins()[1]
			if connection ~= nil then

				local execCount = 0
				for _, p in connection:GetNode():SidePins(PD_In) do
					if p:IsType(PN_Exec) then execCount = execCount + 1 end
				end

				if execCount > 1 then self.emit("\t__targetPin = " .. connection.id) end
				--self.emit("\tgoto jmp_" .. self:GetID(connection:GetNode()))
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
	self:WalkBackPureNodes(node, function(pure)
		if emitted[pure] then return end
		emitted[pure] = true
		self.emitContext( CTX_SingleNode .. graphID .. "_" .. self:GetID(pure), 1 )
	end)

	-- emit this non-pure node's code
	self.emitContext( CTX_SingleNode .. graphID .. "_" .. nodeID, 1 )

	self.finish()

end

function meta:AddRequiredMetaTable(t)

	self.requiredMetaTables = self.requiredMetaTables or {}
	self.requiredMetaTables[t] = true

end

function meta:GetRequiredMetaTables()

	return self.requiredMetaTables or {}

end

-- emits some boilerplate code for indexing gmod's metatables
function meta:CompileMetaTableLookup()

	self.begin(CTX_MetaTables)

	local tables = {}
	for k,v in pairs(self.requiredMetaTables or {}) do
		tables[#tables+1] = k
	end

	if #tables ~= 0 then self.emit("_FR_MTL(" .. table.concat(tables, ",") .. ")") end

	self.finish()

end

-- lua doesn't have a switch/case construct, so build a massive 'if' bank to jump to each section of the code.
function meta:CompileGraphJumpTable(graph)

	self.begin(CTX_JumpTable .. self:GetID(graph))

	local nextJumpID = 0

	local jl = {0}

	for _, node in graph:Nodes() do
		local id = self:GetID(node)
		if node:GetCodeType() ~= NT_Pure then
			nextJumpID = math.max(nextJumpID, id+1)
		end
	end

	-- some nodes have internal jump symbols to control program flow (delay / sequence)
	-- create jump vectors for each of those
	local jumpTable = self:GetGraphJumpTable(graph)
	for _, node in graph:Nodes() do
		local id = self:GetID(node)
		for _, j in ipairs(node:GetJumpSymbols()) do

			if not node.execReachable then continue end --print("***Node will not execute: " .. node:ToString())

			jumpTable[id] = jumpTable[id] or {}
			jumpTable[id][j] = nextJumpID
			jl[#jl+1] = nextJumpID

			--print("Require jump symbol: " .. node:ToString() .. " " .. j .. " => " .. nextJumpID)

			nextJumpID = nextJumpID + 1

		end
	end


	self.emit("_FR_JLIST(" .. table.concat(jl, ",") .. ")")

	self.finish()

end

function meta:CompileGraphNodeJumps(graph)

	local jl = {}

	local graphID = self:GetID(graph)
	self.begin(CTX_JumpTable .. graphID)

	self.jumpsRequired[graphID] = self.jumpsRequired[graphID] or {}

	-- emit jumps for all non-pure functions
	for _, node in graph:Nodes() do
		local id = self:GetID(node)
		if self.jumpsRequired[graphID][id] then
			jl[#jl+1] = id
			--print("ADD JUMP: " .. id .. " : " .. node:ToString())
		end
	end

	self.emit("_FR_JLIST(" .. table.concat(jl, ",") .. ")")

	self.finish()

end

-- builds global variable initializer code for module construction
function meta:CompileGlobalVarListing()

	self.begin(CTX_Vars .. "global")

	self:RunModuleCompile(CP_MODULEGLOBALS)

	self.finish()

end

-- builds local variable initializer code for graph entry function
function meta:CompileGraphVarListing(graph)

	self.begin(CTX_Vars .. self:GetID(graph))

	local locals = {}
	for _, v in ipairs(self.vars) do
		if v.graph ~= graph then continue end
		if not v.literal and not v.global and not v.isFunc and not v.keyAsGlobal then
			locals[#locals+1] = v.var
		end
	end

	self.finish()

end

function meta:CompileNetworkCode()

	self.begin(CTX_Network)

	if bit.band(self.flags, CF_Standalone) ~= 0 then

		self.emit("_FR_STANDALONEHEAD()")

	end

	self.emit("_FR_NETHEAD()")

	self.finish()

	self.begin(CTX_NetworkMeta)

	self.emitBlock [[
	_FR_NETMAIN()
	function meta:netReceiveMessage(len, pl)
		local msgID = net.ReadUInt(16)]]

		self.pushIndent()
		self:RunModuleCompile( CP_NETCODEMSG )
		self.popIndent()

	self.emitBlock [[
	end
	]]

	self.finish()

end

-- glues all the code together
function meta:CompileCodeSegment( noExport )

	local moduleID = self:GetID(self.module)

	self.begin(CTX_Code)

	if bit.band(self.flags, CF_Standalone) ~= 0 and not noExport then
		self.emit("-- Compiled using gm_blueprints v" .. bpcommon.ENV_VERSION .. " ( https://github.com/ZakBlystone/gmod_blueprints )")
	end

	if not noExport then self.emitContext( CTX_MetaTables ) end
	self:RunModuleCompile( CP_MODULECODE )
	self:RunModuleCompile( CP_MODULEMETA )
	self:RunModuleCompile( CP_MODULEBPM )
	if not noExport then self:RunModuleCompile( CP_MODULEFOOTER ) end

	self.finish()

end

function meta:GetDebugSymbols()

	return self.debugSymbols

end

function meta:AddGraphSymbols( graph )

	local t = self.debugSymbols
	local moduleID = self.module:GetUID()
	if not t[moduleID] then
		t[moduleID] = {
			graphs = {},
			nodes = {},
		}
	end
	t = t[moduleID]

	for k, node in graph:Nodes() do
		local id = self:GetID( node )
		local typename = node:GetTypeName()
		local name = node:GetDisplayName()

		t.nodes[id] = {
			typename,
			name,
			node.uid,
		}
	end

	t.graphs[self:GetID( graph )] = {
		graph:GetTitle(),
		graph.uid,
	}

end

function meta:CreateDebugSymbols()

	if self.debugSymbols ~= nil then return end
	if not self.debug then return end

	self.debugSymbols = {}

	self:RunModuleCompile( CP_MODULEDEBUG )

end

function meta:RunNodeCompile(node, pass)

	local ntype = node:GetType()
	if ntype.Compile then return ntype.Compile(node, self, pass) end
	if node.Compile then return node:Compile(self, pass) end
	return false

end

function meta:RunModuleCompile(pass)

	if self.module.Compile then return self.module:Compile(self, pass) end
	return false

end

-- compiles a metamethod for a given event
function meta:CompileGraphMetaHook(graph, node, name)

	local graphID = self:GetID(graph)
	local moduleID = self:GetID(self.module)
	local nodeID = self:GetID(node)

	self.currentNode = node
	self.currentCode = ""

	self.begin(CTX_MetaEvents .. self:GetID(graph))

	self.emit("function meta:" .. name .. "(...)")
	self.pushIndent()

	-- build argument table and store reference to 'self'
	self.emit("__self = self")

	-- emit the code for the event node
	self.emitContext( CTX_SingleNode .. graphID .. "_" .. nodeID )

	if graph:GetType() == GT_Function then
		self.emit(self:GetVarCode(self:FindGraphReturnVar(graph)) .. " = false")
	end

	self.emit("_FR_MPCALL(" .. (self.ilp and 1 or 0) .. ", " .. graphID .. ", " .. nodeID .. ")")

	if graph:GetType() == GT_Function then
		self.emit("if " .. self:GetVarCode(self:FindGraphReturnVar(graph)) .. " == true then")
		self.emit("return")

		local out = {}

		local emitted = {}
		for _, v in ipairs(self.vars) do
			if emitted[v.var] then continue end
			if v.graph == graph and v.isFunc and v.output then
				out[#out+1] = v
				emitted[v.var] = true
			end
		end

		for k, v in ipairs(out) do
			self.emit("\t" .. self:GetVarCode(v) .. (k == #out and "" or ","))
		end

		self.emit("end")
	end

	self.popIndent()
	self.emit("end")

	self.finish()

end

function meta:FlagProtected( name )

	self.containsProtected = true
	self.protectedElements[name] = true

end

function meta:Compile( noExport )

	--print("COMPILING MODULE...")

	ProfileStart("bpcompiler:Compile")

	self:Setup()

	self:RunModuleCompile( CP_PREPASS )

	-- compile the global variable listing (contains all global variables accross all graphs)
	Profile( "global-var-listing", self.CompileGlobalVarListing, self)

	self:RunModuleCompile( CP_MAINPASS )

	Profile("netcode", self.CompileNetworkCode, self)

	-- required metatables
	Profile("meta-lookup", self.CompileMetaTableLookup, self)

	-- compile main code segment
	Profile("code-segment", self.CompileCodeSegment, self, noExport)

	-- debugging info
	Profile("debug-symbols", self.CreateDebugSymbols, self)

	if noExport then return nil end
	if self.containsProtected and not self.allowProtected then
		local elements = ""
		for k, _ in pairs(self.protectedElements) do elements = elements .. "\n" .. k end
		error("Context does not allow the following protected nodes, check your permissions: \n" .. elements)
	end

	local compiledModule = nil

	Profile("code-build-cm", function()
		self.compiledCode = table.concat( self.getContext( CTX_Code ), "\n" )
		compiledModule = bpcompiledmodule.New( self.module, self.compiledCode, self.debugSymbols ) 
	end)

	Profile("write-files", function()

		-- write compiled output to file for debugging
		file.Write(bpcommon.BLUEPRINT_DATA_PATH .. "/last_compile_.txt", compiledModule:GetCode(true))
		file.Write(bpcommon.BLUEPRINT_DATA_PATH .. "/last_compile.txt", compiledModule:GetCode())

	end)

	ProfileEnd()

	return compiledModule

end

function New(...) return bpcommon.MakeInstance(meta, ...) end

--[[if SERVER and bpdefs ~= nil then

	local mod = bpmodule.New()
	local funcid, funcgraph = mod:NewGraph("MyFunction", GT_Function)

	funcgraph.outputs:Add( MakePin(PD_None, nil, PN_Bool), "retvar" )
	funcgraph.outputs:Add( MakePin(PD_None, nil, PN_Bool), "retvar2" )
	funcgraph.inputs:Add( MakePin(PD_None, nil, PN_Bool), "testVar" )

	local graphid, graph = mod:NewGraph("Events", GT_Event)
	graph:AddNode(funcgraph:GetCallNodeType())

	local result = mod:Compile( bit.bor(CF_Default, CF_CompactVars) )
	result:Load()

end]]