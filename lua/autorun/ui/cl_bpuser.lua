if SERVER then AddCSLuaFile() return end

module("bpuiuser", package.seeall)

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self.nameLabel = vgui.Create("DLabel", self)
	self.nameLabel:SetFont("DermaDefaultBold")
	self.nameLabel:SetTextColor( Color(255,255,255) )

	self.checkbox = vgui.Create("DCheckBox", self)

end

function PANEL:SetGroup( group )

	self.group = group
	self.nameLabel:SetText( self.group:GetName() )
	self.nameLabel:SizeToContents()

	local user = self:GetParent():GetUser()

	self.checkbox:SetChecked( user:IsInGroup(self.group) )
	self.checkbox.OnChange = function(pnl, value)

		self.checkbox:SetChecked( not value )
		if value then
			self.group:AddUser( user )
		else
			self.group:RemoveUser( user )
		end

	end

	self.checkbox:SetEnabled( bpusermanager.GetLocalUser():HasPermission( bpgroup.FL_CanEditUsers ) )

end

function PANEL:PerformLayout()

	self.checkbox:SetPos( 4, 2 )
	self.nameLabel:SetPos( self.checkbox:GetWide() + 8, 2)

	self:SizeToChildren( true, false )
	self:SetWide( self:GetWide() + 4 )

end

function PANEL:Paint(w, h)

	local r,g,b,a = self.group:GetColor():Unpack()
	draw.RoundedBox(4, 0, 0, w, h, Color(r,g,b,a))
	draw.RoundedBox(4, 1, 1, w-2, h-2, Color(r/2,g/2,b/2,a))

end

derma.DefineControl( "BPGroupTag", "Blueprint group tag", PANEL, "DPanel" )

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	--self:SetBackgroundColor( Color(30,30,30) )
	self:SetText("")

	self.nameLabel = vgui.Create("DLabel", self)
	self.nameLabel:SetFont("DermaDefaultBold")
	self.nameLabel:SetText("PLAYERNAME")

	self.steamLabel = vgui.Create("DLabel", self)
	self.steamLabel:SetFont("DermaDefaultBold")
	self.steamLabel:SetText("PLAYERSTEAM")

	self.avatar = vgui.Create("AvatarImage", self)
	self.animSlide = Derma_Anim( "Anim", self, self.AnimSlide )
	self.expanded = false
	self.groupTags = {}

end

function PANEL:GroupTagExtraHeight()

	return 3 + #self.groupTags * 22

end

function PANEL:DoClick()

	self.prevHeight = self:GetTall()
	if not self.expanded then
		self.expanded = true
	else
		self.expanded = false
	end
	self.animSlide:Start( .15, { From = self:GetTall() } )

	self:InvalidateLayout( true )
	self:GetParent():InvalidateLayout()
	self:GetParent():GetParent():InvalidateLayout()

end

function PANEL:Paint(w, h)

	draw.RoundedBox(4, 0, 0, w, h, Color(30,30,30))

	if self.user then

		if self.user == bpusermanager.GetLocalUser() then

			draw.RoundedBox(4, 2, 2, w-4, h-4, Color(50,70,50))

		elseif self.user:HasFlag( bpuser.FL_LoggedIn ) then

			draw.RoundedBox(4, 2, 2, w-4, h-4, Color(50,60,70))

		end

	end

end

function PANEL:GetUser()

	return self.user

end

function PANEL:SetUser( user )

	self.user = user
	self.nameLabel:SetText( user:GetName() or "unnamed" )
	self.steamLabel:SetText( user:GetSteamID() or "steamid" )
	self.avatar:SetSteamID( user:GetSteamID64(), 32 )

	self.nameLabel:SizeToContents()
	self.steamLabel:SizeToContents()

	for _, tag in ipairs(self.groupTags) do
		tag:Remove()
	end

	self.groupTags = {}

	local groups = bpusermanager.GetGroups()
	for i=1, #groups do

		local panel = vgui.Create("BPGroupTag", self)
		panel:SetGroup(groups[i])
		panel:SetTall(20)
		table.insert( self.groupTags, panel )

	end

end

function PANEL:PerformLayout()

	self.nameLabel:SetPos(50,3)
	self.steamLabel:SetPos(50,16)
	self.avatar:SetSize(32,32)
	self.avatar:SetPos(4,4)

	for i, pnl in ipairs(self.groupTags) do
		pnl:SetPos( 4, 40 + (i-1) * 22 )
	end

	if not self.expanded then
		self:SetTall(40)
	else
		self:SetTall(40 + self:GroupTagExtraHeight() )
	end
	self.animSlide:Run()

end

function PANEL:Think()

	self.animSlide:Run()

end

function PANEL:AnimSlide( anim, delta, data )

	self:InvalidateLayout()
	self:InvalidateParent()

	if anim.Started  then

		if self.expanded then
			data.To = 40 + self:GroupTagExtraHeight() --math.max( self.prevHeight, self:GetTall() )
		else
			data.To = 40
		end
	end

	self:SetTall( Lerp( delta, data.From, data.To ) )

end

derma.DefineControl( "BPUser", "Blueprint user", PANEL, "DButton" )
