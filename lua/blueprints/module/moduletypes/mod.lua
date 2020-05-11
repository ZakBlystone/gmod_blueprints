AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = LOCTEXT"module_mod_name","Mod"
MODULE.Description = LOCTEXT"module_mod_desc","A Basic Script"
MODULE.Icon = "icon16/joystick.png"
MODULE.Creatable = true
MODULE.CanBeSubmodule = true

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	graph:AddNode("CORE_Init", 120, 100)
	graph:AddNode("GM_Think", 120, 300)
	graph:AddNode("CORE_Shutdown", 120, 500)

end

local blacklistHooks = {
	["WEAPON"] = true,
	["ENTITY"] = true,
	["EFFECT"] = true,
}

function MODULE:CanAddNode(nodeType)

	local group = nodeType:GetGroup()
	if group and nodeType:GetContext() == bpnodetype.NC_Hook and blacklistHooks[group:GetName()] then return false end

	return BaseClass:CanAddNode( nodeType )

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MODULEMETA then

		compiler.emit("function meta:Initialize()")
		compiler.emit("\tlocal instance = self")
		compiler.emit("\tinstance.delays = {}")
		compiler.emit("\tinstance.__bpm = __bpm")
		compiler.emit("\tinstance.guid = __bpm.guid")
		compiler.emitContext( CTX_Vars .. "global", 1 )
		compiler.emit("\tself.bInitialized = true")
		compiler.emit("\tself:netInit()")
		compiler.emit("\tself:hookEvents(true)")
		compiler.emit("\tif self.CORE_Init then self:CORE_Init() end")
		compiler.emit("end")

		compiler.emit([[
function meta:Shutdown()
	if not self.bInitialized then return end
	self:hookEvents(false)
	if self.CORE_Shutdown then self:CORE_Shutdown() end
	self:netShutdown()
end]])

		return true

	elseif pass == CP_MODULEBPM then

		compiler.emit([[
__bpm.init = function()
	local instance = setmetatable({}, __bpm.meta)
	instance:Initialize()
	G_BPInstances = G_BPInstances or {}
	G_BPInstances[__bpm.guid] = instance
end
__bpm.refresh = function()
	local instance = G_BPInstances[__bpm.guid]
	if not instance then return end
	setmetatable(instance, __bpm.meta)
	instance:hookEvents(true)
end
__bpm.shutdown = function()
	local instance = G_BPInstances[__bpm.guid]
	if not instance then return end
	instance:Shutdown()
	G_BPInstances[__bpm.guid] = nil
end]])

	end

end


RegisterModuleClass("Mod", MODULE, "MetaType")