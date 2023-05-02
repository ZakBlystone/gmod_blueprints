AddCSLuaFile()

module("module_metatype", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = false
MODULE.HasOwner = false
MODULE.SelfPinSubClass = nil
MODULE.HasSelfPin = true
MODULE.HasUIDClassname = false

function InlineVarCompileFunc( pinName, var )

	return function(node, compiler, pass)

		if pass == bpcompiler.CP_ALLOCVARS then

			compiler:CreatePinRouter( node:FindPin(PD_Out, pinName), function(pin)
				return { var = var }
			end )

			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			compiler:CompileReturnPin( node )
			return true

		end

	end

end

function MODULE:Setup()

	BaseClass.Setup(self)

	self.autoFills = {}
	self.modulePinType = bppintype.New( PN_BPRef, PNF_None, self ):WithOuter(self)

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
	self.getSelfNodeType.Compile = InlineVarCompileFunc("Self", "__self")

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
	self.getClassNodeType.Compile = InlineVarCompileFunc("Class", "__bpm.guid")

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
		self.getOwnerNodeType.Compile = InlineVarCompileFunc("Owner", "__self.Owner")

	end

	self:AddAutoFill( self:GetModulePinType(), "__self" )

end

function MODULE:IsStatic()

	return false

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

function MODULE:SerializeData( stream )

	stream:Extern( self:GetModulePinType(), "\xE3\x05\x45\x7E\xA6\x93\xC1\x32\x80\x00\x00\x0F\x51\x68\x87\xB6" )
	stream:Extern( self:GetSelfNodeType(), "\xE3\x05\x45\x7E\x53\x60\x58\xAB\x80\x00\x00\x10\x51\x78\x1D\xC6" )
	stream:Extern( self:GetClassNodeType(), "\xE3\x05\x45\x7E\x49\x74\x30\xFA\x80\x00\x00\x11\x51\x8A\x8D\xDA" )
	stream:Extern( self:GetOwnerNodeType(), "\xE3\x05\x45\x7E\xF7\xB7\xCB\xA9\x80\x00\x00\x12\x51\x96\xE4\xE6" )

	return BaseClass.SerializeData( self, stream )

end

function MODULE:IsConstructable() return false end

function MODULE:CanCast( outPinType, inPinType )

	if outPinType:Equal(self:GetModulePinType(), PNF_None) then

		if inPinType:GetSubType() == self.SelfPinSubClass then return true end

	end

	return BaseClass.CanCast( self, outPinType, inPinType )

end

function MODULE:GetLocalNodeTypes( collection, graph )

	BaseClass.GetLocalNodeTypes( self, collection, graph )

	local types = {}

	collection:Add( types )

	types["__Self"] = self:GetSelfNodeType()
	types["__Class"] = self:GetClassNodeType()

	if self.HasOwner then

		types["__Owner"] = self:GetOwnerNodeType()

	end

	for k,v in pairs(types) do v.name = k end

end

function MODULE:GetNodeTypes( collection, graph )

	BaseClass.GetNodeTypes( self, collection, graph )

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
