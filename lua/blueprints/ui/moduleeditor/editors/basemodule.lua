if SERVER then AddCSLuaFile() return end

module("editor_basemodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

local text_module_copied = LOCTEXT("module_export_text", "Module copied to clipboard")
local text_module_key_copied = LOCTEXT("module_export_key_ok", "Blueprint key copied to clipboard")
local text_module_key_failed = LOCTEXT("module_export_key_failed", "Error creating sharable key: %s")
local text_module_name = LOCTEXT("module_name", "Module Name")

local text_menu_save = LOCTEXT("menu_save", "Save")
local text_menu_export = LOCTEXT("menu_export", "Export")
local text_menu_export_shareable = LOCTEXT("menu_export_shareable", "Export shareable key")
local text_menu_export_lua = LOCTEXT("menu_export_lua","Export Lua script")
local text_menu_local_install = LOCTEXT("menu_localinstall","Local: Install")
local text_menu_local_uninstall = LOCTEXT("menu_localuninstall","Local: Uninstall")
local text_menu_send_to_server = LOCTEXT("menu_sendtoserver","Send to server")

local text_run_fail = LOCTEXT("module_run_fail", "Failed to run")
local text_compile_fail = LOCTEXT("module_compile_fail", "Failed to compile")

local text_script_copied = LOCTEXT("module_lua_export", "Lua script copied to clipboard")
local text_local_no_permission = LOCTEXT("module_local_no_permission", "You do not have permission to run local scripts")
local text_module_save_fail = LOCTEXT("module_save_fail", "Failed to create module: %s")

local suppressExportMsg = CreateConVar("bp_suppress_export_message", "0", FCVAR_ARCHIVE, "For debugging, disables to popup notification when exporting things")

EDITOR.CanSave = true
EDITOR.CanSendToServer = false
EDITOR.CanInstallLocally = false
EDITOR.CanExportLuaScript = false

function EDITOR:ShouldCreateMenuBar()

	if self:GetModule():FindOuter( bpmodule_meta ) then return false end
	return true

end

function EDITOR:PopulateMenuBar( t )

	if self:GetModule():FindOuter( bpmodule_meta ) then return end

	if self.CanSave then

		t[#t+1] = { name = text_menu_save, func = function() self:Save() end, icon = "icon16/disk.png" }
		t[#t+1] = { name = text_menu_export, func = function() self:Export() end, icon = "icon16/folder_go.png" }
		t[#t+1] = { name = text_menu_export_shareable, func = function(...) self:ExportShareableKey(...) end, icon = "icon16/folder_go.png" }

	end

	if self.CanSendToServer then

		t[#t+1] = { name = text_menu_send_to_server, func = function(...) self:SendToServer(...) end, color = Color(80,180,80), icon = "icon16/server_go.png" }

	end

	if self.CanInstallLocally then

		t[#t+1] = { name = text_menu_local_install, func = function(...) self:InstallLocally(...) end, icon = "icon16/flag_green.png" }
		t[#t+1] = { name = text_menu_local_uninstall, func = function(...) self:UninstallLocally(...) end, icon = "icon16/flag_red.png" }

	end

	if self.CanExportLuaScript then

		t[#t+1] = { name = text_menu_export_lua, func = function(...) self:ExportLua(...) end, icon = "icon16/page_code.png" }

	end
end

function EDITOR:Export()

	local text = bpmodule.SaveToText( self:GetTargetModule() )
	SetClipboardText( text )
	if not suppressExportMsg:GetBool() then 
		bpmodal.Message({
			message = text_module_copied, 
			title = text_menu_export
		})
	end

end

function EDITOR:ExportShareableKey( pnl )

	local text = bpmodule.SaveToText( self:GetTargetModule() )
	local prev = pnl:GetText()

	pnl:SetEnabled(false)
	bppaste.Upload( text, function( ok, result )

		if IsValid(pnl) then pnl:SetEnabled(true) end
		if ok then
			SetClipboardText( result )
			bpmodal.Message({
				message = text_module_key_copied, 
				title = text_menu_export_shareable
			})
		else
			bpmodal.Message({
				message = text_module_key_failed(tostring(result)), 
				title = text_menu_export_shareable
			})
		end

	end)

end

function EDITOR:SendToServer()

	_G.G_BPError = nil
	self:GetMainEditor():ClearReport()
	--bpnet.SendModule( self.module )
	local ok, res = self:GetTargetModule():TryBuild( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
	if ok then
		ok, res = res:TryLoad()
		if ok then
			self:Save( function(ok) if ok then print("**Uploading Module") self:Upload(true) end end )
		else
			bpmodal.Message({
				message = res,
				title = text_run_fail
			})
		end
	else
		bpmodal.Message({
			message = res,
			title = text_compile_fail
		})
	end

end

function EDITOR:InstallLocally()

	if not bpusermanager.GetLocalUser():HasPermission( bpgroup.FL_CanRunLocally ) then
		bpmodal.Message({
			message = text_local_no_permission, 
			title = text_menu_local_install, 
		})
		return
	end

	local ok, res = self:GetTargetModule():TryBuild( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
	if ok then
		ok, res = res:TryLoad()
		if ok then
			bpenv.Uninstall( self:GetTargetModule():GetUID() )
			bpenv.Install( res )
			bpenv.Instantiate( res:GetUID() )
		else
			bpmodal.Message({
				message = res,
				title = text_run_fail
			})
		end
	else
		bpmodal.Message({
			message = res,
			title = text_compile_fail
		})
	end

end

function EDITOR:UninstallLocally()

	bpenv.Uninstall( self:GetTargetModule():GetUID() )

end

function EDITOR:ExportLua()

	local ok, res = self:GetTargetModule():TryBuild( bit.bor(bpcompiler.CF_Standalone, bpcompiler.CF_Comments) )
	if ok then
		SetClipboardText( res:GetCode() )
		if not suppressExportMsg:GetBool() then
			bpmodal.Message({
				message = text_script_copied,
				title = text_menu_export_lua
			})
		end
	else
		ErrorNoHalt( res )
	end

end

function EDITOR:Upload( execute )

	local file = self:GetFile()
	if not file then return end

	local name = bpfilesystem.ModulePathToName( file:GetPath() )
	bpfilesystem.UploadObject(self:GetTargetModule(), name or file:GetPath(), execute)

end


function EDITOR:Save( callback )

	local file = self:GetFile()
	local tab = self:GetTab()
	if file == nil then

		bpmodal.String({
			title = text_menu_save,
			message = text_module_name,
			default = "untitled",
			confirm = function( text )
				local file = bpfilesystem.AddLocalModule( self:GetTargetModule(), text )
				if file ~= nil then
					tab:SetLabel( text )
					if callback then callback(true) end
				else
					if callback then callback(false) end
					bpmodal.Message({
						message = text_module_save_fail(text),
						title = "error",
					})
				end
			end,
		})

	else

		print("**Saving Module")
		bpmodule.Save( file:GetPath(), self:GetTargetModule() )
		bpfilesystem.MarkFileAsChanged( file, false )
		if tab then tab:SetSuffix("") end
		if callback then callback(true) end

	end

end

function EDITOR:GetTargetModule()

	local mod = self:GetModule()
	local outer = mod:FindOuter(bpmodule_meta)
	if outer then
		return outer
	end
	return mod

end

RegisterModuleEditorClass("basemodule", EDITOR)