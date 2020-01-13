if SERVER then AddCSLuaFile() return end

module("bpuifilemanager", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}

function PANEL:OnFileOpen( file )

end

function PANEL:Init()

	self:SetBackgroundColor(Color(60,60,60))
	self.list = vgui.Create("BPListView", self)
	self.list:Dock( FILL )
	self.list.btnAdd:Remove()
	self.list.alwaysSelect = true

	self.stimer = CurTime()
	self.sitem = nil

	self.list.OnItemSelected = function(p, id, item)
		if (CurTime() - self.stimer < .25) and self.sitem == item then
			self:OnFileOpen(item)
		end
		self.stimer = CurTime()
		self.sitem = item
	end

end

function PANEL:SetView(name, list)

	self.list:SetText( name )

	if list then self.list:SetList( list ) end

	return self

end

function PANEL:PerformLayout()

end

vgui.Register( "BPFileView", PANEL, "DPanel" )


local PANEL = {}

function PANEL:Init()

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

	--local localFiles = bplist.New():NamedItems():SetSanitizer( bpfile.Sanitizer )
	--localFiles:Add(bpfile.New(), "zaks/testmodule")
	--localFiles:Add(bpfile.New(), "zaks/testmodule")

	self.localView = vgui.Create("BPFileView"):SetView("Local", G_FS_Client:GetFiles())
	self.remoteView = vgui.Create("BPFileView"):SetView("Server", G_FS_Server:GetFiles())

	G_FS_Server:GetFiles():Subscribe( true )

	self.content:SetLeft(self.localView)
	self.content:SetRight(self.remoteView)
	self.content:SetMiddle(self.middle)
	self.content:SetDividerWidth(50)

	self.localView.OnFileOpen = function(p, file)
		local mod = bpmodule.New()
		self.editor:OpenModule( mod )
	end

end

function PANEL:OnRemove()

	G_FS_Server:GetFiles():Subscribe( false )

end

function PANEL:PerformLayout()

	local w = self:GetWide() - self.content:GetDividerWidth()
	self.content:SetLeftMin(w/2)
	self.content:SetRightMin(w/2)

end

vgui.Register( "BPFileManager", PANEL, "DPanel" )