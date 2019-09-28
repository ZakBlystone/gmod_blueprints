AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpgraph.lua")
include("sh_bpnodedef.lua")

module("bpcompile", package.seeall, bpcommon.rescope(bpschema, bpnodedef))

indent = 0
function printi(...)
	Msg(string.rep(" ", indent))
	Msg(...)
	Msg("\n")
end

function pushi() indent = indent + 1 end
function popi() indent = indent - 1 end

local CTX_SingleNode = "singlenode_"
local CTX_FunctionNode = "functionnode_"
local CTX_Graph = "graph_"
local CTX_JumpTable = "jumptable_"
local CTX_MetaTables = "metatables_"
local CTX_Vars = "vars_"
local CTX_Code = "code"
local CTX_MetaEvents = "metaevents_"
local CTX_Hooks = "hooks_"

function EnumerateGraphVars(cs, nodeType, uniqueKeys)

	unique = uniqueKeys or {}
	for nodeID, node in cs.graph:Nodes() do
		local ntype = node.nodeType
		local extType = ntype.type
		if extType == nodeType then

			-- some nodetypes have local variables exclusive to themselves
			for _, l in pairs(ntype.locals or {}) do

				local key = "local_" .. ntype.name .. "_v_" .. l
				if unique[key] ~= nil then
					local id = 1
					local kx = key .. id
					while unique[kx] ~= nil do
						id = id + 1
						kx = key .. id
					end
					key = kx
				end
				unique[key] = 1

				table.insert(cs.vars, {
					id = #cs.vars,
					var = key,
					localvar = l,
					node = nodeID,
					graph = cs.graph.id,
				})

			end

			-- unconnected pins can contain literals, make internal variables for them
			for _, pinID in pairs(ntype.pinlayout.inputs) do
				local pin = ntype.pins[pinID]
				local pinType = cs.graph:GetPinType( nodeID, pinID )

				if node.literals and node.literals[pinID] ~= nil then

					local l = tostring(node.literals[pinID])
					if pinType == PN_String then
						l = "\"" .. l .. "\""
					end

					print("LITERAL: " .. node.literals[pinID] .. " " .. ntype.name .. "(" .. nodeID .. ")[" .. pinID .. "]")
					table.insert(cs.vars, {
						id = #cs.vars,
						var = l,
						type = pinType,
						literal = true,
						node = nodeID,
						pin = pinID,
						graph = cs.graph.id,
					})

				end

			end

			PrintTable(node.literals)

			-- output pins create local variables, if the function is non-pure, the return variable is global
			for _, pinID in pairs(ntype.pinlayout.outputs) do
				local pin = ntype.pins[pinID]
				local pinType = cs.graph:GetPinType( nodeID, pinID )

				if pinType == PN_Exec then continue end

				local key = "fcall_" .. ntype.name .. "_ret_" .. (pin[3] ~= "" and pin[3] or "pin")
				if unique[key] ~= nil then
					local id = 1
					local kx = key .. id
					while unique[kx] ~= nil do
						id = id + 1
						kx = key .. id
					end
					key = kx
				end
				unique[key] = 1
				table.insert(cs.vars, {
					id = #cs.vars,
					var = key,
					type = pinType,
					init = Defaults[pinType],
					global = ntype.type ~= NT_Pure,
					node = nodeID,
					pin = pinID,
					graph = cs.graph.id,
				})
			end
		end
	end

end

function FindLocalVarForNode(cs, nodeID, vname)

	for k,v in pairs(cs.vars) do

		if not v.localvar then continue end
		if v.graph ~= cs.graph.id then continue end
		if v.node == nodeID and v.localvar == vname then return v end

	end

end

function FindVarForPin(cs, nodeID, pinID)

	for k,v in pairs(cs.vars) do

		if v.localvar then continue end
		if v.graph ~= cs.graph.id then continue end
		if v.node == nodeID and v.pin == pinID then return v end

	end

end

function GetVarCode(cs, var)

	if var.global then return "__self." .. var.var end
	return var.var

