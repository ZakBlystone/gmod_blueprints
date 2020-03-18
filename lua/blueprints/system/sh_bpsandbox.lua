AddCSLuaFile()

module("bpsandbox", package.seeall, bpcommon.rescope( bpcommon ))


function RefreshCreationMenu( name )

	if not g_SpawnMenu then return end
	for _, v in ipairs( g_SpawnMenu.CreateMenu:GetItems() ) do
		if v.Name == name then
			v.Panel:GetChildren()[1]:Remove()
			local newchild = spawnmenu.GetCreationTabs()[v.Name].Function()
			newchild:SetParent( v.Panel )
			newchild:Dock( FILL )
		end
	end

end

function RefreshSWEPs()

	RefreshCreationMenu("#spawnmenu.category.weapons")

end

function RefreshSENTs()

	RefreshCreationMenu("#spawnmenu.category.entities")

end

if CLIENT then

	--[[local classes = {}
	local function baseWrap(func, base)

		setfenv(func, setmetatable({},
		{
			__index = function(s,k) return k == "BaseClass" and classes[base] or _G[k] end
		}))

	end

	local function wrapClass(t, base)
		t = bpcommon.CopyTable(t)
		t.__index = function(s, k) return rawget(t, k) or classes[base].__index(s, k) end
		for _, func in pairs(t) do
			if type(func) ~= "function" then continue end
			baseWrap(func, base)
		end
		return t
	end

	local function register(n, t, b)
		print("Registered class '" .. n .. "' with base '" .. tostring(b or "None") .. "'" )
		classes[n] = wrapClass(t, b)
	end

	local function create(n)
		local cl = classes[n]
		return setmetatable({}, cl)
	end

	local a = {}
	function a:FuncA() print("Ran a:FuncA") end
	function a:FuncC() print("Ran a:FuncC") end

	local b = {}
	function b:FuncA() print("Ran b:FuncA") BaseClass:FuncA() end
	--function b:FuncC() print("Ran b:FuncC") end

	local m = {}
	function m:FuncA() print("Ran m:FuncA") BaseClass:FuncA() self:FuncC() end
	function m:FuncB() print("Ran m:FuncB") end

	register("m", m, "b")
	register("b", b, "a")
	register("a", a)

	local mi = create("m")

	mi:FuncA()
	mi:FuncB()]]

	--[[local mx = {}
	mx.__index = mx
	function mx:myFunc()
		print("Hello myFunc: " .. tostring(test))
	end

	setfenv(mx.myFunc, setmetatable({},
	{
		__index =
		function(s,k)
			if k == "test" then return 10 end
			return _G[k]
		end
	}
	))

	local i = setmetatable({}, mx)
	i:myFunc()]]

end