AddCSLuaFile()

module("_", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = LOCTEXT"module_effect_name","Effect"
MODULE.Description = LOCTEXT"module_effect_desc","A Clientside Effect you can dispatch using util.Effect"
MODULE.Icon = "icon16/lightning.png"
MODULE.Creatable = true
MODULE.CanBeSubmodule = true
MODULE.AdditionalConfig = true
MODULE.SelfPinSubClass = "Entity"
MODULE.HasUIDClassname = true

function MODULE:Setup()

	BaseClass.Setup(self)

	self:AddAutoFill( bppintype.New( PN_Ref, PNF_None, "CEffectData" ), "__self.__data" )

	self.dispatchNodeType = bpnodetype.New():WithOuter(self)
	self.dispatchNodeType:SetCodeType(NT_Function)
	self.dispatchNodeType.GetDisplayName = function() return "Dispatch " .. self:GetName() end
	self.dispatchNodeType.GetGraphThunk = function() return self end
	self.dispatchNodeType.GetRole = function() return ROLE_Shared end
	self.dispatchNodeType.GetCategory = function() return self:GetName() end
	self.dispatchNodeType.GetRawPins = function()
		return {
			MakePin(PD_In, "EffectData", PN_Ref, PNF_None, "CEffectData"),
		}
	end
	self.dispatchNodeType.Compile =  function(node, compiler, pass)

		if pass == bpcompiler.CP_ALLOCVARS then 

			compiler:CreatePinVar( node:FindPin(PD_In, "EffectData") )
			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			local edit = self:GetConfigEdit()
			compiler.emit( [[util.Effect(]] .. edit:Index("classname"):ToString() .. [[, ]] .. compiler:GetPinCode( node:FindPin(PD_In, "EffectData") ) .. [[)]])
			compiler:CompileReturnPin( node )
			return true

		end

	end

end

function MODULE:GetNodeTypes( collection, graph )

	BaseClass.GetNodeTypes( self, collection, graph )

	local types = {}

	collection:Add( types )
	types["__Dispatch"] = self:GetDispatchNodeType()
	for k,v in pairs(types) do v.name = k end

end

function MODULE:SerializeData( stream )

	stream:Extern( self:GetDispatchNodeType(), "\x43\xBE\x45\x7E\x10\xE2\xC1\x5B\x80\x00\x00\xBD\x1F\xB0\x72\x12" )

	return BaseClass.SerializeData( self, stream )

end

function MODULE:GetDispatchNodeType() return self.dispatchNodeType end
function MODULE:GetSelfPinType() return bppintype.New( PN_Ref, PNF_None, "Entity" ) end

function MODULE:SetupEditValues( values )

	values:Index("classname"):SetRuleFlags( value_string.RULE_NOUPPERCASE, value_string.RULE_NOSPACES, value_string.RULE_NOSPECIAL )

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

local blacklistHooks = {
	["WEAPON"] = true,
	["ENTITY"] = true,
	["CORE"] = true,
}

function MODULE:CanAddNode(nodeType)

	local group = nodeType:GetGroup()
	if group and nodeType:GetContext() == bpnodetype.NC_Hook and blacklistHooks[group:GetName()] then return false end

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
		compiler.emit("\tinstance.guid = __hexBytes(string.format(\"%0.32X\", self:EntIndex()))")
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
	effects.Register( __bpm.meta, __bpm.class )
end
__bpm.shutdown = function()

end]])

	end

end

RegisterModuleClass("EFFECT", MODULE, "MetaType")
