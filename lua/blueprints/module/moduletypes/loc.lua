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

function MODULE:WriteData( stream, mode, version )

	BaseClass.WriteData( self, stream, mode, version )

	stream:WriteStr( self.data.locale )

	local num = 0
	for k,v in pairs(self.data.keys) do
		num = num + 1
	end

	stream:WriteInt( num, false )

	for k,v in pairs(self.data.keys) do
		stream:WriteStr( k )
		stream:WriteStr( v )
	end

end

function MODULE:ReadData( stream, mode, version )

	BaseClass.ReadData( self, stream, mode, version )

	self.data.locale = stream:ReadStr()

	local num = stream:ReadInt()

	for i=1, num do

		local k = stream:ReadStr()
		local v = stream:ReadStr()
		self.data.keys[k] = v

	end

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