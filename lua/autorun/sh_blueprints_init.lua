AddCSLuaFile()

local enabled = CreateConVar("bp_enabled", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Enable blueprint system (you must restart the server for this to take effect)")
if not enabled:GetBool() then return end

if SERVER then
	util.AddNetworkString("bphandshake")
	util.AddNetworkString("bpmessage")
	util.AddNetworkString("bpclosechannel")
end

local function bpinclude(path)
	include("blueprints/" .. path)
end

-- CORE
bpinclude("core/sh_bpcommon.lua")
bpinclude("core/sh_bpclassloader.lua")
bpinclude("core/sh_bpcollection.lua")
bpinclude("core/sh_bpindexer.lua")
bpinclude("core/sh_bpbuffer.lua")
bpinclude("core/sh_bplist.lua")
bpinclude("core/sh_bplistdiff.lua")
bpinclude("core/sh_bpnetlist.lua")
bpinclude("core/sh_bpstringtable.lua")
bpinclude("core/sh_bpdata.lua")
bpinclude("core/sh_bptransfer.lua")
bpinclude("core/sh_bppaste.lua")

-- GRAPH
bpinclude("graph/sh_bppintype.lua")
bpinclude("graph/sh_bppin.lua")
bpinclude("graph/sh_bpschema.lua")
bpinclude("graph/sh_bpnodetype.lua")
bpinclude("graph/sh_bpnodetypegroup.lua")
bpinclude("graph/sh_bpnode.lua")
bpinclude("graph/sh_bpgraph.lua")

-- MODULE
bpinclude("module/sh_bpvariable.lua")
bpinclude("module/sh_bpstruct.lua")
bpinclude("module/sh_bpevent.lua")
bpinclude("module/sh_bpmodule.lua")
bpinclude("module/sh_bpcompiledmodule.lua")
bpinclude("module/sh_bpenv.lua")
bpinclude("module/sh_bpnet.lua")
bpinclude("module/sh_bpcompiler.lua")

-- SYSTEM
bpinclude("system/sh_bpuser.lua")
bpinclude("system/sh_bpgroup.lua")
bpinclude("system/sh_bpusermanager.lua")
bpinclude("system/sh_bpfile.lua")
bpinclude("system/sh_bpfilesystem.lua")
bpinclude("system/sh_bpswep.lua")

-- DEFS
bpinclude("defs/sh_bpdefpack.lua")
bpinclude("defs/sh_bpdefs.lua")

-- UI
bpinclude("ui/sh_bpui.lua")
bpinclude("ui/cl_bppickmenu.lua")
bpinclude("ui/cl_bprenderutils.lua")
bpinclude("ui/cl_bprender2d.lua")
bpinclude("ui/cl_bptextwrap.lua")
bpinclude("ui/cl_bpmenubar.lua")
bpinclude("ui/cl_bpfilemanager.lua")
bpinclude("ui/cl_bpuser.lua")
bpinclude("ui/cl_bpgroup.lua")
bpinclude("ui/cl_bpusermanager.lua")
bpinclude("ui/cl_bpgraph.lua")
bpinclude("ui/cl_bpgraphcreatemenu.lua")
bpinclude("ui/cl_bpgraphpin.lua")
bpinclude("ui/cl_bpgraphnode.lua")
bpinclude("ui/cl_bpgraphnodeset.lua")
bpinclude("ui/cl_bpgraphpainter.lua")
bpinclude("ui/cl_bpgrapheditor.lua")
bpinclude("ui/cl_bpgrapheditorinterface.lua")
bpinclude("ui/cl_bplistview.lua")
bpinclude("ui/cl_bptextliteraledit.lua")
bpinclude("ui/cl_bpgrapheditmenu.lua")
bpinclude("ui/cl_bpstructeditmenu.lua")
bpinclude("ui/cl_bpvarcreatemenu.lua")
bpinclude("ui/cl_bpmoduleeditor.lua")
bpinclude("ui/cl_bpassetbrowser.lua")
bpinclude("ui/cl_bpeditor.lua")

-- TEST
include("sh_blueprints_test.lua")

hook.Run("BPPostInit")