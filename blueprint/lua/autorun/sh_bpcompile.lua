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

function EnumerateVars(cs, nodeType)

	local unique = {}
	for nodeID, node in pairs(cs.graph.nodes) do
		local ntype = node.nodeType
		local extType = ntype.type
		if extType == nodeType then

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
				})

			end

			for _, pinID in pairs(ntype.pinlayout.inputs) do
				local pin = ntype.pins[pinID]

				if node.literals and node.literals[pinID] ~= nil then

					local l = tostring(node.literals[pinID])
					if pin[2] == PN_String then
						l = "\"" .. l .. "\""
					end

					print("LITERAL: " .. node.literals[pinID] .. " " .. ntype.name .. "(" .. nodeID .. ")[" .. pinID .. "]")
					table.insert(cs.vars, {
						id = #cs.vars,
						var = l,
						type = pin[2],
						literal = true,
						node = nodeID,
						pin = pinID,
					})

				end

			end

			PrintTable(node.literals)

			for _, pinID in pairs(ntype.pinlayout.outputs) do
				local pin = ntype.pins[pinID]
				if pin[2] == PN_Exec then continue end

				local key = "fcall_" .. ntype.name .. "_ret_" .. pin[3]
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
					type = pin[2],
					init = Defaults[pin[2]],
					global = ntype.type ~= NT_Pure,
					node = nodeID,
					pin = pinID,
				})
			end
		end
	end

end

function FindLocalVarForNode(cs, nodeID, vname)

	for k,v in pairs(cs.vars) do

		if not v.localvar then continue end
		if v.node == nodeID and v.localvar == vname then return v end

	end

end

function FindVarForPin(cs, nodeID, pinID)

	for k,v in pairs(cs.vars) do

		if v.localvar then continue end
		if v.node == nodeID and v.pin == pinID then return v end

	end

end

function GetPinConnections(cs, pinDir, nodeID, pinID)

	local out = {}
	for k, v in pairs(cs.graph.connections) do
		if pinDir == PD_In and (v[3] ~= nodeID or v[4] ~= pinID) then continue end
		if pinDir == PD_Out and (v[1] ~= nodeID or v[2] ~= pinID) then continue end
		table.insert(out, v)
	end
	return out

end

function GetNodePins(cs, nodeID, pinDir)

	local out = {}
	local node = cs.graph.nodes[nodeID]
	for pinID, pin in pairs(node.nodeType.pins) do
		if pin[1] ~= pinDir then continue end
		out[pinID] = pin
	end
	return out

end

