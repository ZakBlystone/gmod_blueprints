AddCSLuaFile()

module("bpgroup", package.seeall)

FL_None = 0
FL_Permanent = 1           --Group cannot be removed
FL_CanUpload = 2           --User can upload files to server
FL_CanRunLocally = 4       --User can run blueprints locally
FL_CanUseProtected = 8     --User can use protected nodes
FL_CanToggle = 16          --User can toggle running blueprints on server
FL_CanEditPermissions = 32 --User can edit group permission table
FL_CanEditUsers = 64       --User can add and remove users from groups
FL_CanEditGroups = 128     --User can add and remove groups
FL_CanViewAny = 256        --User can view any blueprint on the server
FL_AllPermissions = 0xFFFF

local meta = bpcommon.MetaTable("bpgroup")
meta.__eq = function(a,b) return a.name == b.name end

bpcommon.AddFlagAccessors(meta)

function meta:Init( name, flags )

	self.flags = flags or FL_None
	self.name = name
	return self

end

function meta:WriteToStream(stream, mode, version)

	bpdata.WriteValue( self.name, stream )
	stream:WriteBits( self.flags, 16 )

	return self

end

function meta:ReadFromStream(stream, mode, version)

	self.name = bpdata.ReadValue( stream )
	self.flags = stream:ReadBits( 16 )

	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end