end

function GetPinConnections(cs, pinDir, nodeID, pinID)

	local out = {}
	for k, v in cs.graph:Connections() do
		if pinDir == PD_In and (v[3] ~= nodeID or v[4] ~= pinID) then continue end
		if pinDir == PD_Out and (v[1] ~= nodeID or v[2] ~= pinID) then continue end
		table.insert(out, v)
	end
	return out

end

function GetNodePins(cs, nodeID, pinDir)

	local out = {}
	local node = cs.graph:GetNode(nodeID)
	for pinID, pin in pairs(node.nodeType.pins) do
		if pin[1] ~= pinDir then continue end
		out[pinID] = pin
	end
	return out

end

function GetGraphJumpTable(cs)

	cs.nodejumps[cs.graph.id] = cs.nodejumps[cs.graph.id] or {}
	return cs.nodejumps[cs.graph.id]

end

function CompileVars(cs, code, inVars, outVars, nodeID, ntype)

	local str = code

	printi("Compile Code: '" .. code .. "': " .. #inVars .. " " .. #outVars)

	str = string.Replace( str, "@graph", "graph_" .. cs.graph.id .. "_entry" )
	str = string.Replace( str, "!node", tostring(nodeID))
	str = string.Replace( str, "!graph", tostring(cs.graph.id))

	for k,v in pairs(inVars) do
		str = string.Replace( str, "$" .. k, GetVarCode(cs, v) )
	end

	for k,v in pairs(outVars) do
		str = string.Replace( str, "#" .. k, v.jump and "goto jmp_" .. GetVarCode(cs, v) or GetVarCode(cs, v) )
		str = string.Replace( str, "#_" .. k, GetVarCode(cs, v) )
	end

	for k,v in pairs(ntype.locals or {}) do
		local var = FindLocalVarForNode(cs, nodeID, v)
		if var == nil then error("Failed to find internal variable: " .. tostring(v)) end
		str = string.Replace( str, "%" .. v, GetVarCode(cs, var) )
	end

	local jumpTable = GetGraphJumpTable(cs)[nodeID]
	for k,v in pairs(jumpTable or {}) do
		print("REPL JUMP VECTOR: " .. k .. " = " .. v)
		str = string.Replace( str, "^" .. k, "jmp_" .. v )
		str = string.Replace( str, "^_" .. k, tostring(v) )
	end

	return str

end

function CompileNodeSingle(cs, nodeID)

	local node = cs.graph:GetNode(nodeID)
	local ntype = node.nodeType
	local lookup = ntype.pinlookup

	if not ntype.code then
		ErrorNoHalt("No code for node: " .. ntype.name .. "\n")
		return
	end

	cs.begin(CTX_SingleNode .. cs.graph.id .. "_" .. nodeID)

	pushi()
	printi("Compile Node: " .. node.nodeType.name .. "[" .. nodeID .. "]")

	local inVars = {}
	local outVars = {}

	for pinID, pin in pairs( GetNodePins(cs, nodeID, PD_In) ) do
		local pinType = cs.graph:GetPinType( nodeID, pinID )
		if pinType == PN_Exec then continue end

		local lookupID = lookup[pinID][2]
		local connections = GetPinConnections(cs, PD_In, nodeID, pinID)
		for _, v in pairs(connections) do

			local var = FindVarForPin(cs, v[1], v[2])
			if var then
				inVars[lookupID] = var
			else
				error("COULDN'T FIND INPUT VAR FOR " .. ntype.name)
			end

		end
		if #connections == 0 then
			printi("Pin Not Connected: " .. pin[3]) 

			local literalVar = FindVarForPin(cs, nodeID, pinID)
			if literalVar ~= nil then
				inVars[lookupID] = literalVar
			else
				local nullable = bit.band(pin[4], PNF_Nullable) ~= 0
				if nullable then
					printi("Pin is nullable")
					inVars[lookupID] = { var = "nil" }
				else
					error("Pin must be connected: " .. ntype.name .. "." .. pin[3])
				end
			end
		end

		printi("<< " .. pinID .. " : " .. #inVars .. " => " .. pin[3])

	end

	for pinID, pin in pairs( GetNodePins(cs, nodeID, PD_Out) ) do
		
		local pinType = cs.graph:GetPinType( nodeID, pinID )
		local lookupID = lookup[pinID][2]
		local connections = GetPinConnections(cs, PD_Out, nodeID, pinID)
		if ntype.type == NT_Event then

			outVars[lookupID] = FindVarForPin(cs, nodeID, pinID)
			if outVars[lookupID] ~= nil then PrintTable(outVars[lookupID]) end

		else

			if pinType == PN_Exec then
				outVars[lookupID] = {
					var = #connections == 0 and "0" or connections[1][3],
					jump = true,
				}

			else

				local var = FindVarForPin(cs, nodeID, pinID)
				if var then 
					--table.insert(outVars, var)
					printi("ASGN >> " .. pinID .. " : " .. lookupID .. " => " .. pin[3])
					outVars[lookupID] = var
				else
					error("Unable to find var for pin " .. ntype.name .. "." .. pin[3])
				end

			end

		end

		printi(">> " .. pinID .. " : " .. lookupID .. " => " .. pin[3])

	end	

	local code = ntype.code
	code = string.Replace(code, "\t", "")
	code = CompileVars(cs, code, inVars, outVars, nodeID, ntype)

	if cs.ilp and ntype.type == NT_Function or ntype.type == NT_Special then
		cs.emit("__ilp = __ilp + 1 if __ilp > " .. cs.ilpmax .. " then __ilptrip = true goto __terminus end")
	end

	if cs.debug then
		cs.emit("__dbgnode = " .. nodeID)
	end

	for _, l in pairs(string.Explode("\n", code)) do
		cs.emit(l)
	end

	--cs.emit("\t" .. code)
	cs.finish()

	popi()

	--PrintTable(node)

end

function WalkBackPureNodes(cs, nodeID, call)

	local max = 10000
	local stack = {}
	local output = {}
	table.insert(stack, nodeID)

	while #stack > 0 and max > 0 do

		max = max - 1

		local pnode = stack[#stack]
		table.remove(stack, #stack)

		for pinID, pin in pairs( GetNodePins(cs, pnode, PD_In) ) do

			local connections = GetPinConnections(cs, PD_In, pnode, pinID)
			for _, v in pairs(connections) do

				if cs.graph:GetNode( v[1] ).nodeType.type == NT_Pure then
					table.insert(stack, v[1])
					table.insert(output, v[1])
				end

			end

		end

	end

	for i=#output, 1, -1 do
		call(output[i])
	end

end

function CompileNodeFunction(cs, nodeID)

	local node = cs.graph:GetNode(nodeID)
	if node.nodeType.type == NT_Event then 
		cs.begin(CTX_FunctionNode .. cs.graph.id .. "_" .. nodeID)

		if cs.debugcomments then cs.emit("-- " .. node.nodeType.name) end

		cs.emit("::jmp_" .. nodeID .. "::")

		local jumps = false
		for pinID, pin in pairs( GetNodePins(cs, nodeID, PD_Out) ) do
			local pinType = cs.graph:GetPinType( nodeID, pinID )

			if pinType == PN_Exec then
				local connections = GetPinConnections(cs, PD_Out, nodeID, pinID)
				for _, v in pairs(connections) do
					cs.emit("\tgoto jmp_" .. v[3])
					jumps = true
				end
			end

		end

		if not jumps then
			cs.emit("\tgoto popcall")
		end

		cs.finish()
		return 
	end

	cs.begin(CTX_FunctionNode .. cs.graph.id .. "_" .. nodeID)

	if cs.debugcomments then cs.emit("-- " .. node.nodeType.name) end

	cs.emit("::jmp_" .. nodeID .. "::")

	pushi()
	printi("COMPILE FUNC: " .. node.nodeType.name)

	pushi()
	local emitted = {}
	WalkBackPureNodes(cs, nodeID, function(pure)
		if emitted[pure] then return end
		emitted[pure] = true
		printi(cs.graph:GetNode(pure).nodeType.name)
		cs.emitContext( CTX_SingleNode .. cs.graph.id .. "_" .. pure, 1 )
	end)
	popi()

	cs.emitContext( CTX_SingleNode .. cs.graph.id .. "_" .. nodeID, 1 )

	popi()

	cs.finish()

end

function CompileMetaTableLookup(cs)

	cs.begin(CTX_MetaTables)

	local tables = {
		"Player",
		"Entity",
		"PhysObj",
	}

	for k, v in pairs(tables) do
		cs.emit("local " .. v ..  "_ = FindMetaTable(\"" .. v .. "\")")
	end

	cs.finish()

end

function CompileGraphJumpTable(cs)

	cs.begin(CTX_JumpTable .. cs.graph.id)

	local nextJumpID = 0

	cs.emit( "if ip == 0 then goto jmp_0 end" )

	for id, node in cs.graph:Nodes() do
		if node.nodeType.type ~= NT_Pure then
			cs.emit( "if ip == " .. id .. " then goto jmp_" .. id .. " end" )
		end
		nextJumpID = math.max(nextJumpID, id+1)
	end

	local jumpTable = GetGraphJumpTable(cs)
	for id, node in cs.graph:Nodes() do
		for _, j in pairs(node.nodeType.jumpSymbols or {}) do

			jumpTable[id] = jumpTable[id] or {}
			jumpTable[id][j] = nextJumpID
			MsgC(Color(80,255,80), "JUMP VECTOR: " .. id .. " = " .. nextJumpID .. "\n")
			cs.emit( "if ip == " .. nextJumpID .. " then goto jmp_" .. nextJumpID .. " end" )
			nextJumpID = nextJumpID + 1

		end
	end

	cs.finish()

end

function CompileGlobalVarListing(cs)

	cs.begin(CTX_Vars .. "global")

	for k, v in pairs(cs.vars) do

		if not v.literal and v.global then

			cs.emit("instance." .. v.var .. " = nil")

		end

	end

	cs.finish()

end

function CompileGraphVarListing(cs)

	cs.begin(CTX_Vars .. cs.graph.id)

	for k, v in pairs(cs.vars) do

		if v.graph ~= cs.graph.id then continue end
		if not v.literal and not v.global then

			cs.emit("local " .. v.var .. " = nil")

		end

	end

	cs.finish()

end

function CompileGraphEntry(cs)

	local graphID = cs.graph.id

	print("ENTRY: " .. CTX_Graph .. graphID)
	cs.begin(CTX_Graph .. graphID)

	cs.emit("\nlocal function graph_" .. graphID .. "_entry( ip )\n")

	cs.emit("\tlocal cs = {}")

	if cs.debug then
		cs.emit( "\t__dbggraph = " .. graphID)
	end

	cs.emitContext( CTX_Vars .. graphID, 1 )

	cs.emit( "\tlocal function pushjmp(i) table.insert(cs, 1, i) end")

	cs.emit( "\tgoto jumpto" )

	cs.emit( "\n\t::jmp_0:: ::popcall::\n\tif #cs > 0 then ip = cs[1] table.remove(cs, 1) else goto __terminus end" )

	cs.emit( "\n\t::jumpto::" )

	cs.emitContext( CTX_JumpTable .. graphID, 1 )

	local code = cs.getFilteredContexts( CTX_FunctionNode .. cs.graph.id )
	for k, _ in pairs(code) do
		cs.emitContext( k, 1 )
	end

	cs.emit("\n\t::__terminus::\n")
	cs.emit("end")

	cs.finish()

	--print(table.concat( cs.getContext( CTX_Graph .. cs.graph.id ), "\n" ))

end

function CompileCodeSegment(cs)

	cs.begin(CTX_Code)

	cs.emitContext( CTX_MetaTables )
	cs.emit("local __self = nil")

	if cs.debug then
		cs.emit( "local __dbgnode = -1")
		cs.emit( "local __dbggraph = -1")
	end

	if cs.ilp then
		cs.emit( "local __ilptrip = false" )
		cs.emit( "local __ilp = 0" )
		cs.emit( "local __ilph = 0" )
	end

	cs.emit("local __bpm = {}")
	--cs.emitContext( CTX_Graph .. cs.graph.id  )

	for id in cs.module:GraphIDs() do
		print("EMIT: " .. CTX_Graph .. id )
		cs.emitContext( CTX_Graph .. id )
	end

	if cs.ilp then
		cs.emit("__bpm.checkilp = function()")
		cs.emit("\tif __ilph > " .. cs.ilpmaxh .. " then __bpm.onError(\"Infinite loop in hook\", " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) return true end")
		cs.emit("\tif __ilptrip then __bpm.onError(\"Infinite loop\", " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) return true end")
		cs.emit("end")
	end
	cs.emit("local meta = BLUEPRINT_OVERRIDE_META or {}")
	cs.emit("if BLUEPRINT_OVERRIDE_META == nil then meta.__index = meta end")
	cs.emit("__bpm.meta = meta")
	cs.emit("__bpm.delays = {}")
	cs.emit("__bpm.delayExists = function(key)")
	cs.emit("\tfor i=#__bpm.delays, 1, -1 do if __bpm.delays[i].key == key then return true end end")
	cs.emit("\treturn false")
	cs.emit("end")

	cs.emit("__bpm.delay = function(key, delay, func)")
	cs.emit("\tfor i=#__bpm.delays, 1, -1 do if __bpm.delays[i].key == key then table.remove(__bpm.delays, i) end end")
	cs.emit("\ttable.insert( __bpm.delays, { key = key, func = func, time = delay })")
	cs.emit("end")

	cs.emit("__bpm.onError = function(msg, mod, graph, node) end")
	cs.emit("__bpm.call = function(eventName, ...)")
	cs.emit("\tlocal evt = __bpm.events[eventName]")
	cs.emit("\tif not evt then __bpm.onError(\"Event \" .. eventName .. \" doesn't exist.\",-1,-1) return end")
	cs.emit("\tlocal s, a,b,c,d,e,f,g = pcall( evt.func, ... )")
	cs.emit("\tif not s then __bpm.onError(a:sub(a:find(':', 11)+2, -1), " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) end")
	cs.emit("end")

	cs.emit("__bpm.update = function()")
	cs.emit("\tlocal dt = FrameTime()")
	if cs.ilp then cs.emit("\t__ilph = 0") end
	cs.emit("\tfor i=#__bpm.delays, 1, -1 do")
	cs.emit("\t\t__bpm.delays[i].time = __bpm.delays[i].time - dt")
	cs.emit("\t\tif __bpm.delays[i].time <= 0 then __bpm.delays[i].func() table.remove(__bpm.delays, i) end")
	cs.emit("\tend")
	cs.emit("end")

	for k, _ in pairs( cs.getFilteredContexts(CTX_MetaEvents) ) do
		cs.emitContext( k )
	end

	cs.emit("__bpm.new = function()")
	cs.emit("\tlocal instance = setmetatable({}, meta)")
	cs.emitContext( CTX_Vars .. "global", 1 )
	cs.emit("\treturn instance")
	cs.emit("end")
	cs.emit("__bpm.events = {")

	for k, _ in pairs( cs.getFilteredContexts(CTX_Hooks) ) do
		cs.emitContext( k, 1 )
	end

	cs.emit("}")

	cs.emit("__BPMODULE = __bpm")


	cs.finish()

end

function PreCompileGraph(cs, graph, uniqueKeys)

	cs.graph = graph

	EnumerateGraphVars(cs, NT_Pure)
	EnumerateGraphVars(cs, NT_Function, uniqueKeys)
	EnumerateGraphVars(cs, NT_Event, uniqueKeys)
	EnumerateGraphVars(cs, NT_Special, uniqueKeys)

	CompileGraphJumpTable(cs)
	CompileGraphVarListing(cs)

end

function CompileGraphMetaHook(cs, graph, nodeID)

	local node = cs.graph:GetNode(nodeID)

	cs.begin(CTX_MetaEvents .. node.nodeType.name)

	cs.emit("function meta:" .. node.nodeType.name .. "(...)")

	cs.emit("\tlocal arg = {...}")
	cs.emit("\t__self = self")
	cs.emitContext( CTX_SingleNode .. cs.graph.id .. "_" .. nodeID, 1 )

	if cs.ilp then
		cs.emit("\tif __bpm.checkilp() then return end")
		cs.emit("\t__ilptrip = false")
		cs.emit("\t__ilp = 0")
		cs.emit("\t__ilph = __ilph + 1")
	end

	cs.emit("\tlocal b,e = pcall(graph_" .. cs.graph.id .. "_entry, " .. nodeID .. ")")
	cs.emit("\tif not b then __bpm.onError(tostring(e), " .. cs.module.id .. ", __dbggraph or -1, __dbgnode or -1) end")

	if cs.ilp then
		cs.emit("\tif __bpm.checkilp() then return end")
		cs.emit("\t__ilph = __ilph - 1")
	end

	cs.emit("end")

	cs.finish()

end

function CompileGraph(cs, graph)

	cs.graph = graph

	for id in cs.graph:NodeIDs() do
		CompileNodeSingle(cs, id)
	end

	for id, node in cs.graph:Nodes() do
		if node.nodeType.type ~= NT_Pure then
			CompileNodeFunction(cs, id)
		end
	end

	for id, node in cs.graph:Nodes() do
		if node.nodeType.type == NT_Event then
			CompileGraphMetaHook(cs, graph, id)
		end
	end

	CompileGraphEntry(cs)

	cs.begin(CTX_Hooks .. cs.graph.id)

	for id, node in cs.graph:Nodes() do
		if node.nodeType.type == NT_Event and node.nodeType.hook then

			cs.emit("[\"" .. node.nodeType.name .. "\"] = {")

			cs.emit("\thook = \"" .. node.nodeType.hook .. "\",")
			cs.emit("\tgraphID = " .. cs.graph.id .. ",")
			cs.emit("\tnodeID = " .. id .. ",")
			cs.emit("\tmoduleID = " .. cs.module.id .. ",")
			cs.emit("\tkey = \"__bphook_" .. cs.module.id .. "\"")
			--cs.emit("\t\tfunc = nil,")

			cs.emit("},")

		end
	end

	cs.finish()

end

function Compile(mod)

	print("COMPILE MODULE")

	local cs = {
		module = mod,
		compiledNodes = {},
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
	}
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

	CompileMetaTableLookup(cs)

	local uniqueKeys = {}
	for id, graph in mod:Graphs() do
		PreCompileGraph( cs, graph, uniqueKeys )
	end

	CompileGlobalVarListing(cs)

	for id, graph in mod:Graphs() do
		CompileGraph( cs, graph )
	end

	CompileCodeSegment(cs)

	cs.compiled = table.concat( cs.getContext( CTX_Code ), "\n" )

	--print(cs.compiled)
	file.Write("blueprints/last_compile.txt", cs.compiled)

	RunString(cs.compiled, "")
	local x = __BPMODULE
	__BPMODULE = nil
	return x

end

if SERVER then
	local mod = bpmodule.CreateTestModule()
	mod:Compile()
	--[[local code = Compile(mod)
	local inst = code.new()

	code.onError = function(msg, mod, graph, node)
		print("BLUEPRINT ERROR[" .. mod .. "]: " .. tostring(msg) .. " at " .. tostring(graph) .. "[" .. tostring(node) .. "]")
	end

	print("New Instance: " .. tostring(inst))
	PrintTable(getmetatable(inst))
	inst:PlayerTick()]]
end