AddCSLuaFile()

module("mod_dermalayout", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.CanBeSubmodule = true
MODULE.Name = LOCTEXT"module_dermalayout_name","Derma Layout"
MODULE.Description = LOCTEXT"module_dermalayout_desc","Custom UI Panel"
MODULE.Icon = "icon16/application_edit.png"
MODULE.EditorClass = "dermalayout"
MODULE.SelfPinSubClass = "Panel"
MODULE.HasUIDClassname = true

function MODULE:Setup()

	BaseClass.Setup(self)

end

function MODULE:Compile(compiler, pass)

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

		compiler.emit([[
__bpm.init = function() end
__bpm.postInit = function() if __bpm.ref then __bpm.ref:PostInit() end end
__bpm.refresh = function() end
__bpm.shutdown = function() end]])

	end

end

RegisterModuleClass("DermaLayout", MODULE, "MetaType")