AddCSLuaFile()

module("bpcompat", package.seeall)

COMPAT_HOOKS = {}
COMPAT_ENV = nil
COMPAT_SCRIPT = nil
COMPAT_PATH = nil
COMPAT_GLOBALS = { 
	package = {
		seeall = function(x)
			local m = getmetatable(x)
			m.__index = COMPAT_ENV
		end,
		preload = {},
		loaders = {},
		loaded = {},
	},
	module = function(x, ...)
		--print("MODULE: " .. tostring(x))
		local mod = setmetatable({}, {
			__index = {},
			__newindex = function(s,k,v)
				rawset(s, k, v)
			end,
		})
		for _, x in ipairs({...}) do
			x(mod)
		end
		setfenv(COMPAT_SCRIPT, mod)
		COMPAT_GLOBALS.package.loaded[x] = mod
	end,
	hook = {
		Add = function(ev, key, func, ...)
			COMPAT_HOOKS[ev] = COMPAT_HOOKS[ev] or {}
			COMPAT_HOOKS[ev][key] = function(...)
				return func(...)
			end
			--print("HOOK: " .. ev)
		end,
		Run = function(ev, ...)
			PrintTable(COMPAT_HOOKS[ev] or {})
			for k,v in pairs(COMPAT_HOOKS[ev] or {}) do
				v(...)
			end
		end,
	},
	AddCSLuaFile = function(x)
		if CLIENT then return end
		local script = (x or COMPAT_PATH)
		if script then 
			AddCSLuaFile(script) 
			print(script)
		end
	end,
	include = function(path)
		path = path:gsub("blueprints/", "blueprints/system/compat16/")
		--print("INCLUDE PATH: " .. tostring(path))
		local script = CompileFile(path)
		local PUSH_STATE = COMPAT_SCRIPT
		local PUSH_PATH = COMPAT_PATH
		COMPAT_PATH = path
		COMPAT_SCRIPT = script
		setfenv(script, COMPAT_ENV)
		script()
		COMPAT_SCRIPT = PUSH_STATE
		COMPAT_PATH = PUSH_PATH
	end,
	file = setmetatable({
		Find = function(path, type)
			if type == "LUA" then
				path = path:gsub("blueprints/", "blueprints/system/compat16/")
			end
			local f,d = file.Find(path, type)
			--print("FIND: " .. path .. " : " .. #f)
			return f,d
		end,
	}, {
		__index = _G.file
	}),
	-- hack to satisfy bptextwrap module being used on clients during pin init
	bptextwrap = {
		New = function()
			local inst = {}
			setmetatable(inst, {
				__index = function() return function() return inst end end,
			})
			return inst
		end
	},
}

local ProtectedGlobals = {
	G_BPMetaRegistry = true,
	G_BPClassLoaders = true,
}

local SafeTables = {
	table = true,
	math = true,
	bit = true,
	debug = true,
	util = true,
	string = true,
	os = true,
	surface = true,
	file = true,
	system = true,
}

COMPAT_ENV = setmetatable({}, {
	__newindex = function(s,k,v) COMPAT_GLOBALS[k] = v end,
	__index = function(s,k) 
		--print("L REG: " .. k) 
		if k == "_G" then return COMPAT_ENV end
		if ProtectedGlobals[k] then return COMPAT_GLOBALS[k] end
		local x = COMPAT_GLOBALS[k] or COMPAT_GLOBALS.package.loaded[k]
		if x then return x end
		if type(_G[k]) == "table" and not SafeTables[k] then return nil end
		return _G[k]
	end, 
})

local function bpinclude(path)
	local script = CompileFile("blueprints/system/compat16/" .. path)
	COMPAT_PATH = "blueprints/system/compat16/" .. path
	COMPAT_SCRIPT = script
	setfenv(script, COMPAT_ENV)
	script()
end

-- CORE
--bpinclude("core/sh_bplocalization.lua")
bpinclude("core/sh_bpcommon.lua")
bpinclude("core/sh_bpclassloader.lua")
bpinclude("core/sh_bpcollection.lua")
bpinclude("core/sh_bpindexer.lua")
bpinclude("core/sh_bpbuffer.lua")
bpinclude("core/sh_bplist.lua")
bpinclude("core/sh_bplistdiff.lua")
bpinclude("core/sh_bpstringtable.lua")
bpinclude("core/sh_bpdata.lua")

-- GRAPH
bpinclude("graph/sh_bpschema.lua")
bpinclude("graph/sh_bppintype.lua")
bpinclude("graph/sh_bppin.lua")
bpinclude("graph/sh_bpcast.lua")
--bpinclude("graph/sh_bpcompiler.lua")
bpinclude("graph/sh_bpnodetype.lua")
bpinclude("graph/sh_bpnodetypegroup.lua")
bpinclude("graph/sh_bpnode.lua")
bpinclude("graph/sh_bpgraph.lua")

-- MODULE
bpinclude("module/sh_bpvariable.lua")
bpinclude("module/sh_bpstruct.lua")
bpinclude("module/sh_bpevent.lua")
bpinclude("module/sh_bpmodule.lua")
--bpinclude("module/sh_bpcompiledmodule.lua")
--bpinclude("module/sh_bpenv.lua")
--bpinclude("module/sh_bpnet.lua")

--PrintTable(COMPAT_GLOBALS)

-- DEFS
bpinclude("defs/sh_bpdefpack.lua")
bpinclude("defs/sh_bpdefs.lua")

print("RUNNING COMPAT INIT HOOK")
COMPAT_ENV.hook.Run("BPPostInit")

print(bpcommon.ENV_VERSION)

if CLIENT then

concommand.Add("bp_convert", function(p,c,a)

	if not a[1] then return end

	local old = COMPAT_ENV.bpmodule.New()
	old:Load("blueprints/client/bpm_" .. a[1] .. ".txt")

	print(old:GetType())

	local new = bpmodule.New()
	local graphMap = {}
	local graphIDMapOld = {}
	local graphIDMapNew = {}
	local nodeMap = {}
	local nodeIDMap = {}
	local varIDMap = {}
	local graphCallMap = {}

	local function ConvertPinType( base, addFlags )
		return bppintype.New( 
			base:GetBaseType(), 
			bit.bor(base:GetFlags(), addFlags or 0), 
			base:GetSubType() 
		)
	end

	if old:CanHaveStructs() then

		for k, oldStruct in old:Structs() do
			local id, newStruct = new.structs:ConstructNamed(oldStruct:GetName())
			newStruct:PreModify()

			for id, pin in oldStruct.pins:Items() do

				local pt = bppintype.New( pin:GetBaseType(), pin:GetFlags(), pin:GetSubType() )
				newStruct.pins:Construct( pin:GetDir(), pin:GetName(), pt, pin:GetDescription() )

			end

			newStruct.nameMap = oldStruct.nameMap
			newStruct.invNameMap = oldStruct.invNameMap

			newStruct:PostModify()

		end

	end

	local newPinTypes = bpcollection.New()
	new:GetPinTypes(newPinTypes)

	if old:CanHaveVariables() then

		for k, var in old:Variables() do

			local existingType = nil
			if var:GetType():GetBaseType() == bpschema.PN_Struct then
				for _, x in newPinTypes:Items() do
					if x:GetSubType() == var:GetType():GetSubType() then
						existingType = x
						break
					end
				end
			end

			local addFlags = 0
			if existingType then addFlags = existingType:GetFlags() end
			local newType = ConvertPinType( var:GetType(), addFlags )
			local id, newVar = new:NewVariable( var:GetName(), newType )
			varIDMap[k] = id
			--print("VAR: " .. var:GetName() .. " " .. k .. " -> " .. id)
		end

	end

	if old:CanHaveEvents() then

		for k, oldEvent in old:Events() do
			local id, newEvent = new.events:ConstructNamed(oldEvent:GetName())
			newEvent.flags = oldEvent.flags
			newEvent:PreModify()

			for id, pin in oldEvent.pins:Items() do

				local pt = bppintype.New( pin:GetBaseType(), pin:GetFlags(), pin:GetSubType() )
				newEvent.pins:Construct( pin:GetDir(), pin:GetName(), pt, pin:GetDescription() )

			end

			newEvent:PostModify()

		end

	end

	for k, oldGraph in old:Graphs() do
		print(oldGraph:GetTitle())

		local id, newGraph = new:NewGraph( oldGraph:GetTitle(), oldGraph:GetType() )
		newGraph:SetFlags( oldGraph:GetFlags() )
		graphIDMapNew[newGraph] = id
		graphIDMapNew[id] = newGraph

		graphMap[oldGraph] = newGraph
		graphIDMapOld[oldGraph] = k
		graphIDMapOld[k] = oldGraph

		for k, input in oldGraph:Inputs() do
			local pt = bppintype.New( input:GetBaseType(), input:GetFlags(), input:GetSubType() )
			newGraph.inputs:Construct( input:GetDir(), input:GetName(), pt, input:GetDescription() )
		end

		for k, output in oldGraph:Outputs() do
			local pt = bppintype.New( output:GetBaseType(), output:GetFlags(), output:GetSubType() )
			newGraph.outputs:Construct( output:GetDir(), output:GetName(), pt, output:GetDescription() )
		end

		if newGraph:GetType() == bpschema.GT_Function then
			local newEntry = newGraph:GetEntryNode()
			local newExit = newGraph:GetExitNode()

			newGraph:RemoveNode(newEntry)
			newGraph:RemoveNode(newExit)
		end
	end

	local nodeTypes = bpcollection.New()
	old:GetNodeTypes(nodeTypes, nil)

	for id, type in nodeTypes:Items() do

		local _,_,id = type:GetName():find("__Call(%d+)")
		if id then
			id = tonumber(id)
			local oldGraphTarget = graphIDMapOld[id]
			if not oldGraphTarget then
				error("Failed to remap old graph to new graph")
			end

			local newTarget = graphMap[oldGraphTarget]
			local newID = graphIDMapNew[newTarget]

			print("REMAP GRAPH CALL ID: " .. id .. " -> " .. newID)

			for k, oldGraph in old:Graphs() do
				for _, node in oldGraph:Nodes() do
					if node:GetTypeName() == type:GetName() then
						node.nodeType = "__Call" .. newID
					end
				end
			end
		end

		local _,_,mode,id = type:GetName():find("__V(%a+)(%d+)")
		if mode and id then
			id = tonumber(id)
			local newID = varIDMap[id]

			print("REMAP GRAPH " .. mode .. " ID: " .. id .. " -> " .. newID)

			for k, oldGraph in old:Graphs() do
				for _, node in oldGraph:Nodes() do
					if node:GetTypeName() == type:GetName() then
						node.nodeType = "__V" .. mode .. newID
					end
				end
			end
		end

	end

	for oldGraph, newGraph in pairs(graphMap) do

		local nodeTypes = newGraph:GetNodeTypes()
		for k, oldNode in oldGraph:Nodes() do

			local type = oldNode:GetTypeName()
			local _, newNode = newGraph:AddNode( type, oldNode.x, oldNode.y )

			newNode:PreModify()
			for x,y in pairs(oldNode.data) do
				newNode.data[x] = y
			end
			newNode:PostModify()

			nodeMap[oldNode] = newNode
			nodeIDMap[k] = newNode

			for id, oldPin, pos in oldNode:Pins(function(x) return x:GetDir() == bpschema.PD_In end) do
				local newPin = newNode:FindPin(bpschema.PD_In, oldPin:GetName())
				if newPin then
					newPin:SetLiteral( oldNode:GetLiteral(id) )
				end
			end

		end

		for k, oldNode in oldGraph:Nodes() do

			for id, pin, pos in oldNode:Pins(function(x) return x:GetDir() == bpschema.PD_Out end) do

				for _, target in ipairs(pin:GetConnectedPins()) do

					local targetNode = target:GetNode()
					print(pin:GetName() .. " -> " .. target:GetName())

					local A = nodeMap[oldNode]
					local B = nodeMap[targetNode]
					if A and B then

						local APin = A:FindPin(bpschema.PD_Out, pin:GetName())
						local BPin = B:FindPin(bpschema.PD_In, target:GetName())

						if APin and BPin then

							APin:Connect(BPin)

						end

					end

				end

			end

		end

	end

	local window = vgui.Create("BPFrame")
	local edit = vgui.Create("BPModuleEditor", window)
	edit:Dock(FILL)
	edit:SetModule(new)

	window:SetTitle("Blueprint")
	window:SetSkin("Blueprints")
	window:SetSize(1200,600)
	window:SetSizable(true)
	window:Center()
	window:MakePopup()

end)

end