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

function meta:FormatErrorMessage( msg, modUID, graphID, nodeID )

	local dbgGraph = self:LookupGraph( modUID, graphID )
	local dbgNode = self:LookupNode( modUID, nodeID )
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
			self.errorHandler(self, msg, mod, graph, node)
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
	self.debugSymbols = stream:Value(self.debugSymbols)
	return stream

end

function meta:LookupNode(modUID, id)

	if not self.debugSymbols[modUID] then return end
	return self.debugSymbols[modUID].nodes[id]

end

function meta:LookupGraph(modUID, id)

	if not self.debugSymbols[modUID] then return end
	return self.debugSymbols[modUID].graphs[id]

end

function New(...)
	return bpcommon.MakeInstance(meta, ...)
end

fragments["nethead"] = [[
local _wb,_rb,_wd,_rd,_wu,_ru=net.WriteBool,net.ReadBool,net.WriteData,net.ReadData,net.WriteUInt,net.ReadUInt
if not G_BPNet then G_BPNet={c=G_BPNetChannels or{},h=G_BPNetHandlers or{},m={
netShake=function(x,inst,ready,ch) net.Start("bphandshake") _wd(x.__bpm.guid,16) _wd(inst,16) if ch then _wu(ch,16) end _wb(ready or false) end,
netStartMessage=function(x,id) net.Start("bpmessage") _wu(x.nch,16) _wu(id,16) end,
netInit=function(x) 
	x.netReady=nil x.ncl={} x.hash=x.__bpm.guid..x.guid G_BPNet.h[x.hash]=x if CLIENT then x:netShake(x.guid) net.SendToServer() return end
	local i=0 repeat i=i+1 until not G_BPNet.c[i] or i==65535 and error("BPNET_ERR:0") G_BPNet.c[i]=x x.nch=i end,
netShutdown=function(x) G_BPNet.h[x.hash]=nil G_BPNet.c[x.nch or-1]=nil if SERVER then net.Start("bpclosechannel") _wu(x.nch or-1,16) net.Broadcast() end end,
netUpdate=function(x) for i,c in ipairs(x.ncl) do local s,e=pcall(c.f,unpack(c.a)) s=s or x.__bpm.onError(e,0,c.g,c.n) x.ncl[i]=nil end end,
netHandshake=function(x,inst,len,pl) 
	if SERVER then if _rb() then x.netReady=true else x:netShake(inst,false,x.nch) net.Send(pl) end return end
	x.nch=_ru(16) G_BPNet.c[x.nch]=G_BPNet.c[x.nch] and error("BPNET_ERR:1") or x x:netShake(x.guid,true) net.SendToServer() x.netReady=true end}}
net.Receive("bpmessage",function(...) local ch=G_BPNet.c[_ru(16)] if ch then ch:netReceiveMessage(...) end end)
net.Receive("bphandshake",function(len,pl) local mod,inst=_rd(16),_rd(16) local h=G_BPNet.h[mod..inst] if h then h:netHandshake(inst,len,pl) end end)
net.Receive("bpclosechannel", function() G_BPNet.c[_ru(16)]=nil end) end
]]

