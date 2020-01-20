AddCSLuaFile()

if SERVER then
	util.AddNetworkString("bphandshake")
	util.AddNetworkString("bpmessage")
	util.AddNetworkString("bpclosechannel")
end

-- CORE
include("core/sh_bpcommon.lua")
include("core/sh_bpindexer.lua")
include("core/sh_bpbuffer.lua")
include("core/sh_bplist.lua")
include("core/sh_bplistdiff.lua")
include("core/sh_bpnetlist.lua")
include("core/sh_bpstringtable.lua")
include("core/sh_bpdata.lua")
include("core/sh_bptransfer.lua")

-- GRAPH
include("graph/sh_bppintype.lua")
include("graph/sh_bppin.lua")
include("graph/sh_bpschema.lua")
include("graph/sh_bpnodeclasses.lua")
include("graph/sh_bpnodetype.lua")
include("graph/sh_bpnodetypegroup.lua")
include("graph/sh_bpnode.lua")
include("graph/sh_bpgraph.lua")

-- MODULE
include("module/sh_bpvariable.lua")
include("module/sh_bpstruct.lua")
include("module/sh_bpevent.lua")
include("module/sh_bpmodule.lua")
include("module/sh_bpcompiledmodule.lua")
include("module/sh_bpenv.lua")
include("module/sh_bpnet.lua")
include("module/sh_bpcompiler.lua")

-- SYSTEM
include("system/sh_bpuser.lua")
include("system/sh_bpgroup.lua")
include("system/sh_bpusermanager.lua")
include("system/sh_bpfile.lua")
include("system/sh_bpfilesystem.lua")

-- DEFS
include("defs/sh_bpdefpack.lua")
include("defs/sh_bpdefs.lua")

-- UI
include("ui/sh_bpui.lua")
include("ui/cl_bprenderutils.lua")
include("ui/cl_bprender2d.lua")
include("ui/cl_bpmenubar.lua")
include("ui/cl_bpfilemanager.lua")
include("ui/cl_bpuser.lua")
include("ui/cl_bpgroup.lua")
include("ui/cl_bpusermanager.lua")
include("ui/cl_bpgraph.lua")
include("ui/cl_bpgraphcreatemenu.lua")
include("ui/cl_bpgraphpin.lua")
include("ui/cl_bpgraphnode.lua")
include("ui/cl_bpgraphnodeset.lua")
include("ui/cl_bpgraphpainter.lua")
include("ui/cl_bpgrapheditor.lua")
include("ui/cl_bpgrapheditorinterface.lua")
include("ui/cl_bplistview.lua")
include("ui/cl_bptextliteraledit.lua")
include("ui/cl_bpgrapheditmenu.lua")
include("ui/cl_bpstructeditmenu.lua")
include("ui/cl_bpvarcreatemenu.lua")
include("ui/cl_bpmoduleeditor.lua")
include("ui/cl_bpeditor.lua")

-- TEST
include("sh_bptest.lua")