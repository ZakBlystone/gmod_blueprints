AddCSLuaFile()

G_BPMetaRegistry = G_BPMetaRegistry or {}

module("bpcommon", package.seeall)

file.CreateDir("blueprints")

ENABLE_PROFILING = true
ENABLE_DEEP_PROFILING = false

STREAM_FILE = 1
STREAM_NET = 2

ENV_VERSION = "1.4"

function rescope(...)
	local scopes = {...}
	local vars = {}

	--[[for i=#scopes, 1, -1 do

		for k, v in pairs(scopes[i]) do
			if k:sub(1,1) ~= '_' then
				vars[k] = v
			end
		end

	end]]

	return function(x)
		local m = getmetatable(x)
		local pindex = m.__index
		m.__index = function( self, index )
			if index:sub(1,1) ~= '_' then 
				for _, scope in pairs(scopes) do
					local v = rawget(scope, index)
					if v ~= nil then return v end
				end
			end
			return pindex[ index ]
		end
		--[[for k, v in pairs(vars) do
			x._M[k] = v
		end]]
	end
end

local ps = {
	enabled = false,
	start = 0,
}

function ProfileStart(name)

	if not ENABLE_PROFILING then return end
	if ENABLE_DEEP_PROFILING then

		ps.enabled = true
		ps.stack = { children = {}, entries = {} }
		ps.ptr = ps.stack

	end

	ps.start = os.clock()
	ps.name = name or "unnamed"
	--MsgC(Color(80,180,200), "Begin profile[" .. ps.name .. "]...\n")

end

function Profile(key, func, ...)

	if not ps.enabled then return func(...) end

	local tab = { parent = ps.ptr, children = {}, key = key, time = 0 }
	table.insert(ps.ptr.children, tab)
	ps.ptr = tab

	local start = os.clock()
	local ret = {func(...)}
	local finish = os.clock()
	local entry = tab.entry

	tab.time = (finish - start) * 1000
	ps.ptr = ps.ptr.parent

	return unpack(ret)

end

local function RecurseStack(st, depth)

	local data = {}
	local timedata = {}

	depth = depth or 0
	for _, smp in ipairs(st.children) do

		local t = data[table.insert(data, {key=smp.key, smp=smp, t=nil})]

		timedata[t.key] = timedata[t.key] or {}
		t.t = timedata[t.key]

		t.t.samples = (t.t.samples or 0) + 1
		t.t.min = math.min((t.t.min or 99999), smp.time)
		t.t.max = math.max((t.t.max or 0), smp.time)
		t.t.total = (t.t.total or 0) + smp.time

	end

	table.sort(data, function(a,b) return a.t.total > b.t.total end)

	for k,v in ipairs(data) do
		print( string.rep(" ", (depth)) .. string.format("%-" .. (32 - depth) .. "s%8.2f%8.2f%8.2f%8.2f%8.2f", " -" .. v.key .. "[" .. v.t.samples .. "]", 
			v.smp.time,
			(v.t.total)/v.t.samples,
			v.t.total, 
			v.t.min,
			v.t.max))

		RecurseStack(v.smp, depth+1)
	end

end

function ProfileEnd()

	if not ENABLE_PROFILING then return end

	ps.enabled = false

	if ENABLE_DEEP_PROFILING then
		print( string.format("%-32s%8s%7s%10s%6s%8s", "function", "this", "avg", "total", "min", "max") )
		RecurseStack(ps.stack)
	end

	MsgC(Color(80,180,200), "Total time[" .. ps.name .. "]: " .. (os.clock() - ps.start)*1000 .. "\n")

end


function CallbackList(t, listindex)
	local env = getfenv(2)
	local cblist = env
	if listindex then
		env[listindex] = {}
		cblist = env[listindex]
	end

	cblist["CB_LOOKUP"] = {}

	local cbx = 1
	for k,v in ipairs(t) do
		cblist["CB_" .. tostring(v)] = cbx
		cblist["CB_LOOKUP"][cbx] = "CB_" .. tostring(v)
		cbx = cbx * 2
	end

	cblist["CB_ALL"] = cbx-1
end

function ZipStringLeft(str, max)

	local len = str:len()
	if len > max then
		return "..." .. str:sub(len - max + 4, -1)
	end
	return str

end

function Camelize(str)

	if str:len() == 0 then return "" end

	return str[1]:upper() .. str:sub(2,-1)

end

function Sanitize(str)

	if str == nil then return nil end
	local out = ""
	for str in str:gmatch("[%w_]") do out = out .. str end
	if out:len() == 0 then return nil end
	return out

