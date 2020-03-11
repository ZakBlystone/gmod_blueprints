AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Effect"
MODULE.Description = "A Clientside Effect you can dispatch using util.Effect"
MODULE.Icon = "icon16/lightning.png"
MODULE.Creatable = true
MODULE.AdditionalConfig = true

function MODULE:Setup()

	BaseClass.Setup(self)

	self.getSelfNodeType = bpnodetype.New()
	self.getSelfNodeType:SetCodeType(NT_Pure)
	self.getSelfNodeType.GetDisplayName = function() return "Self" end
	self.getSelfNodeType.GetGraphThunk = function() return self end
	self.getSelfNodeType.GetRole = function() return ROLE_Shared end
	self.getSelfNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Self", PN_Ref, PNF_None, "Entity"),
		}
	end
	self.getSelfNodeType:SetCode( "#1 = __self.Entity" )

end

function MODULE:SetupEditValues( values )

end

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

	return BaseClass.CanAddNode( self, nodeType )

end

function MODULE:GetNodeTypes( graph, collection )

	BaseClass.GetNodeTypes( self, graph, collection )

	local types = {}

	collection:Add( types )

	types["__Self"] = self.getSelfNodeType

	for k,v in pairs(types) do v.name = k end

end

function MODULE:IsConstructable() return false end

function MODULE:AutoFillsPinClass( class )

	if class == "CEffectData" then return true end

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	if pass == CP_PREPASS then

		-- All unconnected entity pins point to self
		for k, v in ipairs( compiler.graphs ) do
			for _, node in v:Nodes() do
				for _, pin in node:SidePins(PD_In) do
					if pin:GetBaseType() ~= PN_Ref then continue end
					if pin:GetSubType() == "CEffectData" and #pin:GetConnectedPins() == 0 then
						pin:SetLiteral("__self.__data")
					end
				end
			end
		end

	elseif pass == CP_MODULEMETA then

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

RegisterModuleClass("EFFECT", MODULE, "Configurable")
