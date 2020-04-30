AddCSLuaFile()

module("bpnodetype", package.seeall, bpcommon.rescope(bpschema))

NC_Class = 0
NC_Lib = 1
NC_Hook = 2
NC_Struct = 3

local meta = bpcommon.MetaTable("bpnodetype")

bpcommon.AddFlagAccessors(meta)

meta.__eq = function(a, b)
	if a.codeType ~= b.codeType then return false end
	if a.role ~= b.role then return false end
	if a.flags ~= b.flags then return false end
	if a.code ~= b.code then return false end
	if a.category ~= b.category then return false end

	if a:GetFullName() ~= b:GetFullName() then return false end

	local aPins = a:GetPins()
	local bPins = b:GetPins()
	if #aPins ~= #bPins then return false end
	for k, pin in ipairs(aPins) do
		if not bPins[k] then return false end
		if pin ~= bPins[k] then return false end
	end
	return true
end

local PIN_INPUT_EXEC = MakePin( PD_In, "Exec", PN_Exec )
local PIN_OUTPUT_EXEC = MakePin( PD_Out, "Exec", PN_Exec )
local PIN_OUTPUT_THRU = MakePin( PD_Out, "Thru", PN_Exec )

function meta:Init()

	self.flags = 0
	self.role = ROLE_Shared
	self.codeType = NT_Pure
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
	self.globals = {}
	self.informs = {}
	self.pins = {}
	self.warning = nil
	self.modFilter = nil
	return self

end

function meta:AddPin(pin) self.pins[#self.pins+1] = pin end
function meta:AddRequiredMeta(meta) self.requiredMeta[#self.requiredMeta+1] = meta end
function meta:AddPinRedirect(fromName, toName) self.pinRedirects[fromName] = toName end
function meta:AddJumpSymbol(name) self.jumpSymbols[#self.jumpSymbols+1] = name end
function meta:AddLocal(name) self.locals[#self.locals+1] = name end
function meta:AddGlobal(name) self.globals[#self.globals+1] = name end
function meta:AddInform(pinID) self.informs[#self.informs+1] = pinID end
function meta:SetModFilter(filter) self.modFilter = filter:lower() end
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

function meta:GetModFilter() return self.modFilter end
function meta:GetRole() return self.role end
function meta:GetCodeType() return self.codeType end
function meta:GetJumpSymbols() return self.jumpSymbols end
function meta:GetLocals() return self.locals end
function meta:GetGlobals() return self.globals end
function meta:GetInforms() return self.informs end
function meta:GetDescription() return self.desc end
function meta:GetGraphThunk() return self.graphThunk end
function meta:GetNodeParam(key) return self.nodeParams[key] end
function meta:GetRequiredMeta() return self.requiredMeta end
function meta:GetGroup() return self:FindOuter( bpnodetypegroup_meta ) end
function meta:GetColor() return NodeTypeColors[ self:GetCodeType() ] end
function meta:GetContext()

	if self.context then return self.context end

	local group = self:GetGroup()
	if group then return bpnodetypegroup.NodeContextFromGroupType( group:GetType() ) end

	return nil

end

function meta:GetNodeClass()

	if self.nodeClass ~= nil then return self.nodeClass end
	if (self:GetCodeType() == NT_Function or self:GetCodeType() == NT_Pure) and self.code == nil then
		return "FuncCall"
	end
	if (self:GetCodeType() == NT_Event and self.code == nil) then
		return "EventBind"
	end

end

function meta:ReturnsValues()

	for _, v in ipairs(self.pins) do
		if v:GetDir() == PD_In and v:GetBaseType() ~= PN_Exec then return true end
	end
	return false

end

function meta:ClearPins()

	self.pins = {}

end

function meta:GetRawPins()

	return self.pins

end

function meta:GetPins()
	local pins = {}
	local group = self:GetGroup()

	if self:GetContext() == NC_Class and group then

		local pinTypeOverride = group:GetParam("pinTypeOverride")
		local typeName = group:GetParam("typeName")
		local groupName = group:GetName()

		if not self:HasFlag(NTF_DirectCall) then

			if pinTypeOverride then
				pins[#pins+1] = MakePin(
					PD_In,
					bpcommon.Camelize(typeName or groupName),
					pinTypeOverride
				)
			else
				pins[#pins+1] =  MakePin(
					PD_In,
					bpcommon.Camelize(typeName or groupName),
					PN_Ref, PNF_None, groupName
				)
			end

		end

	end

	table.Add(pins, self:GetRawPins())

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
	if #pins <= 2 and self:GetCodeType() == NT_Pure then
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

	local group = self:GetGroup()

	if self.category then return self.category end
	if group == nil then return nil end

	return group:GetName()

end

function meta:GetHook()

	if self:HasFlag(NTF_NotHook) then return nil end

	return self.name

end

function meta:GetName() return self.name end
function meta:GetFullName()

	local group = self:GetGroup()
	if group == nil then return self.name end

	local groupName = group:GetName()
	if self:GetContext() ~= NC_Class then
		if groupName == "GLOBAL" then return self.name end
	end

	return groupName .. "_" .. self.name

end

function meta:GetDisplayName()

	local group = self:GetGroup()
	if group == nil then return self.displayName or self.name end

	local groupName = group:GetName()
	if self:GetContext() == NC_Class then
		return self.displayName or (groupName .. ":" .. self.name)
	elseif self:GetContext() == NC_Hook then
		return self.name
	end
	
	return self.displayName or (groupName == "GLOBAL" and self.name or groupName .. "." .. self.name)

end

function meta:GetCode() return self.code end

function meta:Serialize(stream)

	self.flags = stream:Bits(self.flags, 16)
	self.role = stream:Bits(self.role, 8)
	self.codeType = stream:Bits(self.codeType, 8)
	self.name = stream:String(self.name)
	self.code = stream:String(self.code)
	self.category = stream:String(self.category)
	self.displayName = stream:String(self.displayName)
	self.nodeClass = stream:String(self.nodeClass)
	self.warning = stream:String(self.warning)
	self.desc = stream:String(self.desc)

	self.nodeParams = stream:StringMap(self.nodeParams)
	self.requiredMeta = stream:StringArray(self.requiredMeta)
	self.pinRedirects = stream:StringMap(self.pinRedirects)
	self.jumpSymbols = stream:StringArray(self.jumpSymbols)
	self.locals = stream:StringArray(self.locals)
	self.globals = stream:StringArray(self.globals)
	self.informs = stream:Value(self.informs)
	self.modFilter = stream:String(self.modFilter)

	local numPins = stream:Bits(#self.pins, 8)
	for i=1, numPins do
		self.pins[i] = stream:Object(self.pins[i] or bppin.New(), nil, true)
	end

	return stream

end

function meta:ToString()

	return tostring( self:GetFullName() )

end

function New(...) return bpcommon.MakeInstance(meta, ...) end