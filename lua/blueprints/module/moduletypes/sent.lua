AddCSLuaFile()

module("module_sent", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Entity"
MODULE.Description = "A Scripted Entity you can spawn in the world"
MODULE.Icon = "icon16/bricks.png"
MODULE.Creatable = true
MODULE.AdditionalConfig = true
MODULE.HasOwner = true
MODULE.SelfPinSubClass = "Entity"

function MODULE:Setup()

	BaseClass.Setup(self)

	self:AddAutoFill( PinType( PN_Ref, PNF_None, "PhysObj" ), "__self:GetPhysicsObject()" )
	self:AddAutoFill( PinType( PN_Ref, PNF_None, "Entity" ), "__self" )

end

function MODULE:GetOwnerPinType() return PinType( PN_Ref, PNF_None, "Entity" ) end

function MODULE:SetupEditValues( values ) end
function MODULE:GetDefaultConfigTable()

	return {
		classname = bpcommon.GUIDToString(self:GetUID(), true):lower(),
		entity = {
			Base = "base_anim",
			Type = "anim",
			Author = "",
			Category = "Blueprint",
			Contact = "",
			Purpose = "",
			Instructions = "",
			PrintName = "BP Scripted Entity",
			AutomaticFrameAdvance = false,
			Spawnable = true,
			AdminOnly = false,
		}
	}

end

function MODULE:CreateDefaults()

	local id, graph = self:NewGraph("EventGraph")
	local _, init = graph:AddNode("ENTITY_Initialize", 120, 100)
	local _, model = graph:AddNode("Entity_SetModel", 250, 100)
	local _, phys = graph:AddNode("Entity_PhysicsInit", 700, 100)

	init:FindPin( PD_Out, "Exec" ):Connect( model:FindPin( PD_In, "Exec") )
	model:FindPin( PD_In, "model" ):SetLiteral( "models/props_junk/watermelon01.mdl" )
	model:FindPin( PD_Out, "Thru" ):Connect( phys:FindPin( PD_In, "Exec") )
	phys:FindPin( PD_In, "SolidType" ):SetLiteral( "SOLID_VPHYSICS" )

end

local allowedHooks = {
	["GM"] = false,
	["ENTITY"] = true,
}

function MODULE:CanAddNode(nodeType)

	local group = nodeType:GetGroup()
	if group and nodeType:GetContext() == bpnodetype.NC_Hook and not allowedHooks[group:GetName()] then return false end

	return BaseClass.CanAddNode( self, nodeType )

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MODULEMETA then

		local entityTable = edit:Index("entity")
		compiler.emit( "meta = table.Merge( meta, " .. entityTable:ToString() .. " )")

		compiler.emit([[
for k,v in pairs(meta) do
	local _, _, m = k:find("ENTITY_(.+)")
	if m then meta[ m ] = v end
end]])

		compiler.emit("function meta:Initialize()")
		compiler.emit("\tlocal instance = self")
		compiler.emit("\tinstance.delays = {}")
		compiler.emit("\tinstance.__bpm = __bpm")
		compiler.emit("\tinstance.guid = __bpm.hexBytes(string.format(\"%0.32X\", self:EntIndex()))")
		compiler.emitContext( CTX_Vars .. "global", 1 )
		compiler.emit("\tself.bInitialized = true")
		compiler.emit("\tself.lastThink = CurTime()")
		compiler.emit("\tself:netInit()")
		compiler.emit("\tif self.ENTITY_Initialize then self:ENTITY_Initialize() end")
		compiler.emit("end")

		compiler.emit([[
function meta:Think()
	local r = nil
	if CLIENT and not self.bInitialized then self:Initialize() end
	if self.ENTITY_Think then r = self:ENTITY_Think() end
	if self.lastThink then self:update( CurTime() - self.lastThink ) end
	self.lastThink = CurTime()
	return r
end
function meta:OnRemove()
	if not self.bInitialized then return end
	if self.ENTITY_OnRemove then self:ENTITY_OnRemove() end
	self:netShutdown()
end]])

		return true

	elseif pass == CP_MODULEBPM then

		local classname = edit:Index("classname")

		compiler.emit("__bpm.class = " .. classname:ToString())
		compiler.emit([[
__bpm.init = function()
	scripted_ents.Register( meta, __bpm.class )
	if CLIENT and bpsandbox then bpsandbox.RefreshSENTs() end
end
__bpm.shutdown = function()
	if CLIENT then return end
	for _, e in ipairs( ents.FindByClass( __bpm.class ) ) do
		if IsValid(e) then 
			e:Remove()
		end
	end
end]])

	end

end

RegisterModuleClass("SENT", MODULE, "MetaType")