end

function GetSingular(str)

	return str:sub(-1,-1) == "s" and str:sub(1,-2) or str

end

-- Creates a unique key if needed
function CreateUniqueKey(tab, key)

	if tab[key] ~= nil then
		local id = 1
		local kx = key .. id
		while tab[kx] ~= nil do
			id = id + 1
			kx = key .. id
		end
		key = kx
	end
	tab[key] = 1
	return key

end

-- List of items which have ids
function CreateIndexableListIterators(meta, variable)

	local singular = GetSingular(variable)
	local varName = Camelize(singular)
	local iteratorName = varName .. "s"
	local idIteratorName = varName .. "IDs"

	meta[iteratorName] = function(self, ...)
		return self[variable]:Items(...)
	end

	meta[idIteratorName] = function(self, ...)
		return self[variable]:ItemIDs(...)
	end

	meta["Get" .. varName] = function(self, ...)
		return self[variable]:Get(...)
	end

	meta["Remove" .. varName .. "If"] = function(self, ...)
		return self[variable]:RemoveIf(...)
	end

	meta["Remove" .. varName] = function(self, ...)
		return self[variable]:Remove(...)
	end

end

local function WithOuter(self, outer)
	rawset(self, "__outer", outer)
	return self
end
local function GetOuter(self, check)
	local outer = rawget(self, "__outer")
	if outer and check and getmetatable(outer).__hash ~= check.__hash then return nil end
	return outer
end
local function GetOutermost(self, check)
	local outer = rawget(self, "__outer")
	if not outer then
		if check and getmetatable(self).__hash ~= check.__hash then return nil end
		return self
	end

	return GetOutermost(outer, check)
end
local function FindOuter(self, check)
	local outer = rawget(self, "__outer")
	if outer then
		if type(check) == "function" then if check(outer) then return outer end
		elseif getmetatable(outer).__hash == check.__hash then return outer end
		return FindOuter(outer, check)
	end
end

function MetaTable(name, extends)

	G_BPMetaRegistry[name] = G_BPMetaRegistry[name] or {}
	local mt = G_BPMetaRegistry[name]
	mt.__index = mt
	mt.__hash = util.CRC(name)
	mt.WithOuter = WithOuter
	mt.GetOuter = GetOuter
	mt.GetOutermost = GetOutermost
	mt.FindOuter = FindOuter

	if extends then
		local base = G_BPMetaRegistry[name]
		if base == nil then error("Couldn't find base class for " .. name .. " : " .. tostring(extends)) end
		table.Inherit(mt, base)
	end

	for k, v in pairs(G_BPMetaRegistry) do
		if name ~= k and v.__hash == mt.__hash then
			error("CRC32 HASH COLLISION: " .. name .. " <--> " .. k .. " [" .. mt.__hash .. " <--> " .. v.__hash)
		end
	end

	_G["is" .. name] = function(tbl) return (getmetatable(tbl) or {}).__hash == mt.__hash end
	_G[name .. "_meta"] = mt

	return mt

end

function GetMetaTableFromHash(hash)

	for k,v in pairs(G_BPMetaRegistry) do
		if v.__hash == hash then return v end
	end

end

function FindMetaTable(name)

	return G_BPMetaRegistry[name]

end

function GetMetaTableName(tbl)

	for k,v in pairs(G_BPMetaRegistry) do
		if v.__hash == tbl.__hash then return k end
	end
	return "unknown"

end

function MakeInstance(meta, ...)

	if type(meta) == "string" then meta = G_BPMetaRegistry[name] end
	return setmetatable({}, meta):Init(...)

end

function ForwardMetaCallsVia(meta, target, getter)

	target = FindMetaTable(target)
	if target == nil then error("Couldn't find metatable: " .. tostring(target)) end

	for k,v in pairs(target) do
		if type(v) == "function" and k[1] ~= "_" and meta[k] == nil then
			meta[k] = function(self, ...)
				local o = self[getter](self)
				return o[k](o, ...)
			end
		end
	end

end

-- Adds accessors to metatable for accessing bitflags
function AddFlagAccessors(meta, readOnly, var)

	var = var or "flags"
	local key = Camelize(var)
	local singular = GetSingular(key)
	local getter = "Get" .. key
	if not readOnly then
		meta["Set" .. key] = function(self, fl) self[var] = fl end
		meta["Set" .. singular] = function(self, fl) self[var] = bit.bor(self[var], fl) end
		meta["Add" .. singular] = function(self, fl) self[var] = bit.bor(self[var], fl) end
		meta["Clear" .. singular] = function(self, fl) self[var] = bit.band(self[var], bit.bnot(fl)) end
	end

	meta["Has" .. singular] = function(self, fl) return bit.band(self[getter](self), fl) ~= 0 end
	meta[getter] = function(self) return self[var] end

	return meta

