AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpgraph.lua")
include("sh_bpnodedef.lua")
include("sh_bpmodule.lua")

module("bpcompile", package.seeall, bpcommon.rescope(bpschema, bpnodedef))

-- Some print utilities that I never fully used
indent = 0
function printi(...)
	Msg(string.rep(" ", indent))
	Msg(...)
	Msg("\n")
end

function pushi() indent = indent + 1 end
function popi() indent = indent - 1 end

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

function Profile( cs, key, func, ... )

	if not cs.profile then return func(...) end

	cs.times[key] = cs.times[key] or {time = 0, samples = 0, min = 9999, max = 0}
	local t = cs.times[key]
	local s = os.clock()
	local a,b,c,d,e,f,g = func(...)
	t.max = math.max(t.max, (os.clock() - s))
	t.min = math.min(t.min, (os.clock() - s))
	t.time = t.time + (os.clock() - s)
	t.samples = t.samples + 1
	return a,b,c,d,e,f,g

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

function CreateFunctionGraphVars(cs, uniqueKeys)

	local unique = uniqueKeys
	local name = cs.graph:GetName()
	local key = bpcommon.CreateUniqueKey(unique, "func_" .. name .. "_returned")
	table.insert(cs.vars, {
		var = key,
		type = PN_Bool,
		init = "false",
		node = nil,
		pin = nil,
		graph = cs.graph.id,
		isFunc = true,
	})

	for nodeID, node in cs.graph:Nodes() do
		local codeType = node:GetCodeType()
		if codeType == NT_FuncInput then

			for pinID, pin in node:SidePins(PD_Out) do
				local pinType = cs.graph:GetPinType( nodeID, pinID )
				if pinType == PN_Exec then continue end

				local key = bpcommon.CreateUniqueKey(unique, "func_" .. name .. "_in_" .. (pin[3] ~= "" and pin[3] or "pin"))
				--print(" " .. key)

				table.insert(cs.vars, {
					var = key,
					init = Defaults[pinType],
					type = pinType,
					node = nodeID,
					pin = pinID,
					graph = cs.graph.id,
					isFunc = true,
				})
			end

		elseif codeType == NT_FuncOutput then

			for pinID, pin in node:SidePins(PD_In) do
				local pinType = cs.graph:GetPinType( nodeID, pinID )
				if pinType == PN_Exec then continue end

				-- TODO, multiple return nodes access the same variables, make these graph-scope instead.
				local key = bpcommon.CreateUniqueKey({}, "func_" .. name .. "_out_" .. (pin[3] ~= "" and pin[3] or "pin"))

				if node.literals and node.literals[pinID] ~= nil then

					local l = tostring(node.literals[pinID])

					-- string literals need to be surrounded by quotes
					-- TODO: Sanitize these
					if pinType == PN_String then l = "\"" .. SanitizeString(l) .. "\"" end

					table.insert(cs.vars, {
						var = l,
						type = pinType,
						literal = true,
						node = nodeID,
						pin = pinID,
						graph = cs.graph.id,
						isFunc = true,
					})

				end

				table.insert(cs.vars, {
					var = key,
					init = Defaults[pinType],
					type = pinType,
					node = nodeID,
					pin = pinID,
					graph = cs.graph.id,
					output = true,
					isFunc = true,
				})
			end

		end
	end

end

local nodeTypeEnumerateData = {
	[NT_Pure] = { unique = false },
	[NT_Function] = { unique = true },
	[NT_Event] = { unique = true },
	[NT_Special] = { unique = true },
}

function EnumerateGraphVars(cs, uniqueKeys)

	local localScopeUnique = {}
	for nodeID, node in cs.graph:Nodes() do
		local codeType = node:GetCodeType()
		local e = nodeTypeEnumerateData[codeType]
		if not e then continue end

		local unique = e.unique and uniqueKeys or localScopeUnique

		-- some nodetypes have local variables exclusive to themselves
		for _, l in pairs(node:GetLocals()) do

			local key = bpcommon.CreateUniqueKey(unique, "local_" .. node:GetTypeName() .. "_v_" .. l)

			table.insert(cs.vars, {
				var = key,
				localvar = l,
				node = nodeID,
				graph = cs.graph.id,
			})

		end

		-- unconnected pins can contain literals, make internal variables for them
		for pinID, pin in node:SidePins(PD_In) do
			local pinType = cs.graph:GetPinType( nodeID, pinID )

			if node.literals and node.literals[pinID] ~= nil then

				local l = tostring(node.literals[pinID])

				-- string literals need to be surrounded by quotes
				-- TODO: Sanitize these
				if pinType == PN_String then l = "\"" .. SanitizeString(l) .. "\"" end

				table.insert(cs.vars, {
					var = l,
					type = pinType,
					literal = true,
					node = nodeID,
					pin = pinID,
					graph = cs.graph.id,
				})

			end

		end

		-- output pins create local variables, if the function is non-pure, the variable is global
		for pinID, pin in node:SidePins(PD_Out) do
			local pinType = cs.graph:GetPinType( nodeID, pinID )

			if pinType == PN_Exec then continue end

			local key = bpcommon.CreateUniqueKey(unique, "fcall_" .. node:GetTypeName() .. "_ret_" .. (pin[3] ~= "" and pin[3] or "pin"))

			table.insert(cs.vars, {
				var = key,
				type = pinType,
				init = Defaults[pinType],
				global = codeType ~= NT_Pure,
				node = nodeID,
				pin = pinID,
				graph = cs.graph.id,
			})

		end
	end

