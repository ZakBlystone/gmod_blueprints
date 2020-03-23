AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Effect"
MODULE.Description = "A Clientside Effect you can dispatch using util.Effect"
MODULE.Icon = "icon16/lightning.png"
MODULE.Creatable = true
MODULE.AdditionalConfig = true
MODULE.SelfPinSubClass = "Entity"
MODULE.HasUIDClassname = true

function MODULE:Setup()

	BaseClass.Setup(self)

	self:AddAutoFill( PinType( PN_Ref, PNF_None, "CEffectData" ), "__self.__data" )

end

function MODULE:GetSelfPinType() return PinType( PN_Ref, PNF_None, "Entity" ) end

function MODULE:SetupEditValues( values ) end
function MODULE:GetDefaultConfigTable()

	return {
		classname = bpcommon.GUIDToString(self:GetUID(), true):lower(),
	}

end

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	local _, init = graph:AddNode("EFFECT_Init", 120, 100)
	local _, init = graph:AddNode("EFFECT_Render", 120, 200)
	local _, init = graph:AddNode("EFFECT_Think", 120, 300)

end

local allowedHooks = {
	["GM"] = false,
	["EFFECT"] = true,
}

function MODULE:CanAddNode(nodeType)

	local group = nodeType:GetGroup()
	if group and nodeType:GetContext() == bpnodetype.NC_Hook and not allowedHooks[group:GetName()] then return false end

	if nodeType:GetRole() == ROLE_Server then return false end

	return BaseClass.CanAddNode( self, nodeType )

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MODULEMETA then

		compiler.emit([[
for k,v in pairs(meta) do
	local _, _, m = k:find("EFFECT_(.+)")
	if m then meta[ m ] = v end
end]])

		compiler.emit("function meta:Init( data )")
		compiler.emit("\tlocal instance = self")
		compiler.emit("\tinstance.delays = {}")
		compiler.emit("\tinstance.__data = data")
		compiler.emit("\tinstance.__bpm = __bpm")
		compiler.emit("\tinstance.guid = __bpm.hexBytes(string.format(\"%0.32X\", self:EntIndex()))")
		compiler.emitContext( CTX_Vars .. "global", 1 )
		compiler.emit("\tif self.EFFECT_Init then self:EFFECT_Init() end")
		compiler.emit("end")

		compiler.emit([[
function meta:Think()
	local r = nil
	if self.EFFECT_Think then r = self:EFFECT_Think() end
	self:update()
	return r
end
function meta:Render()
	if self.EFFECT_Render then self:EFFECT_Render() end
end]])

		return true

	elseif pass == CP_MODULEBPM then

		local classname = edit:Index("classname")

		compiler.emit("__bpm.class = " .. classname:ToString())
		compiler.emit([[
__bpm.init = function()
	if SERVER then return end
	effects.Register( meta, __bpm.class )
end
__bpm.shutdown = function()

end]])

	end

end

RegisterModuleClass("EFFECT", MODULE, "MetaType")
