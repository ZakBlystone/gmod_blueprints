if SERVER then AddCSLuaFile() return end

module("browser_sound", package.seeall, bpcommon.rescope(bpschema))


local PANEL = {}
local ButtonZoneX = 25

function PANEL:Init()

	self.AllowAutoRefresh = true
	--self:SetBackgroundColor( Color(30,30,30) )

	self.nameLabel = vgui.Create("DLabel", self)
	self.nameLabel:SetFont("DermaDefaultBold")
	self.nameLabel:SetText("Sound Name")

	self.playButton = vgui.Create("DImage", self)
	self.playButton:SetImage("icon16/control_play.png")

	self.icon = vgui.Create("DImage", self)

	self.playTime = 0
	self.duration = 0

	self:SetText("")

end

function PANEL:SetIcon( icon )

	if icon and icon ~= "" then
		self.icon = vgui.Create("DImage", self)
		self.icon:SetImage( icon )
	end

end

function PANEL:Select() end
function PANEL:DoClick()

	local x,y = self:LocalCursorPos()
	if x > ButtonZoneX then
		self:Select()
	else
		self:PlayStop()
	end

end

function PANEL:Think()

	if self.patch then
		if self.playTime ~= 0 then
			if CurTime() - self.playTime >= self.duration then
				self:PlayStop()
			end
		end
	end

end

function PANEL:OnRemove()

	if self.playTime ~= 0 then
		self:PlayStop()
	end

end

function PANEL:PlayStop()

	self.patch = self.patch or CreateSound( LocalPlayer(), self:GetSoundFile() )
	if self.patch:IsPlaying() then
		self.patch:Stop()
		self.duration = 0
		self.playTime = 0
		self.playButton:SetImage("icon16/control_play.png")
	else
		self.patch:Play()
		self.duration = SoundDuration( self:GetSoundFile() )
		self.playTime = CurTime()
		self.playButton:SetImage("icon16/control_stop.png")
	end

end

function PANEL:SetSoundFile( file, name )

	self.soundFile = file
	self.nameLabel:SetText( name )

end

function PANEL:Paint(w, h)

	local r,g,b,a = 80,80,80,255

	local x,y = self:LocalCursorPos()
	if self.Hovered and x > ButtonZoneX then
		r = 180
		g = 120
	end

	draw.RoundedBox(4, 0, 0, w, h, Color(r,g,b,a))
	draw.RoundedBox(4, 1, 1, w-2, h-2, Color(r/2,g/2,b/2,a))

	if self.duration ~= 0 and self.playTime ~= 0 then
		local f = math.min((CurTime() - self.playTime) / self.duration, 1)
		draw.RoundedBox(4, 1, 1, (w-2) * f, h-2, Color(50,100,200,a))
	end

	surface.SetDrawColor(255,255,255)
	surface.DrawLine( ButtonZoneX, 0, ButtonZoneX, h )

end

function PANEL:GetSoundFile()

	return self.soundFile

end

function PANEL:PerformLayout()

	self.nameLabel:SetPos(32,2)
	self.nameLabel:SizeToContents()
	self.nameLabel:SetTall(16)

	self.playButton:SetPos(4,2)
	self.playButton:SetSize(16,16)

	if self.icon then

		self.icon:SetPos( self:GetWide() - 20, (self:GetTall() - 16)/2 )
		self.icon:SetSize(16,16)

	end

	self:SetTall(20)

end

derma.DefineControl( "BPSoundClip", "Sound Clip", PANEL, "DButton" )


local BROWSER = {}

BROWSER.Title = "Sound"
BROWSER.AssetPath = "sound"
BROWSER.AllowedExtensions = {
	[".wav"] = true,
	[".mp3"] = true,
}

function BROWSER:CreateResultsPanel( parent )

	local panel = vgui.Create( "DPanelList", parent )
	panel:SetAutoSize(true)
	panel:SetSpacing( 1 )
	panel:SetStretchHorizontally( true )
	return panel

end

function BROWSER:ClearResults()

	local res = self:GetResultsPanel()

	for k, panel in ipairs( res.Items ) do
		panel:Remove()
	end

	res:Clear()

end

function BROWSER:DoPathFixup( path ) return path:gsub("^sound/", "") end
function BROWSER:CreateResultEntry( node )

	local snd = vgui.Create("BPSoundClip")
	snd:SetSoundFile( node.path, self:WasSearch() and node.path or node.file )
	snd.Select = function() self:ChooseAsset( node.path ) end

	if self:WasSearch() then

		local icon = self:FindIconForNode(node)
		snd:SetIcon(icon)

	end

	return snd

end

function BROWSER:AddResult( node, pnl )

	self:GetResultsPanel():AddItem( pnl )

end

RegisterAssetBrowserClass("sound", BROWSER)