AddCSLuaFile()

module("bpcommon", package.seeall)

file.CreateDir("blueprints")

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

	meta[iteratorName] = function(self)

		local i = 0
		local n = #self[variable]
		return function() 
			i = i + 1
			if i <= n then return self[variable][i].id, self[variable][i] end
		end

	end

	meta[idIteratorName] = function(self)

		local i = 0
		local n = #self[variable]
		return function() 
			i = i + 1
			if i <= n then return self[variable][i].id end
		end

	end

	local iter = meta[iteratorName]
	meta["Get" .. varName] = function(self, id)

		for _, item in iter(self) do
			if item.id == id then return item end
		end

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
	obj.AddListener 	= function(self, func, mask)
		if self.__incall then table.insert(self.__deferred, {1, func, mask or cblist.CB_ALL}) self.__handleDeferred = true return end
		self.__callbacks[func] = mask or cblist.CB_ALL 
	end
	
	obj.RemoveListener 	= function(self, func) 
		if self.__incall then table.insert(self.__deferred, {2, func}) self.__handleDeferred = true return end
		self.__callbacks[func] = nil 
	end
	
	obj.FireListeners 	= function(self, cb, ...) 
		obj.__incall = true
		for k,v in pairs(self.__callbacks) do 
			if bit.band(cb, v) ~= 0 then local b,e = pcall(k, cb, ...) if not b then print(e) end end
		end
		obj.__incall = false
		if self.__handleDeferred then
			for k, v in pairs(self.__deferred) do
				if v[1] == 1 then self:AddListener(v[2], v[3]) end
				if v[1] == 2 then self:RemoveListener(v[2]) end
			end
			self.__handleDeferred = false
		end
	end
end