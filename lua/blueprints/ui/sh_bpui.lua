AddCSLuaFile()

if SERVER then

	resource.AddFile("resource/fonts/Akkurat-Bold.ttf")
	resource.AddFile("resource/fonts/JetBrainsMono-Bold.ttf")
	resource.AddFile("materials/icon64/blueprints.png")
	resource.AddFile("materials/bpgraphatlas.png")

else

G_BPGraphAtlas = Material("bpgraphatlas.png", "smooth")

surface.CreateFont( "NodeTitleFont", {
	font = "Akkurat-Bold", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
	extended = false,
	size = 35,
	weight = 1000,
	blursize = 0,
} )

surface.CreateFont( "NodeTitleFontShadow", {
	font = "Akkurat-Bold", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
	extended = false,
	size = 35,
	weight = 1200,
	blursize = 3,
} )

surface.CreateFont( "NodePinFont", {
	font = "Akkurat-Bold", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
	extended = false,
	size = 28,
	weight = 500,
	blursize = 0,
} )

surface.CreateFont( "NodeLiteralFont", {
	font = "JetBrains Mono",
	size = 26,
	weight = 1000,
} )

local hexChars = "0123456789abcdef"
local hexLookup = {}
for i=1, #hexChars do hexLookup[hexChars[i]] = i hexLookup[hexChars[i]:upper()] = i end

function HexColor(hex)

	local r,g,b
	for s in string.gmatch(hex, "(%x%x)") do
		if not r then r = hexLookup[s[1]] * 0x10 + hexLookup[s[2]]
		elseif not g then g = hexLookup[s[1]] * 0x10 + hexLookup[s[2]]
		elseif not b then b = hexLookup[s[1]] * 0x10 + hexLookup[s[2]]
		end
	end

	return Color(r, g, b, 255)

end

function AdjustHSV(color, offsetH, offsetS, offsetV)

	local h,s,v = ColorToHSV(color)
	return HSVToColor(h + offsetH, s + offsetS, v + offsetV)

end

function LerpColors(t, a, b)

	return Color(
		a.r * (1-t) + b.r * t,
		a.g * (1-t) + b.g * t,
		a.b * (1-t) + b.b * t,
		a.a * (1-t) + b.a * t
	)

end

end