--[===[
fragments["nethead"] = [=[
if not G_BPNet then RunString(util.Decompress(util.Base64Decode[[
XQAAAQDHBQAAAAAAAAAjl8RHgpuwwCcoIXqOPxF/iuhx4DpRX7lPaNyHPjlbtRzrkjWE/RpNMY5dS5b+ya25mEWEOF7RIuR5FZ2TQyb5gYXxIO+flg0ynR97YiDGoy+/CmcnQVvDRzjTGKp/
QkHEwyzIGexHLz0tMaFvZhyZoA+Z/jgcYkQNyJT+1SAhtmmDZxpFRYs3uhBN43LnQV8RmMny9RMX+nUF3Ju3RLk2rVBdZ2H83KCIk4SEE/uSajrcRoEbV8cPY78IDeoucFHAM3JYs8e1yFBx
9p8v7+wRdYTwrHbGaHMV+d10RL1nJH8/+OPAHJW6ltegLaxllc0UA25wyQ8+Yoa/8EyyDqdP6O1uOJ4yGkEmzEOJ3d5yAlL/We7vmUjmaWFiaCRsFclScZwUh5BVyPjFN3bGJBO5qyzJXBhE
PqwLdp1not1EBOVLgn1qMsG5B9PoAfUkUfpQoM3gkljN8Zd8tVNKgFpFmXtaqEsIZ6aAdkEIAg5S9C3qlIW4x7t1kUmoMJo9Ixo4HD6ljXUUzjTnMzT0UMh13OkgaQlpN7u4kME4OEGXU1xh
AL28u1z1+GAOFmm7jOj8CcEM/wLkOU37GzxpkS6rSrYghhX7QqPJGxtmQ6zcTmbHYtrRBAz705Dvfm+/vZAITaEpDiZzPu0ftJvBBd+sSjFpHNFB5/N6jEgMAe7iMAK3FMGN6tOuo1FgdkR4
OBYhYR4DerWYkUaYgzLVDMz7DfT1EAR/hypLBNgKSEUx6eSITB8V/SF+uWHaSV/6PDbzhUA5YRCFySnxpw5FzFMyjWm69bndat/zqGEQPs+0LcwcYa/hrzgTxE0CQw0wyGkcMUOYQPyrKHRi
jIyPIpca95qW7ICt5ZeIOmWkTn2N8vqTTFnYTW1qNWOmAAA=]])) end
]=]
]===]

fragments["netmain"] = [[
table.Merge( meta, G_BPNet.m )
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
__bpm.delayKill = function(key) for i=#__self.delays, 1, -1 do if __self.delays[i].key == key then __self.delays[i].kill = true end end end
__bpm.onError = function(msg, mod, graph, node) ]] .. (args[3] and "error(msg)" or "") .. [[ end
__bpm.error = function(msg) __bpm.onError(tostring(msg), __bpm.guid, __dbggraph or -1, __dbgnode or -1) end]]

end

fragments["update"] = function(args)

	local x = "\n"
	if args[1] == "1" then x = "\n\t__ilph = 0\n" end

	local net = "\n"
	if args[2] == "1" then net = "\n\tif self.netReady then self:netUpdate() end\n" end

	return [[
function meta:update( rate )]] .. x .. [[
	__self = self
	rate = rate or FrameTime()]] .. net .. [[
	local t,d = self.delays
	for i=#t, 1, -1 do d = t[i] if d.kill or d.t == nil then table.remove(t,i) end end
	for i=#t, 1, -1 do d = t[i] d.t = d.t - rate if not d.kill and d.t <= 0 then d.t = d.f(unpack(d.a)) end end
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

fragments["jump"] = [[if ip == \1 then goto jmp_\1 end]]
fragments["ilpd"] = function(args)

	local ilp = args[1]
	local nodeID = args[2]
	local nodeRole = args[3] or "0"

	return [[
__ilp = __ilp + 1 if __ilp > ]] .. ilp .. [[ then __ilptrip = true goto __terminus end
__dbgnode = ]] .. nodeID

end

fragments["ilp"] = [[__ilp = __ilp + 1 if __ilp > \1 then __ilptrip = true goto __terminus end]]
fragments["dbg"] = function(args)

	local nodeID = args[1]
	local nodeRole = args[2] or "0"

	return "__dbgnode = " .. nodeID

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

	local ret = "local __self, _targetPin"
	if args[1] == "1" then
		ret = ret .. [[

local __dbgnode, __dbggraph = -1, -1]]
	end

	if args[2] == "1" then
		ret = ret .. [[

local __ilptrip, __ilp, __ilph = false, 0, 0]]
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
local __emptyTable = function() return {} end
local function __genericIsValid(x) return type(x) == 'number' or type(x) == 'boolean' or IsValid(x) end
local function __guidString(str) return str:gsub(".", function(x) local b = string.byte(x) return __hex[1+b/16] .. __hex[1+b%16] end) end
local function __hexBytes(str) return str:gsub("%w%w", function(x) return string.char(tonumber(x[1],16) * 16 + tonumber(x[2],16)) end) end
local function __graph(f) return setfenv(f, setmetatable({cs={},recurse=f}, {__index = _G})) end]]

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