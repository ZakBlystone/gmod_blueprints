if SERVER then AddCSLuaFile() return end

include("cl_bpnode.lua")
include("cl_bppin.lua")

local PANEL = {}
local TITLE = "Blueprint Editor"

function PANEL:Init()

	local w = ScrW() * .8
	local h = ScrH() * .8
	local x = (ScrW() - w)/2
	local y = (ScrH() - h)/2

	local MenuOptions = {
		["Compile and upload"] = function()
			bpnet.SendGraph( self.graph )
		end,
	}

	--x = 20

	self:SetPos(x, y)
	self:SetSize(w, h)

	self:SetMouseInputEnabled( true )
	self:SetTitle( TITLE )
	self:SetDraggable(true)
	self:SetSizable(true)
	self:ShowCloseButton(true)

	self.Menu = vgui.Create("DPanel", self)
	self.Menu:Dock( TOP )
	self.Menu:SetBackgroundColor( Color(80,80,80) )

	for k,v in pairs(MenuOptions) do
		local opt = vgui.Create("DButton", self.Menu)
		opt:SetText("Compile and upload")
		opt:SizeToContentsX()
		opt:SetWide( opt:GetWide() + 10 )
		opt:SetTall( 25 )
		opt.DoClick = function(btn)
			local b,e = pcall( v )
			if not b then
				self.StatusText:SetTextColor( Color(255,100,100) )
				self.StatusText:SetText(e)
			else
				self.StatusText:SetTextColor( Color(255,255,255) )
				self.StatusText:SetText("")
			end
		end
	end

	self.Menu:SizeToChildren( true, true )

	self.Status = vgui.Create("DPanel", self)
	self.Status:Dock( BOTTOM )
	self.Status:SetBackgroundColor( Color(50,50,50) )

	self.StatusText = vgui.Create("DLabel", self.Status)
	self.StatusText:SetFont("DermaDefaultBold")
	self.StatusText:Dock( FILL )
	self.StatusText:SetText("")


	self.Content = vgui.Create("BPGraph", self)
	self.Content:Dock( FILL )
	self.Content:DockMargin( 0, 0, 0, 0 )

	print(tostring(e))

end

function PANEL:SetGraph( graph )

	self.graph = graph
	self.Content:SetGraph( graph )

end

vgui.Register( "BPEditor", PANEL, "DFrame" )


--if true then return end

local function OpenEditor()


	if G_BPEditorInstance then

		if IsValid(G_BPEditorInstance) then G_BPEditorInstance:Remove() end
		G_BPEditorInstance = nil

	end

	local graph = bpgraph.New()

	--for i=1, 2 do
	local editor = vgui.Create( "BPEditor" )
	editor:SetVisible(true)
	editor:MakePopup()
	editor:SetGraph( graph )
	--end

	bpnet.DownloadServerGraph( graph )
	--graph:CreateTestGraph()
	--graph:RemoveNode( graph.nodes[1] )

	G_BPEditorInstance = editor

end

concommand.Add("open_blueprint", function()



end)

hook.Add("PlayerBindPress", "catch_f2", function(ply, bind, pressed)

	if bind == "gm_showteam" then
		OpenEditor()
	end

end)