AddCSLuaFile()

module("mod_nodelib", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.Name = LOCTEXT"module_nodelib_name","Node Library"
MODULE.Description = LOCTEXT"module_nodelib_desc","Custom node library"
MODULE.Icon = "icon16/table.png"
MODULE.EditorClass = "nodelib"
MODULE.Developer = true

bpcommon.CreateIndexableListIterators(MODULE, "structs")

function MODULE:Setup()

	BaseClass.Setup(self)

	self.groups = bplist.New( bpnodetypegroup_meta ):WithOuter(self):PreserveNames(true)

	--local nodes2 = bpnodetypegroup.New( bpnodetypegroup.TYPE_Lib ):WithOuter(self)
	--nodes2:SetName("GLOBAL")

	self.structs = bplist.New( bpstruct_meta ):NamedItems("Struct"):WithOuter(self)


end

function MODULE:GetNodeTypes()

end

function MODULE:SerializeData( stream )

	BaseClass.SerializeData(self, stream)

	self.groups:Serialize( stream )
	self.structs:Serialize( stream )

end

function MODULE:GetPinTypes( collection )

	BaseClass.GetPinTypes( self, collection )

	local types = {}
	collection:Add( types )

	for id, v in self:Structs() do

		local pinType = bppintype.New(PN_Struct, PNF_Custom, v.name):WithOuter( v )
		types[#types+1] = pinType

	end

end

function MODULE:GetNodeTypes()

end

function MODULE:RequestGraphForEvent( nodeType )

	return nil

end

function MODULE:AutoFillsPinType( pinType )

	return false

end

function MODULE:Compile( compiler, pass )


	if pass == CP_MODULECODE then

		local mod = self:SaveToText()
		compiler.emit("if not game.SinglePlayer() and CLIENT then return end")
		compiler.emit("local data = [[" .. mod .. "]]")
		compiler.emit([[hook.Add("BPPopulateDefs", ]] .. bpcommon.EscapedGUID( self:GetUID() ) .. [[, function(pack)]])
		compiler.emit([[
	if not bpcommon.CheckVersionCompat("]] .. bpcommon.ENV_VERSION ..  [[", "nodelib", "Tried to load outdated node library: ]] .. self:GetName() .. [[") then return end
	local mod = bpmodule.New()
	mod:LoadFromText(data)
	for _, group in mod.groups:Items() do pack:AddNodeGroup(group) end
	for _, struct in mod.structs:Items() do pack:AddStruct(struct) end]])
		compiler.emit("end)")

	end

end

RegisterModuleClass("NodeLib", MODULE, "Configurable")