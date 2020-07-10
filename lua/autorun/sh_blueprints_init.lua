AddCSLuaFile()

if G_BPInitialized then return end

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
bpinclude("core/sh_bplocalization.lua")
bpinclude("core/sh_bpcommon.lua")
bpinclude("core/sh_bpclassloader.lua")
bpinclude("core/sh_bpcollection.lua")
bpinclude("core/sh_bpindexer.lua")
bpinclude("core/sh_bpbuffer.lua")
bpinclude("core/sh_bplist.lua")
bpinclude("core/sh_bplistdiff.lua")
--bpinclude("core/sh_bpnetlist.lua")
bpinclude("core/sh_bpstringtable.lua")
bpinclude("core/sh_bpdata.lua")
bpinclude("core/sh_bpobjectlinker.lua")
bpinclude("core/sh_bpstream.lua")
bpinclude("core/sh_bptransfer.lua")
bpinclude("core/sh_bppaste.lua")
bpinclude("core/sh_bpvalue.lua")

-- LOCALIZATION
bpinclude("localization/en_us.lua")
bpinclude("localization/de_de.lua")
bpinclude("localization/fr_fr.lua")
bpinclude("localization/pl.lua")
bpinclude("localization/ru.lua")

-- GRAPH
bpinclude("graph/sh_bpschema.lua")
bpinclude("graph/sh_bppintype.lua")
bpinclude("graph/sh_bppin.lua")
bpinclude("graph/sh_bpcallback.lua")
bpinclude("graph/sh_bpcast.lua")
bpinclude("graph/sh_bpcompiler.lua")
bpinclude("graph/sh_bpnodetype.lua")
bpinclude("graph/sh_bpnodetypegroup.lua")
bpinclude("graph/sh_bpnode.lua")
bpinclude("graph/sh_bpgraph.lua")

-- DERMA
bpinclude("derma/sh_bplayout.lua")
bpinclude("derma/sh_bpdermanode.lua")

-- MODULE
bpinclude("module/sh_bpvariable.lua")
bpinclude("module/sh_bpstruct.lua")
bpinclude("module/sh_bpevent.lua")
bpinclude("module/sh_bpmodule.lua")
bpinclude("module/sh_bpcompiledmodule.lua")
bpinclude("module/sh_bpenv.lua")
bpinclude("module/sh_bpnet.lua")

-- SYSTEM
bpinclude("system/sh_bpuser.lua")
bpinclude("system/sh_bpgroup.lua")
bpinclude("system/sh_bpsandbox.lua")
bpinclude("system/sh_bpusermanager.lua")
bpinclude("system/sh_bpfile.lua")
bpinclude("system/sh_bpfilesystem.lua")
--bpinclude("system/sh_bpswep.lua")

-- DEFS
bpinclude("defs/sh_bpdefpack.lua")
bpinclude("defs/sh_bpdefs.lua")

-- UI
bpinclude("ui/sh_bpui.lua")
bpinclude("ui/utils/cl_bpframe.lua")
bpinclude("ui/utils/cl_bpcategorycollapse.lua")
bpinclude("ui/utils/cl_bpcategorylist.lua")
bpinclude("ui/utils/cl_bprenderutils.lua")
bpinclude("ui/utils/cl_bprender2d.lua")
bpinclude("ui/utils/cl_bppickmenu.lua")
bpinclude("ui/utils/cl_bptextwrap.lua")
bpinclude("ui/utils/cl_bpmenubar.lua")
bpinclude("ui/utils/cl_bplistpanel.lua")
bpinclude("ui/utils/cl_bplistview.lua")
bpinclude("ui/utils/cl_bpviewport2d.lua")
bpinclude("ui/dermaeditor/cl_bpdpreview.lua")
bpinclude("ui/filemanager/cl_bpfilemanager.lua")
bpinclude("ui/filemanager/cl_bptemplates.lua")
bpinclude("ui/usermanager/cl_bpuser.lua")
bpinclude("ui/usermanager/cl_bpgroup.lua")
bpinclude("ui/usermanager/cl_bpusermanager.lua")
bpinclude("ui/grapheditor/cl_bpgraph.lua")
bpinclude("ui/grapheditor/cl_bpgraphpin.lua")
bpinclude("ui/grapheditor/cl_bpgraphnode.lua")
bpinclude("ui/grapheditor/cl_bpgraphnodeset.lua")
bpinclude("ui/grapheditor/cl_bpgraphpainter.lua")
bpinclude("ui/grapheditor/cl_bpgrapheditor.lua")
bpinclude("ui/grapheditor/cl_bpgrapheditorinterface.lua")
bpinclude("ui/grapheditor/cl_bptextliteraledit.lua")
bpinclude("ui/moduleeditor/cl_bpgrapheditmenu.lua")
bpinclude("ui/moduleeditor/cl_bpstructeditmenu.lua")
bpinclude("ui/moduleeditor/cl_bpvarcreatemenu.lua")
bpinclude("ui/moduleeditor/cl_bpmoduleeditor.lua")
bpinclude("ui/moduleeditor/cl_bppinlistentry.lua")
bpinclude("ui/assetbrowser/cl_bpassettile.lua")
bpinclude("ui/assetbrowser/cl_bpassetbrowser.lua")
bpinclude("ui/cl_bpskin.lua")
bpinclude("ui/cl_bpeditor.lua")

-- TEST
include("sh_blueprints_test.lua")

hook.Run("BPPostInit")

G_BPInitialized = true