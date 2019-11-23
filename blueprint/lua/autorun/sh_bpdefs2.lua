AddCSLuaFile()

include("sh_bptransfer.lua")
include("sh_bpcommon.lua")
include("sh_bpstruct.lua")
include("sh_bpnodetypegroup.lua")
include("sh_bpstruct.lua")

module("bpdefs", package.seeall, bpcommon.rescope(bpschema))

local pinTypeLookup = {}
local pinFlagLookup = {}
local nodeGroups = {}
local structs = {}
local enums = {}

local roleLookup = {
	["SERVER"] = ROLE_Server,
	["CLIENT"] = ROLE_Client,
	["SHARED"] = ROLE_Shared,
}

local nodetypeLookup = {
	["FUNC"] = NT_Function,
	["PURE"] = NT_Pure,
	["SPECIAL"] = NT_Special,
	["EVENT"] = NT_Event,
}

for k,v in pairs(bpschema) do
	if k:sub(1,3) == "PN_" then pinTypeLookup[k] = v end
	if k:sub(1,4) == "PNF_" then pinFlagLookup[k] = v end
end

local function EnumerateDefs( base, output, search )

	local files, folders = file.Find(base, search)
	for _, f in pairs(files) do table.insert(output, {base:sub(0,-2) .. f, search}) end
	for _, f in pairs(folders) do EnumerateDefs( base:sub(0,-2) .. f .. "/*", output, search ) end

end

local literalKeywords = {
	["DISPLAY"] = true,
	["CODE"] = true,
	["DESC"] = true,
	["WARN"] = true,
}

local blockHandlers = {}

