if SERVER then AddCSLuaFile() return end

module("bpuifilemanager", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}

local lockIconLocal = "icon16/accept.png"
local lockIconRemote = "icon16/lock_delete.png"
local lockIconUnlocked = "icon16/page.png"
local statusIconHasChanges = "icon16/asterisk_yellow.png"
local statusIconRunning = "icon16/resultset_next.png"
local statusIconStopped = "icon16/stop.png"
local typeIconDefault = "icon16/joystick.png"

local text_query_delete = LOCTEXT("query_file_delete", "Are you sure you want to delete '%s'?")
local text_query_title_delete = LOCTEXT("query_file_delete_title", "Delete File")

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

	self.typeImage = vgui.Create("DImage", self)
	self.typeImage:SetImage(typeIconDefault)

end

function PANEL:GetName()

	return self.file and self.file:GetName() or "file"

end

function PANEL:GetFile()

	return self.file

end

function PANEL:GetTypeIcon(type)

	local loader = bpmodule.GetClassLoader()
	local class = loader:Get(type)
	return class and class.Icon or typeIconDefault

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

	if file.header then
		local fileType = file.header.type
		if type(fileType) == "string" then
			self.typeImage:SetImage( self:GetTypeIcon(fileType) )
		end
	end

	if self.file:HasFlag( bpfile.FL_IsServerFile ) then
		title = title .. " r" .. tostring(self.file:GetRevision())
	end
	self.nameLabel:SetText( title )

	if role == bpfilesystem.FT_Local then
		self.statusImage:SetVisible( self.file:HasFlag( bpfile.FL_HasLocalChanges) )
	else
		self.typeImage:SetVisible(false)
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

	self.typeImage:SizeToContents()

	if self.statusImage:IsVisible() then
		self.typeImage:SetPos(w-48-4, h/2 - self.typeImage:GetTall()/2)
	else
		self.typeImage:SetPos(w-32-4, h/2 - self.typeImage:GetTall()/2)
	end

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

	local mod = bpmodule.Load(self.file:GetPath()):WithOuter(self.file)
	local name = bpfilesystem.ModulePathToName( self.file:GetPath() )
	bpfilesystem.UploadObject(mod, name or self.file:GetPath())

end

