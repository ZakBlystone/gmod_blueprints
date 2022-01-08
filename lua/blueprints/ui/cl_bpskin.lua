if SERVER then AddCSLuaFile() return end

local skin_hue = CreateConVar("bp_editor_ui_hue", "0", FCVAR_ARCHIVE, "Theming", 0, 360)
local skin_sat = CreateConVar("bp_editor_ui_sat", "1", FCVAR_ARCHIVE, "Theming", 0, 3)
local skin_val = CreateConVar("bp_editor_ui_val", "1", FCVAR_ARCHIVE, "Theming", 0, 3)

SKIN = {}

SKIN.PrintName		= "Blueprints Skin"
SKIN.Author		= "Zachary Blystone"
SKIN.DermaVersion	= 1
SKIN.GwenTexture	= Material( "bpskin.png" )

SKIN.colPropertySheet			= Color( 170, 170, 170, 255 )
SKIN.colTab						= SKIN.colPropertySheet
SKIN.colTabInactive				= Color( 140, 140, 140, 255 )
SKIN.colTabShadow				= Color( 0, 0, 0, 170 )
SKIN.colTabText					= Color( 255, 255, 255, 255 )
SKIN.colTabTextInactive			= Color( 0, 0, 0, 200 )
SKIN.fontTab					= "DermaDefault"

SKIN.colCollapsibleCategory		= Color( 255, 255, 255, 20 )

SKIN.colCategoryText			= Color( 255, 255, 255, 255 )
SKIN.colCategoryTextInactive	= Color( 200, 200, 200, 255 )
SKIN.fontCategoryHeader			= "TabLarge"

SKIN.colNumberWangBG			= Color( 255, 240, 150, 255 )
SKIN.colTextEntryBG				= Color( 240, 240, 240, 255 )
SKIN.colTextEntryBorder			= Color( 20, 20, 20, 255 )
SKIN.colTextEntryText			= Color( 255, 255, 255, 255 )
SKIN.colTextEntryTextHighlight	= Color( 20, 200, 250, 255 )
SKIN.colTextEntryTextCursor		= Color( 255, 255, 255, 255 )
SKIN.colTextEntryTextPlaceholder= Color( 128, 128, 128, 255 )

SKIN.colMenuBG					= Color( 255, 255, 255, 200 )
SKIN.colMenuBorder				= Color( 0, 0, 0, 200 )

SKIN.colButtonText				= Color( 255, 255, 255, 255 )
SKIN.colButtonTextDisabled		= Color( 255, 255, 255, 55 )
SKIN.colButtonBorder			= Color( 20, 20, 20, 255 )
SKIN.colButtonBorderHighlight	= Color( 255, 255, 255, 50 )
SKIN.colButtonBorderShadow		= Color( 0, 0, 0, 100 )

SKIN.tex = {}

SKIN.tex.Selection					= GWEN.CreateTextureBorder( 384, 32, 31, 31, 4, 4, 4, 4 )

SKIN.tex.Panels = {}
SKIN.tex.Panels.Normal				= GWEN.CreateTextureBorder( 256,	0, 63, 63, 16, 16, 16, 16 )
SKIN.tex.Panels.Bright				= GWEN.CreateTextureBorder( 256+64, 0, 63, 63, 16, 16, 16, 16 )
SKIN.tex.Panels.Dark				= GWEN.CreateTextureBorder( 256,	64, 63, 63, 16, 16, 16, 16 )
SKIN.tex.Panels.Highlight			= GWEN.CreateTextureBorder( 256+64, 64, 63, 63, 16, 16, 16, 16 )

