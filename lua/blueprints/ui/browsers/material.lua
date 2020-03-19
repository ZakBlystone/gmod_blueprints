if SERVER then AddCSLuaFile() return end

module("browser_material", package.seeall, bpcommon.rescope(bpschema))

local BROWSER = {}

RegisterAssetBrowserClass("material", BROWSER)