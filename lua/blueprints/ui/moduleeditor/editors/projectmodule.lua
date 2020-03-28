if SERVER then AddCSLuaFile() return end

module("editor_projectmodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

RegisterModuleEditorClass("projectmodule", EDITOR, "basemodule")