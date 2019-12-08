AddCSLuaFile()

if SERVER then

	resource.AddFile("resource/fonts/Akkurat-Bold.ttf")

else

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

end