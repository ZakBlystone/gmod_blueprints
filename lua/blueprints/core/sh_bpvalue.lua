AddCSLuaFile()

module("bpvaluetype", package.seeall)

bpcommon.CallbackList({
	"VALUE_CHANGED",
})

local valueClasses = bpclassloader.Get("Value", "blueprints/core/valuetypes/", "BPValueTypeClassRefresh")
local meta = bpcommon.MetaTable("bpvaluetype")

function meta:Init( class )

	bpcommon.MakeObservable(self)

	if class then
		self._class = class
		valueClasses:Install(self._class, self)
		self:Set( self:GetDefault() )
	end

	return self

end

function meta:GetDefault()

	return nil

end

function meta:Set(v)

	if v ~= self._value then
		self:FireListeners(CB_VALUE_CHANGED, self._value, v)
	end

	self._value = v
	return self

end

function meta:Get()

	return self._value

end

function meta:CreateVGUI( info )

	local entry = vgui.Create("DTextEntry")
	entry:SetText( self:ToString() )
	entry:SelectAllOnFocus()
	entry:SetUpdateOnType(true)

	if info.onFinished then
		local detour = entry.OnKeyCodeTyped
		entry.OnKeyCodeTyped = function(pnl, code)
			if code == KEY_ENTER then return info.onFinished() end
			detour(pnl, code)
		end
	end
	entry.OnValueChange = function(pnl, value)
		self:SetFromString( value )
		pnl:SetText( self:ToString() )
		if info.onChanged then info.onChanged() end
	end

	return entry

end

function meta:ToString()

	return "<invalid>"

end

function meta:SetFromString( str )

end

function meta:WriteToStream(stream)

	bpdata.WriteValue( self._value, stream )
	bpdata.WriteValue( self._class, stream )
	return self

end

function meta:ReadFromStream(stream)

	self._value = bpdata.ReadValue( stream )
	self._class = bpdata.ReadValue( stream )
	valueClasses:Install(self._class, self)
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end

function FromValue( val )

	for k,v in pairs(valueClasses.registered) do
		if v.Match(val) then return New( k ):Set(val) end
	end
	error("No value type for: " .. tostring(val))
	return nil

end

local test = {
	Spawnable = false,
	AdminOnly = false,
	Primary = {
		ClipSize = 8,
		DefaultClip = 32,
		Automatic = false,
		Ammo = "Pistol",
	},
	Secondary = {
		ClipSize = 8,
		DefaultClip = 32,
		Automatic = false,
		Ammo = "Pistol",
	}
}

if SERVER then

	print("TESTING")
	local t = FromValue(test)
	PrintTable(t)

end