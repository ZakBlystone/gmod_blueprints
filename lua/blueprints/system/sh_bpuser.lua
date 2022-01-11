AddCSLuaFile()

module("bpuser", package.seeall)

FL_None = 0
FL_LoggedIn = 1
FL_NewUser = 2

local meta = bpcommon.MetaTable("bpuser")
meta.__eq = function(a,b) return a:Equals(b) end

bpcommon.AddFlagAccessors(meta)

function meta:ToString()

	return tostring(self:GetName()) .. " [ " .. tostring(self:GetSteamID()) .. " ]"

end

function meta:Init( ply )

	if ply then self:SetPlayer(ply) end

	self.flags = FL_None
	self.groups = 0

	return self

end

function meta:HasPermission( fl )

	return bpgroup.CheckPermissions(self:GetPlayer(), fl)

end

function meta:Equals( other )

	return isbpuser(other) and self:GetSteamID() == other:GetSteamID()

end

function meta:GetSteamID()

	return self.steamID

end

function meta:GetSteamID64()

	return util.SteamIDTo64( self.steamID )

end

function meta:IsValid()

	return self.steamID ~= nil

end

function meta:GetPlayer()

	if SERVER and game.SinglePlayer() then error("Cannot find player by steamID on SERVER in singleplayer") end

	return player.GetBySteamID( self:GetSteamID() )

end

function meta:SetPlayer(ply)

	if SERVER and game.SinglePlayer() then error("Cannot determine player steamID on SERVER in singleplayer") end

	self.name = ply:GetName()
	self.steamID = ply:SteamID()

end

function meta:GetName()

	return self.name

end

function meta:Serialize(stream)

	self.steamID = stream:Value(self.steamID)
	self.name = stream:Value(self.name)
	self.flags = stream:Bits(self.flags, 8)
	self.groups = stream:Bits(self.groups, 32)

	if stream:IsFile() and stream:IsReading() then
		self:ClearFlag( FL_LoggedIn )
		self:ClearFlag( FL_NewUser )
	end

	if stream:IsReading() and CLIENT then

		-- Get up-to-date name
		steamworks.RequestPlayerInfo( self:GetSteamID64(), function( name )

			self.name = name

		end )

	end

	return stream

end

function New(...) return bpcommon.MakeInstance(meta, ...) end