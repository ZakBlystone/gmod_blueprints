AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bppin.lua")

module("bpnodetype", package.seeall, bpcommon.rescope(bpschema))

NC_Class = 0
NC_Lib = 1
NC_Hook = 2
NC_Struct = 3

local meta = bpcommon.MetaTable("bpnodetype")

bpcommon.AddFlagAccessors(meta)

meta.__tostring = function(self) return self:ToString() end

local PIN_INPUT_EXEC = MakePin( PD_In, "Exec", PN_Exec )
local PIN_OUTPUT_EXEC = MakePin( PD_Out, "Exec", PN_Exec )
local PIN_OUTPUT_THRU = MakePin( PD_Out, "Thru", PN_Exec )

function meta:Init(context, group)

	self.flags = 0
	self.role = 0
	self.codeType = 0
	self.code = nil
	self.category = nil
	self.displayName = nil
	self.desc = nil
	self.nodeClass = nil
	self.nodeParams = {}
	self.requiredMeta = {}
	self.pinRedirects = {}
	self.jumpSymbols = {}
	self.locals = {}
	self.informs = {}
	self.pins = {}
	self.warning = nil
	self.context = context
	self.group = group
	return self

end

function meta:AddPin(pin) table.insert(self.pins, pin) end
function meta:AddRequiredMeta(meta) table.insert(self.requiredMeta, meta) end
function meta:AddPinRedirect(fromName, toName) self.pinRedirects[fromName] = toName end
function meta:AddJumpSymbol(name) table.insert(self.jumpSymbols, name) end
function meta:AddLocal(name) table.insert(self.locals, name) end
function meta:AddInform(pinID) table.insert(self.informs, pinID) end
function meta:SetRole(role) self.role = role end
function meta:SetCodeType(codeType) self.codeType = codeType end
function meta:SetName(name) self.name = name end
function meta:SetCode(code) self.code = code end
function meta:SetCategory(category) self.category = category end
function meta:SetDisplayName(name) self.displayName = name end
function meta:SetDescription(desc) self.desc = desc end
function meta:SetGraphThunk(id) self.graphThunk = id end
function meta:SetNodeClass(class) self.nodeClass = class end
function meta:SetNodeParam(key, value) self.nodeParams[key] = value end
function meta:SetWarning(msg) self.warning = msg end
function meta:SetContext(context) self.context = context end

function meta:GetRole() return self.role end
function meta:GetCodeType() return self.codeType end
function meta:GetJumpSymbols() return self.jumpSymbols end
function meta:GetLocals() return self.locals end
function meta:GetInforms() return self.informs end
function meta:GetDescription() return self.desc end
function meta:GetGraphThunk() return self.graphThunk end
function meta:GetNodeClass() return self.nodeClass end
function meta:GetNodeParam(key) return self.nodeParams[key] end
function meta:GetRequiredMeta() return self.requiredMeta end
function meta:GetContext() return self.context end
function meta:GetGroup() return self.group end
function meta:ReturnsValues()

	for k,v in pairs(self.pins) do
		if v:GetDir() == PD_In and v:GetBaseType() ~= PN_Exec then return true end
	end
	return false

end

function meta:GetPins()
	local pins = {}

	if self:GetContext() == NC_Class and self.group then

		local pinTypeOverride = self.group:GetParam("pinTypeOverride")
		local typeName = self.group:GetParam("typeName")
		local groupName = self.group:GetName()

		if pinTypeOverride then
			table.insert(pins, MakePin(
				PD_In,
				bpcommon.Camelize(typeName or groupName),
				pinTypeOverride
			))
		else
			table.insert(pins, MakePin(
				PD_In,
				bpcommon.Camelize(typeName or groupName),
				PN_Ref, PNF_None, groupName
			))
		end

	end

	table.Add(pins, self.pins)

	if self:GetCodeType() == NT_Function then
		table.insert(pins, 1, PIN_OUTPUT_THRU)
		table.insert(pins, 1, PIN_INPUT_EXEC)
	elseif self:GetCodeType() == NT_Event then
		table.insert(pins, 1, PIN_OUTPUT_EXEC)
	elseif self:GetCodeType() == NT_FuncInput then
		table.insert(pins, 1, PIN_OUTPUT_EXEC)
	elseif self:GetCodeType() == NT_FuncOutput then
		table.insert(pins, 1, PIN_INPUT_EXEC)
	end

	--HACK
	local count = 0
	for k,v in pairs(pins) do
		count = count + 1
	end
	if count <= 2 and self:GetCodeType() == NT_Pure then
		self:AddFlag(NTF_Compact)
	end

	return pins
