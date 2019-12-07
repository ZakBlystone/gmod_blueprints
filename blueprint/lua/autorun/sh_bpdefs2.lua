AddCSLuaFile()

include("sh_bptransfer.lua")
include("sh_bpcommon.lua")
include("sh_bpdefpack.lua")

module("bpdefs", package.seeall, bpcommon.rescope(bpschema))

local ready = false
local pinTypeLookup = {}
local pinFlagLookup = {}
local defpack = bpdefpack.New()

local WITH_DOCUMENTATION = true
local DEFPACK_LOCATION = "blueprints/bp_newdefinitionpack.txt"

function Ready()
	return ready
end

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

local function CreateReducedEnumKeys( enum )

	local blacklist = {
		"LAST",
		"FIRST",
		"ALL",
	}

	local blacklisted = {}
	if #enum.entries == 0 then print("Enum has no entries: " .. enum.name) return end

	local common = enum.entries[1].key
	for k,v in pairs(enum.entries) do
		for _, b in pairs(blacklist) do
			if v.key:sub(0, b:len()) == b then blacklisted[v.key] = true break end
		end
		if blacklisted[v.key] then continue end

		while common:len() > 0 and v.key:sub(0, common:len()) ~= common do
			common = common:sub(0,-2)
		end
	end

	local commonLen = common:len()
	for k,v in pairs(enum.entries) do
		v.shortkey = blacklisted[v.key] and v.key or v.key:sub(commonLen+1, -1)
	end

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
				tuple = {state.literalInstigator, state.literal},
				literal = state.literal,
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

		literal = line:sub(keyword:len()+1, -1):Trim()
		state.literal = literal
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

	defpack = bpdefpack.New()

	local foundDefs = {}
	EnumerateDefs( "data/bpdefs/*", foundDefs, "THIRDPARTY" )

	for k,v in pairs(foundDefs) do
		--if string.find(v[1], "core") or string.find(v[1], "gamemode") then
			ParseDefinitionFile(v[1], v[2])
		--end
	end

end

local function ParsePin(t)

	local args = t.tuple
	local desc = WITH_DOCUMENTATION and t.literal or nil
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
	if key == "COLLAPSE" then nodeType:AddFlag(NTF_Collapse) end
	if key == "COMPACT" then nodeType:AddFlag(NTF_Compact) end
	if key == "DEPRECATED" then nodeType:AddFlag(NTF_Deprecated) end
	if key == "DESC" and WITH_DOCUMENTATION then nodeType:SetDescription(v.literal) end
	if key == "DISPLAY" then nodeType:SetDisplayName(v.literal) end
	if key == "INFORM" then for i=2, #v.tuple do nodeType:AddInform(tonumber(v.tuple[i])) end end
	if key == "JUMP" then nodeType:AddJumpSymbol(v.tuple[2]) end
	if key == "LATENT" then nodeType:AddFlag(NTF_Latent) end
	if key == "LOCAL" then nodeType:AddLocal(v.tuple[2]) end
	if key == "GLOBAL" then nodeType:AddGlobal(v.tuple[2]) end
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
	local pinTypeOverride = pinTypeLookup[ block.tuple[3] ]
	block.struct = bpstruct.New()
	block.struct:SetName(name)
	block.struct:SetPinTypeOverride(pinTypeOverride)
	block.struct.pins:PreserveNames(true)

	defpack:AddStruct(block.struct)

end,
function(block, value) 
	local key = value.tuple[1]
	if key == "NAME" then block.struct:RemapName(value.tuple[2], value.tuple[3]) end
	if key == "METATABLE" then block.struct:SetMetaTable(value.tuple[2]) end
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

	defpack:AddEnum(block.enum)

end,
function(block, value)

	if value.tuple[1] == "VALUE" then
		table.insert(block.enum.entries, {
			key = value.tuple[2],
			desc = WITH_DOCUMENTATION and value.literal or nil,
		})
		block.enum.lookup[value.tuple[2]] = #block.enum.entries
	end

end,
function(block, parent)

	CreateReducedEnumKeys( block.enum )

end)

local topLevelHandlers = function(block, value)
	if value.tuple[1] == "REDIRECTNODE" then
		defpack:AddNodeRedirector( value.tuple[2], value.tuple[3] )
	end