SKIN.tex.Button						= GWEN.CreateTextureBorder( 480, 0, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Button_Hovered				= GWEN.CreateTextureBorder( 480, 32, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Button_Dead				= GWEN.CreateTextureBorder( 480, 64, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Button_Down				= GWEN.CreateTextureBorder( 480, 96, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Shadow						= GWEN.CreateTextureBorder( 448, 0, 31, 31, 8, 8, 8, 8 )

SKIN.tex.Tree						= GWEN.CreateTextureBorder( 256, 128, 127, 127, 16, 16, 16, 16 )
SKIN.tex.Checkbox_Checked			= GWEN.CreateTextureNormal( 448, 32, 15, 15 )
SKIN.tex.Checkbox					= GWEN.CreateTextureNormal( 464, 32, 15, 15 )
SKIN.tex.CheckboxD_Checked			= GWEN.CreateTextureNormal( 448, 48, 15, 15 )
SKIN.tex.CheckboxD					= GWEN.CreateTextureNormal( 464, 48, 15, 15 )
SKIN.tex.RadioButton_Checked		= GWEN.CreateTextureNormal( 448, 64, 15, 15 )
SKIN.tex.RadioButton				= GWEN.CreateTextureNormal( 464, 64, 15, 15 )
SKIN.tex.RadioButtonD_Checked		= GWEN.CreateTextureNormal( 448, 80, 15, 15 )
SKIN.tex.RadioButtonD				= GWEN.CreateTextureNormal( 464, 80, 15, 15 )
SKIN.tex.TreePlus					= GWEN.CreateTextureNormal( 448, 96, 15, 15 )
SKIN.tex.TreeMinus					= GWEN.CreateTextureNormal( 464, 96, 15, 15 )
SKIN.tex.TextBox					= GWEN.CreateTextureBorder( 0, 150, 127, 21, 4, 4, 4, 4 )
SKIN.tex.TextBox_Focus				= GWEN.CreateTextureBorder( 0, 172, 127, 21, 4, 4, 4, 4 )
SKIN.tex.TextBox_Disabled			= GWEN.CreateTextureBorder( 0, 194, 127, 21, 4, 4, 4, 4 )
SKIN.tex.MenuBG_Column				= GWEN.CreateTextureBorder( 128, 128, 127, 63, 24, 8, 8, 8 )
SKIN.tex.MenuBG						= GWEN.CreateTextureBorder( 128, 192, 127, 63, 8, 8, 8, 8 )
SKIN.tex.MenuBG_Hover				= GWEN.CreateTextureBorder( 128, 256, 127, 31, 8, 8, 8, 8 )
SKIN.tex.MenuBG_Spacer				= GWEN.CreateTextureNormal( 128, 288, 127, 3 )
SKIN.tex.Menu_Strip					= GWEN.CreateTextureBorder( 0, 128, 127, 21, 8, 8, 8, 8 )
SKIN.tex.Menu_Check					= GWEN.CreateTextureNormal( 448, 112, 15, 15 )
SKIN.tex.Tab_Control				= GWEN.CreateTextureBorder( 0, 256, 127, 127, 8, 8, 8, 8 )
SKIN.tex.TabB_Active				= GWEN.CreateTextureBorder( 0,		416, 63, 31, 8, 8, 8, 8 )
SKIN.tex.TabB_Inactive				= GWEN.CreateTextureBorder( 128,	416, 63, 31, 8, 8, 8, 8 )
SKIN.tex.TabT_Active				= GWEN.CreateTextureBorder( 0,		384, 63, 31, 8, 8, 8, 8 )
SKIN.tex.TabT_Inactive				= GWEN.CreateTextureBorder( 128,	384, 63, 31, 8, 8, 8, 8 )
SKIN.tex.TabL_Active				= GWEN.CreateTextureBorder( 64,		384, 31, 63, 8, 8, 8, 8 )
SKIN.tex.TabL_Inactive				= GWEN.CreateTextureBorder( 64+128, 384, 31, 63, 8, 8, 8, 8 )
SKIN.tex.TabR_Active				= GWEN.CreateTextureBorder( 96,		384, 31, 63, 8, 8, 8, 8 )
SKIN.tex.TabR_Inactive				= GWEN.CreateTextureBorder( 96+128, 384, 31, 63, 8, 8, 8, 8 )
SKIN.tex.Tab_Bar					= GWEN.CreateTextureBorder( 128, 352, 127, 31, 4, 4, 4, 4 )

SKIN.tex.Tab_Close					= GWEN.CreateTextureNormal( 32, 469, 21, 24 )
SKIN.tex.Tab_Close_Hover			= GWEN.CreateTextureNormal( 64, 469, 21, 24 )
SKIN.tex.Tab_Close_Down				= GWEN.CreateTextureNormal( 96, 469, 21, 24 )

SKIN.tex.Window = {}

SKIN.tex.Window.Normal			= GWEN.CreateTextureBorder( 0, 0, 127, 127, 8, 32, 8, 8 )
SKIN.tex.Window.Inactive		= GWEN.CreateTextureBorder( 128, 0, 127, 127, 8, 32, 8, 8 )

SKIN.tex.Window.Close			= GWEN.CreateTextureNormal( 32, 448, 31, 24 )
SKIN.tex.Window.Close_Hover		= GWEN.CreateTextureNormal( 64, 448, 31, 24 )
SKIN.tex.Window.Close_Down		= GWEN.CreateTextureNormal( 96, 448, 31, 24 )

SKIN.tex.Window.Maxi			= GWEN.CreateTextureNormal( 32 + 96 * 2, 448, 31, 24 )
SKIN.tex.Window.Maxi_Hover		= GWEN.CreateTextureNormal( 64 + 96 * 2, 448, 31, 24 )
SKIN.tex.Window.Maxi_Down		= GWEN.CreateTextureNormal( 96 + 96 * 2, 448, 31, 24 )

SKIN.tex.Window.Restore			= GWEN.CreateTextureNormal( 32 + 96 * 2, 448 + 32, 31, 24 )
SKIN.tex.Window.Restore_Hover	= GWEN.CreateTextureNormal( 64 + 96 * 2, 448 + 32, 31, 24 )
SKIN.tex.Window.Restore_Down	= GWEN.CreateTextureNormal( 96 + 96 * 2, 448 + 32, 31, 24 )

SKIN.tex.Window.Mini			= GWEN.CreateTextureNormal( 32 + 96, 448, 31, 24 )
SKIN.tex.Window.Mini_Hover		= GWEN.CreateTextureNormal( 64 + 96, 448, 31, 24 )
SKIN.tex.Window.Mini_Down		= GWEN.CreateTextureNormal( 96 + 96, 448, 31, 24 )

SKIN.tex.Scroller = {}
SKIN.tex.Scroller.TrackV				= GWEN.CreateTextureBorder( 384,		208, 15, 127, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonV_Normal		= GWEN.CreateTextureBorder( 384 + 16,	208, 15, 127, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonV_Hover			= GWEN.CreateTextureBorder( 384 + 32,	208, 15, 127, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonV_Down			= GWEN.CreateTextureBorder( 384 + 48,	208, 15, 127, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonV_Disabled		= GWEN.CreateTextureBorder( 384 + 64,	208, 15, 127, 4, 4, 4, 4 )

SKIN.tex.Scroller.TrackH				= GWEN.CreateTextureBorder( 384, 128,		127, 15, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonH_Normal		= GWEN.CreateTextureBorder( 384, 128 + 16,	127, 15, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonH_Hover			= GWEN.CreateTextureBorder( 384, 128 + 32,	127, 15, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonH_Down			= GWEN.CreateTextureBorder( 384, 128 + 48,	127, 15, 4, 4, 4, 4 )
SKIN.tex.Scroller.ButtonH_Disabled		= GWEN.CreateTextureBorder( 384, 128 + 64,	127, 15, 4, 4, 4, 4 )

SKIN.tex.Scroller.LeftButton_Normal		= GWEN.CreateTextureBorder( 464,		208, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.LeftButton_Hover		= GWEN.CreateTextureBorder( 480,		208, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.LeftButton_Down		= GWEN.CreateTextureBorder( 464,		272, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.LeftButton_Disabled	= GWEN.CreateTextureBorder( 480 + 48,	272, 15, 15, 2, 2, 2, 2 )

SKIN.tex.Scroller.UpButton_Normal		= GWEN.CreateTextureBorder( 464,		208 + 16, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.UpButton_Hover		= GWEN.CreateTextureBorder( 480,		208 + 16, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.UpButton_Down			= GWEN.CreateTextureBorder( 464,		272 + 16, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.UpButton_Disabled		= GWEN.CreateTextureBorder( 480 + 48,	272 + 16, 15, 15, 2, 2, 2, 2 )

SKIN.tex.Scroller.RightButton_Normal	= GWEN.CreateTextureBorder( 464,		208 + 32, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.RightButton_Hover		= GWEN.CreateTextureBorder( 480,		208 + 32, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.RightButton_Down		= GWEN.CreateTextureBorder( 464,		272 + 32, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.RightButton_Disabled	= GWEN.CreateTextureBorder( 480 + 48,	272 + 32, 15, 15, 2, 2, 2, 2 )

SKIN.tex.Scroller.DownButton_Normal		= GWEN.CreateTextureBorder( 464,		208 + 48, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.DownButton_Hover		= GWEN.CreateTextureBorder( 480,		208 + 48, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.DownButton_Down		= GWEN.CreateTextureBorder( 464,		272 + 48, 15, 15, 2, 2, 2, 2 )
SKIN.tex.Scroller.DownButton_Disabled	= GWEN.CreateTextureBorder( 480 + 48,	272 + 48, 15, 15, 2, 2, 2, 2 )

SKIN.tex.Menu = {}
SKIN.tex.Menu.RightArrow = GWEN.CreateTextureNormal( 464, 112, 15, 15 )

SKIN.tex.Input = {}

SKIN.tex.Input.ComboBox = {}
SKIN.tex.Input.ComboBox.Normal		= GWEN.CreateTextureBorder( 384, 336,	127, 31, 8, 8, 32, 8 )
SKIN.tex.Input.ComboBox.Hover		= GWEN.CreateTextureBorder( 384, 336+32, 127, 31, 8, 8, 32, 8 )
SKIN.tex.Input.ComboBox.Down		= GWEN.CreateTextureBorder( 384, 336+64, 127, 31, 8, 8, 32, 8 )
SKIN.tex.Input.ComboBox.Disabled	= GWEN.CreateTextureBorder( 384, 336+96, 127, 31, 8, 8, 32, 8 )

SKIN.tex.Input.ComboBox.Button = {}
SKIN.tex.Input.ComboBox.Button.Normal	= GWEN.CreateTextureNormal( 496, 272, 15, 15 )
SKIN.tex.Input.ComboBox.Button.Hover	= GWEN.CreateTextureNormal( 496, 272+16, 15, 15 )
SKIN.tex.Input.ComboBox.Button.Down		= GWEN.CreateTextureNormal( 496, 272+32, 15, 15 )
SKIN.tex.Input.ComboBox.Button.Disabled	= GWEN.CreateTextureNormal( 496, 272+48, 15, 15 )

SKIN.tex.Input.UpDown = {}
SKIN.tex.Input.UpDown.Up = {}
SKIN.tex.Input.UpDown.Up.Normal		= GWEN.CreateTextureCentered( 384,		112, 7, 7 )
SKIN.tex.Input.UpDown.Up.Hover		= GWEN.CreateTextureCentered( 384+8,	112, 7, 7 )
SKIN.tex.Input.UpDown.Up.Down		= GWEN.CreateTextureCentered( 384+16,	112, 7, 7 )
SKIN.tex.Input.UpDown.Up.Disabled	= GWEN.CreateTextureCentered( 384+24,	112, 7, 7 )

SKIN.tex.Input.UpDown.Down = {}
SKIN.tex.Input.UpDown.Down.Normal	= GWEN.CreateTextureCentered( 384,		120, 7, 7 )
SKIN.tex.Input.UpDown.Down.Hover	= GWEN.CreateTextureCentered( 384+8,	120, 7, 7 )
SKIN.tex.Input.UpDown.Down.Down		= GWEN.CreateTextureCentered( 384+16,	120, 7, 7 )
SKIN.tex.Input.UpDown.Down.Disabled	= GWEN.CreateTextureCentered( 384+24,	120, 7, 7 )

SKIN.tex.Input.Slider = {}
SKIN.tex.Input.Slider.H = {}
SKIN.tex.Input.Slider.H.Normal		= GWEN.CreateTextureNormal( 416, 32,	15, 15 )
SKIN.tex.Input.Slider.H.Hover		= GWEN.CreateTextureNormal( 416, 32+16, 15, 15 )
SKIN.tex.Input.Slider.H.Down		= GWEN.CreateTextureNormal( 416, 32+32, 15, 15 )
SKIN.tex.Input.Slider.H.Disabled	= GWEN.CreateTextureNormal( 416, 32+48, 15, 15 )

SKIN.tex.Input.Slider.V = {}
SKIN.tex.Input.Slider.V.Normal		= GWEN.CreateTextureNormal( 416+16, 32, 15, 15 )
SKIN.tex.Input.Slider.V.Hover		= GWEN.CreateTextureNormal( 416+16, 32+16, 15, 15 )
SKIN.tex.Input.Slider.V.Down		= GWEN.CreateTextureNormal( 416+16, 32+32, 15, 15 )
SKIN.tex.Input.Slider.V.Disabled	= GWEN.CreateTextureNormal( 416+16, 32+48, 15, 15 )

SKIN.tex.Input.ListBox = {}
SKIN.tex.Input.ListBox.Background		= GWEN.CreateTextureBorder( 256, 256, 63, 127, 8, 8, 8, 8 )
SKIN.tex.Input.ListBox.Hovered			= GWEN.CreateTextureBorder( 320, 320, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Input.ListBox.EvenLine			= GWEN.CreateTextureBorder( 352, 256, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Input.ListBox.OddLine			= GWEN.CreateTextureBorder( 352, 288, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Input.ListBox.EvenLineSelected	= GWEN.CreateTextureBorder( 320, 256, 31, 31, 8, 8, 8, 8 )
SKIN.tex.Input.ListBox.OddLineSelected	= GWEN.CreateTextureBorder( 320, 288, 31, 31, 8, 8, 8, 8 )

SKIN.tex.ProgressBar = {}
SKIN.tex.ProgressBar.Back	= GWEN.CreateTextureBorder( 384,	0, 31, 31, 8, 8, 8, 8 )
SKIN.tex.ProgressBar.Front	= GWEN.CreateTextureBorder( 384+32, 0, 31, 31, 8, 8, 8, 8 )

SKIN.tex.CategoryList = {}
SKIN.tex.CategoryList.Outer		= GWEN.CreateTextureBorder( 256, 384, 63, 63, 8, 8, 8, 8 )
SKIN.tex.CategoryList.Inner		= GWEN.CreateTextureBorder( 320, 384, 63, 63, 8, 21, 8, 8 )
SKIN.tex.CategoryList.Header	= GWEN.CreateTextureBorder( 320, 352, 63, 31, 8, 8, 8, 8 )

SKIN.tex.Tooltip = GWEN.CreateTextureBorder( 384, 64, 31, 31, 8, 8, 8, 8 )

SKIN.Colours = {}

SKIN.Colours.Window = {}
SKIN.Colours.Window.TitleActive		= GWEN.TextureColor( 4 + 8 * 0, 508 )
SKIN.Colours.Window.TitleInactive	= GWEN.TextureColor( 4 + 8 * 1, 508 )

SKIN.Colours.Button = {}
SKIN.Colours.Button.Normal			= GWEN.TextureColor( 4 + 8 * 2, 508 )
SKIN.Colours.Button.Hover			= GWEN.TextureColor( 4 + 8 * 3, 508 )
SKIN.Colours.Button.Down			= GWEN.TextureColor( 4 + 8 * 2, 500 )
SKIN.Colours.Button.Disabled		= GWEN.TextureColor( 4 + 8 * 3, 500 )

SKIN.Colours.Tab = {}
SKIN.Colours.Tab.Active = {}
SKIN.Colours.Tab.Active.Normal		= GWEN.TextureColor( 4 + 8 * 4, 508 )
SKIN.Colours.Tab.Active.Hover		= GWEN.TextureColor( 4 + 8 * 5, 508 )
SKIN.Colours.Tab.Active.Down		= GWEN.TextureColor( 4 + 8 * 4, 500 )
SKIN.Colours.Tab.Active.Disabled	= GWEN.TextureColor( 4 + 8 * 5, 500 )

SKIN.Colours.Tab.Inactive = {}
SKIN.Colours.Tab.Inactive.Normal	= GWEN.TextureColor( 4 + 8 * 6, 508 )
SKIN.Colours.Tab.Inactive.Hover		= GWEN.TextureColor( 4 + 8 * 7, 508 )
SKIN.Colours.Tab.Inactive.Down		= GWEN.TextureColor( 4 + 8 * 6, 500 )
SKIN.Colours.Tab.Inactive.Disabled	= GWEN.TextureColor( 4 + 8 * 7, 500 )

SKIN.Colours.Label = {}
SKIN.Colours.Label.Default			= GWEN.TextureColor( 4 + 8 * 8, 508 )
SKIN.Colours.Label.Bright			= GWEN.TextureColor( 4 + 8 * 9, 508 )
SKIN.Colours.Label.Dark				= GWEN.TextureColor( 4 + 8 * 8, 500 )
SKIN.Colours.Label.Highlight		= GWEN.TextureColor( 4 + 8 * 9, 500 )

SKIN.Colours.Tree = {}
SKIN.Colours.Tree.Lines				= GWEN.TextureColor( 4 + 8 * 10, 508 ) ---- !!!
SKIN.Colours.Tree.Normal			= GWEN.TextureColor( 4 + 8 * 11, 508 )
SKIN.Colours.Tree.Hover				= GWEN.TextureColor( 4 + 8 * 10, 500 )
SKIN.Colours.Tree.Selected			= GWEN.TextureColor( 4 + 8 * 11, 500 )

SKIN.Colours.Properties = {}
SKIN.Colours.Properties.Line_Normal			= GWEN.TextureColor( 4 + 8 * 12, 508 )
SKIN.Colours.Properties.Line_Selected		= GWEN.TextureColor( 4 + 8 * 13, 508 )
SKIN.Colours.Properties.Line_Hover			= GWEN.TextureColor( 4 + 8 * 12, 500 )
SKIN.Colours.Properties.Title				= GWEN.TextureColor( 4 + 8 * 13, 500 )
SKIN.Colours.Properties.Column_Normal		= GWEN.TextureColor( 4 + 8 * 14, 508 )
SKIN.Colours.Properties.Column_Selected		= GWEN.TextureColor( 4 + 8 * 15, 508 )
SKIN.Colours.Properties.Column_Hover		= GWEN.TextureColor( 4 + 8 * 14, 500 )
SKIN.Colours.Properties.Column_Disabled		= Color( 240, 240, 240 )
SKIN.Colours.Properties.Border				= GWEN.TextureColor( 4 + 8 * 15, 500 )
SKIN.Colours.Properties.Label_Normal		= GWEN.TextureColor( 4 + 8 * 16, 508 )
SKIN.Colours.Properties.Label_Selected		= GWEN.TextureColor( 4 + 8 * 17, 508 )
SKIN.Colours.Properties.Label_Hover			= GWEN.TextureColor( 4 + 8 * 16, 500 )
SKIN.Colours.Properties.Label_Disabled		= GWEN.TextureColor( 4 + 8 * 16, 508 )

SKIN.Colours.Category = {}
SKIN.Colours.Category.Header				= GWEN.TextureColor( 4 + 8 * 18, 500 )
SKIN.Colours.Category.Header_Closed			= GWEN.TextureColor( 4 + 8 * 19, 500 )
SKIN.Colours.Category.Line = {}
SKIN.Colours.Category.Line.Text				= GWEN.TextureColor( 4 + 8 * 20, 508 )
SKIN.Colours.Category.Line.Text_Hover		= GWEN.TextureColor( 4 + 8 * 21, 508 )
SKIN.Colours.Category.Line.Text_Selected	= GWEN.TextureColor( 4 + 8 * 20, 500 )
SKIN.Colours.Category.Line.Button			= GWEN.TextureColor( 4 + 8 * 21, 500 )
SKIN.Colours.Category.Line.Button_Hover		= GWEN.TextureColor( 4 + 8 * 22, 508 )
SKIN.Colours.Category.Line.Button_Selected	= GWEN.TextureColor( 4 + 8 * 23, 508 )
SKIN.Colours.Category.LineAlt = {}
SKIN.Colours.Category.LineAlt.Text				= GWEN.TextureColor( 4 + 8 * 22, 500 )
SKIN.Colours.Category.LineAlt.Text_Hover		= GWEN.TextureColor( 4 + 8 * 23, 500 )
SKIN.Colours.Category.LineAlt.Text_Selected		= GWEN.TextureColor( 4 + 8 * 24, 508 )
SKIN.Colours.Category.LineAlt.Button			= GWEN.TextureColor( 4 + 8 * 25, 508 )
SKIN.Colours.Category.LineAlt.Button_Hover		= GWEN.TextureColor( 4 + 8 * 24, 500 )
SKIN.Colours.Category.LineAlt.Button_Selected	= GWEN.TextureColor( 4 + 8 * 25, 500 )

SKIN.Colours.TooltipText = GWEN.TextureColor( 4 + 8 * 26, 500 )

SKIN.FlatUI = true

local _permut = {
	function(a,b,c) return a,b,c end,
	function(a,b,c) return b,a,c end,
	function(a,b,c) return c,a,b end,
	function(a,b,c) return c,b,a end,
	function(a,b,c) return b,c,a end,
	function(a,b,c) return a,c,b end,
}

local function rgb(h,s,v)

	h = h % 360 / 60
	local x = v * s * math.abs(h % 2 - 1)
	return _permut[1+math.floor(h)](v,v-x,v-v*s)

end

local function hsv(r,g,b)

	local v = math.max(r,g,b)
	local c = v - math.min(r,g,b)
	if c * v == 0 then return 0, 0, v
	elseif v == r then return 60 * (g-b) / c % 360, c/v, v
	elseif v == g then return 120 + 60 * (b-r) / c, c/v, v
	elseif v == b then return 240 + 60 * (r-g) / c, c/v, v
	end

end

function SKIN:AdjustColor(r,g,b)

	local h,s,v = hsv(r,g,b)
	return rgb(
		h + skin_hue:GetFloat(),
		s * skin_sat:GetFloat(),
		v * skin_val:GetFloat())

end

function SKIN:FlatBoxNC( d, x, y, w, h, r, g, b, a, ... )

	bprenderutils.RoundedBoxFast(d,x,y,w,h,r,g,b,a,...)

end

function SKIN:FlatBox( d, x, y, w, h, r, g, b, a, ... )

	r,g,b = self:AdjustColor(r,g,b)
	bprenderutils.RoundedBoxFast(d,x,y,w,h,r,g,b,a,...)

end

function SKIN:PaintMenuBarButton( panel, w, h )

	local col = panel.color
	local r,g,b = 50,55,60
	if col then r,g,b = col.r, col.g, col.b end

	if panel:IsEnabled() then
		if panel.Hovered then r,g,b = 200,100,50
		elseif panel:IsDown() then r,g,b = 50,170,200
		elseif col == nil then
			r,g,b = self:AdjustColor(r,g,b)
		end
	else
		r,g,b = r-20,g-20,b-10
		if col == nil then
			r,g,b = self:AdjustColor(r,g,b)
		end
	end

	local br,bg,bb = r+40,g+40,b+40
	self:FlatBoxNC(2, 0, 0, w, h, br,bg,bb,255,true,true,true,true)
	self:FlatBoxNC(2, 1, 1, w-2, h-2, r,g,b,255,true,true,true,true)

end

function SKIN:PaintFileManagerEntry( panel, w, h )

	local selected = panel:IsSelected()

	if panel:IsServerFile() then

		local r,g,b = HexColor("dfe6e9", true)
		if selected then 
			r,g,b = HexColor("ffd271", true) 
		else
			r,g,b = self:AdjustColor(r,g,b)
		end

		panel.nameLabel:SetTextColor( Color(r,g,b) )

		local lock = panel:GetLock()
		local isLocalLock = panel:IsLockedLocally()
		local col = lock and (isLocalLock and HexColor("9cf196") or HexColor("edaaaa")) or HexColor("636e72")
		self:FlatBoxNC(8, 0, 0, w, h, col.r/1.5, col.g/1.5, col.b/1.5, 255, false, true, false, true)

	else

		local r,g,b = HexColor("636e72", true)
		if selected then 
			r,g,b = HexColor("ffd271", true)
		else
			r,g,b = self:AdjustColor(r,g,b)
		end

		panel.nameLabel:SetTextColor( Color(r,g,b) )
		local r,g,b = self:AdjustColor(HexColor("#2d3436", true))
		self:FlatBoxNC(8, 0, 0, w, h, r,g,b,255,false,true,false,true)

	end

end

function SKIN:PaintPanel( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	if not self.FlatUI then
		self.tex.Panels.Normal( 0, 0, w, h, panel.m_bgColor )
	else
		local r,g,b,a = (panel.m_bgColor or Color(255,255,255)):Unpack()
		self:FlatBox(2,0,0,w,h,r*.2,g*.22,b*.25,a,true,true,true,true)
	end

end

function SKIN:PaintFrame( panel, w, h )

	if ( panel.m_bPaintShadow ) then

		local wasEnabled = DisableClipping( true )
		self.tex.Shadow( -4, -4, w+10, h+10 )
		DisableClipping( wasEnabled )

	end

	if ( panel:HasHierarchicalFocus() ) then

		if not self.FlatUI then
			self.tex.Window.Normal( 0, 0, w, h )
		else 
			self:FlatBox(2,0,0,w,h,60,70,75,255,true,true,true,true)
			self:FlatBox(2,0,0,w,28,230,255,255,20,true,true,false,false)
		end

	else

		if not self.FlatUI then
			self.tex.Window.Inactive( 0, 0, w, h )
		else
			self:FlatBox(2,0,0,w,h,30,35,35,255,true,true,true,true)
		end

	end

end

function SKIN:PaintTabCloseButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	if ( panel:GetDisabled() ) then
		return self.tex.Tab_Close( 0, 0, w, h, Color( 255, 255, 255, 50 ) )
	end

	if ( panel.Depressed || panel:IsSelected() ) then
		return self.tex.Tab_Close_Down( 0, 0, w, h )
	end

	if ( panel.Hovered ) then
		return self.tex.Tab_Close_Hover( 0, 0, w, h )
	end

	self.tex.Tab_Close( 0, 0, w, h )

end

function SKIN:PaintWindowCloseButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	if ( panel:GetDisabled() ) then
		return self.tex.Window.Close( 0, 0, w, h, Color( 255, 255, 255, 50 ) )
	end

	if ( panel.Depressed || panel:IsSelected() ) then
		return self.tex.Window.Close_Down( 0, 0, w, h )
	end

	if ( panel.Hovered ) then
		return self.tex.Window.Close_Hover( 0, 0, w, h )
	end

	self.tex.Window.Close( 0, 0, w, h )

end

function SKIN:PaintWindowMaximizeButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	if ( panel:GetDisabled() ) then
		return self.tex.Window.Maxi( 0, 0, w, h, Color( 255, 255, 255, 50 ) )
	end

	if ( panel.Depressed || panel:IsSelected() ) then
		return self.tex.Window.Maxi_Down( 0, 0, w, h )
	end

	if ( panel.Hovered ) then
		return self.tex.Window.Maxi_Hover( 0, 0, w, h )
	end

	self.tex.Window.Maxi( 0, 0, w, h )

end

function SKIN:PaintTab( panel, w, h )

	if ( panel:IsActive() ) then
		return self:PaintActiveTab( panel, w, h )
	end

	if not self.FlatUI then
		self.tex.TabT_Inactive( 0, 0, w, h )
	else
		self:FlatBox(2,0,0,w,h,50,60,64,255,true,true,true,true)
	end

end

function SKIN:PaintActiveTab( panel, w, h )

	if not self.FlatUI then
		self.tex.TabT_Active( 0, 0, w, h )
	else
		self:FlatBox(2,0,0,w,h,80,90,94,255,true,true,true,true)
	end

end

function SKIN:PaintPropertySheet( panel, w, h )

	-- TODO: Tabs at bottom, left, right

	local ActiveTab = panel:GetActiveTab()
	local Offset = 0
	if ( ActiveTab ) then Offset = ActiveTab:GetTall() - 8 end

	if not self.FlatUI then
		self.tex.Tab_Control( 0, Offset, w, h-Offset )
	else
		self:FlatBox(2,0,Offset,w,h-Offset,80,90,94,255,true,true,true,true)
	end

end

function SKIN:PaintComboBox( panel, w, h )

	if not self.FlatUI then
		if ( panel:GetDisabled() ) then
			return self.tex.Input.ComboBox.Disabled( 0, 0, w, h )
		end

		if ( panel.Depressed || panel:IsMenuOpen() ) then
			return self.tex.Input.ComboBox.Down( 0, 0, w, h )
		end

		if ( panel.Hovered ) then
			return self.tex.Input.ComboBox.Hover( 0, 0, w, h )
		end

		self.tex.Input.ComboBox.Normal( 0, 0, w, h )
	else

		if panel:GetDisabled() then
			self:FlatBox(2,0,0,w,h,30,35,35,255,true,true,true,true)
		elseif panel.Hovered then
			self:FlatBox(2,0,0,w,h,80,90,94,255,true,true,true,true)
		elseif panel.Depressed or panel:IsMenuOpen() then
			self:FlatBox(2,0,0,w,h,80,90,94,255,true,true,true,true)
		else
			self:FlatBox(2,0,0,w,h,50,60,64,255,true,true,true,true)
		end
	end

end

derma.DefineSkin( "Blueprints", "Makes blueprints look good", SKIN )
derma.RefreshSkins()