function PANEL:DoDoubleClick()

	--print("DoubleClick")

	if self.file and self.role == bpfilesystem.FT_Local then

		if self.file:HasFlag( bpfile.FL_IsServerFile ) then

			if self.file:GetLock() ~= bpusermanager.GetLocalUser() then

				bpfilesystem.TakeLock( self.file, function(res, msg)

					if res then
						self:OpenFile()
					else
						bpmodal.Message({
							message = msg,
							title =  "Failed to take lock on file",
						})
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

	--print("Clicked")

	self.view:GetEditor().selectedFile = self

end

function PANEL:CloseMenu()

	if IsValid( self.menu ) then
		self.menu:Remove()
	end

end

function PANEL:OpenMenu()

	self:CloseMenu()
	local options = {}

	if self.role == bpfilesystem.FT_Remote then

		if self.file:HasFlag( bpfile.FL_Running ) then

			options[#options+1] = {
				title = "Stop File",
				icon = statusIconStopped,
				func = function() bpfilesystem.StopFile( self.file ) end,
			}

		else

			options[#options+1] = {
				title = "Run File",
				icon = statusIconRunning,
				func = function() bpfilesystem.RunFile( self.file ) end,
			}

		end

		options[#options+1] = { title = "Download", func = function()

			bpfilesystem.DownloadFile( self.file, function(res, msg)

				if not res then
					bpmodal.Message({
						message = msg,
						title =  "Failed to download file",
					})
				end

			end )

		end }

	end

	if self.file:HasFlag( bpfile.FL_IsServerFile ) then

		if self.file:GetLock() == nil then

			options[#options+1] = { title = "Take Lock", func = function()

				bpfilesystem.TakeLock( self.file, function(res, msg)

					if not res then
						bpmodal.Message({
							message = msg,
							title =  "Failed to take lock on file",
						})
					end

				end )

			end }

		else

			options[#options+1] = { title = "Release Lock", func = function()

				self.view:GetEditor():CloseFile( self.file, function()
					bpfilesystem.ReleaseLock( self.file, function(res, msg)

						if not res then
							bpmodal.Message({
								message = msg,
								title =  "Failed to release lock on file",
							})
						end

					end )
				end )

			end }

		end

	elseif self.role == bpfilesystem.FT_Local then

		options[#options+1] = { title = "Upload", func = function()

			self:UploadFile()

		end }

	end

	if self.role == bpfilesystem.FT_Local then

		options[#options+1] = { title = "Delete", func = function()

			bpmodal.Query({
				message = text_query_delete(self.file:GetName()),
				title = text_query_title_delete,
				options = {
					{ "yes", function() self.view:GetEditor():CloseFileUID( self.file:GetUID() ) file.Delete(self.file:GetPath()) bpfilesystem.IndexLocalFiles() end },
					{ "no", function() end },
				},
			})

		end }

	else

		options[#options+1] = { title = "Delete", func = function()

			bpmodal.Query({
				message = text_query_delete(self.file:GetName()),
				title = text_query_title_delete,
				options = {
					{ "yes", function() bpfilesystem.DeleteFile( self.file ) end },
					{ "no", function() end },
				},
			})

		end }

	end

	self.menu = bpmodal.Menu({
		options = options,
		width = 100,
	}, self)

end

function PANEL:DoRightClick()

	self.view:GetEditor().selectedFile = self
	self:OpenMenu()

end

derma.DefineControl( "BPFile", "Blueprint file", PANEL, "DButton" )


local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true

	self:SetBackgroundColor(Color(150,150,150))

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

	self.label:SetText( tostring(title) )
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
	self.menu:Add(LOCTEXT("file_newmodule","New Module"), function() self:ModuleDropdown() end, nil, "icon16/asterisk_yellow.png")
	self.menu:Add(LOCTEXT("file_refresh_local","Refresh Local Files"), function() self.localList:ClearFiles() bpfilesystem.IndexLocalFiles(true) end, nil, "icon16/arrow_refresh.png")
	self.menu:Add(LOCTEXT("file_import","Import"), function() self.editor:OpenImport() end, nil, "icon16/folder_page.png")
	self.menu:Add(LOCTEXT("file_import_legacy","Convert Legacy"), function() self.editor:OpenLegacyImporter() end, nil, "icon16/folder_page.png")
	self.menu:Add(LOCTEXT("file_help","Help"), function() self.editor:OpenHelp() end, nil, "icon16/help.png")
	self.menu:Add(LOCTEXT("file_about","About"), function() self.editor:OpenAbout() end, nil)
	--self.menu:Add("Upload", function() end, nil, "icon16/arrow_up.png")

	self.middle = vgui.Create("DPanel")
	self.middle.Paint = function() end

	self.contentPanel = vgui.Create("DPanel", self)
	self.contentPanel:Dock( FILL )
	self.contentPanel.Paint = function() end
	--self.contentPanel:SetBackgroundColor( Color(50,50,50) )

	self.content = vgui.Create("DHorizontalDivider", self.contentPanel)
	self.content:Dock( FILL )
	self.content:DockMargin(4,4,4,4)
	self.content:SetBackgroundColor( Color(30,30,30) )

	self.remoteList = vgui.Create("BPFileList"):SetTitle(LOCTEXT("file_list_server","Server Files"))
	self.localList = vgui.Create("BPFileList"):SetTitle(LOCTEXT("file_list_client","Local Files"))

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

--function PANEL:Paint() end

function PANEL:ModuleDropdown()

	if IsValid(self.cmenu) then self.cmenu:Remove() end

	local options = {}

	local loader = bpmodule.GetClassLoader()
	local classes = bpcommon.Transform( loader:GetClasses(), {}, function(k) return {name = k, class = loader:Get(k)} end )

	table.sort( classes, function(a,b) return tostring(a.class.Name) < tostring(b.class.Name) end )

	bpcommon.Transform( classes, options, function(v)
		local cl = v.class
		if not cl.Creatable or cl.Developer then return end
		return {
			title = tostring(cl.Name),
			func = function() self:CreateModule( v.name ) end,
			icon = cl.Icon,
			desc = cl.Description,
		}
	end)

	options[#options+1] = {}

	local templateCategories = {}

	bpcommon.Transform( classes, templateCategories, function(v)
		local cl = v.class
		if not cl.Creatable then return end

		local templates = bptemplates.GetByType( v.name )
		if #templates == 0 then return end

		local options = bpcommon.Transform( templates, {}, function(v)

			return {
				title = tostring(v.name),
				func = function()
					local mod = bptemplates.CreateTemplate( v )
					self.editor:OpenModule(mod, "unnamed", nil)
				end,
				icon = cl.Icon,
				desc = tostring(v.description) .. "\nby " .. tostring(v.author),
			}

		end )

		return {
			title = tostring(cl.Name),
			options = options,
			icon = cl.Icon,
			desc = cl.Description,
		}
	end)

	options[#options+1] = {
		title = LOCTEXT("module_submenu_examples","Examples"),
		options = templateCategories,
		icon = "icon16/book.png",
	}

	options[#options+1] = {}

	local devOptions = bpcommon.Transform( classes, {}, function(v)
		local cl = v.class
		if not cl.Creatable or not cl.Developer then return end
		return {
			title = tostring(cl.Name),
			func = function() self:CreateModule( v.name ) end,
			icon = cl.Icon,
			desc = cl.Description,
		}
	end)

	options[#options+1] = {
		title = LOCTEXT("module_submenu_developer","Developer"),
		options = devOptions,
		icon = "icon16/application_osx_terminal.png",
	}

	self.cmenu = bpmodal.Menu({
		options = options,
		width = 100,
	}, self)

end

function PANEL:CreateModule(type)

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