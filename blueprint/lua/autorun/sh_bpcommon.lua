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

--Makes the object observable (creates listener system)
function MakeObservable(obj, cblist)
	local env = getfenv(2)
	cblist = cblist or env

	obj.__callbacks = {}
	obj.AddListener 	= function(self, func, mask) self.__callbacks[func] = mask or cblist.CB_ALL end
	obj.RemoveListener 	= function(self, func) self.__callbacks[func] = nil end
	obj.FireListeners 	= function(self, cb, ...) 
		for k,v in pairs(self.__callbacks) do 
			if bit.band(cb, v) ~= 0 then local b,e = pcall(k, cb, ...) if not b then print(e) end end
		end
	end
end