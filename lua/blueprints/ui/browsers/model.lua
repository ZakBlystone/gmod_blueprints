if SERVER then AddCSLuaFile() return end

module("browser_model", package.seeall, bpcommon.rescope(bpschema))

local BROWSER = {}

RegisterAssetBrowserClass("model", BROWSER)