AddCSLuaFile()

module("bpcompiledmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema))

local meta = bpcommon.MetaTable("bpcompiledmodule")
local fragments = {}

function meta:Init( mod, code, debugSymbols )

	if mod then
		self.type = mod:GetType()
		self.uniqueID = mod:GetUID()
	end

	self.code = code
	self.debugSymbols = debugSymbols
	self.unit = nil
	return self

end

function meta:TranslateCode( code )

	if self.translated then return self.translated end

	if code[1] ~= '\n' then code = "\n" .. code end

	code = code:gsub("([\n%s]+)_FR_(%w+)%(([^%)]*)%)", function(a, b, args)

		local fr = fragments[b:lower()]
		if args then
			if type(fr) == "string" then
				local i = 1
				for y in string.gmatch(args, "([^%),]+)[,%s]*") do
					fr = fr:gsub("\\" .. i, y)
					i = i + 1
				end
			else
				local t = {}
				for y in string.gmatch(args, "([^%),]+)[,%s]*") do
					t[#t+1] = y
				end
				fr = fr(t, self)
			end
		end
		return a .. fr:gsub("\n", "\n" .. a:gsub("\n", ""))

	end)

	self.translated = code

	return code

end

function meta:SetOwner( owner )

	self.owner = owner
	return self

end

function meta:GetOwner()

	return self.owner

end

function meta:GetType()

	return self.type

end

function meta:GetUID()

	return self.uniqueID

end

function meta:GetCode( raw )

	if not raw then
		return self:TranslateCode( self.code )
	end

	return self.code

end

function meta:IsValid()

	return self.unit ~= nil

end

function meta:Get()

	return self.unit

end

function meta:Load()

	if self.unit then return self end
	local code = self:GetCode()
	local result = CompileString(code, "bpmodule[" .. bpcommon.GUIDToString( self:GetUID() ) .. "]")
	if result then self.unit = result() end
	return self

end

function meta:TryLoad()

	local code = self:GetCode()
	local result, err = CompileString(code, "bpmodule[" .. bpcommon.GUIDToString( self:GetUID() ) .. "]", false)
	if not result then return false, err end
	if type(result) == "string" then return false, result end
	self.unit = result()
	return true, self

end

function meta:FormatErrorMessage( msg, graphID, nodeID )

	local dbgGraph = self:LookupGraph( graphID )
	local dbgNode = self:LookupNode( nodeID )
	if not dbgNode or not dbgGraph then return msg end

	msg = msg:gsub("bpmodule%[.+%]:%d+:", "")
	msg = "[%graph]" .. msg
	msg = msg:gsub("%%node", dbgNode[2] or dbgNode[1])
	msg = msg:gsub("%%graph", dbgGraph[1])

	return msg

end

local imeta = {}

function imeta:__GetModule()

	return self.__module

end

function imeta:__BindGamemodeHooks()

	local meta = getmetatable(self)

	if self.CORE_Init then self:CORE_Init() end
	local bpm = self.__bpm

	for k,v in pairs(bpm.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local function call(...) return self[k](self, ...) end
		local key = "bphook_" .. GUIDToString(self.guid, true)
		--print("BIND KEY: " .. v.hook .. " : " .. key)
		hook.Add(v.hook, key, call)
	end

end

function imeta:__UnbindGamemodeHooks()

	local meta = getmetatable(self)

	if self.shuttingDown then ErrorNoHalt("!!!!!Recursive shutdown!!!!!") return end
	local bpm = self.__bpm

	for k,v in pairs(bpm.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local key = "bphook_" .. GUIDToString(self.guid, true)
		--print("UNBIND KEY: " .. v.hook .. " : " .. key)
		hook.Remove(v.hook, key, false)
	end

	self.shuttingDown = true
	if self.CORE_Shutdown then self:CORE_Shutdown() end
	self.shuttingDown = false

end

function imeta:__Init( )

	if self.netInit then self:netInit() end
	self:__BindGamemodeHooks()

end

function imeta:__Shutdown()

	if self.netShutdown then self:netShutdown() end
	self:__UnbindGamemodeHooks()

end

function meta:Instantiate( forceGUID )

	local func = self:Get().new
	if not func then return nil end

	local instance = func()
	local meta = bpcommon.CopyTable(getmetatable(instance))
	for k,v in pairs(imeta) do meta[k] = v end
	setmetatable(instance, meta)
	instance.__module = self
	if forceGUID then instance.guid = forceGUID end
	return instance

end

function meta:Refresh()

	local func = self:Get().refresh
	if func then func() end

end

function meta:Initialize()

	local func = self:Get().init
	if func then func() end

end

function meta:Shutdown()

	local func = self:Get().shutdown
	if func then func() end

end

function meta:AttachErrorHandler()

	if self.errorHandler ~= nil then
		self:Get().onError = function(msg, mod, graph, node)
			self.errorHandler(self, msg, graph, node)
		end
	end

end

function meta:SetErrorHandler(errorHandler)

	self.errorHandler = errorHandler

	if self:IsValid() then
		self:AttachErrorHandler()
	end

end

function meta:Serialize(stream)

	self.uniqueID = stream:GUID(self.uniqueID)
	self.type = stream:Value(self.type)
	self.code = stream:Value(self.code)
	--self.debugSymbols = stream:Value(self.debugSymbols)
	return stream

end

function meta:LookupNode(id)

	return self.debugSymbols.nodes[id]

end

function meta:LookupGraph(id)

	return self.debugSymbols.graphs[id]

end

function New(...)
	return setmetatable({}, meta):Init(...)
end

fragments["nethead"] = [[
G_BPNetHandlers = G_BPNetHandlers or {}
G_BPNetChannels = G_BPNetChannels or {}
net.Receive("bpmessage", function(...) local ch = G_BPNetChannels[net.ReadUInt(16)] if ch ~= nil then ch:netReceiveMessage(...) end end)
net.Receive("bpclosechannel", function(len, pl) G_BPNetChannels[net.ReadUInt(16)] = nil end)
net.Receive("bphandshake", function(len, pl) local mod, inst = net.ReadData(16), net.ReadData(16)
	for _, v in ipairs(G_BPNetHandlers) do if v.__bpm.guid == mod and inst == v.guid then v:netReceiveHandshake(inst, len, pl) end end
end)
local __net = {}
function __net:netInit()
	self.netReady, self.ncl = false, {} G_BPNetHandlers[#G_BPNetHandlers+1] = self
	if SERVER then local id for i=0, 65535 do if G_BPNetChannels[i] == nil then id = i break elseif i == 65535 then error("Max network channels") end end
	G_BPNetChannels[id] = self self.chann = { id = id, guid = self.guid } return end
	net.Start("bphandshake") net.WriteData(self.__bpm.guid, 16) net.WriteData(self.guid, 16) net.WriteBool(false) net.SendToServer()
end
function __net:netShutdown()
	table.RemoveByValue(G_BPNetHandlers, self)
	if not self.chann or not G_BPNetChannels[self.chann.id] then return else G_BPNetChannels[self.chann.id] = nil end
	if SERVER then net.Start("bpclosechannel") net.WriteUInt(self.chann.id, 16) net.Broadcast() end
end
function __net:netUpdate()
	if not self.netReady then return end
	for i, c in ipairs(self.ncl) do local s,e = pcall(c.f, unpack(c.a)) s = s or self.__bpm.onError(e, 0, c.g, c.n) self.ncl[i] = nil end
end
function __net:netReceiveHandshake(inst, len, pl)
	if SERVER then if net.ReadBool() then self.netReady = true return end
	net.Start("bphandshake") net.WriteData(self.__bpm.guid, 16) net.WriteData(inst, 16) net.WriteUInt(self.chann.id, 16) net.Send(pl) return end
	self.chann = { id = net.ReadUInt(16), guid = self.guid }
	if G_BPNetChannels[self.chann.id] then error("Network channel already allocated") else G_BPNetChannels[self.chann.id] = self end
	net.Start("bphandshake") net.WriteData(self.__bpm.guid, 16) net.WriteData(self.guid, 16) net.WriteBool(true) net.SendToServer() self.netReady = true
end
function __net:netStartMessage(id) net.Start("bpmessage") net.WriteUInt(self.chann.id, 16) net.WriteUInt(id, 16) end
]]

fragments["netmain"] = [[
table.Merge( meta, __net )
function meta:netPostCall(f, ...) self.ncl[#self.ncl+1] = {f = f, a = {...}, g = __dbggraph or -1, n = __dbgnode or -1} end]]

fragments["support"] = function(args) 

	local str = ""
	if args[1] == "1" then
		str = [[
__bpm.checkilp = function()
	if __ilph > ]] .. args[2] .. [[ then __bpm.error("Infinite loop in hook") return true end
	if __ilptrip then __bpm.error("Infinite loop") return true end
end
]]
	end

return str .. [[
__bpm.delayExists = function(key) for i=#__self.delays, 1, -1 do if __self.delays[i].key == key then return true end end end
__bpm.delay = function(key, delay, func, ...) __bpm.delayKill(key) __self.delays[#__self.delays+1] = { key = key, f = func, t = delay, a = {...} } end
__bpm.delayKill = function(key) for i=#__self.delays, 1, -1 do if __self.delays[i].key == key then table.remove(__self.delays, i) end end end
__bpm.onError = function(msg, mod, graph, node) ]] .. (args[3] and "error(msg)" or "") .. [[ end
__bpm.error = function(msg) __bpm.onError(tostring(msg), 0, __dbggraph or -1, __dbgnode or -1) end]]

end

fragments["update"] = function(args)

	local x = "\n"
	if args[1] == "1" then x = "\n\t__ilph = 0\n" end

	local net = "\n"
	if args[2] == "1" then net = "\n\tself:netUpdate()\n" end

	return [[
function meta:update( rate )]] .. x .. [[
	__self = self
	rate = rate or FrameTime()]] .. net .. [[
	local t,d = self.delays
	for i=#t, 1, -1 do d = t[i] d.t = d.t - rate if d.t <= 0 then d.t = d.f(unpack(d.a)) if not d.t then table.remove(t,i) end end end
end]]

end

fragments["metahooks"] = [[
function meta:hookEvents( enable )
	local key = "bphook_"..__guidString(self.guid)
	for k,v in pairs(hook.GetTable()) do hook.Remove(k, key) end
	if not enable then return end
	for k,v in pairs(self.__bpm.events) do
		hook.Add( v.hook, key, function(...) return self[k](self, ...) end )
	end
end]]

fragments["projectfooter"] = [[
local function runAll(func, ...) for _, m in pairs(__modules) do if m[func] then m[func](...) end end end
__bpm = { onError = function() end }
__bpm.init = function() runAll("init") runAll("postInit") end
__bpm.shutdown = function() runAll("shutdown") end
__bpm.refresh = function() runAll("refresh") end
for _, m in pairs(__modules) do m.onError = function(...) __bpm.onError(...) end end
]]

-------------------------------------------------------- RUNTIME --------------------------------------------------------

fragments["standalonehead"] = [[
if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("bphandshake")
	util.AddNetworkString("bpmessage")
	util.AddNetworkString("bpclosechannel")
end]]

fragments["callstack"] = [[
sp=0 goto jumpto ::popcall:: if sp == 0 then goto __terminus end 
ip=cs[sp] sp=sp-1 ::jumpto::
]]

local netChecks = {
	["0"] = "",
	["1"] = "\n__svcheck()",
	["2"] = "\n__clcheck()",
}

fragments["jump"] = [[if ip == \1 then goto jmp_\1 end]]
fragments["ilpd"] = function(args)

	local ilp = args[1]
	local nodeID = args[2]
	local nodeRole = args[3] or "0"

	return [[
__ilp = __ilp + 1 if __ilp > ]] .. ilp .. [[ then __ilptrip = true goto __terminus end
__dbgnode = ]] .. nodeID .. netChecks[nodeRole]

end

fragments["ilp"] = [[__ilp = __ilp + 1 if __ilp > \1 then __ilptrip = true goto __terminus end]]
fragments["dbg"] = function(args)

	local nodeID = args[1]
	local nodeRole = args[2] or "0"

	return "__dbgnode = " .. nodeID .. netChecks[nodeRole]

end

fragments["jlist"] = function(jumps)

	local ret = ""
	for k, v in ipairs(jumps) do
		ret = ret .. (k == 1 and "" or "\n") .. "if ip == " .. v ..  " then goto " .. (v == "0" and "popcall" or "jmp_" .. v) .. " end"
	end
	return ret

end

fragments["locals"] = function(locals)

	local ret = ""
	for k, v in ipairs(locals) do
		ret = ret .. (k == 1 and "" or "\n") .. "local " .. v ..  " = nil"
	end
	return ret

end

fragments["ilocals"] = function(args)

	local n = tonumber(args[1])
	local ret = ""
	for k=0, n-1 do
		local id = k == 0 and "f" or "f" .. k
		ret = ret .. (k == 0 and "" or "\n") .. "local " .. id ..  " = nil"
	end
	return ret

end

fragments["mtl"] = function(tables)

	local ret = ""
	for k, v in ipairs(tables) do
		ret = ret .. (k == 1 and "" or "\n") .. "local " .. v ..  "_ = FindMetaTable(\"" .. v .. "\")"
	end
	return ret

end

fragments["mpcall"] = function(args)
	local ret = ""

	if args[1] == "1" then
		ret = ret .. "if __bpm.checkilp() then return end __ilptrip=false __ilp=0 __ilph=__ilph+1"
	end

	-- infinite-loop-protection, prevents a loop case where an event calls a function which in turn calls the event.
	-- a counter is incremented and as recursion happens, the counter increases.
	ret = ret .. [[

local b,e = pcall(graph_]] .. args[2] .. [[_entry, ]] .. args[3] .. [[) b = b or __bpm.error(e)]]

	if args[1] == "1" then
		ret = ret .. [[

if __bpm.checkilp() then return end __ilph = __ilph - 1]]
	end
	return ret

end

fragments["head"] = function(args)

	local ret = "local __self = nil\nlocal __targetPin = nil"
	if args[1] == "1" then
		ret = ret .. [[

local __dbgnode = -1
local __dbggraph = -1]]
	end

	if args[2] == "1" then
		ret = ret .. [[

local __ilptrip = false
local __ilp = 0
local __ilph = 0]]
	end

	return ret

end

fragments["modhead"] = function(args, mod)

	return [[
local __bpm = { guid = ]] .. args[1] .. [[, meta = {} }
local meta = __bpm.meta meta.__index = meta]]

end

fragments["utils"] = function(args)

	return [[
local __hex = "0123456789ABCDEF"
local function __genericIsValid(x) return type(x) == 'number' or type(x) == 'boolean' or IsValid(x) end
local function __guidString(str) return str:gsub(".", function(x) local b = string.byte(x) return __hex[1+b/16] .. __hex[1+b%16] end) end
local function __hexBytes(str) return str:gsub("%w%w", function(x) return string.char(tonumber(x[1],16) * 16 + tonumber(x[2],16)) end) end
local function __svcheck() if not SERVER then error("Node '%node' can't run on client") end end
local function __clcheck() if not CLIENT then error("Node '%node' can't run on server") end end
local function __graph(f) return setfenv(f, setmetatable({cs={},recurse=f}, {__index = _G})) end
G_BPInstances = G_BPInstances or {}]]

end

fragments["hook"] = [[
["\1"] = {
	hook = "\2",
	graphID = "\3",
	nodeID = "\4",
},]]


if SERVER and false then

	local test = [[
		print("__FRAGMENT_TEST__")
		_FR_CALLSTACK()
		_FR_JLIST(1,2,3,4)
		__bpm.events = {
			_FR_HOOK(CalcView,CalcView,5,-1)
		}
	]]

	local res = test:gsub("([\n%s]+)_FR_(%w+)%(([^%)]*)%)", function(a, b, args)

		local fr = fragments[b:lower()]
		if args then
			if type(fr) == "string" then
				local i = 1
				for y in string.gmatch(args, "([^%),]+)[,%s]*") do
					fr = fr:gsub("\\" .. i, y)
					i = i + 1
				end
			else
				local t = {}
				for y in string.gmatch(args, "([^%),]+)[,%s]*") do
					t[#t+1] = y
				end
				fr = fr(t)
			end
		end
		return a .. fr:gsub("\n", a)

	end)

	print(res)



end