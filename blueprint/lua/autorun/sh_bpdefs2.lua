AddCSLuaFile()

include("sh_bptransfer.lua")
include("sh_bpcommon.lua")
include("sh_bpstruct.lua")
include("sh_bpnodetypegroup.lua")

module("bpdefs", package.seeall, bpcommon.rescope(bpschema))

local pinTypeLookup = {}
local pinFlagLookup = {}

for k,v in pairs(bpschema) do
	if k:sub(1,3) == "PN_" then pinTypeLookup[k] = v end
	if k:sub(1,4) == "PNF_" then pinFlagLookup[k] = v end
end

local function EnumerateDefs( base, output, search )

	local files, folders = file.Find(base, search)
	for _, f in pairs(files) do table.insert(output, {base:sub(0,-2) .. f, search}) end
	for _, f in pairs(folders) do EnumerateDefs( base:sub(0,-2) .. f .. "/*", output, search ) end

end

local literalBlocks = {
	["CODE"] = true,
	["DESC"] = true,
	["WARN"] = true,
}

local function FixupSeparator(char, args, startPos, endPos)

	startPos = startPos or 1
	endPos = endPos or #args

	local pattern = "[^" .. char .. "]+"
	local out = {}
	for i=startPos, endPos do
		for a in string.gmatch(args[i], pattern) do
			table.insert(out, a)
		end
	end
	return out, #out ~= #args

end

local function ParsePin(args, literalInline)

	local desc = nil
	if literalInline ~= 0 then 
		desc = args[literalInline]
		while #args >= literalInline do table.remove(args) end
	end

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

	if args[4] then
		for _, fl in pairs(string.Explode("|", args[4])) do
			flags = bit.bor(flags, pinFlagLookup[fl] or 0)
		end
	end

	local pinType = bppintype.New( type, flags, ex )
	local pin = bppin.New( dir, name, pinType, desc )
	return pin

end

local function ParseLine(line, state)

	local closed = false
	local wasLiteralBlock = false
	if line[1] == "{" then 
		state.level = state.level + 1
		if state.literalLine == 1 then state.literalBlock = true end
		return 
	end

	local literalInline = 0
	local args = nil
	if line[1] == "}" then 
		closed = true
		wasLiteralBlock = state.literalBlock
		state.level = state.level - 1 
		state.literalBlock = false 
	else

		state.literalLine = 0
		if not state.literalBlock then
			args = {}
			local i = 1
			for tla in string.gmatch(line, "[^%s]+") do
				table.insert(args, tla)
				if i == 1 and literalBlocks[tla] then state.literalLine = i end
				i = i + 1
			end
		else
			state.literal = state.literal:Trim() .. "\n" .. line
			return
		end

		if state.literalLine ~= 0 then
			state.literalInstigator = args[state.literalLine]
			state.literal = table.concat(args, " ", state.literalLine+1)
			local args2 = {}
			for i=1, state.literalLine do table.insert(args2, args[i]) end
			table.insert(args2, state.literal)
			if state.literal:Trim() == "" then return end
			args = args2
		else
			literalInline = 0
			for i=1, #args do
				if args[i][1] == "#" then 
					literalInline = i
					args[i] = args[i]:sub(2,-1)
				end
			end
			if literalInline ~= 0 then
				local literal = table.concat(args, " ", literalInline)
				args = FixupSeparator(',', args, 1, literalInline-1)
				table.insert(args, literal)
			else
				args = FixupSeparator(',', args)
			end
		end
	end

	if closed and state.literalInstigator and wasLiteralBlock then
		args = {state.literalInstigator, state.literal}
	end

	if args then
		table.insert(state.parsed, {
			level = state.level,
			args = args,
		})
	end

end

local function ParseDefinitionFile( filePath, search )
	
	local state = { level = 0, literalLine = 0, literalInstigator = nil, literal = nil, parsed = {} }
	local str = file.Read( filePath, search )
	if str == nil then error("Failed to read file: " .. tostring(filePath)) end
	
	local lines = string.Explode("\n", str)
	for _, line in pairs(lines) do
		ParseLine(line:Trim(), state)
	end

	for k,v in pairs(state.parsed) do

		--print(string.rep("  ", v.level) .. table.concat(v.args, " ~~ "))

	end

end

function LoadAndParseDefs()

	bpcommon.ProfileStart("parse definitions")

	local foundDefs = {}
	EnumerateDefs( "data/bpdefs/*", foundDefs, "THIRDPARTY" )

	for k,v in pairs(foundDefs) do
		ParseDefinitionFile(v[1], v[2])
	end

	bpcommon.ProfileEnd()

end

if SERVER then
	LoadAndParseDefs()
end