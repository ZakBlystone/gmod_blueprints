AddCSLuaFile()

module("mod_projectmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.Name = LOCTEXT"module_project_name","Project"
MODULE.Description = LOCTEXT"module_project_desc","Project"
MODULE.Icon = "icon16/wrench.png"
MODULE.EditorClass = "projectmodule"

RegisterModuleClass("ProjectModule", MODULE, "Configurable")