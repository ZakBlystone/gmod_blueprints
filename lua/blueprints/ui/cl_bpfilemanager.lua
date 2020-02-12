if SERVER then AddCSLuaFile() return end

module("bpuifilemanager", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}

local lockIconLocal = "icon16/accept.png"
local lockIconRemote = "icon16/lock_delete.png"
local lockIconUnlocked = "icon16/page.png"
local statusIconHasChanges = "icon16/asterisk_yellow.png"
local statusIconRunning = "icon16/resultset_next.png"
local statusIconStopped = "icon16/stop.png"

function PANEL:OnFileOpen( file )

end

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetText("")

	self.nameLabel = vgui.Create("DLabel", self)
	self.nameLabel:SetFont("DermaDefaultBold")

	self.lockImage = vgui.Create("DImage", self)
	self.lockImage:SetImage(lockIconUnlocked)

	self.statusImage = vgui.Create("DImage", self)
	self.statusImage:SetImage(statusIconHasChanges)

end

function PANEL:GetName()

	return self.file and self.file:GetName() or "file"

end

function PANEL:GetFile()

	return self.file

end

function PANEL:SetFile(file, role)

	self.file = file
	self.role = role

	local title = ""
	if role == bpfilesystem.FT_Local then
		title = tostring(self.file:GetName()).. " --- " .. tostring(self.file:GetPath())
	else
		title = tostring(self.file:GetName()) .. " --- by: " .. tostring( self.file:GetOwner() )
	end

	if self.file:HasFlag( bpfile.FL_IsServerFile ) then
		title = title .. " r" .. tostring(self.file:GetRevision())
	end
	self.nameLabel:SetText( title )

	if role == bpfilesystem.FT_Local then
		self.statusImage:SetVisible( self.file:HasFlag( bpfile.FL_HasLocalChanges) )
	else
		self.statusImage:SetVisible( true )
		self.statusImage:SetImage( self.file:HasFlag( bpfile.FL_Running ) and statusIconRunning or statusIconStopped )
	end

	local lock = self.file:GetLock()
	if lock then

		local isLocal = lock == bpusermanager.GetLocalUser()
		self.lockImage:SetImage(isLocal and lockIconLocal or lockIconRemote)
		self.lockImage:SetVisible(true)

	else

		if self.file:HasFlag( bpfile.FL_IsServerFile ) then

			self.lockImage:SetImage(lockIconUnlocked)
			self.lockImage:SetVisible(false)

		else

			self.lockImage:SetVisible(false)

		end

	end

end

function PANEL:PerformLayout()

	self.nameLabel:SetPos( 4, 4)
	self.nameLabel:SizeToContents()

	local w,h = self:GetSize()
	self.lockImage:SizeToContents()
	self.lockImage:SetPos(w-self.lockImage:GetWide()-4, h/2 - self.lockImage:GetTall()/2)

	self.statusImage:SizeToContents()
	self.statusImage:SetPos(w-32-4, h/2 - self.lockImage:GetTall()/2)

end

function PANEL:Paint(w, h)

	if not self.view then return end

	local selected = self.view:GetEditor().selectedFile == self

	if self.file:HasFlag( bpfile.FL_IsServerFile ) then

		--draw.RoundedBoxEx(8, 0, 0, w-40, h, HexColor("#2d3436"), false, false, false, false)
		self.nameLabel:SetTextColor( selected and HexColor("ffd271") or HexColor("#dfe6e9") )

		local lock = self.file:GetLock()
		local col = lock and (lock == bpusermanager.GetLocalUser() and HexColor("#9cf196") or HexColor("#edaaaa")) or HexColor("#636e72")
		draw.RoundedBoxEx(8, 0, 0, w, h, Color(col.r/1.5, col.g/1.5, col.b/1.5), false, true, false, true)

	else

		self.nameLabel:SetTextColor( selected and HexColor("ffd271") or HexColor("#636e72") )
		draw.RoundedBoxEx(8, 0, 0, w, h, HexColor("#2d3436"), false, true, false, true)

	end

end

function PANEL:OpenFile()

	self.view:GetEditor():OpenFile( self.file )

end

function PANEL:UploadFile()

	local mod = bpmodule.New()
	local name = bpfilesystem.ModulePathToName( self.file:GetPath() )
	mod:Load(self.file:GetPath())
	bpfilesystem.UploadObject(mod, name or self.file:GetPath())

end

function PANEL:DoDoubleClick()

	print("DoubleClick")

	if self.file and self.role == bpfilesystem.FT_Local then

		if self.file:HasFlag( bpfile.FL_IsServerFile ) then

			if self.file:GetLock() ~= bpusermanager.GetLocalUser() then

				bpfilesystem.TakeLock( self.file, function(res, msg)

					if res then
						self:OpenFile()
					else
						Derma_Message( msg, "Failed to take lock on file", "OK" )
					end

				end )

			else

				self:OpenFile()

			end

		else

			self:OpenFile()

		end

	end

