if SERVER then AddCSLuaFile() return end

module("editor_basemodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.CanSave = true
EDITOR.CanSendToServer = false
EDITOR.CanInstallLocally = false
EDITOR.CanExportLuaScript = false

function EDITOR:PopulateMenuBar( t )

	if self.CanSave then

		t[#t+1] = { name = LOCTEXT("menu_save", "Save"), func = function() self:Save() end, icon = "icon16/disk.png" }
		t[#t+1] = { name = LOCTEXT("menu_export", "Export"), func = function() self:Export() end, icon = "icon16/folder_go.png" }
		t[#t+1] = { name = LOCTEXT("menu_export_shareable", "Export shareable key"), func = function(...) self:ExportShareableKey(...) end, icon = "icon16/folder_go.png" }

	end

	if self.CanSendToServer then

		t[#t+1] = { name = LOCTEXT("menu_sendtoserver","Send to server"), func = function(...) self:SendToServer(...) end, color = Color(80,180,80), icon = "icon16/server_go.png" }

	end

	if self.CanInstallLocally then

		t[#t+1] = { name = LOCTEXT("menu_localinstall","Local: Install"), func = function(...) self:InstallLocally(...) end, icon = "icon16/flag_green.png" }
		t[#t+1] = { name = LOCTEXT("menu_localuninstall","Local: Uninstall"), func = function(...) self:UninstallLocally(...) end, icon = "icon16/flag_red.png" }

	end

	if self.CanExportLuaScript then

		t[#t+1] = { name = LOCTEXT("menu_export_lua","Export Lua script"), func = function(...) self:ExportLua(...) end, icon = "icon16/page_code.png" }

	end

end

function EDITOR:Export()

	local text = self:GetModule():SaveToText()
	SetClipboardText( text )
	Derma_Message( "Module copied to clipboard", "Export", "Ok" )

end

function EDITOR:ExportShareableKey( pnl )

	local text = self:GetModule():SaveToText()
	local prev = pnl:GetText()

	pnl:SetEnabled(false)
	bppaste.Upload( text, function( ok, result )

		if IsValid(pnl) then pnl:SetEnabled(true) end
		if ok then
			SetClipboardText( result )
			Derma_Message( "Blueprint key copied to clipboard", "Export shareable key", "Ok" )
		else
			Derma_Message( "Error creating sharable key: " .. tostring(result), "Export shareable key", "Ok" )
		end

	end)

end

function EDITOR:SendToServer()

	_G.G_BPError = nil
	self:GetMainEditor():ClearReport()
	--bpnet.SendModule( self.module )
	local ok, res = self:GetModule():TryBuild( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
	if ok then
		ok, res = res:TryLoad()
		if ok then
			self:Save( function(ok) if ok then self:Upload(true) end end )
		else
			Derma_Message( res, "Failed to run", "OK" )
		end
	else
		Derma_Message( res, "Failed to compile", "OK" )
	end

end

function EDITOR:InstallLocally()

	if not bpusermanager.GetLocalUser():HasPermission( bpgroup.FL_CanRunLocally ) then
		Derma_Message( "You do not have permission to run local scripts", "Run Locally", "OK" )
		return
	end

	local ok, res = self:GetModule():TryBuild( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
	if ok then
		ok, res = res:TryLoad()
		if ok then
			bpenv.Uninstall( self:GetModule():GetUID() )
			bpenv.Install( res )
			bpenv.Instantiate( res:GetUID() )
		else
			Derma_Message( res, "Failed to run", "OK" )
		end
	else
		Derma_Message( res, "Failed to compile", "OK" )
	end

end

function EDITOR:UninstallLocally()

	bpenv.Uninstall( self:GetModule():GetUID() )

end

function EDITOR:ExportLua()

	local ok, res = self:GetModule():TryBuild( bit.bor(bpcompiler.CF_Standalone, bpcompiler.CF_Comments) )
	if ok then
		SetClipboardText( res:GetCode() )
	else
		ErrorNoHalt( res )
	end

end

function EDITOR:Upload( execute )

	local file = self:GetFile()
	if not file then return end

	local name = bpfilesystem.ModulePathToName( file:GetPath() )
	bpfilesystem.UploadObject(self:GetModule(), name or file:GetPath(), execute)

end


function EDITOR:Save( callback )

	local file = self:GetFile()
	local tab = self:GetTab()
	if file == nil then

		Derma_StringRequest("Save Module", "Module Name", "untitled",
		function( text )
			local file = bpfilesystem.AddLocalModule( self:GetModule(), text )
			if file ~= nil then
				tab:SetLabel( text )
				if callback then callback(true) end
			else
				if callback then callback(false) end
				Derma_Message("Failed to create module: " .. text, "Error", "Ok")
			end
		end, nil, "OK", "Cancel")

	else

		self:GetModule():Save( file:GetPath() )
		bpfilesystem.MarkFileAsChanged( file, false )
		if tab then tab:SetSuffix("") end
		if callback then callback(true) end

	end

end

RegisterModuleEditorClass("basemodule", EDITOR)