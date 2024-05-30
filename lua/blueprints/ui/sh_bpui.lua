AddCSLuaFile()

if SERVER then

	resource.AddFile("resource/fonts/Akkurat-Bold.ttf")
	resource.AddFile("resource/fonts/JetBrainsMono-Bold.ttf")
	resource.AddFile("materials/icon64/blueprints.png")
	resource.AddFile("materials/bpgraphatlas.png")
	resource.AddFile("materials/bpskin.png")

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

function HexColor(hex, raw, with_alpha)

	local r,g,b,a = 0,0,0,255
	for x in string.gmatch(hex, "(%x%x)") do
		r,g,b,a = g,b,a,tonumber(x,16)
	end
	if not with_alpha then r,g,b,a = g,b,a,255 end
	if raw then return r,g,b end
	return Color(r,g,b,a)

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