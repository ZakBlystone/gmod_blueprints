AddCSLuaFile()

module("bpenv", package.seeall, bpcommon.rescope(bpcommon))

installed = installed or {}
active = active or {}

DestroyAll = nil
Uninstall = nil

function HandleModuleError( mod, msg, graphID, nodeID )

	hook.Run("BPModuleError", mod, msg, graphID, nodeID)

end

function Get( uid )

	return installed[uid]

end

function Install( mod )

	local uid = mod:GetUID()

	if installed[uid] and mod:GetType() == "mod" then Uninstall( uid ) end

	--print("INSTALL MODULE: " .. GUIDToString(uid))

	mod:SetErrorHandler( HandleModuleError )
	mod:Initialize()
	installed[mod:GetUID()] = mod

end

function Uninstall( uid )

	if uid == nil then return end

	if installed[uid] ~= nil then
		--print("UNINSTALL MODULE: " .. GUIDToString(uid))

		installed[uid]:Shutdown()

		DestroyAll(uid)
		installed[uid] = nil
	else
		--print("ALREADY UNINSTALLED MODULE: " .. GUIDToString(uid))
	end

end

function Instantiate( uid, forceGUID )

	if not installed[uid] then error("Tried to instantiate module before it was installed") end

	local instance = installed[uid]:Instantiate( forceGUID )
	if instance == nil then return nil end

	instance:__Init()
	active[#active+1] = instance
	return instance

end

function NumRunningInstances( uid )

	local count = 0
	for i=#active, 1, -1 do
		if active[i]:__GetModule():GetUID() == uid then count = count + 1 end
	end
	return count

end

function Destroy( instance )

	if instance == nil then return end
	instance:__Shutdown()
	table.RemoveByValue(active, instance)

end

function DestroyAll( uid )

	for i=#active, 1, -1 do
		if active[i]:__GetModule():GetUID() == uid then Destroy(active[i]) end
	end

end

hook.Add("Think", "BPUpdateModules", function()

	for _, instance in ipairs(active) do
		instance:update()
	end

end)