end

function meta:AddFlag(fl) self.flags = bit.bor(self.flags, fl) end
function meta:HasFlag(fl) return bit.band(self.flags, fl) ~= 0 end
function meta:GetFlags() return self.flags end

function meta:RemapPin(pinName)

	local mapTo = self.pinRedirects[pinName] 
	if mapTo then
		print("Remap Pin: " .. pinName .. " -> " .. mapTo)
		return mapTo
	end
	return pinName

end

function meta:GetCategory()

	if self.category then return self.category end
	if self.group == nil then return nil end

	return self.group:GetName()

end

function meta:GetHook()

	if self:HasFlag(NTF_NotHook) then return nil end

	return self.name

end

function meta:GetName()

	if self.group == nil then return self.name end

	local groupName = self.group:GetName()
	if self:GetContext() ~= NC_Class then
		if groupName == "GLOBAL" then return self.name end
	end

	return groupName .. "_" .. self.name

end

function meta:GetDisplayName()

	if self.group == nil then return self.displayName or self.name end

	local groupName = self.group:GetName()
	if self:GetContext() == NC_Class then
		return self.displayName or (groupName .. ":" .. self.name)
	elseif self:GetContext() == NC_Hook then
		return self.name
	end
	
	return self.displayName or (groupName == "GLOBAL" and self.name or groupName .. "." .. self.name)

end

function meta:GetCode() 

	if self.code then return self.code end
	if self.group == nil then return nil end

	local groupName = self.group:GetName()

	if self:GetContext() == NC_Hook then

		local ret, arg, pins = PinRetArg( self, nil, function(s,v,k)
			return s.. " = " .. "arg[" .. (k-1) .. "]"
		end, "\n" )

		return ret

	end

	local ret, arg, pins = PinRetArg( self )
	local call = groupName .. "_." .. self.name

	if self:GetContext() == NC_Lib then 
		call = groupName == "GLOBAL" and self.name or groupName .. "." .. self.name
	end

	return (ret .. (#pins[PD_Out] ~= 0 and " = " or "") .. call .. "(" .. arg .. ")")

end

function meta:WriteToStream(stream)

	assert(stream:IsUsingStringTable())
	stream:WriteBits(self.flags, 16)
	stream:WriteBits(self.role, 8)
	stream:WriteBits(self.codeType, 8)
	stream:WriteStr(self.name)
	stream:WriteStr(self.code)
	stream:WriteStr(self.category)
	stream:WriteStr(self.displayName)
	stream:WriteStr(self.nodeClass)
	stream:WriteStr(self.warning)
	stream:WriteStr(self.desc)
	bpdata.WriteValue(self.nodeParams, stream)
	bpdata.WriteValue(self.requiredMeta, stream)
	bpdata.WriteValue(self.pinRedirects, stream)
	bpdata.WriteValue(self.jumpSymbols, stream)
	bpdata.WriteValue(self.locals, stream)
	bpdata.WriteValue(self.informs, stream)

	stream:WriteBits(#self.pins, 8)
	for i=1, #self.pins do
		self.pins[i]:WriteToStream(stream)
	end

	return self

end

function meta:ReadFromStream(stream)

	assert(stream:IsUsingStringTable())
	self.flags = stream:ReadBits(16)
	self.role = stream:ReadBits(8)
	self.codeType = stream:ReadBits(8)
	self.name = stream:ReadStr()
	self.code = stream:ReadStr()
	self.category = stream:ReadStr()
	self.displayName = stream:ReadStr()
	self.nodeClass = stream:ReadStr()
	self.warning = stream:ReadStr()
	self.desc = stream:ReadStr()
	self.nodeParams = bpdata.ReadValue(stream)
	self.requiredMeta = bpdata.ReadValue(stream)
	self.pinRedirects = bpdata.ReadValue(stream)
	self.jumpSymbols = bpdata.ReadValue(stream)
	self.locals = bpdata.ReadValue(stream)
	self.informs = bpdata.ReadValue(stream)

	local numPins = stream:ReadBits(8)
	for i=1, numPins do
		table.insert(self.pins, bppin.New():ReadFromStream(stream))
	end

	return self

end

function meta:ToString()

	return self:GetName()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end