function CompileVars(cs, code, inVars, outVars, nodeID, ntype)

	local str = code

	printi("Compile Code: '" .. code .. "': " .. #inVars .. " " .. #outVars)

	str = string.Replace( str, "@graph", "graph_" .. cs.graph.id .. "_entry" )
	str = string.Replace( str, "!node", tostring(nodeID))
	str = string.Replace( str, "!graph", tostring(cs.graph.id))

	for k,v in pairs(inVars) do
		str = string.Replace( str, "$" .. k, v.var )
	end

	for k,v in pairs(outVars) do
		str = string.Replace( str, "#" .. k, v.jump and "goto jmp_" .. v.var or v.var )
		str = string.Replace( str, "#_" .. k, v.var )
	end

	for k,v in pairs(ntype.locals or {}) do
		local var = FindLocalVarForNode(cs, nodeID, v)
		if var == nil then error("Failed to find internal variable: " .. tostring(v)) end
		str = string.Replace( str, "%" .. v, var.var )
	end

	for k,v in pairs(cs.nodejumps[nodeID] or {}) do
		print("REPL JUMP VECTOR: " .. k)
		str = string.Replace( str, "^" .. k, "jmp_" .. v )
		str = string.Replace( str, "^_" .. k, tostring(v) )
	end

	return str

end

function CompileNodeSingle(cs, nodeID)

	local node = cs.graph.nodes[nodeID]
	local ntype = node.nodeType
	local lookup = ntype.pinlookup

	if not ntype.code then
		ErrorNoHalt("No code for node: " .. ntype.name .. "\n")
		return
	end

	cs.begin(CTX_SingleNode .. nodeID)

	pushi()
	printi("Compile Node: " .. node.nodeType.name .. "[" .. nodeID .. "]")

	local inVars = {}
	local outVars = {}

	for pinID, pin in pairs( GetNodePins(cs, nodeID, PD_In) ) do
		if pin[2] == PN_Exec then continue end

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
		
		local lookupID = lookup[pinID][2]
		local connections = GetPinConnections(cs, PD_Out, nodeID, pinID)
		if ntype.type == NT_Event then

			outVars[lookupID] = FindVarForPin(cs, nodeID, pinID)
			if outVars[lookupID] ~= nil then PrintTable(outVars[lookupID]) end

		else

			if pin[2] == PN_Exec then
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

				if cs.graph.nodes[ v[1] ].nodeType.type == NT_Pure then
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

	local node = cs.graph.nodes[nodeID]
	if node.nodeType.type == NT_Event then 
		cs.begin(CTX_FunctionNode .. nodeID)

		if cs.debugcomments then cs.emit("-- " .. node.nodeType.name) end

		cs.emit("::jmp_" .. nodeID .. "::")

		local jumps = false
		for pinID, pin in pairs( GetNodePins(cs, nodeID, PD_Out) ) do

			if pin[2] == PN_Exec then
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

	cs.begin(CTX_FunctionNode .. nodeID)

	if cs.debugcomments then cs.emit("-- " .. node.nodeType.name) end

	cs.emit("::jmp_" .. nodeID .. "::")

	pushi()
	printi("COMPILE FUNC: " .. node.nodeType.name)

	pushi()
	local emitted = {}
	WalkBackPureNodes(cs, nodeID, function(pure)
		if emitted[pure] then return end
		emitted[pure] = true
		printi(cs.graph.nodes[pure].nodeType.name)
		cs.emitContext( CTX_SingleNode .. pure, 1 )
	end)
	popi()

	cs.emitContext( CTX_SingleNode .. nodeID, 1 )

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

function CompileJumpTable(cs)

	cs.begin(CTX_JumpTable .. cs.graph.id)

	local nextJumpID = 0

	cs.emit( "if ip == 0 then goto jmp_0 end" )

	for k, v in pairs(cs.graph.nodes) do
		if v.nodeType.type ~= NT_Pure then
			cs.emit( "if ip == " .. k .. " then goto jmp_" .. k .. " end" )
		end
		nextJumpID = math.max(nextJumpID, k+1)
	end

	for k, v in pairs(cs.graph.nodes) do
		for _, j in pairs(v.nodeType.jumpSymbols or {}) do

			cs.nodejumps[k] = cs.nodejumps[k] or {}
			cs.nodejumps[k][j] = nextJumpID
			print("JUMP VECTOR: " .. j .. " = " .. nextJumpID)
			cs.emit( "if ip == " .. nextJumpID .. " then goto jmp_" .. nextJumpID .. " end" )
			nextJumpID = nextJumpID + 1

		end
	end

	cs.finish()

end

function CompileVarListing(cs)

	cs.begin(CTX_Vars .. "global")

	for k, v in pairs(cs.vars) do

		if not v.literal and v.global then

			cs.emit("local " .. v.var .. " = nil")

		end

	end

	cs.finish()

	cs.begin(CTX_Vars .. cs.graph.id)

	for k, v in pairs(cs.vars) do

		if not v.literal and not v.global then

			cs.emit("local " .. v.var .. " = nil")

		end

	end

	cs.finish()

end

function CompileGraphEntry(cs)

	cs.begin(CTX_Graph .. cs.graph.id)

	cs.emit("\nlocal function graph_" .. cs.graph.id .. "_entry( ip )\n")

	cs.emit("\tlocal cs = {}")

	if cs.debug then
		cs.emit( "\t__dbggraph = " .. cs.graph.id)
	end

	cs.emitContext( CTX_Vars .. cs.graph.id, 1 )

	cs.emit( "\tlocal function pushjmp(i) table.insert(cs, 1, i) end")

	cs.emit( "\tgoto jumpto" )

	cs.emit( "\n\t::jmp_0:: ::popcall::\n\tif #cs > 0 then ip = cs[1] table.remove(cs, 1) else goto __terminus end" )

	cs.emit( "\n\t::jumpto::" )

	cs.emitContext( CTX_JumpTable .. cs.graph.id, 1 )

	local code = cs.getFilteredContexts("functionnode")
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
	cs.emitContext( CTX_Vars .. "global" )
	cs.emitContext( CTX_Graph .. cs.graph.id  )

	if cs.ilp then
		cs.emit("__bpm.checkilp = function()")
		cs.emit("\tif __ilph > " .. cs.ilpmaxh .. " then __bpm.onError(\"Infinite loop in hook\", __dbggraph or -1, __dbgnode or -1) return true end")
		cs.emit("\tif __ilptrip then __bpm.onError(\"Infinite loop\", __dbggraph or -1, __dbgnode or -1) return true end")
		cs.emit("end")
	end
	cs.emit("__bpm.delays = {}")
	cs.emit("__bpm.delay = function(graph, node, delay, func)")
	cs.emit("\tlocal key = graph .. node")
	cs.emit("\tfor i=#__bpm.delays, 1, -1 do if __bpm.delays[i].key == key then table.remove(__bpm.delays, i) end end")
	cs.emit("\ttable.insert( __bpm.delays, { key = key, func = func, time = delay })")
	cs.emit("end")

	cs.emit("__bpm.onError = function(msg, graph, node) end")
	cs.emit("__bpm.call = function(eventName, ...)")
	cs.emit("\tlocal evt = __bpm.events[eventName]")
	cs.emit("\tif not evt then __bpm.onError(\"Event \" .. eventName .. \" doesn't exist.\",-1,-1) return end")
	cs.emit("\tlocal s, a,b,c,d,e,f,g = pcall( evt.func, ... )")
	cs.emit("\tif not s then __bpm.onError(a:sub(a:find(':', 11)+2, -1), __dbggraph or -1, __dbgnode or -1) end")
	cs.emit("end")

	cs.emit("__bpm.update = function()")
	cs.emit("\tlocal dt = FrameTime()")
	if cs.ilp then cs.emit("\t__ilph = 0") end
	cs.emit("\tfor i=#__bpm.delays, 1, -1 do")
	cs.emit("\t\t__bpm.delays[i].time = __bpm.delays[i].time - dt")
	cs.emit("\t\tif __bpm.delays[i].time <= 0 then __bpm.delays[i].func() table.remove(__bpm.delays, i) end")
	cs.emit("\tend")
	cs.emit("end")

	cs.emit("__bpm.events = {")
	cs.emit("\t[\"InternalUpdate\"] = { hook = \"Think\", graphID = " .. cs.graph.id .. ", nodeID = -1, func = __bpm.update },")

	for k, v in pairs(cs.graph.nodes) do
		if v.nodeType.type == NT_Event then

			cs.emit("\t[\"" .. v.nodeType.name .. "\"] = {")

			if v.nodeType.hook then

				cs.emit("\t\thook = \"" .. v.nodeType.hook .. "\",")

			end

			cs.emit("\t\tgraphID = " .. cs.graph.id .. ",")
			cs.emit("\t\tnodeID = " .. k .. ",")
			cs.emit("\t\tfunc = function(...)")

			cs.emit("\t\t\tlocal arg = {...}")

			cs.emitContext( CTX_SingleNode .. k, 3 )

			if cs.ilp then
				cs.emit("\t\t\tif __bpm.checkilp() then return end")
				cs.emit("\t\t\t__ilptrip = false")
				cs.emit("\t\t\t__ilp = 0")
				cs.emit("\t\t\t__ilph = __ilph + 1")
			end

			cs.emit("\t\t\tgraph_" .. cs.graph.id .. "_entry(" .. k .. ")")

			if cs.ilp then
				cs.emit("\t\t\tif __bpm.checkilp() then return end")
				cs.emit("\t\t\t__ilph = __ilph - 1")
			end

			cs.emit("\t\tend")

			cs.emit("\t},")

		end
	end

	cs.emit("}")

	cs.emit("__BPMODULE = __bpm")


	cs.finish()

end

function Compile(graph)

	print("COMPILE GRAPH")

	local cs = {
		graph = graph,
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
		return cs.contexts[ctx]
	end
	cs.getFilteredContexts = function(filter)
		local out = {}
		for k,v in pairs(cs.contexts) do
			if string.find(k, filter) ~= nil then out[k] = v end
		end
		return out
	end

	EnumerateVars(cs, NT_Pure)
	EnumerateVars(cs, NT_Function)
	EnumerateVars(cs, NT_Event)
	EnumerateVars(cs, NT_Special)

	CompileJumpTable(cs)

	for k, v in pairs(cs.graph.nodes) do
		--if v.nodeType.type ~= NT_Event then
			CompileNodeSingle(cs, k)
		--end
	end

	for k, v in pairs(cs.graph.nodes) do
		if v.nodeType.type ~= NT_Pure then
			CompileNodeFunction(cs, k)
		end
	end

	CompileMetaTableLookup(cs)
	CompileVarListing(cs)
	CompileGraphEntry(cs)
	CompileCodeSegment(cs)

	cs.compiled = table.concat( cs.getContext( CTX_Code ), "\n" )
	print(cs.compiled)

	file.Write("last_compile.txt", cs.compiled)

	RunString(cs.compiled)
	local x = __BPMODULE
	__BPMODULE = nil
	return x

end

if SERVER then
	local graph = bpgraph.CreateTestGraph()
	local code = Compile(graph)
end