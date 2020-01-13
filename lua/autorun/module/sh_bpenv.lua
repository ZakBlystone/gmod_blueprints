AddCSLuaFile()

module("bpenv", package.seeall, bpcommon.rescope(bpcommon))

installed = installed or {}
active = active or {}

DestroyAll = nil
Uninstall = nil

function HandleModuleError( mod, msg, graphID, nodeID )

	Uninstall( mod )
	hook.Run("BPModuleError", mod, msg, graphID, nodeID)

end

function Get( uid )

	return installed[uid]

end

function Install( mod )

	local uid = mod:GetUID()

	print("INSTALL MODULE: " .. GUIDToString(uid))

	if installed[uid] then
		self:Uninstall( uid )
	end
	mod:SetErrorHandler( HandleModuleError )
	installed[mod:GetUID()] = mod

end

function Uninstall( mod )

	local uid = mod:GetUID()

	if installed[mod:GetUID()] ~= nil then
		print("UNINSTALL MODULE: " .. GUIDToString(uid))

		DestroyAll(mod)
		installed[mod:GetUID()] = nil
	else
		--print("ALREADY UNINSTALLED MODULE: " .. GUIDToString(uid))
	end

end

function Instantiate( mod, forceGUID )

	local instance = mod:Instantiate( forceGUID )
	instance:__Init()
	active[#active+1] = instance
	return instance

end

function NumRunningInstances( mod )

	local uid = mod:GetUID()
	local count = 0
	for i=#active, 1, -1 do
		if active[i]:__GetModule():GetUID() == uid then count = count + 1 end
	end
	return count

end

function Destroy( instance )

	instance:__Shutdown()
	table.RemoveByValue(active, instance)

end

function DestroyAll( mod )

	local uid = mod:GetUID()
	for i=#active, 1, -1 do
		if active[i]:__GetModule():GetUID() == uid then Destroy(active[i]) end
	end

end

hook.Add("Think", "BPUpdateModules", function()

	for _, instance in ipairs(active) do
		instance:update()
	end

end)