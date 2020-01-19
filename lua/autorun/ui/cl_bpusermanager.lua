if SERVER then AddCSLuaFile() return end

module("bpuiusermanager", package.seeall)

local PANEL = {}
local UserViews = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self.menu = bpuimenubar.AddTo(self)
	self.menu:Add("Add Group", function() end, nil, "icon16/asterisk_yellow.png")

	self.contentPanel = vgui.Create("DPanel", self)
	self.contentPanel:Dock( FILL )
	self.contentPanel:SetBackgroundColor( Color(50,50,50) )

	self.content = vgui.Create("DHorizontalDivider", self.contentPanel)
	self.content:Dock( FILL )
	self.content:SetBackgroundColor( Color(30,30,30) )

	self.groupLookup = {}
	self.groupList = vgui.Create("DPanelList")
	self.groupList:SetSpacing(2)
	self.groupList:EnableVerticalScrollbar()

	self.userLookup = {}
	self.userList = vgui.Create("DPanelList")
	self.userList:SetSpacing(2)
	self.userList:EnableVerticalScrollbar()

	self.content:SetLeft(self.groupList)
	self.content:SetRight(self.userList)
	--self.content:SetDividerWidth(5)
	self.content:SetLeftWidth(200)

	UserViews[#UserViews+1] = self

	self:UpdateUsers()
	self:UpdateGroups()

end

function PANEL:OnRemove()

	table.RemoveByValue(UserViews, self)

end

function PANEL:UpdateUsers()

	local userList = table.Copy( bpusermanager.GetUsers() )

	local user = bpuser.New()
	user.name = "Foohy"
	user.steamID = "STEAM_1:1:18712009"
	userList[#userList+1] = user

	for _, v in ipairs( userList ) do
		local id = v:GetSteamID()
		local existing = self.userLookup[id]
		if not existing then
			local panel = vgui.Create("BPUser")
			panel:SetUser(v)
			self.userList:AddItem( panel )
			self.userLookup[id] = panel
		else
			existing:SetUser(v)
		end
	end

	table.sort( self.userList.Items, function( a, b )

		return a:GetUser():GetName() < b:GetUser():GetName()

	end)

end

function PANEL:UpdateGroups()

	self.groupList:Clear( true )

	local persist = {}
	for _, v in ipairs( bpusermanager.GetGroups() ) do
		local id = v:GetName()
		local existing = self.groupLookup[id]
		if not existing then
			local panel = vgui.Create("BPGroup")
			panel:SetGroup(v)
			self.groupList:AddItem( panel )
			self.groupLookup[id] = panel
		else
			existing:SetGroup(v)
		end
		persist[id] = true
	end

	for k,v in pairs(self.groupLookup) do
		if not persist[k] then
			v:Remove()
			self.groupLookup[k] = nil
		end
	end

end

hook.Add("BPUserTableUpdated", "usermanagerui", function()

	for _, v in ipairs(UserViews) do v:UpdateUsers() end

end)

hook.Add("BPGroupTableUpdated", "usermanagerui", function()

	for _, v in ipairs(UserViews) do v:UpdateGroups() end

end)

derma.DefineControl( "BPUserManager", "Blueprint user manager", PANEL, "DPanel" )