end

-- find a node-local variable by name for a given node
function FindLocalVarForNode(cs, nodeID, vname)

	for k,v in pairs(cs.vars) do

		if not v.localvar then continue end
		if v.graph ~= cs.graph.id then continue end
		if v.node == nodeID and v.localvar == vname then return v end

	end

end

-- find the variable that is assigned to the given node/pin
function FindVarForPin(cs, nodeID, pinID, noLiteral)

	for k,v in pairs(cs.vars) do

		if v.literal == true and noLiteral then continue end
		if v.localvar then continue end
		if v.graph ~= cs.graph.id then continue end
		if v.node == nodeID and v.pin == pinID then return v end

	end

end

-- basically just adds a self prefix for global variables to scope them into the module
function GetVarCode(cs, var, jump)

	if var == nil then
		error("Failed to get var for " .. cs.currentNode:ToString() .. " ``" .. cs.currentCode .. "``" )
	end

	local s = ""
	if jump and var.jump then s = "goto jmp_" end
	if var.literal then return s .. var.var end
	if var.global or var.isFunc then return "__self." .. var.var end
	return s .. var.var

end

-- returns all connections to a given node's pin
function GetPinConnections(cs, pinDir, nodeID, pinID)

	local out = {}
	for k, v in cs.graph:Connections() do
		if pinDir == PD_In and (v[3] ~= nodeID or v[4] ~= pinID) then continue end
		if pinDir == PD_Out and (v[1] ~= nodeID or v[2] ~= pinID) then continue end
		table.insert(out, v)
	end
	return out

end

-- finds or creates a jump table for the current graph
function GetGraphJumpTable(cs)

	cs.nodejumps[cs.graph.id] = cs.nodejumps[cs.graph.id] or {}
	return cs.nodejumps[cs.graph.id]

end

