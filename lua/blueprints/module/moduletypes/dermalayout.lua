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

	self.layoutRoot = nil

end

function MODULE:CreateDefaults()

	print("CREATE DEFAULTS")

	self.layoutRoot = bpdermanode.New("Window")
	local button = bpdermanode.New("Button", self.layoutRoot)

end

function MODULE:Root()

	return self.layoutRoot

end

function MODULE:SerializeData( stream )

	BaseClass.SerializeData( self, stream )

	self.layoutRoot = stream:Object( self.layoutRoot, self )

end

function MODULE:CanHaveVariables() return true end
function MODULE:CanHaveStructs() return true end
function MODULE:CanHaveEvents() return false end
function MODULE:RequiresNetCode() return false end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MAINPASS then

		compiler.begin("derma")
		compiler.emit("local __panels = {}")
		compiler.emit("local __makePanel(id, ...) return vgui.CreateFromTable(__panels[id], ...) end")
		if self:Root() then
			print("Compile root: ", tostring(self:Root()))
			self:Root():Compile(compiler, pass)
		else
			print("No root node")
		end
		compiler.finish()


	elseif pass == CP_MODULECODE then

		compiler.emitContext("derma")


	elseif pass == CP_MODULEMETA then

		return true

	elseif pass == CP_MODULEBPM then

		compiler.emit([[
__bpm.init = function() end
__bpm.postInit = function() end
__bpm.refresh = function() end
__bpm.shutdown = function() end]])

	end

end

RegisterModuleClass("DermaLayout", MODULE, "MetaType")