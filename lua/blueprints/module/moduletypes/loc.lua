AddCSLuaFile()

module("mod_locmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.Name = LOCTEXT"module_loc_name","Localization"
MODULE.Description = LOCTEXT"module_loc_desc","Localization data for the editor"
MODULE.Icon = "icon16/table.png"
MODULE.EditorClass = "locmodule"
MODULE.Developer = true

function MODULE:Setup()

	BaseClass.Setup(self)

	self.data = {}

	local t = {}
	for k, v in ipairs( bplocalization.GetKeys() ) do
		t[v] = tostring(bplocalization.Get(v))
	end

	self.data.locale = "en_us"
	self.data.keys = t

end

function MODULE:GetLanguage()

	return self.data.language

end

function MODULE:GetLocString( key )

	return self.data.keys[key]

end

function MODULE:SerializeData(stream)

	BaseClass.SerializeData( self, stream )

	self.data.language = stream:String( self.data.language )
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
		if bit.band(compiler.flags, CF_Standalone) ~= 0 then
			compiler.emit("bplocalization.AddLocTable(data)")
		else
			compiler.emit("__bpm.init = function() bplocalization.AddLocTable(data) end")
			compiler.emit("__bpm.shutdown = function() bplocalization.RemoveLocTable(data) end")
			compiler.emit("return __bpm")
		end

	end

end

RegisterModuleClass("LocModule", MODULE, "Configurable")