end

RegisterBlock("HOOKS", 0, function(block, parent)

	block.group = bpnodetypegroup.New(bpnodetypegroup.TYPE_Hooks)
	block.group:SetName( block.tuple[2] )

	defpack:AddNodeGroup(block.group)

end, topLevelHandlers)
RegisterBlock("LIB", 0, function(block, parent)

	block.group = bpnodetypegroup.New(bpnodetypegroup.TYPE_Lib)
	block.group:SetName( block.tuple[2] )

	defpack:AddNodeGroup(block.group)

end, topLevelHandlers)
RegisterBlock("CLASS", 0, function(block, parent)

	block.group = bpnodetypegroup.New(bpnodetypegroup.TYPE_Class)
	block.group:SetName( block.tuple[2] )

	if block.tuple[3] then block.group:SetParam("typeName", block.tuple[3]) end
	if block.tuple[4] then block.group:SetParam("pinTypeOverride", pinTypeLookup[block.tuple[4]]) end

	defpack:AddNodeGroup(block.group)

end, topLevelHandlers)

local function RegisterNodeBlock(name, codeType)

	RegisterBlock(name, 1,
	function(block, parent)
		block.type = parent.group:NewEntry()
		block.type:SetCodeType(codeType)
		block.type:SetName(block.tuple[2])
		block.type:SetRole(roleLookup[ block.tuple[3] ])
	end,
	function(block, value) ParseNodeValue(block.type, value) end,
	function(block, parent)
		if block.type.TBD or block.type:HasFlag(NTF_Protected) then --for now, protected nodes don't exist
			parent.group:RemoveEntry(block.type)
		end
	end)

end

RegisterNodeBlock("HOOK", NT_Event)
RegisterNodeBlock("PURE", NT_Pure)
RegisterNodeBlock("FUNC", NT_Function)
RegisterNodeBlock("SPECIAL", NT_Special)

local function LoadDefinitionPack(data)

	if data == nil then print("No pack to load") end
	ready = false

	print("Unpacking definitions")

	local co = coroutine.create( function()
		local stream = bpdata.InStream(false, true)
		stream:UseStringTable()
		stream:LoadString(data, true, false)
		defpack = bpdefpack.New():ReadFromStream(stream)

		defpack:PostInit()
		ready = true
	end)

	local iter = 0
	timer.Create("DefLoader2", 0, 0, function()
		local success, msg = coroutine.resume(co)
		if not success then print("ERROR: " .. tostring(msg)) end
		iter = iter + 1
		if iter % 5 == 0 then MsgC(Color(100,255,100), ".") end
		if coroutine.status(co) == "dead" then
			--bpnodedef.InstallDefs()
			timer.Remove("DefLoader2")
		end
	end)

end

if game.SinglePlayer() then
	LoadAndParseDefs()
	defpack:PostInit()
	ready = true
elseif SERVER then
	bpcommon.ProfileStart("parse definitions")
	LoadAndParseDefs()

	local stream = bpdata.OutStream(false, true, true)
	stream:UseStringTable()
	
	defpack:WriteToStream(stream)

	stream:WriteToFile(DEFPACK_LOCATION, true, false)
	bpcommon.ProfileEnd()

	defpack:PostInit()

	for k,v in pairs(bptransfer.GetStates()) do v:AddFile(DEFPACK_LOCATION, "defs2") end

	hook.Add("BPTransferStateReady", "downloadDefs2", function(ply, state)
		state:AddFile(DEFPACK_LOCATION, "defs2")
	end)
else

	hook.Add("BPTransferRequest", "downloadDefs", function(state, data)
		if data.tag == "defs2" then
			ready = false
		end
	end)
	hook.Add("BPTransferReceived", "downloadDefs", function(state, data)
		if data.tag == "defs2" then
			lastReceivedPack = data.buffer:GetString()
			timer.Simple(.5, function()
				LoadDefinitionPack(lastReceivedPack)
			end)
		end
	end)
end

bptransfer.RegisterTag("defs2", {
	status = "Downloading Blueprint Definitions",
})

function Get()
	return defpack
end