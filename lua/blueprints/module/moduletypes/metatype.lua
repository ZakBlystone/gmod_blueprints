AddCSLuaFile()

module("module_metatype", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Name = "Metatype"
MODULE.Creatable = false
MODULE.HasOwner = false
MODULE.SelfPinSubClass = nil

function MODULE:Setup()

	BaseClass.Setup(self)

	self.modulePinType = PinType( PN_BPRef, PNF_None, self:GetUID() ):WithModule(self)

	self.getSelfNodeType = bpnodetype.New()
	self.getSelfNodeType:SetCodeType(NT_Pure)
	self.getSelfNodeType.GetDisplayName = function() return "Self" end
	self.getSelfNodeType.GetGraphThunk = function() return self end
	self.getSelfNodeType.GetRole = function() return ROLE_Shared end
	self.getSelfNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Self", self.modulePinType),
		}
	end
	self.getSelfNodeType:SetCode( "#1 = __self" )

	self.getClassNodeType = bpnodetype.New()
	self.getClassNodeType:SetCodeType(NT_Pure)
	self.getClassNodeType.GetDisplayName = function() return "Class" end
	self.getClassNodeType.GetGraphThunk = function() return self end
	self.getClassNodeType.GetRole = function() return ROLE_Shared end
	self.getClassNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Class", PN_BPClass, PNF_None),
		}
	end
	self.getClassNodeType:SetCode( "#1 = __bpm.guid" )

	if self.HasOwner then

		self.getOwnerNodeType = bpnodetype.New()
		self.getOwnerNodeType:SetCodeType(NT_Pure)
		self.getOwnerNodeType.GetDisplayName = function() return "Owner" end
		self.getOwnerNodeType.GetGraphThunk = function() return self end
		self.getOwnerNodeType.GetRole = function() return ROLE_Shared end
		self.getOwnerNodeType.GetRawPins = function()
			return {
				MakePin(PD_Out, "Owner", self:GetOwnerPinType()),
			}
		end
		self.getOwnerNodeType:SetCode( "#1 = __self.Owner" )

	end

end

function MODULE:GetModulePinType() return self.modulePinType end
function MODULE:GetOwnerPinType() return PinType( PN_Ref, PNF_None, "" ) end

function MODULE:GetSelfNodeType() return self.getSelfNodeType end
function MODULE:GetClassNodeType() return self.getClassNodeType end
function MODULE:GetOwnerNodeType() return self.getOwnerNodeType end

function MODULE:IsConstructable() return false end

function MODULE:CanCast( outPinType, inPinType )

	if outPinType:Equal(self.modulePinType) then

		if inPinType:GetSubType() == self.SelfPinSubClass then return true end

	end

	return BaseClass.CanCast( self, outPinType, inPinType )

end

function MODULE:GetNodeTypes( collection, graph )

	BaseClass.GetNodeTypes( self, collection, graph )

	local types = {}

	collection:Add( types )

	types["__Self"] = self:GetSelfNodeType()
	types["__Class"] = self:GetClassNodeType()

	if self.HasOwner then

		types["__Owner"] = self:GetOwnerNodeType()

	end

	for k,v in pairs(types) do v.name = k end

end

function MODULE:GetPinTypes( collection )

	BaseClass.GetPinTypes( self, collection )

	local types = {}

	collection:Add( types )
	types[#types+1] = self:GetModulePinType()

end

RegisterModuleClass("MetaType", MODULE, "Configurable")
