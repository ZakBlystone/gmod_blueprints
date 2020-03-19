if SERVER then AddCSLuaFile() return end

module("browser_texture", package.seeall, bpcommon.rescope(bpschema))

local BROWSER = {}

RegisterAssetBrowserClass("texture", BROWSER)