end

function PANEL:DoClick()

	print("Clicked")

	self.view:GetEditor().selectedFile = self

end

function PANEL:CloseMenu()

	if IsValid( self.menu ) then
		self.menu:Remove()
	end

end

function PANEL:OpenMenu()

	self:CloseMenu()

	self.menu = DermaMenu( false, self )

	if self.role == bpfilesystem.FT_Remote then

		if self.file:HasFlag( bpfile.FL_Running ) then

			self.menu:AddOption( "Stop File", function()
				bpfilesystem.StopFile( self.file )
			end)

		else

			self.menu:AddOption( "Run File", function()
				bpfilesystem.RunFile( self.file )
			end)

		end

		self.menu:AddOption( "Download", function()

			bpfilesystem.DownloadFile( self.file, function(res, msg)

				if not res then
					Derma_Message( msg, "Failed to download file", "OK" )
				end

			end )

		end )

	end

	if self.file:HasFlag( bpfile.FL_IsServerFile ) then

		if self.file:GetLock() == nil then

			self.menu:AddOption( "Take Lock", function()

				bpfilesystem.TakeLock( self.file, function(res, msg)

					if not res then
						Derma_Message( msg, "Failed to take lock on file", "OK" )
					end

				end )

			end )

		else

			self.menu:AddOption( "Release Lock", function()

				self.view:GetEditor():CloseFile( self.file, function()
					bpfilesystem.ReleaseLock( self.file, function(res, msg)

						if not res then
							Derma_Message( msg, "Failed to release lock on file", "OK" )
						end

					end )
				end )

			end )

		end

	elseif self.role == bpfilesystem.FT_Local then

		self.menu:AddOption( "Upload", function()

			self:UploadFile()

		end)

	end

	if self.role == bpfilesystem.FT_Local then

		self.menu:AddOption( "Delete", function()

		Derma_Query("Are you sure you want to delete \"" .. self.file:GetName() .. "\"?", "Delete File",
		"Yes", function() self.view:GetEditor():CloseFileUID( self.file:GetUID() ) file.Delete(self.file:GetPath()) bpfilesystem.IndexLocalFiles() end,
		"No", function() end)

		end)

	else

		self.menu:AddOption( "Delete", function()

		Derma_Query("Are you sure you want to delete \"" .. self.file:GetName() .. "\"?", "Delete File",
		"Yes", function() bpfilesystem.DeleteFile( self.file ) end,
		"No", function() end)

		end)

	end
	
	self.menu:SetMinimumWidth( 100 )
	self.menu:Open( gui.MouseX(), gui.MouseY(), false, self )

end

function PANEL:DoRightClick()

	self.view:GetEditor().selectedFile = self
	self:OpenMenu()

end

derma.DefineControl( "BPFile", "Blueprint file", PANEL, "DButton" )


local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetBackgroundColor( Color(40,40,40) )

	self.label = vgui.Create("DLabel", self)
	self.label:SetText("FILES")
	self.label:DockMargin(8, 2, 2, 2)
	self.label:Dock( TOP )
	self.label:SetFont("DermaDefaultBold")

	self.listLookup = {}
	self.list = vgui.Create("DPanelList", self)
	self.list:SetSpacing(2)
	self.list:EnableVerticalScrollbar()
	self.list:Dock( FILL )

end

function PANEL:SetTitle( title )

	self.label:SetText( title )
	return self

end

function PANEL:ClearFiles()

	for i=#self.list.Items, 1, -1 do
		local item = self.list.Items[i]
		local uid = item:GetFile():GetUID()
		self.listLookup[uid] = nil
		self.list.Items[i]:Remove()
		table.remove(self.list.Items, i)
	end

end

function PANEL:UpdateFiles(fileList, role)

	local persist = {}
	for _, v in pairs( fileList ) do
		local id = v:GetUID()
		local existing = self.listLookup[id]
		persist[id] = true
		if not existing then
			local panel = vgui.Create("BPFile")
			panel:SetFile(v, role)
			panel.view = self
			self.list:AddItem( panel )
			self.listLookup[id] = panel
		else
			existing:SetFile(v, role)
		end
	end

	for i=#self.list.Items, 1, -1 do
		local item = self.list.Items[i]
		local uid = item:GetFile():GetUID()
		if not persist[uid] then
			self.listLookup[uid] = nil
			self.list.Items[i]:Remove()
			table.remove(self.list.Items, i)
		end
	end

	table.sort( self.list.Items, function( a, b )

		return a:GetName() < b:GetName()

	end)

