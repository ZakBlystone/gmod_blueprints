AddCSLuaFile()

module("mod_locmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.Name = LOCTEXT("module_loc_name","Localization")
MODULE.Description = LOCTEXT("module_loc_desc","Localization data for the editor")
MODULE.Icon = "icon16/table.png"
MODULE.EditorClass = "locmodule"
MODULE.Developer = true

function MODULE:Setup()

	BaseClass.Setup(self)

	bplocalization.ScanLuaFiles()

	self.data = {}

	local t = {}
	for k, v in ipairs( bplocalization.GetKeys() ) do
		t[v] = tostring(bplocalization.Get(v))
	end

	self.data.locale = "en-us"
	self.data.keys = t

end

function MODULE:GetLocale()

	return self.data.locale

end

function MODULE:GetLocString( key )

	return self.data.keys[key]

end

function MODULE:SerializeData(stream)

	BaseClass.SerializeData( self, stream )

	self.data.locale = stream:String( self.data.locale )
	self.data.keys = stream:StringMap( self.data.keys )

	return stream

end

function MODULE:Compile( compiler, pass )

	if pass == CP_MODULECODE then

		-- header for module
		if bit.band(compiler.flags, CF_Standalone) == 0 then
			compiler.emit("_FR_MODHEAD()")
		else
			compiler.emit("AddCSLuaFile()")
		end

		compiler.emit("local data = " .. bpvaluetype.FromValue(self.data, function() return self.data end):ToString() )
		compiler.emit("if CLIENT then")
		compiler.pushIndent()
		if bit.band(compiler.flags, CF_Standalone) ~= 0 then
			compiler.emit("bplocalization.AddLocTable(data)")
		else
			compiler.emit("__bpm.init = function() bplocalization.AddLocTable(data, true) end")
			compiler.emit("__bpm.shutdown = function() bplocalization.RemoveLocTable(data) end")
			compiler.emit("return __bpm")
		end
		compiler.popIndent()
		compiler.emit("end")

	end

end

RegisterModuleClass("LocModule", MODULE, "Configurable")