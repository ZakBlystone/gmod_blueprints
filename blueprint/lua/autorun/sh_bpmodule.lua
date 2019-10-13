AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpdata.lua")
include("sh_bpgraph.lua")
include("sh_bpvariable.lua")
include("sh_bplist.lua")

module("bpmodule", package.seeall, bpcommon.rescope(bpschema, bpnodedef)) --bpnodedef is temporary

bpcommon.CallbackList({
	"MODULE_CLEAR",
	"GRAPH_ADD",
	"GRAPH_REMOVE",
	"VARIABLE_ADD",
	"VARIABLE_REMOVE",
})

fmtMagic = 0x42504D58
fmtVersion = 3

local meta = {}
meta.__index = meta

nextModuleID = nextModuleID or 0
activeModules = activeModules or {}

bpcommon.CreateIndexableListIterators(meta, "graphs")
bpcommon.CreateIndexableListIterators(meta, "variables")

function meta:Init()

	self.graphs = bplist.New():NamedItems("Graph")
	self.variables = bplist.New():NamedItems("Var")
	self.id = nextModuleID

	self.graphs:AddListener(function(cb, id)

		if cb == bplist.CB_ADD then
			self:FireListeners(CB_GRAPH_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			self:FireListeners(CB_GRAPH_REMOVE, id)
		end

	end, bplist.CB_ALL)

	self.variables:AddListener(function(cb, id, var)

		if cb == bplist.CB_ADD then
			self:FireListeners(CB_VARIABLE_ADD, id)
		elseif cb == bplist.CB_REMOVE then
			local match = {["Set" .. var.name] = 1, ["Get" .. var.name] = 1}
			for _, graph in self:Graphs() do
				graph:RemoveNodeIf( function( node )
					return match[node.nodeType]
				end )
			end

			self:FireListeners(CB_VARIABLE_REMOVE, id)
		end

	end, bplist.CB_ALL)

	bpcommon.MakeObservable(self)

	nextModuleID = nextModuleID + 1
	return self

end

function meta:GetNodeTypes( graphID )

	local types = {}
	local base = NodeTypes

	for _, v in self:Variables() do

		local name = v:GetName()
		types["Set" .. name] = v:SetterNodeType()
		types["Get" .. name] = v:GetterNodeType()

	end

	for k,v in pairs(types) do v.name = k end
	for k,v in pairs(base) do
		if not types[k] then types[k] = v end
	end

	return types

end

function meta:Clear()

	self.graphs:Clear()
	self.variables:Clear()

	self:FireListeners(CB_MODULE_CLEAR)

end

function meta:NewVariable(name, type, default, flags)

	return self.variables:Add( bpvariable.New(type, default, flags), name )

end

function meta:NewGraph(name)

	return self.graphs:Add( bpgraph.New(self, GT_Event), name )

end

function meta:CopyGraph( graphID )

	local graph = self:GetGraph( graphID )
	if graph == nil then return end

	local copy = self:GetGraph( self:NewGraph( "graphproxy_" .. self.nextGraphID ) )
	graph:CopyInto(copy)

	return copy

end

function meta:WriteToStream(stream)

	stream:WriteInt( fmtMagic, false )
	stream:WriteInt( fmtVersion, false )

	bpdata.WriteValue( self.variables:GetTable(), stream )

	stream:WriteInt( self.graphs:Size(), false )
	for id, graph in self:Graphs() do
		local name = graph:GetName()
		stream:WriteInt( name:len(), false )
		stream:WriteStr( name )
		graph:WriteToStream(stream, fmtVersion)
	end

end

function meta:ReadFromStream(stream)

	self:Clear()

	local magic = stream:ReadInt( false )
	local version = stream:ReadInt( false )

	if magic ~= fmtMagic then error("Invalid blueprint data") end
	if version > fmtVersion then error("Blueprint data version is newer") end

	if version >= 2 then
		local vars = bpdata.ReadValue( stream )
		for _, v in pairs(vars) do
			self:NewVariable(v.name, v.type, v.default, v.flags)
		end
	end

	local count = stream:ReadInt( false )
	for i=1, count do
		local id = self:NewGraph( stream:ReadStr(stream:ReadInt(false)) )
		local graph = self:GetGraph(id)
		graph:ReadFromStream(stream, version)
	end

end

function meta:CreateTestModule()

	local a = self:GetGraph( self:NewGraph("Function") )
	local b = self:GetGraph( self:NewGraph("EventGraph") )

	a:CreateTestGraph()
	b:CreateTestGraph()

	return self

end

function meta:BindGamemodeHooks()

	if not self:IsValid() then return end

	local bp = self:Get()
	local meta = bp.meta
	local instance = self:GetSingleton()

	if instance.Init then instance:Init() end

	for k,v in pairs(bp.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local function call(...) return instance[k](instance, ...) end
		hook.Add(v.hook, v.key, call)
	end

end

function meta:UnbindGamemodeHooks()

	if not self:IsValid() then return end

	local bp = self:Get()
	local meta = bp.meta

	for k,v in pairs(bp.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		hook.Remove(v.hook, v.key)
	end

end

function meta:SetEnabled( enable )

	if not self:IsValid() then return end

	local isEnabled = activeModules[self.id] ~= nil
	if isEnabled == false and enable == true then
		self:BindGamemodeHooks()
		activeModules[self.id] = self
		return
	end

	if isEnabled == true and enable == false then
		self:UnbindGamemodeHooks()
		activeModules[self.id] = nil
		return
	end

end

function meta:GetSingleton()

	self.singleton = self.singleton or (self:IsValid() and self:Get().new() or nil)
	return self.singleton

end

function meta:Compile(compileErrorHandler)

	local ok, res = false, nil
	if compileErrorHandler then
		ok, res = xpcall(bpcompile.Compile, function(err)
			if compileErrorHandler then compileErrorHandler(self, debug.traceback()) return end
		end, self)
	else
		ok, res = true, bpcompile.Compile(self)
	end

	if ok then
		self.compiled = res
		self:AttachErrorHandler()
	end

end

function meta:AttachErrorHandler()

	if self.errorHandler ~= nil then
		self:Get().onError = function(msg, mod, graph, node)
			self.errorHandler(self, msg, graph, node)
		end
	end

end

function meta:IsValid()

	return self.compiled ~= nil

end

function meta:Get()

	return self.compiled

end

function meta:SetErrorHandler(errorHandler)

	self.errorHandler = errorHandler

	if self:IsValid() then
		self:AttachErrorHandler()
	end

end

function New(...)
	return setmetatable({}, meta):Init(...)
end

function CreateTestModule()
	return New():CreateTestModule()
end

hook.Add("Think", "__updatebpmodules", function()

	for _, m in pairs(activeModules) do
		m:Get().update()
	end

end)