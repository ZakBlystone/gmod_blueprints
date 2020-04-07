AddCSLuaFile()

module("mod_nodelib", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.Name = LOCTEXT"module_nodelib_name","Node Library"
MODULE.Description = LOCTEXT"module_nodelib_desc","Custom node library"
MODULE.Icon = "icon16/table.png"
MODULE.EditorClass = "nodelib"

function MODULE:Setup()

	BaseClass.Setup(self)

	self.groups = bplist.New( bpnodetypegroup_meta ):WithOuter(self):PreserveNames(true)
	
	--local nodes = bpnodetypegroup.New( bpnodetypegroup.TYPE_Lib ):WithOuter(self)
	--nodes:SetName("DarkRP")

	--local nodes2 = bpnodetypegroup.New( bpnodetypegroup.TYPE_Lib ):WithOuter(self)
	--nodes2:SetName("GLOBAL")

	self.structs = bplist.New( bpstruct_meta ):WithOuter(self)

	--self.groups:Add(nodes)
	--self.groups:Add(nodes2)

	--[[local test = nodes:NewEntry() test:SetName("createEntity") test:SetCodeType( NT_Function ) test:AddPin( MakePin( PD_In, "name", PN_String ) )
	local test = nodes:NewEntry() test:SetName("createEntityGroup") test:SetCodeType( NT_Function ) test:AddPin( MakePin( PD_In, "name", PN_String ) )
	local test = nodes:NewEntry() test:SetName("createFood") test:SetCodeType( NT_Function ) test:AddPin( MakePin( PD_In, "name", PN_String ) )
	local test = nodes:NewEntry() test:SetName("getChatSound") test:SetCodeType( NT_Pure ) 
		test:AddPin( MakePin( PD_In, "text", PN_String ) )
		test:AddPin( MakePin( PD_Out, "soundPaths", PN_String, PNF_Table ) )
		test:SetRole( ROLE_Server )]]

	--[[self.test = bpnodetype.New():WithOuter(self)
	self.test:SetContext(bpnodetype.NC_Lib)
	self.test:SetNodeClass("FuncCall")
	self.test:SetDisplayName("PrintMessage")
	self.test:SetCategory("GLOBAL")]]

end

function MODULE:GetNodeTypes()

end

function MODULE:GetPinTypes( collection )

	BaseClass.GetPinTypes( self, collection )

end

function MODULE:AutoFillsPinType( pinType )

	return false

end

function MODULE:WriteData( stream, mode, version )

	BaseClass.WriteData( self, stream, mode, version )

end

function MODULE:ReadData( stream, mode, version )

	BaseClass.ReadData( self, stream, mode, version )

end

function MODULE:Compile( compiler, pass )

end

RegisterModuleClass("NodeLib", MODULE, "Configurable")