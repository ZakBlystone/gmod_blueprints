if SERVER then AddCSLuaFile() return end

module("bpuifilemanager", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}

function PANEL:OnFileOpen( file )

end

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetText("")

	self.nameLabel = vgui.Create("DLabel", self)
	self.nameLabel:SetFont("DermaDefaultBold")

end

function PANEL:SetFile(file, role)

	self.file = file
	self.role = role

	if role == bpfilesystem.FT_Local then
		self.nameLabel:SetText( file:GetName() .. " --- " .. tostring(file:GetPath()) )
	else
		self.nameLabel:SetText( file:GetName() )
	end

end

function PANEL:PerformLayout()

	self.nameLabel:SetPos( 4, 4)
	self.nameLabel:SizeToContents()

end

function PANEL:Paint(w, h)

	draw.RoundedBox(4, 0, 0, w, h, Color(50,50,50))

end

derma.DefineControl( "BPFile", "Blueprint file", PANEL, "DButton" )


local PANEL = {}
local FileViews = {}

function PANEL:Init()

	FileViews[#FileViews+1] = self

	self.menu = bpuimenubar.AddTo(self)
	self.menu:Add("New Module", function() end, nil, "icon16/asterisk_yellow.png")

	self.middle = vgui.Create("DPanel")
	self.middle:SetBackgroundColor(Color(70,70,70))

	self.contentPanel = vgui.Create("DPanel", self)
	self.contentPanel:Dock( FILL )
	self.contentPanel:SetBackgroundColor( Color(50,50,50) )

	self.content = vgui.Create("DHorizontalDivider", self.contentPanel)
	self.content:Dock( FILL )
	self.content:SetBackgroundColor( Color(30,30,30) )

	self.remoteLookup = {}
	self.remoteList = vgui.Create("DPanelList")
	self.remoteList:SetSpacing(2)
	self.remoteList:EnableVerticalScrollbar()

	self.localLookup = {}
	self.localList = vgui.Create("DPanelList")
	self.localList:SetSpacing(2)
	self.localList:EnableVerticalScrollbar()

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

function PANEL:OnRemove()

	table.RemoveByValue(FileViews, self)

end

function PANEL:UpdateRemoteFiles()

	local fileList = bpfilesystem.GetFiles()

	for _, v in ipairs( fileList ) do
		local id = v:GetUID()
		local existing = self.remoteLookup[id]
		if not existing then
			local panel = vgui.Create("BPFile")
			panel:SetFile(v, bpfilesystem.FT_Remote)
			self.remoteList:AddItem( panel )
			self.remoteLookup[id] = panel
		else
			existing:SetFile(v)
		end
	end

	table.sort( self.remoteList.Items, function( a, b )

		return a:GetName() < b:GetName()

	end)

end

function PANEL:UpdateLocalFiles()

	local fileList = bpfilesystem.GetLocalFiles()

	for _, v in ipairs( fileList ) do
		local id = v:GetUID()
		local existing = self.localLookup[id]
		if not existing then
			local panel = vgui.Create("BPFile")
			panel:SetFile(v, bpfilesystem.FT_Local)
			self.localList:AddItem( panel )
			self.localLookup[id] = panel
		else
			existing:SetFile(v)
		end
	end

	table.sort( self.localList.Items, function( a, b )

		return a:GetName() < b:GetName()

	end)

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