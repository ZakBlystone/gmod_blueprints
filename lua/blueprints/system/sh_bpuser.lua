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

function meta:ShiftGroupBits( id )

	assert(SERVER)
	local keepMask = bit.lshift(1, id) - 1
	local shiftMask = bit.bnot( self.groups )
	local old = bit.band( self.groups, keepMask )
	local shifted = bit.band( bit.rshift( self.groups, 1 ), shiftMask )
	self.groups = bit.bor( shifted, bit.band( self.groups, keepMask ) )

end

function meta:AddGroup( group )

	assert(SERVER)
	local id = bpusermanager.GetGroupID( group )
	if id == -1 then print("Unable to find group: " .. group:GetName()) return end
	self.groups = bit.bor( self.groups, bit.lshift(1, id) )

end

function meta:RemoveGroup( group )

	assert(SERVER)
	local id = bpusermanager.GetGroupID( group )
	if id == -1 then print("Unable to find group: " .. group:GetName()) return end
	self.groups = bit.band( self.groups, bit.bnot( bit.lshift(1, id) ) )

end

function meta:IsInGroup( group )

	local id = bpusermanager.GetGroupID( group )
	if id == -1 then print("Unable to find group: " .. group:GetName()) return end
	return bit.band( self.groups, bit.lshift(1, id) ) ~= 0

end

function meta:GetPermissions()

	local groups = bpusermanager.GetGroups()
	local p = 0
	for i=0, 31 do
		if bit.band( self.groups, bit.lshift(1, i) ) ~= 0 then
			p = bit.bor(p, groups[i+1]:GetFlags())
		end
	end
	return p

end

function meta:HasPermission( fl )

	return bit.band( self:GetPermissions(), fl ) ~= 0

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