end

--Makes the object observable (creates listener system)
function MakeObservable(obj, cblist)
	local env = getfenv(2)
	cblist = cblist or env

	obj.__callbacks = {}
	obj.__deferred = {}
	obj.__incall = false
	obj.__handleDeferred = false
	obj.__suppressed = false

	obj.SuppressEvents   = function(self, suppressed) 
		self.__suppressed = suppressed 
	end

	obj.AddListener 	= function(self, func, mask)
		if self.__incall then table.insert(self.__deferred, {1, func, mask or cblist.CB_ALL}) self.__handleDeferred = true return true end
		self.__callbacks[func] = mask or cblist.CB_ALL
	end
	
	obj.RemoveListener 	= function(self, func) 
		if self.__incall then table.insert(self.__deferred, {2, func}) self.__handleDeferred = true return true end
		self.__callbacks[func] = nil
	end
	
	obj.FireListeners 	= function(self, cb, ...)
		if self.__suppressed then return end
		self.__incall = true
		for k,v in pairs(self.__callbacks) do 
			if bit.band(cb, v) ~= 0 then 
			local b,e = xpcall(k, function(err) print(err) print(debug.traceback()) end, cb, ...)
			end
		end
		self.__incall = false
		if self.__handleDeferred then
			for i=#self.__deferred, 1, -1 do
				local v = self.__deferred[i]
				if v[1] == 1 then self:AddListener(v[2], v[3]) end
				if v[1] == 2 then self:RemoveListener(v[2]) end
				table.remove(self.__deferred, i)
			end
			self.__handleDeferred = false
		end
	end
end

function GUIDToString( guid, raw )

	local fmt = nil
	if raw then
		fmt = "%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X%0.2X"
	else
		fmt = "{%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X}"
	end
	return string.format(fmt,
		guid[1]:byte(),
		guid[2]:byte(),
		guid[3]:byte(),
		guid[4]:byte(),
		guid[5]:byte(),
		guid[6]:byte(),
		guid[7]:byte(),
		guid[8]:byte(),
		guid[9]:byte(),
		guid[10]:byte(),
		guid[11]:byte(),
		guid[12]:byte(),
		guid[13]:byte(),
		guid[14]:byte(),
		guid[15]:byte(),
		guid[16]:byte())

end

function GUID()

	local d,b,g,m=os.date"*t",function(x,y)return x and y or 0 end,system,bit
	local r,n,s,u,x,y=function(x,y)return m.band(m.rshift(x,y or 0),0xFF)end,
	math.random(2^32-1),_G.__guidsalt or b(CLIENT,2^31),os.clock()*1000,
	d.min*1024+d.hour*32+d.day,d.year*16+d.month;_G.__guidsalt=s+1;return
	string.char(r(x),r(x,8),r(y),r(y,8),r(n,24),r(n,16),r(n,8),r(n),r(s,24),r(s,16),
	r(s,8),r(s),r(u,16),r(u,8),r(u),d.sec*4+b(g.IsWindows(),2)+b(g.IsLinux(),1))

end

function GCHandle(func)

	local prx = newproxy(true)
	local meta = getmetatable(prx)
	function meta.__gc( self ) pcall( func ) end
	return prx

end

function PlayerKey(ply)

	return ply:AccountID() or "singleplayer"

end

function Transform(tab, out, func, ...)

	if type(tab) == "function" then

		for _, v in tab() do
			out[#out+1] = func(v, ...)
		end

	else

		for _, v in ipairs(tab) do
			out[#out+1] = func(v, ...)
		end

	end
	return out

end

function CopyTable( tab, lookup_table )

	if ( tab == nil ) then return nil end

	local copy = {}
	setmetatable( copy, debug.getmetatable( tab ) )
	for i, v in pairs( tab ) do
		if ( !istable( v ) ) then
			copy[ i ] = v
		elseif i ~= "__outer" then
			lookup_table = lookup_table or {}
			lookup_table[ tab ] = copy
			if ( lookup_table[ v ] ) then
				copy[ i ] = lookup_table[ v ] -- we already copied this table. reuse the copy.
			else
				copy[ i ] = CopyTable( v, lookup_table ) -- not yet copied. copy it.
			end
		end
	end
	return copy

end