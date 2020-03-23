if SERVER then AddCSLuaFile() return end

module("browser_texture", package.seeall, bpcommon.rescope(bpschema))

local BROWSER = {}

BROWSER.Title = "Texture"
BROWSER.AssetPath = "materials"
BROWSER.AllowedExtensions = {
	[".vtf"] = true,
	[".png"] = true,
}

local function ReadVTFHeader( path, pathType )

	local f = file.Open( path, "r", pathType )
	if f == nil then return end

	local t = {
		sig = f:ReadULong(),
		v0 = f:ReadULong(),
		v1 = f:ReadULong(),
		hsize = f:ReadULong(),
		w = f:ReadUShort(),
		h = f:ReadUShort(),
		flags = f:ReadULong(),
		frames = f:ReadUShort(),
	}

	f:Close()
	return t

end

function BROWSER:DoPathFixup( path ) return path:gsub("^materials/", "") end
function BROWSER:CreateResultEntry( node )

	local texVTF = node.path:match("(.+)%.vtf")
	local texPNG = node.path:match("(.+)%.png")

	local animated = false
	local animFrames = 0
	local mat = node.path
	if texVTF then
		local info = ReadVTFHeader( "materials/" .. node.path, node.pathType )
		if info then 
			animFrames = info.frames
			animated = info.frames > 1
		end
		mat = CreateMaterial("bpassettexturevtf_" .. texVTF, "UnlitGeneric")
		mat:SetTexture("$basetexture", texVTF)
		--print("Make material for: " .. texVTF)
	elseif texPNG then
		return Material(texPNG)
	end

	local icon = vgui.Create( "DImage" )
	icon:SetSize(92,92)
	icon:SetMaterial( mat ) --iSkin, BodyGroups

	if animated then
		local detour = icon.Paint
		icon.Paint = function(pnl, w, h)
			detour(pnl, w, h)
			local x,y = pnl:LocalCursorPos()
			local fr = (CurTime() * 15) % animFrames
			if x > -10 and x < w + 10 and y > -10 and y < h + 10 then
				x = math.Clamp(x, 0, w)
				fr = math.floor( (x / w) * (animFrames-1) + .5 )
				draw.SimpleText(fr .. " / " .. animFrames-1, "DermaDefault", 0, 0, Color(255,255,255))
			end

			mat:SetFloat( "$frame", fr )
		end
	end

	return icon

end

RegisterAssetBrowserClass("texture", BROWSER)