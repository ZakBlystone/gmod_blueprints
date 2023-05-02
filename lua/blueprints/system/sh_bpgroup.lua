AddCSLuaFile()

module("bpgroup", package.seeall)

FL_CanUpload = 1          --User can upload files to server
FL_CanRunLocally = 2      --User can run blueprints locally
FL_CanUseProtected = 4    --User can use protected nodes
FL_CanToggle = 8          --User can toggle running blueprints on server
FL_CanViewAny = 16        --User can view any blueprint on the server
FL_CanDelete = 32         --User can delete files on the server

PermissionInfo = {
	[FL_CanUpload] = {"Can Upload", "blueprint upload", "User can upload their blueprints to the server"},
	[FL_CanRunLocally] = {"Can Run Locally", "blueprint run-local", "User can run their blueprints locally"},
	[FL_CanUseProtected] = {"Can Use Protected", "blueprint protected", "User can create protected / unsafe nodes", "superadmin"},
	[FL_CanToggle] = {"Can Toggle Blueprints", "blueprint toggle", "User can toggle running blueprints on server"},
	--[FL_CanViewAny] = {"Can View Any", "blueprint view-any", "User can view any blueprint on the server"},
	[FL_CanDelete] = {"Can Delete", "blueprint delete", "User can delete files on the server"},
}

function LookupPrivilegeName(fl)

	return PermissionInfo[fl][2]

end

function CheckPermissions(ply, fl)

	if not IsValid(ply) then return false end
	return CAMI.PlayerHasAccess(
		ply, 
		bpgroup.LookupPrivilegeName(fl), 
		nil, nil, nil)

end

for k,v in pairs(PermissionInfo) do

	CAMI.RegisterPrivilege({
		Name = v[2],
		MinAccess = v[4] or "admin",
		Description = v[3],
	})

end