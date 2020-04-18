AddCSLuaFile()

module("module_metatype", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = false
MODULE.HasOwner = false
MODULE.SelfPinSubClass = nil
MODULE.HasSelfPin = true
MODULE.HasUIDClassname = false

function MODULE:Setup()

	BaseClass.Setup(self)

	self.autoFills = {}
	self.modulePinType = bppintype.New( PN_BPRef, PNF_None, self:GetUID() ):WithOuter(self)

	self.getSelfNodeType = bpnodetype.New():WithOuter(self)
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

	self.getClassNodeType = bpnodetype.New():WithOuter(self)
	self.getClassNodeType:SetCodeType(NT_Pure)
	self.getClassNodeType.GetDisplayName = function() return "Class" end
	self.getClassNodeType.GetGraphThunk = function() return self end
	self.getClassNodeType.GetRole = function() return ROLE_Shared end
	self.getClassNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Class", PN_BPClass, PNF_None, self:GetUID() ),
		}
	end
	self.getClassNodeType:SetCode( "#1 = __bpm.guid" )

	if self.HasOwner then

		self.getOwnerNodeType = bpnodetype.New():WithOuter(self)
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

	self:AddAutoFill( self:GetModulePinType(), "__self" )

end

function MODULE:GenerateNewUID()

	local previousUID = self:GetUID()
	BaseClass.GenerateNewUID( self )

	if self.HasUIDClassname then
		local classname = self:GetConfigEdit():Index("classname")
		if classname and bpcommon.HexBytes(classname:Get() or "") == previousUID then
			print("Propegate new UID: " .. bpcommon.GUIDToString( previousUID ) .. " -> " .. bpcommon.GUIDToString(self:GetUID()) )
			classname:Set( bpcommon.GUIDToString( self:GetUID(), true ):lower() )
		end
	end

end

function MODULE:AddAutoFill( pinType, literal )

	if pinType:GetBaseType() == PN_Dummy then return end

	table.insert(self.autoFills,
	{
		pinType = pinType,
		literal = literal,
	})

end

function MODULE:TryAutoFillPin( pin )

	for _, v in ipairs(self.autoFills) do

		if pin:GetType():Equal( v.pinType ) and #pin:GetConnectedPins() == 0 then

			pin:SetLiteral( v.literal )
			return

		end

	end

end

function MODULE:AutoFillsPinType( pinType )

	for _, v in ipairs(self.autoFills) do

		if pinType:Equal( v.pinType ) then return true end

	end

	return false

end

function MODULE:GetModulePinType() return self.modulePinType end
function MODULE:GetOwnerPinType() return bppintype.New( PN_Dummy, PNF_None, "" ) end

function MODULE:GetSelfNodeType() return self.getSelfNodeType end
function MODULE:GetClassNodeType() return self.getClassNodeType end
function MODULE:GetOwnerNodeType() return self.getOwnerNodeType end

function MODULE:IsConstructable() return false end

function MODULE:CanCast( outPinType, inPinType )

	if outPinType:GetBaseType() == PN_BPClass and inPinType:GetBaseType() == PN_BPClass then

		local inSub = inPinType:GetSubType()
		local outSub = outPinType:GetSubType()
		if not bpcommon.IsGUID( inSub ) and bpcommon.IsGUID( outSub )then

			local mod = self:ResolveModuleUID( outSub )
			return mod:GetType() == inSub

		end

	end

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

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MODULEMETA then

		compiler.emit("_FR_METAHOOKS()")

	elseif pass == CP_PREPASS then

		for k, v in ipairs( self.cgraphs ) do
			for _, node in v:Nodes() do
				for _, pin in node:SidePins(PD_In) do
					self:TryAutoFillPin( pin )
				end
			end
		end

	elseif pass == CP_MODULEFOOTER then

		if bit.band(compiler.flags, CF_Standalone) ~= 0 then

			compiler.emit("__bpm.init()")

		end

	end

end

RegisterModuleClass("MetaType", MODULE, "GraphModule")
