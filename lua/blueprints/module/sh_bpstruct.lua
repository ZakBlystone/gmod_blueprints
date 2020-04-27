AddCSLuaFile()

module("bpstruct", package.seeall, bpcommon.rescope(bpschema))

local meta = bpcommon.MetaTable("bpstruct")

function meta:Init()

	self.pins = bplist.New(bppin_meta):NamedItems("Pins"):WithOuter(self)
	self.nameMap = {}
	self.invNameMap = {}
	self.pins:Bind("preModify", self, self.PreModify)
	self.pins:Bind("postModify", self, self.PostModify)

	-- Struct maker node
	self.makerNodeType = bpnodetype.New():WithOuter(self)
	self.makerNodeType:SetContext(bpnodetype.NC_Struct)
	self.makerNodeType:SetNodeClass("StructMake")
	self.makerNodeType.GetDisplayName = function() return "Make" .. self:GetName() end
	self.makerNodeType.GetDescription = function() return (self.desc or "Makes a " .. self:GetName() .. " structure") end
	self.makerNodeType.GetCategory = function() return self:GetName() end
	self.makerNodeType.GetFlags = function() return self.custom and NTF_Custom or NTF_None end
	self.makerNodeType.struct = self

	-- Struct breaker node
	self.breakerNodeType = bpnodetype.New():WithOuter(self)
	self.breakerNodeType:SetContext(bpnodetype.NC_Struct)
	self.breakerNodeType:SetNodeClass("StructBreak")
	self.breakerNodeType.GetDisplayName = function() return "Break" .. self:GetName() end
	self.breakerNodeType.GetDescription = function() return self.desc or "Returns components of a " .. self:GetName() .. " structure" end
	self.breakerNodeType.GetCategory = function() return self:GetName() end
	self.breakerNodeType.GetFlags = function() return self.custom and NTF_Custom or NTF_None end
	self.breakerNodeType.struct = self

	return self

end

function meta:GetModule()

	return self:FindOuter( bpmodule_meta )

end

function meta:PreModify()

	local mod = self:GetModule()
	if not mod then return end
	mod:PreModifyNodeType( self.makerNodeType )
	mod:PreModifyNodeType( self.breakerNodeType )

end

function meta:PostModify()

	local mod = self:GetModule()
	if not mod then return end
	mod:PostModifyNodeType( self.makerNodeType )
	mod:PostModifyNodeType( self.breakerNodeType )

end

function meta:AddPin(pin)

	local name = pin:GetName()
	return self.pins:Add( pin, self.nameMap[name:lower()] or name )

end

function meta:SetPinTypeOverride(override)

	self.pinTypeOverride = override

end

function meta:GetPinTypeOverride()

	return self.pinTypeOverride

end

function meta:SetName(name)

	self.name = name

end

function meta:GetName()

	return self.name

end

function meta:SetMetaTable(tableName)

	self.metaTable = tableName

end

function meta:GetMetaTable()

	return self.metaTable

end

function meta:RemapName(old, new)

	self.nameMap[old:lower()] = new
	self.invNameMap[new:lower()] = old

end

function meta:MarkAsCustom()

	self.custom = true
	return self

end

function meta:MakerNodeType()

	return self.makerNodeType

end

function meta:BreakerNodeType()

	return self.breakerNodeType

end

function meta:PostInit()

end

function meta:Serialize(stream)

	stream:Extern( self:MakerNodeType() )
	stream:Extern( self:BreakerNodeType() )

	self.pins:Serialize(stream)
	self.nameMap = stream:Value(self.nameMap)
	self.invNameMap = stream:Value(self.invNameMap)
	self.metaTable = stream:Value(self.metaTable)

	return stream

end

function New(...) return bpcommon.MakeInstance(meta, ...) end