AddCSLuaFile()

module("bpcommon", package.seeall)

file.CreateDir("blueprints")

ENABLE_PROFILING = true
ENABLE_DEEP_PROFILING = false

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
	for _, smp in pairs(st.children) do

		local t = data[table.insert(data, {key=smp.key, smp=smp, t=nil})]

		timedata[t.key] = timedata[t.key] or {}
		t.t = timedata[t.key]

		t.t.samples = (t.t.samples or 0) + 1
		t.t.min = math.min((t.t.min or 99999), smp.time)
		t.t.max = math.max((t.t.max or 0), smp.time)
		t.t.total = (t.t.total or 0) + smp.time

	end

	table.sort(data, function(a,b) return a.t.total > b.t.total end)

	for k,v in pairs(data) do
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
	for k,v in pairs(t) do
		cblist["CB_" .. tostring(v)] = cbx
		cblist["CB_LOOKUP"][cbx] = "CB_" .. tostring(v)
		cbx = cbx * 2
	end

	cblist["CB_ALL"] = cbx-1
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

--[[
	day/mo = 5bits-> 6bits
	hour = 5bits  -> 6bits
	minute = 6bits
	month = 4bits -> 6bits
	second = 6bits
	year = 12bits -> 12bits
	rand = 32bits -> 24bits
	salt = 32bits -> 24bits
	uptime = 24bits
]]

function GUIDToString( guid )

	return string.format("{%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X-%0.2X%0.2X%0.2X%0.2X}",
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

_G.__guidsalt = _G.__guidsalt or 0
function GUID()

	_G.__guidsalt = _G.__guidsalt + 1
	local dd = os.date("*t")
	local rand = math.random(0, 2^32-1)
	local salt = _G.__guidsalt
	local uptime = os.clock() * 1000

	local out = bpdata.OutStream(true)
	out:WriteBits(dd.day, 5)
	out:WriteBits(dd.hour, 5)
	out:WriteBits(dd.min, 6)
	out:WriteBits(dd.month, 4)
	out:WriteBits(dd.sec, 6)
	out:WriteBits(dd.year, 12)
	out:WriteBits(rand, 32)
	out:WriteBits(salt, 32)
	out:WriteBits(uptime, 24)
	out:WriteBits(system.IsWindows() and 1 or 0, 1)
	out:WriteBits(system.IsLinux() and 1 or 0, 1)

	local str, len = out:GetString(false, false)
	return str

end