-- replaces meta-code in the node type (see top of sh_bpnodedef) with references to actual variables
function CompileVars(cs, code, inVars, outVars, nodeID)

	local str = code
	local node = cs.graph:GetNode(nodeID)
	local inBase = 0
	local outBase = 0

	cs.currentNode = node
	cs.currentCode = str

	if node:GetCodeType() == NT_Function then
		inBase = 1
		outBase = 1
	end

	--printi("Compile Code: '" .. code .. "': " .. #inVars .. " " .. #outVars)

	-- replace macros
	str = string.Replace( str, "@graph", "graph_" .. cs.graph.id .. "_entry" )
	str = string.Replace( str, "!node", tostring(nodeID))
	str = string.Replace( str, "!graph", tostring(cs.graph.id))

	-- replace input pin codes
	str = str:gsub("$(%d+)", function(x) return GetVarCode(cs, inVars[tonumber(x) + inBase]) end)

	-- replace output pin codes
	str = str:gsub("#_(%d+)", function(x) return GetVarCode(cs, outVars[tonumber(x) + outBase]) end)
	str = str:gsub("#(%d+)", function(x) return GetVarCode(cs, outVars[tonumber(x) + outBase], true) end)

	local lmap = {}
	for k,v in pairs(node:GetLocals()) do
		local var = FindLocalVarForNode(cs, nodeID, v)
		if var == nil then error("Failed to find internal variable: " .. tostring(v)) end
		lmap[v] = var
	end

	str = str:gsub("%%([%w_]+)", function(x)
		if not lmap[x] then error("FAILED TO FIND LOCAL: " .. tostring(x)) end
		return GetVarCode(cs, lmap[x]) end
	)

	-- replace jumps
	local jumpTable = GetGraphJumpTable(cs)[nodeID] or {}
	str = str:gsub("%^_([%w_]+)", function(x) return tostring(jumpTable[x]) end)
	str = str:gsub("%^([%w_]+)", function(x) return "jmp_" .. jumpTable[x] end)
	str = DesanitizeCodedString(str)

	if node:GetCodeType() == NT_Function then
		str = str .. "\n" .. GetVarCode(cs, outVars[1], true)
	end

	return str

end

-- compiles a single node
function CompileNodeSingle(cs, nodeID)

	local node

	Profile(cs, "node-lookup", function()

		node = cs.graph:GetNode(nodeID)

	end)

	local code = node:GetCode()
	local codeType = node:GetCodeType()
	local graphThunk = node:GetGraphThunk()

	cs.currentNode = node
	cs.currentCode = str

	-- TODO: Instead of building these strings, find a more direct approach of compiling these
	-- generate code based on function graph inputs and outputs
	if graphThunk ~= nil then
		local target = cs.module:GetGraph( graphThunk )
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
			if v[2] == PN_Exec then continue end
			code = code .. "#" .. k .. " = arg[" .. ipin-1 .. "]\n"
			ipin = ipin + 1
		end

		if code:len() > 0 then code = code:sub(0, -2) end
	end

	if codeType == NT_FuncOutput then
		code = ""
		local ipin = 2
		for k, v in node:SidePins(PD_In) do
			if v[2] == PN_Exec then continue end
			code = code .. "#" .. k .. " = $" .. k .. "\n"
			ipin = ipin + 1
		end

		local ret = FindVarForPin(cs, nil, nil, true)
		code = code .. GetVarCode(cs, ret) .. " = true\n"
		code = code .. "goto __terminus\n"

		if code:len() > 0 then code = code:sub(0, -2) end
	end

	if not code then
		ErrorNoHalt("No code for node: " .. node:ToString() .. "\n")
		return
	end

	-- the context to emit (singlenode_graph#_node#)
	cs.begin(CTX_SingleNode .. cs.graph.id .. "_" .. nodeID)

	pushi()
	--printi("Compile Node: " .. ntype.name .. "[" .. nodeID .. "]")

	-- list of inputs/outputs to compile
	local inVars = {}
	local outVars = {}

	-- iterate through all input pins
	for pinID, pin, pos in node:SidePins(PD_In) do
		local pinType = cs.graph:GetPinType( nodeID, pinID )
		if pinType == PN_Exec then continue end

		if codeType == NT_FuncOutput then
			outVars[pos] = FindVarForPin(cs, nodeID, pinID, true)
		end


		-- iterate through all of this pin's connections, and find variables on the pins it's connected to.
		local connections = GetPinConnections(cs, PD_In, nodeID, pinID)
		for _, v in pairs(connections) do

			local var = FindVarForPin(cs, v[1], v[2])
			if var then
				inVars[pos] = var
			else
				error("COULDN'T FIND INPUT VAR FOR " .. node:ToString(pinID))
			end

		end

		-- if there are no connections, try to assign literals on this pin
		if #connections == 0 then
			--printi("Pin Not Connected: " .. pin[3]) 

			local literalVar = FindVarForPin(cs, nodeID, pinID)
			if literalVar ~= nil then
				inVars[pos] = literalVar
			else
				-- unconnected nullable pins just have their value set to nil
				local nullable = bit.band(pin[4], PNF_Nullable) ~= 0
				if nullable then
					--printi("Pin is nullable")
					inVars[pos] = { var = "nil" }
				else
					error("Pin must be connected: " .. node:ToString(pinID))
				end
			end
		end

		--printi("<< " .. pinID .. " : " .. #inVars .. " => " .. pin[3])

	end

	-- iterate through all output pins
	for pinID, pin, pos in node:SidePins(PD_Out) do
		
		local pinType = cs.graph:GetPinType( nodeID, pinID )
		local connections = GetPinConnections(cs, PD_Out, nodeID, pinID)
		if codeType == NT_Event then

			-- assign return values for all event pins
			outVars[pos] = FindVarForPin(cs, nodeID, pinID)
			--if outVars[lookupID] ~= nil then PrintTable(outVars[lookupID]) end

		else

			if pinType == PN_Exec then

				-- unconnect exec pins jump to ::jmp_0:: which just pops the stack
				outVars[pos] = {
					var = #connections == 0 and "0" or connections[1][3],
					jump = true,
				}

			else

				-- find output variable to write to on this pin
				local var = FindVarForPin(cs, nodeID, pinID)
				if var then 
					--table.insert(outVars, var)
					--printi("ASGN >> " .. pinID .. " : " .. lookupID .. " => " .. pin[3])
					outVars[pos] = var
				else
					error("Unable to find var for pin " .. node:ToString(pinID))
				end

			end

		end

		--printi(">> " .. pinID .. " : " .. lookupID .. " => " .. pin[3])

	end	

	-- grab code off node type and remove tabs
	code = string.Replace(code, "\t", "")

	-- take all the mapped variables and place them in the code string
	code = Profile(cs, "vct", CompileVars, cs, code, inVars, outVars, nodeID)

	-- emit some infinite-loop-protection code
	if cs.ilp and (codeType == NT_Function or codeType == NT_Special or codeType == NT_FuncOutput) then
		cs.emit("__ilp = __ilp + 1 if __ilp > " .. cs.ilpmax .. " then __ilptrip = true goto __terminus end")
	end

	-- and debugging info
	if cs.debug then
		cs.emit("__dbgnode = " .. nodeID)
	end

	-- break the code apart and emit each line
	for _, l in pairs(string.Explode("\n", code)) do
		cs.emit(l)
	end

	cs.finish()

	popi()

end

-- given a non-pure function, walk back through the tree of pure nodes that contribute to its inputs
-- traversal order follows proceedural execution of nodes (inputs traversed, then node)
function WalkBackPureNodes(cs, nodeID, call)

	local max = 10000
	local stack = {}
	local output = {}

	table.insert(stack, nodeID)

	while #stack > 0 and max > 0 do

		max = max - 1

		local pnode = stack[#stack]
		table.remove(stack, #stack)

		for pinID, pin in cs.graph:GetNode(pnode):SidePins(PD_In) do

			local connections = GetPinConnections(cs, PD_In, pnode, pinID)
			for _, v in pairs(connections) do

				local node = cs.graph:GetNode( v[1] )
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
function CompileNodeFunction(cs, nodeID)

	local node = cs.graph:GetNode(nodeID)
	local codeType = node:GetCodeType()

	cs.begin(CTX_FunctionNode .. cs.graph.id .. "_" .. nodeID)
	if cs.debugcomments then cs.emit("-- " .. node:ToString()) end
	cs.emit("::jmp_" .. nodeID .. "::")

	-- event nodes are really just jump stubs
	if codeType == NT_Event or codeType == NT_FuncInput then 

		for pinID, pin in node:SidePins(PD_Out) do
			local pinType = cs.graph:GetPinType( nodeID, pinID )
			if pinType ~= PN_Exec then continue end

			-- get the exec pin's connection and jump to the node it's connected to
			local connection = GetPinConnections(cs, PD_Out, nodeID, pinID)[1]
			if connection ~= nil then
				cs.emit("\tgoto jmp_" .. connection[3])
				cs.finish()
				return
			end
		end
		
		-- unconnected exec pins just pop the callstack
		cs.emit("\tgoto popcall")
		cs.finish()
		return

	end

	pushi()
	--printi("COMPILE FUNC: " .. nodeType.name)

	pushi()

	-- walk through all connected pure nodes, emit each node's code context once
	local emitted = {}
	WalkBackPureNodes(cs, nodeID, function(pure)
		if emitted[pure] then return end
		emitted[pure] = true
		--printi( cs.graph:GetNode(pure):ToString() )
		cs.emitContext( CTX_SingleNode .. cs.graph.id .. "_" .. pure, 1 )
	end)
	popi()

	-- emit this non-pure node's code
	cs.emitContext( CTX_SingleNode .. cs.graph.id .. "_" .. nodeID, 1 )

	popi()

	cs.finish()

end

-- emits some boilerplate code for indexing gmod's metatables
function CompileMetaTableLookup(cs)

	cs.begin(CTX_MetaTables)

	local tables = {
		"Player",
		"Entity",
		"PhysObj",
		"Weapon",
		"NPC",
	}

	for k, v in pairs( bpdefs.GetClasses() ) do
		table.insert(tables, v.name)
	end

	for k, v in pairs( bpdefs.GetStructs() ) do
		if v.metatable then
			table.insert(tables, v.metatable)
		end
	end

	for k, v in pairs(tables) do
		cs.emit("local " .. v ..  "_ = FindMetaTable(\"" .. v .. "\")")
	end

	cs.finish()

end

-- lua doesn't have a switch/case construct, so build a massive 'if' bank to jump to each section of the code.
function CompileGraphJumpTable(cs)

	cs.begin(CTX_JumpTable .. cs.graph.id)

	local nextJumpID = 0

	-- jmp_0 just pops the call stack
	cs.emit( "if ip == 0 then goto jmp_0 end" )

	-- emit jumps for all non-pure functions
	for id, node in cs.graph:Nodes() do
		if node:GetCodeType() ~= NT_Pure then
			cs.emit( "if ip == " .. id .. " then goto jmp_" .. id .. " end" )
		end
		nextJumpID = math.max(nextJumpID, id+1)
	end

	-- some nodes have internal jump symbols to control program flow (delay / sequence)
	-- create jump vectors for each of those
	local jumpTable = GetGraphJumpTable(cs)
	for id, node in cs.graph:Nodes() do
		for _, j in pairs(node:GetJumpSymbols()) do

			jumpTable[id] = jumpTable[id] or {}
			jumpTable[id][j] = nextJumpID
			cs.emit( "if ip == " .. nextJumpID .. " then goto jmp_" .. nextJumpID .. " end" )
			nextJumpID = nextJumpID + 1

		end
	end

	cs.finish()

end

-- builds global variable initializer code for module construction
function CompileGlobalVarListing(cs)

	cs.begin(CTX_Vars .. "global")

	for k, v in pairs(cs.vars) do
		if not v.literal and v.global then
			cs.emit("instance." .. v.var .. " = nil")
		end
	end

	for id, var in cs.module:Variables() do
		local def = var.default
		if var:GetType() == PN_String and bit.band(var:GetFlags(), PNF_Table) == 0 then def = "\"\"" end
		cs.emit("instance.__" .. var.name .. " = " .. tostring(def))
	end

	cs.finish()

end

-- builds local variable initializer code for graph entry function
function CompileGraphVarListing(cs)

	cs.begin(CTX_Vars .. cs.graph.id)

	for k, v in pairs(cs.vars) do
		if v.graph ~= cs.graph.id then continue end
		if not v.literal and not v.global and not v.isFunc then
			cs.emit("local " .. v.var .. " = nil")
		end
	end

	cs.finish()

end

-- compiles the graph entry function
function CompileGraphEntry(cs)

	local graphID = cs.graph.id

	cs.begin(CTX_Graph .. graphID)

	-- graph function header and callstack
	cs.emit("\nlocal function graph_" .. graphID .. "_entry( ip )\n")
	cs.emit("\tlocal cs = {}")

	-- debugging info
	if cs.debug then
		cs.emit( "\t__dbggraph = " .. graphID)
	end

	-- emit graph-local variables
	cs.emitContext( CTX_Vars .. graphID, 1 )

	-- emit jump table
	cs.emit( "\tlocal function pushjmp(i) table.insert(cs, 1, i) end")
	cs.emit( "\tgoto jumpto" )
	cs.emit( "\n\t::jmp_0:: ::popcall::\n\tif #cs > 0 then ip = cs[1] table.remove(cs, 1) else goto __terminus end" )
	cs.emit( "\n\t::jumpto::" )

	cs.emitContext( CTX_JumpTable .. graphID, 1 )

	-- emit all functions belonging to this graph
	local code = cs.getFilteredContexts( CTX_FunctionNode .. cs.graph.id )
	for k, _ in pairs(code) do
		cs.emitContext( k, 1 )
	end

	-- emit terminus jump vector
	cs.emit("\n\t::__terminus::\n")
	cs.emit("end")

	cs.finish()

	--print(table.concat( cs.getContext( CTX_Graph .. cs.graph.id ), "\n" ))

end

-- glues all the code together
function CompileCodeSegment(cs)

	cs.begin(CTX_Code)

	cs.emitContext( CTX_MetaTables )
	cs.emit("local __self = nil")

	-- debugging and infinite-loop-protection
	if cs.debug then
		cs.emit( "local __dbgnode = -1")
		cs.emit( "local __dbggraph = -1")
	end

	if cs.ilp then
		cs.emit( "local __ilptrip = false" )
		cs.emit( "local __ilp = 0" )
		cs.emit( "local __ilph = 0" )
	end

	-- __bpm is the module table, it contains utilities and listings for module functions
	cs.emit("local __bpm = {}")

	-- emit each graph's entry function
	for id in cs.module:GraphIDs() do
		cs.emitContext( CTX_Graph .. id )
	end

	-- infinite-loop-protection checker
	if cs.ilp then
		cs.emit("__bpm.checkilp = function()")
		cs.emit("\tif __ilph > " .. cs.ilpmaxh .. " then __bpm.onError(\"Infinite loop in hook\", " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) return true end")
		cs.emit("\tif __ilptrip then __bpm.onError(\"Infinite loop\", " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) return true end")
		cs.emit("end")
	end

	-- metatable for the module
	cs.emit("local meta = BLUEPRINT_OVERRIDE_META or {}")
	cs.emit("if BLUEPRINT_OVERRIDE_META == nil then meta.__index = meta end")
	cs.emit("__bpm.meta = meta")
	cs.emit("__bpm.genericIsValid = function(x) return type(x) == 'number' or type(x) == 'boolean' or IsValid(x) end")

	-- delay manager (so that delays can be cancelled when a module is unloaded)
	cs.emit("__bpm.delayExists = function(key)")
	cs.emit("\tfor i=#__self.delays, 1, -1 do if __self.delays[i].key == key then return true end end")
	cs.emit("\treturn false")
	cs.emit("end")
	cs.emit("__bpm.delay = function(key, delay, func)")
	cs.emit("\tfor i=#__self.delays, 1, -1 do if __self.delays[i].key == key then table.remove(__self.delays, i) end end")
	cs.emit("\ttable.insert( __self.delays, { key = key, func = func, time = delay })")
	cs.emit("end")

	-- error management, allows for custom error handling with debug info about which node / graph the error happened in
	cs.emit("__bpm.onError = function(msg, mod, graph, node) end")

	-- update function, runs delays and resets the ilp recursion value for hooks
	cs.emit("function meta:update()")
	cs.emit("\tlocal dt = FrameTime()")
	if cs.ilp then cs.emit("\t__ilph = 0") end
	cs.emit("\tfor i=#self.delays, 1, -1 do")
	cs.emit("\t\tself.delays[i].time = self.delays[i].time - dt")
	cs.emit("\t\tif self.delays[i].time <= 0 then")
	cs.emit("\t\t\tlocal s,e = pcall(self.delays[i].func)")
	cs.emit("\t\t\tif not s then self.delays = {} __bpm.onError(e:sub(e:find(':', 11)+2, -1), " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) end")
	cs.emit("\t\t\ttable.remove(self.delays, i)")
	cs.emit("\t\tend")
	cs.emit("\tend")
	cs.emit("end")

	-- emit all meta events (functions with graph entry points)
	for k, _ in pairs( cs.getFilteredContexts(CTX_MetaEvents) ) do
		cs.emitContext( k )
	end

	-- constructor
	cs.emit("__bpm.new = function()")
	cs.emit("\tlocal instance = setmetatable({}, meta)")
	cs.emitContext( CTX_Vars .. "global", 1 )
	cs.emit("\tinstance.delays = {}")
	cs.emit("\tinstance.__bpm = __bpm")
	cs.emit("\treturn instance")
	cs.emit("end")

	-- event listing
	cs.emit("__bpm.events = {")
	for k, _ in pairs( cs.getFilteredContexts(CTX_Hooks) ) do
		cs.emitContext( k, 1 )
	end
	cs.emit("}")

	-- assign local to _G.__BPMODULE so we can grab it from RunString
	cs.emit("__BPMODULE = __bpm")


	cs.finish()

end

-- called on all graphs before main compile pass, generates all potentially shared data between graphs
function PreCompileGraph(cs, graph, uniqueKeys)

	cs.graph = graph

	Profile(cs, "cache-node-types", function()
		cs.graph:CacheNodeTypes()
	end)

	Profile(cs, "collapse-reroutes", function()
		cs.graph:CollapseRerouteNodes()
	end)

	Profile(cs, "enumerate-graph-vars", function()

		-- 'uniqueKeys' is a table for keeping keys distinct, global variables must be distinct when each graph generates them.
		-- pure node variables do not need exclusive keys between graphs because they are local
		EnumerateGraphVars(cs, uniqueKeys)

	end)

	if cs.graph.type == GT_Function then
		Profile(cs, "create-function-vars", CreateFunctionGraphVars, cs, uniqueKeys)
	end

	-- compile jump table and variable listing for this graph
	Profile(cs, "jump-table", CompileGraphJumpTable, cs)
	Profile(cs, "var-listing", CompileGraphVarListing, cs)

end

-- compiles a metamethod for a given event
function CompileGraphMetaHook(cs, graph, nodeID, name)

	local node = cs.graph:GetNode(nodeID)

	cs.currentNode = node
	cs.currentCode = ""

	cs.begin(CTX_MetaEvents .. name)

	cs.emit("function meta:" .. name .. "(...)")

	-- build argument table and store reference to 'self'
	cs.emit("\tlocal arg = {...}")
	cs.emit("\t__self = self")

	-- emit the code for the event node
	cs.emitContext( CTX_SingleNode .. cs.graph.id .. "_" .. nodeID, 1 )

	-- infinite-loop-protection, prevents a loop case where an event calls a function which in turn calls the event.
	-- a counter is incremented and as recursion happens, the counter increases.
	if cs.ilp then
		cs.emit("\tif __bpm.checkilp() then return end")
		cs.emit("\t__ilptrip = false")
		cs.emit("\t__ilp = 0")
		cs.emit("\t__ilph = __ilph + 1")
	end

	if cs.graph.type == GT_Function then
		cs.emit("\t" .. GetVarCode(cs, FindVarForPin(cs, nil, nil)) .. " = false")
	end

	-- protected call into graph entrypoint, calls error handler on error
	cs.emit("\tlocal b,e = pcall(graph_" .. cs.graph.id .. "_entry, " .. nodeID .. ")")
	cs.emit("\tif not b then __bpm.onError(tostring(e), " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) end")

	-- infinite-loop-protection, after calling the event the counter is decremented.
	if cs.ilp then
		cs.emit("\tif __bpm.checkilp() then return end")
		cs.emit("\t__ilph = __ilph - 1")
	end

	if cs.graph.type == GT_Function then
		cs.emit("\tif " .. GetVarCode(cs, FindVarForPin(cs, nil, nil)) .. " == true then")
		cs.emit("\treturn")

		local out = {}

		local emitted = {}
		for k,v in pairs(cs.vars) do
			if emitted[v.var] then continue end
			if v.graph == cs.graph.id and v.isFunc and v.output then
				table.insert(out, v)
				emitted[v.var] = true
			end
		end

		for k, v in pairs(out) do
			cs.emit("\t\t" .. GetVarCode(cs, v) .. (k == #out and "" or ","))
		end

		cs.emit("\tend")
	end

	cs.emit("end")

	cs.finish()

end

-- compile a full graph
function CompileGraph(cs, graph)

	cs.graph = graph

	-- compile each single-node context in the graph
	for id in cs.graph:NodeIDs() do
		Profile(cs, "single-node", CompileNodeSingle, cs, id)
	end

	-- compile all non-pure function nodes in the graph (and events / special nodes)
	for id, node in cs.graph:Nodes() do
		if node:GetCodeType() ~= NT_Pure then
			Profile(cs, "functions", CompileNodeFunction, cs, id)
		end
	end

	-- compile all events nodes in the graph
	for id, node in cs.graph:Nodes() do
		local codeType = node:GetCodeType()
		if codeType == NT_Event then
			CompileGraphMetaHook(cs, graph, id, node:GetTypeName())
		elseif codeType == NT_FuncInput then
			CompileGraphMetaHook(cs, graph, id, graph:GetName())
		end
	end

	-- compile graph's entry function
	Profile(cs, "graph-entries", CompileGraphEntry, cs)

	--print("COMPILING GRAPH: " .. graph:GetName() .. " [" .. graph:GetFlags() .. "]")

	-- compile hook listing for each event (only events that have hook designations)
	cs.begin(CTX_Hooks .. cs.graph.id)

	for id, node in cs.graph:Nodes() do
		local codeType = node:GetCodeType()
		local hook = node:GetHook()
		if codeType == NT_Event and hook then

			cs.emit("[\"" .. node:GetTypeName() .. "\"] = {")

			cs.emit("\thook = \"" .. hook .. "\",")
			cs.emit("\tgraphID = " .. cs.graph.id .. ",")
			cs.emit("\tnodeID = " .. id .. ",")
			cs.emit("\tmoduleID = " .. cs.module.id .. ",")
			--cs.emit("\t\tfunc = nil,")

			cs.emit("},")

		end
	end

	if graph:HasFlag(bpgraph.FL_HOOK) then
		cs.emit("[\"" .. graph:GetName() .. "\"] = {")

		cs.emit("\thook = \"" .. graph:GetName() .. "\",")
		cs.emit("\tgraphID = " .. graph.id .. ",")
		cs.emit("\tnodeID = -1,")
		cs.emit("\tmoduleID = " .. cs.module.id .. ",")
		cs.emit("\tkey = \"__bphook_" .. cs.module.id .. "\"")
		--cs.emit("\t\tfunc = nil,")

		cs.emit("},")
	end

	cs.finish()

end

function Compile(mod)

	print("COMPILING MODULE...")

	local start = os.clock()

	-- compiler state
	local cs = {
		module = mod,
		compiledNodes = {},
		graphs = {},
		vars = {},
		nodejumps = {},
		contexts = {},
		current_context = nil,
		buffer = "",
		debug = true,
		debugcomments = true,
		ilp = true,
		ilpmax = 10000,
		ilpmaxh = 4,
		times = {},
		profile = false,
	}

	-- context control functions
	cs.begin = function(ctx)
		cs.current_context = ctx
		cs.buffer = {}
	end
	cs.emit = function(text)
		table.insert(cs.buffer, text)
	end
	cs.emitIndented = function(lines, tabcount)
		local t = string.rep("\t", tabcount or 0)
		for _, l in pairs(lines) do
			cs.emit( t .. l )
		end
	end
	cs.emitContext = function(context, tabcount)
		cs.emitIndented( cs.getContext( context ), tabcount )
	end
	cs.finish = function()
		cs.contexts[cs.current_context] = cs.buffer
		cs.buffer = {}
		cs.current_context = nil
	end
	cs.getContext = function(ctx)
		if not cs.contexts[ctx] then error("Compiler context not found: '" .. ctx .. "'") end
		return cs.contexts[ctx]
	end
	cs.getFilteredContexts = function(filter)
		local out = {}
		for k,v in pairs(cs.contexts) do
			if string.find(k, filter) ~= nil then out[k] = v end
		end
		return out
	end

	Profile(cs, "meta-lookup", CompileMetaTableLookup, cs)

	Profile(cs, "copy-graphs", function()

		-- make local copies of all module graphs so they can be edited without changing the module
		for id, graph in mod:Graphs() do
			table.insert( cs.graphs, graph:CopyInto( bpgraph.New() ) )
		end

	end)

	-- pre-compile all graphs in the module
	-- each graph shares a unique key table to ensure global variable names are distinct
	local uniqueKeys = {}
	for _, graph in pairs( cs.graphs ) do
		Profile(cs, "pregraph", PreCompileGraph, cs, graph, uniqueKeys )
	end

	-- compile the global variable listing (contains all global variables accross all graphs)
	Profile( cs, "global-var-listing", CompileGlobalVarListing, cs)

	-- compile each graph
	for _, graph in pairs( cs.graphs ) do
		Profile(cs, "graph", CompileGraph, cs, graph )
	end

	-- compile main code segment
	Profile(cs, "code-segment", CompileCodeSegment, cs)

	cs.compiled = table.concat( cs.getContext( CTX_Code ), "\n" )

	-- write compiled output to file for debugging
	file.Write("blueprints/last_compile.txt", cs.compiled)

	-- run the code and grab the __BPMODULE global
	RunString(cs.compiled, "")
	local x = __BPMODULE
	__BPMODULE = nil

	local finish = os.clock()

	local sorted = {}
	for k,v in pairs(cs.times) do table.insert(sorted, {k = k, s = v.samples, t = v.time, v = v.time / v.samples, min = v.min, max = v.max}) end
	table.sort(sorted, function(a,b) return a.t > b.t end)

	print("COMPILE TOOK: " .. (finish - start) .. " seconds.")

	if cs.profile then

		print( string.format("%-32s%7s%10s%6s%8s", "function", "avg", "total", "min", "max") )
		for _,t in pairs(sorted) do
			print( string.format("%-32s%8.2f%8.2f%8.2f%8.2f", " -" .. t.k .. "[" .. t.s .. "]: ", 
				t.v*1000, 
				t.t*1000,
				t.min*1000,
				t.max*1000))
		end

	end

	return x

end

if SERVER and bpdefs ~= nil then
	local mod = bpmodule.New()
	local funcid, graph = mod:NewGraph("MyFunction", GT_Function)
	--graph:ConnectNodes(1,1,2,1)
	--graph:ConnectNodes(1,2,2,2)
	--graph:ConnectNodes(1,3,2,3)

	graph.outputs:Add( bpvariable.New(), "retvar" )
	graph.outputs:Add( bpvariable.New(), "retvar2" )
	graph.inputs:Add( bpvariable.New(), "testVar" )

	local graphid, graph = mod:NewGraph("Events", GT_Event)
	graph:AddNode("__Call" .. funcid)

	mod:Compile()
	--local mod = bpmodule.CreateTestModule()
	--mod:Compile()
	--[[local code = Compile(mod)
	local inst = code.new()

	code.onError = function(msg, mod, graph, node)
		print("BLUEPRINT ERROR[" .. mod .. "]: " .. tostring(msg) .. " at " .. tostring(graph) .. "[" .. tostring(node) .. "]")
	end

	print("New Instance: " .. tostring(inst))
	PrintTable(getmetatable(inst))
	inst:PlayerTick()]]
end
