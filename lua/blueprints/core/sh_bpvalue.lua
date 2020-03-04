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

function meta:Init( class, getter, setter )

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

function meta:IsReadOnly()

	return self._Set == meta._Set

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
	if info.live then entry:SetUpdateOnType(true) end

	if info.onFinished then
		local detour = entry.OnKeyCodeTyped
		entry.OnKeyCodeTyped = function(pnl, code)
			if code == KEY_ENTER then return info.onFinished() end
			detour(pnl, code)
		end
	end
	entry.OnValueChange = function(pnl, value)
		self:SetFromString( value )
		--pnl:SetText( self:ToString() )
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

function FromValue( val, getter, setter, ... )

	if type(val) ~= "table" and not getter then error("Non-table values require at least a getter") end
	getter = getter or function() return val end

	for k,v in pairs(valueClasses.registered) do
		if v.Match(val) then return New( k, getter, setter, ... ):Set(val) end
	end
	error("No value type for: " .. tostring(val))
	return nil

end

if CLIENT then

	local ent = {
		ClassName = "my_entity",
		SENT = {
			Type = "anim",
			AutomaticFrameAdvance = false,
			Category = "",
			Spawnable = true,
			Editable = false,
			AdminOnly = false,
			PrintName = "My Entity",
			Author = "",
			Contact = "",
			Purpose = "",
			Instructions = "",
			RenderGroup = 1,
			DisableDuplicator = false,
			ScriptedEntityType = "",
			DoNotDuplicate = false,
		}
	}

	local swep = {
		ClassName = "weapon_test",
		SWEP = {
			Spawnable = true,
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
		},
	}

	local both = { ["Scripted Weapon"] = swep, ["Scripted Entity"] = ent, }
	concommand.Add("valuetest", function()

		local typeEdit = bpvaluetype.FromValue( both )
		typeEdit:AddListener( function(cb, old, new, k)
			if cb ~= bpvaluetype.CB_VALUE_CHANGED then return end
			print(tostring(k) .. ": ", tostring(old) .. " => " .. tostring(new))
		end )

		local window = vgui.Create( "DFrame" )
		window:SetSizable( true )
		window:SetPos( 400, 0 )
		window:SetSize( 400, 700 )
		window:MakePopup()

		local inner = typeEdit:CreateVGUI({})
		inner:SetParent(window)
		inner:Dock(FILL)

	end)

end