AddCSLuaFile()

module("bpvaluetype", package.seeall)

bpcommon.CallbackList({
	"VALUE_CHANGED",
})

local valueClasses = bpclassloader.Get("Value", "blueprints/core/valuetypes/", "BPValueTypeClassRefresh")
local meta = bpcommon.MetaTable("bpvaluetype")

FL_NONE = 0
FL_MANDATORY_OPTIONS = 1
FL_HINT_MODEL = 2
FL_HINT_SOUND = 4
FL_HINT_MATERIAL = 8

bpcommon.AddFlagAccessors(meta)

meta.Match = function( v ) return false end

function meta:Init( class, setter, getter )

	bpcommon.MakeObservable(self)

	self.flags = FL_NONE

	if class then
		self._class = class
		valueClasses:Install(self._class, self)
	end

	if setter then self._Set = function(s, v) setter(v) end end
	if getter then self._Get = function(s) return getter() end end

	if self:_Get() == nil then self:_Set( self:GetDefault() ) end

	return self

end

function meta:GetDefault()

	return nil

end

function meta:GetOptions()

	return self._options or {}

end

function meta:SetOptions( opt, mandatory )

	self._options = opt
	return self

end

function meta:OnChanged(old, new, key)

	if new ~= old or key ~= nil then
		self:FireListeners(CB_VALUE_CHANGED, old, new, key)
	end

end

function meta:_Set(v) end
function meta:_Get() return self:GetDefault() end

function meta:Set(v)

	if not self.Match(v) then error("Invalid value for type: " .. self._class) end

	local p = self:_Get()
	self:_Set(v)
	self:OnChanged( p, self:_Get() )
	return self

end

function meta:Get()

	return self:_Get()

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

	bpdata.WriteValue( self._class, stream )
	stream:WriteBits( self.flags, 8 )
	return self

end

function meta:ReadFromStream(stream)

	self._class = bpdata.ReadValue( stream )
	self.flags = stream:ReadBits(8)
	valueClasses:Install(self._class, self)
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end

function FromValue( val, ... )

	for k,v in pairs(valueClasses.registered) do
		if v.Match(val) then return New( k, ... ):Set(val) end
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
	},
	Vec = Vector(1,2,3),
}

if SERVER then

	local tab = nil
	local t = FromValue(test, function(v) tab = v end, function() return tab end)

	print(t:ToString())

end