local function ParseLine(line, state)

	if line == "" then return end

	local keyword, args, literal = string.match(line, "(%w+) ([^#]*),-%s-#*(.*)")
	keyword = keyword or line

	if literal == "" then literal = nil end	
	if line[1] == "{" then

		if state.openLiteralBlock then
			state.openLiteralBlock = false
			state.literalBlock = true
		else
			table.insert(state.parsed, {
				level = state.level,
				opener = true,
			})
		end
		state.level = state.level + 1
		return

	elseif line[1] == "}" then

		state.level = state.level - 1 
		if state.literalBlock then
			table.insert(state.parsed, {
				level = state.level,
				tuple = {state.literalInstigator, state.literal}
			})
		else
			table.insert(state.parsed, {
				level = state.level,
				closer = true,
			})
		end
		state.openLiteralBlock = false
		state.literalBlock = false
		return

	end

	if state.literalBlock then
		state.literal = state.literal:Trim() .. "\n" .. line
		return
	end

	local tuple = nil
	if literalKeywords[keyword] then

		state.literal = line:sub(keyword:len()+1, -1):Trim()
		state.openLiteralBlock = true
		state.literalInstigator = keyword

		if state.literal == "" then return end
		tuple = {keyword, state.literal}

	else

		if args then
			tuple = string.Explode("%s*,%s*", args, true)
			table.insert(tuple, 1, keyword)
			if tuple[#tuple] == "" then table.remove(tuple) end
		else
			tuple = {keyword}
		end

	end

	table.insert(state.parsed, {
		level = state.level,
		tuple = tuple,
		literal = literal,
	})

end

local function ParseDefinitionFile( filePath, search )
	
	local state = { level = 0, literalLine = 0, literalInstigator = nil, literal = nil, parsed = {} }
	local str = file.Read( filePath, search )
	if str == nil then error("Failed to read file: " .. tostring(filePath)) end
	
	local lines = string.Explode("\n", str)
	for _, line in pairs(lines) do
		ParseLine(line:Trim(), state)
	end

	local function GetBlockHandler(block)
		local handlers = blockHandlers[block.level] or {}
		local handler = handlers[block.tuple[1]]
		return handler
	end

	local blockStack = {}
	for i=1, #state.parsed do

		local block = state.parsed[i]
		local prevBlock = state.parsed[i-1]
		local nextBlock = state.parsed[i+1]
		if block.opener then
			local h = GetBlockHandler(prevBlock)
			if h then h.open(prevBlock, blockStack[#blockStack]) end
			table.insert(blockStack, prevBlock)
		elseif block.closer then
			local top = blockStack[#blockStack]
			local h = GetBlockHandler(top)
			if h then h.close(top, blockStack[#blockStack-1]) end
			table.remove(blockStack)
		elseif block ~= blockStack[#blockStack] and (nextBlock == nil or not nextBlock.opener) then
			local top = blockStack[#blockStack]
			local h = GetBlockHandler(top)
			if h then h.value(top, block) end
		end

	end

end

local function RegisterBlock(keyword, level, open, value, close)

	blockHandlers[level] = blockHandlers[level] or {}
	blockHandlers[level][keyword] = {
		open = open,
		value = value or function() end,
		close = close or function() end,
	}

end

function LoadAndParseDefs()

	local foundDefs = {}
	EnumerateDefs( "data/bpdefs/*", foundDefs, "THIRDPARTY" )

	for k,v in pairs(foundDefs) do
		ParseDefinitionFile(v[1], v[2])
		--break
	end

end

local function ParsePin(t)

	local args = t.tuple
	local desc = t.literal
	local dir = args[1] == "IN" and PD_In or PD_Out
	local name = args[2]
	local type = pinTypeLookup[ args[3] ]
	local flags = 0
	local ex = args[5]
	local default = nil
	if string.find(name, "=") then
		local t = string.Explode("=", name)
		name = t[1]:Trim()
		default = t[2]:Trim()
	end

	if type == nil then error("NO TYPE FOR: " .. tostring(args[3])) end

	if args[4] then
		for _, fl in pairs(string.Explode("|", args[4])) do
			flags = bit.bor(flags, pinFlagLookup[fl] or 0)
		end
	end

	local pinType = bppintype.New( type, flags, ex )
	local pin = bppin.New( dir, name, pinType, desc )
	if default then pin:SetDefault(default) end
	return pin

end

local function ParseNodeValue(nodeType, v)
	local key = v.tuple[1]
	if key == "CLASS" then nodeType:SetNodeClass(v.tuple[2]) end
	if key == "CODE" then nodeType:SetCode(v.literal) end
	if key == "COMPACT" then nodeType:AddFlag(NTF_Compact) end
	if key == "DEPRECATED" then nodeType:AddFlag(NTF_Deprecated) end
	if key == "DESC" then nodeType:SetDescription(v.literal) end
	if key == "DISPLAY" then nodeType:SetDisplayName(v.literal) end
	if key == "INFORM" then for i=2, #v.tuple do nodeType:AddInform(v.tuple[i]) end end
	if key == "JUMP" then nodeType:AddJumpSymbol(v.tuple[2]) end
	if key == "LATENT" then nodeType:AddFlag(NTF_Latent) end
	if key == "LOCAL" then nodeType:AddLocal(v.tuple[2]) end
	if key == "METATABLE" then nodeType:AddRequiredMeta(v.tuple[2]) end
	if key == "NOHOOK" then nodeType:AddFlag(NTF_NotHook) end
	if key == "PARAM" then nodeType:SetNodeParam(v.tuple[2], v.tuple[3]) end
	if key == "PROTECTED" then nodeType:AddFlag(NTF_Protected) end
	if key == "REDIRECTPIN" then nodeType:AddPinRedirect(v.tuple[2], v.tuple[3]) end
	if key == "REQUIREMETA" then nodeType:AddRequiredMeta(v.tuple[2]) end
	if key == "TBD" then nodeType.TBD = true end
	if key == "WARN" then nodeType:SetWarning(v.literal) end
	if key == "IN" or key == "OUT" then nodeType:AddPin( ParsePin(v) ) end
end

RegisterBlock("STRUCT", 0, function(block, parent)

	local name = block.tuple[2]
	local desc = block.literal
	block.struct = bpstruct.New()
	block.struct:SetName(name)
	block.struct.pins:PreserveNames(true)

	table.insert(structs, block.struct)

end,
function(block, value) 
	local key = value.tuple[1]
	if key == "NAME" then block.struct:RemapName(value.tuple[2], value.tuple[3]) end
	if key == "PIN" then
		local pin = ParsePin(value)
		block.struct:NewPin(
			pin:GetName(),
			pin:GetBaseType(),
			pin:GetDefault(),
			pin:GetFlags(),
			pin:GetSubType(),
			pin:GetDescription())
	end
end,
function(block, parent)

	block.struct.pins:PreserveNames(false)

end)

RegisterBlock("ENUM", 0, function(block, parent)

	local name = block.tuple[2]
	block.enum = { name = name, entries = {}, lookup = {} }

	table.insert(enums, block.enum)

end,
function(block, value)

	if value.tuple[1] == "VALUE" then
		table.insert(block.enum.entries, {
			key = value.tuple[2],
			desc = value.literal,
		})
		block.enum.lookup[value.tuple[2]] = #block.enum.entries
	end

end)

RegisterBlock("HOOKS", 0, function(block, parent)

	block.group = bpnodetypegroup.New(bpnodetypegroup.TYPE_HOOKS)
	block.group:SetName( block.tuple[2] )

	table.insert(nodeGroups, block.group)

end)
RegisterBlock("LIB", 0, function(block, parent)

	block.group = bpnodetypegroup.New(bpnodetypegroup.TYPE_LIB)
	block.group:SetName( block.tuple[2] )

	table.insert(nodeGroups, block.group)

end)
RegisterBlock("CLASS", 0, function(block, parent)

	block.group = bpnodetypegroup.New(bpnodetypegroup.TYPE_CLASS)
	block.group:SetName( block.tuple[2] )

	if block.tuple[3] then block.group:SetParam("typeName", block.tuple[2]) end
	if block.tuple[4] then block.group:SetParam("pinTypeOverride", pinTypeLookup[block.tuple[2]]) end

	table.insert(nodeGroups, block.group)

end)

local function RegisterNodeBlock(name, type)

	RegisterBlock(name, 1,
	function(block, parent)
		block.type = bpnodetype.New()
		block.type:SetType(type)
		block.type:SetName(block.tuple[2])
		block.type:SetRole(roleLookup[ block.tuple[3] ])
	end,
	function(block, value) ParseNodeValue(block.type, value) end,
	function(block, parent)
		if not block.type.TBD then
			parent.group:Add(block.type)
		end
	end)

end

RegisterNodeBlock("HOOK", NT_Event)
RegisterNodeBlock("PURE", NT_Pure)
RegisterNodeBlock("FUNC", NT_Func)
RegisterNodeBlock("SPECIAL", NT_Special)

if SERVER and false then
	bpcommon.ProfileStart("parse definitions")
	nodeGroups = {}
	LoadAndParseDefs()

	local stream = bpdata.OutStream(false, true, true)
	stream:UseStringTable()
	stream:WriteInt(#nodeGroups, false)
	stream:WriteInt(#structs, false)
	for i=1, #nodeGroups do nodeGroups[i]:WriteToStream(stream) end
	for i=1, #structs do structs[i]:WriteToStream(stream) end
	bpdata.WriteValue(enums, stream)

	stream:WriteToFile("blueprints/newpack.txt", true, false)
	bpcommon.ProfileEnd()
end