end

derma.DefineControl( "BPFileList", "Blueprint file list", PANEL, "DPanel" )

local PANEL = {}
local FileViews = {}

function PANEL:Init()

	FileViews[#FileViews+1] = self

	self.menu = bpuimenubar.AddTo(self)
	self.menu:Add("New Module", function() self:ModuleDropdown() end, nil, "icon16/asterisk_yellow.png")
	self.menu:Add("Refresh Local Files", function() self.localList:ClearFiles() bpfilesystem.IndexLocalFiles(true) end, nil, "icon16/arrow_refresh.png")
	self.menu:Add("Import", function() self.editor:OpenImport() end, nil, "icon16/folder_page.png")
	self.menu:Add("Help", function() self.editor:OpenHelp() end, nil, "icon16/help.png")
	self.menu:Add("About", function() self.editor:OpenAbout() end, nil)
	--self.menu:Add("Upload", function() end, nil, "icon16/arrow_up.png")

	self.middle = vgui.Create("DPanel")
	self.middle:SetBackgroundColor(Color(70,70,70))

	self.contentPanel = vgui.Create("DPanel", self)
	self.contentPanel:Dock( FILL )
	self.contentPanel:SetBackgroundColor( Color(50,50,50) )

	self.content = vgui.Create("DHorizontalDivider", self.contentPanel)
	self.content:Dock( FILL )
	self.content:SetBackgroundColor( Color(30,30,30) )

	self.remoteList = vgui.Create("BPFileList"):SetTitle("Server Files")
	self.localList = vgui.Create("BPFileList"):SetTitle("Local Files")

	self.remoteList.GetEditor = function() return self.editor end
	self.localList.GetEditor = function() return self.editor end

	self.content:SetLeft(self.localList)
	self.content:SetRight(self.remoteList)
	self.content:SetMiddle(self.middle)
	self.content:SetDividerWidth(50)

	--[[self.localView.OnFileOpen = function(p, file)
		local mod = bpmodule.New()
		self.editor:OpenModule( mod )
	end]]

	self:UpdateRemoteFiles()
	self:UpdateLocalFiles()

end

function PANEL:ModuleDropdown()

	if IsValid(self.cmenu) then self.cmenu:Remove() end
	self.cmenu = DermaMenu( false, self )

	local loader = bpmodule.GetClassLoader()
	local classes = bpcommon.Transform( loader:GetClasses(), {}, function(k) return {name = k, class = loader:Get(k)} end )

	table.sort( classes, function(a,b) return a.class.Name < b.class.Name end )

	for _, v in ipairs( classes ) do

		local cl = v.class
		local op = self.cmenu:AddOption( cl.Name, function()

			self:CreateModule( v.name )

		end)
		if cl.Icon then op:SetIcon( cl.Icon ) end
		if cl.Description then op:SetTooltip( cl.Description ) end

	end

	self.cmenu:SetMinimumWidth( 100 )
	self.cmenu:Open( gui.MouseX(), gui.MouseY(), false, self )

end

function PANEL:CreateModule(type)

	--[[print("Create Module")
	Derma_StringRequest("New Module", "Module Name", "untitled",
		function( text )
			local file = bpfilesystem.NewModuleFile( text )
			if not file then Derma_Message("Failed to create module: " .. text, "Error", "Ok") end
			if file ~= nil then self.editor:OpenFile( file ) end
		end, nil, "OK", "Cancel")]]

	local mod = bpmodule.New(type)
	mod:CreateDefaults()
	self.editor:OpenModule(mod, "unnamed", nil)

end

function PANEL:OnRemove()

	table.RemoveByValue(FileViews, self)

end

function PANEL:UpdateRemoteFiles()

	self.remoteList:UpdateFiles( bpfilesystem.GetFiles(), bpfilesystem.FT_Remote )

end

function PANEL:UpdateLocalFiles()

	self.localList:UpdateFiles( bpfilesystem.GetLocalFiles(), bpfilesystem.FT_Local )

end

function PANEL:PerformLayout()

	local w = self:GetWide() - self.content:GetDividerWidth()
	self.content:SetLeftMin(w/2)
	self.content:SetRightMin(w/2)

end

hook.Add("BPFileTableUpdated", "filemanagerui", function(index)

	if index == bpfilesystem.FT_Remote then
		for _, v in ipairs(FileViews) do v:UpdateRemoteFiles() end
	elseif index == bpfilesystem.FT_Local then
		for _, v in ipairs(FileViews) do v:UpdateLocalFiles() end
	end

end)

derma.DefineControl( "BPFileManager", "Blueprint file manager", PANEL, "DPanel" )