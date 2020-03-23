AddCSLuaFile()

module("bpvaluetype", package.seeall)

bpcommon.CallbackList({
	"VALUE_CHANGED",
})

local meta = bpcommon.MetaTable("bpvaluetype")
local valueClasses = bpclassloader.Get("Value", "blueprints/core/valuetypes/", "BPValueTypeClassRefresh", meta)

FL_NONE = 0
FL_MANDATORY_OPTIONS = 1
FL_HINT_BROWSER = 2
FL_READONLY = 4
FL_HIDDEN = 8

bpcommon.AddFlagAccessors(meta)

meta.Match = function( v ) return false end

function meta:Init( class, getter, setter, outer )

	bpcommon.MakeObservable(self)

	self.outer = outer
	self.outermost = self
	while self.outermost.outer ~= nil do
		self.outermost = self.outermost.outer
	end

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

function meta:InitPinType( pinType )

	if self.SetupPinType then
		self:SetupPinType( pinType )
	end
	return self

end

function meta:OverrideClass( class )

	if class then
		self._class = class
		valueClasses:Install(self._class, self)
	end
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

function meta:CheckType( v )

	if not self.Match(v) then error("Invalid value for type: " .. self._class) end

end

function meta:Set(v)

	self:CheckType(v)

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

	entry:SetEnabled(not self:HasFlag(bpvaluetype.FL_READONLY))

	self:AddListener( function(cb, old, new, key)
		if cb == bpvaluetype.CB_VALUE_CHANGED then
			entry:SetText( new )
		end 
	end )

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

function FromValue( val, getter, setter, outer )

	if type(val) == "table" and isbpvaluetype(val) then
		return val
	end

	if type(val) ~= "table" and not getter then error("Non-table values require at least a getter") end
	getter = getter or function() return val end

	for k,v in pairs(valueClasses.registered) do
		if v.Match(val) then return New( k, getter, setter, outer ):Set(val) end
	end
	error("No value type for: " .. tostring(val))
	return nil

end

function FromPinType( pinType, getter, setter, outer )

	return bpcommon.Profile("value-from-pintype", function()

		local class = bpschema.GetPinValueTypeClass( pinType )
		if not class then
			print("No value type for: " .. pinType:ToString() )
			return New( "none", getter, setter, outer ):InitPinType( pinType )
		end

		local vt = New( class, getter, setter, outer ):InitPinType( pinType )
		if class == "struct" then
			local struct = pinType:FindStruct()
			if struct == nil then
				print("Couldn't find struct for type: " .. pinType:ToString())
				return nil
			end
			vt:SetStruct( pinType:FindStruct() )
		end

		if pinType:HasFlag( bpschema.PNF_Table ) then return nil end
		return vt

	end)

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

	--[[local tab = {}
	local vt = FromPinType(bpschema.PinType(bpschema.PN_Struct, 0, "AddonInfo"), function() return tab end)
	if vt then
		vt:Set({})

		print(vt:ToString())
	end]]

end