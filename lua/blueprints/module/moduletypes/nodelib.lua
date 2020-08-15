AddCSLuaFile()

module("mod_nodelib", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.Name = LOCTEXT("module_nodelib_name","Node Library")
MODULE.Description = LOCTEXT("module_nodelib_desc","Custom node library")
MODULE.Icon = "icon16/table.png"
MODULE.EditorClass = "nodelib"
MODULE.Developer = true
MODULE.CanBeSubmodule = true

bpcommon.CreateIndexableListIterators(MODULE, "structs")
bpcommon.CreateIndexableListIterators(MODULE, "groups")

function MODULE:Setup()

	BaseClass.Setup(self)

	self.groups = bplist.New( bpnodetypegroup_meta ):WithOuter(self):PreserveNames(true)

	--local nodes2 = bpnodetypegroup.New( bpnodetypegroup.TYPE_Lib ):WithOuter(self)
	--nodes2:SetName("GLOBAL")

	self.structs = bplist.New( bpstruct_meta ):NamedItems("Struct"):WithOuter(self)


end

function MODULE:GetNodeTypes( collection, graph )

	local tab = {}
	collection:Add(tab)

	for k,v in ipairs(self.structs) do

		local maker = v:MakerNodeType()
		local breaker = v:BreakerNodeType()

		local makerName = "Make" .. v:GetName()
		local breakerName = "Break" .. v:GetName()
		tab[makerName] = maker
		tab[breakerName] = breaker

		maker.name = makerName
		breaker.name = breakerName

	end

	for _,v in self:Groups() do
		for _, e in v:GetEntries():Items() do
			tab[e:GetFullName()] = e
		end
	end

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

	for id, v in self:Groups() do

		if v:GetType() == bpnodetypegroup.TYPE_Class then
			if v:GetParam("pinTypeOverride") then print("SKIP CLASS: " .. tostring(v)) continue end
			types[#types+1] = bppintype.New(PN_Ref, PNF_None, v.name)
		end

	end

end

function MODULE:RequestGraphForEvent( nodeType )

	return nil

end

function MODULE:AutoFillsPinType( pinType )

	return false

end

function MODULE:Compile( compiler, pass )


end

RegisterModuleClass("NodeLib", MODULE, "Configurable")