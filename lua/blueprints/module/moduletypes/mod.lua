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

function MODULE:IsStatic()

	return true

end

function MODULE:GetStaticReference(compiler, fromModule)

	if fromModule == self then
		return "__self"
	end

	assert(isbpcompiler(compiler:GetOuter()))
	return "__modules[" .. compiler:GetOuter():GetID(self) .. "].ref"

end

function MODULE:Compile(compiler, pass)

	local withinProject = self:FindOuter(bpmodule_meta) ~= nil
	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MODULEMETA then

		compiler.emit("function meta:Initialize()")
		compiler.emit("\tself.delays = {}")
		compiler.emit("\tself.__bpm = __bpm")
		compiler.emit("\tself.guid = __bpm.guid")
		compiler.emitContext( CTX_Vars .. "global", 1 )
		compiler.emit("\tself.bInitialized = true")
		compiler.emit("\tself:netInit()")
		compiler.emit("end")
		compiler.emit("function meta:PostInit()")
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

		local s = "\n"
		if not withinProject then s = "\n\t__bpm.ref:PostInit()\n" end

		compiler.emit([[
__bpm.init = function()
	if G_BPInstances[__bpm.guid] ~= nil then return end
	__bpm.ref = setmetatable({}, __bpm.meta)
	__bpm.ref:Initialize()
	G_BPInstances[__bpm.guid] = __bpm.ref
	hook.Add( "Think", __bpm.guid, function(...) local b,e = pcall(__bpm.ref.update, __bpm.ref) b = b or __bpm.error(e) end )]] .. s .. [[
end
__bpm.postInit = function() if __bpm.ref then __bpm.ref:PostInit() end end
__bpm.refresh = function()
	__bpm.ref = G_BPInstances[__bpm.guid]
	if not __bpm.ref then return end
	setmetatable(__bpm.ref, __bpm.meta)
	__bpm.ref.__bpm = __bpm
	__bpm.ref:hookEvents(true)
end
__bpm.shutdown = function()
	__bpm.ref = G_BPInstances[__bpm.guid]
	if not __bpm.ref then return end
	hook.Remove( "Think", __bpm.guid )
	__bpm.ref:Shutdown()
	__bpm.ref = nil
	G_BPInstances[__bpm.guid] = nil
end]])

	end

end


RegisterModuleClass("Mod", MODULE, "MetaType")