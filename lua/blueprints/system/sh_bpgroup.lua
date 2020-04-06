AddCSLuaFile()

module("bpgroup", package.seeall)

FL_None = 0
FL_Locked = 1              --Group cannot be edited or removed
FL_CanUpload = 2           --User can upload files to server
FL_CanRunLocally = 4       --User can run blueprints locally
FL_CanUseProtected = 8     --User can use protected nodes
FL_CanToggle = 16          --User can toggle running blueprints on server
FL_CanEditPermissions = 32 --User can edit group permission table
FL_CanEditUsers = 64       --User can add and remove users from groups
FL_CanEditGroups = 128     --User can add and remove groups
FL_CanViewAny = 256        --User can view any blueprint on the server
FL_CanDelete = 512         --User can delete files on the server
FL_AllPermissions = 0xFFFF

PermissionInfo = {
	{"Can Upload", FL_CanUpload, "User can upload their blueprints to the server"},
	{"Can Run Locally", FL_CanRunLocally, "User can run their blueprints locally"},
	{"Can Use Protected", FL_CanUseProtected, "User can created protected / unsafe nodes"},
	{"Can Toggle Blueprints", FL_CanToggle, "User can toggle running blueprints on server"},
	{"Can Edit Permissions", FL_CanEditPermissions, "User can edit group permissions"},
	{"Can Edit Users", FL_CanEditUsers, "User can add / remove users from a group"},
	{"Can Edit Groups", FL_CanEditGroups, "User can add / remove groups"},
	{"Can Edit View Any", FL_CanViewAny, "User can view any blueprint on the server"},
	{"Can Delete", FL_CanDelete, "User can delete files on the server"}
}

local meta = bpcommon.MetaTable("bpgroup")
meta.__eq = function(a,b) return a.name == b.name end

bpcommon.AddFlagAccessors(meta)

function meta:Init( name, flags )

	self.flags = flags or FL_None
	self.name = name
	return self

end

function meta:GetName()

	return self.name

end

function meta:GetColor()

	return self.color or Color(50,50,50)

end

function meta:SetColor( col )

	self.color = col
	return self

end

function meta:AddUser(user) bpusermanager.AddUser(self, user) end
function meta:RemoveUser(user) bpusermanager.RemoveUser(self, user) end

function meta:Serialize(stream)

	self.name = stream:Value(self.name)
	self.color = stream:Value(self.color)
	self.flags = stream:Bits(self.flags, 16)

	return stream

end

function New(...) return bpcommon.MakeInstance(meta, ...) end