AddCSLuaFile()

include("sh_bpcommon.lua")

module("bpdefs", package.seeall, bpcommon.rescope(bpschema))

local defs = {}
local enums = {}
local classes = {}
local libs = {}

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

local pinTypeLookup = {}
local pinFlagLookup = {}

for k,v in pairs(bpschema) do
	if k:sub(1,3) == "PN_" then pinTypeLookup[k] = v end
	if k:sub(1,4) == "PNF_" then pinFlagLookup[k] = v end
end

DEFTYPE_ENUM = 0
DEFTYPE_CLASS = 1
DEFTYPE_LIB = 2

local function EnumerateDefs( base, output, search )

	local files, folders = file.Find(base, search)
	for _, f in pairs(files) do table.insert(output, {base:sub(0,-2) .. f, search}) end
	for _, f in pairs(folders) do EnumerateDefs( base:sub(0,-2) .. f .. "/*", output, search ) end

end

function GetEnum( name )

	return enums[name]

end

function GetClass( name )

	return classes[name]

end

function GetClasses()

	return classes

end

function GetLibs()

	return libs

end

local function ParseDef( filePath, search )

	local str = file.Read( filePath, search )
	if str == nil then return end

	local lines = string.Explode("\n", str)
	local d = nil
	local d2 = nil
	local lv = 0
	local def = {}
	for _, l in pairs(lines) do

		local tr = l:Trim()
		local args = string.Explode(",", tr)
		local isClass = tr:sub(0, 5) == "CLASS"
		local isLib = tr:sub(0,3) == "LIB"
		if tr:sub(0, 4) == "ENUM" and lv == 0 then
			d = {
				type = DEFTYPE_ENUM,
				enum = args[1]:sub(6,-1),
				desc = table.concat(args, ",", 2):Trim(),
				entries = {},
				lookup = {},
			}
		elseif (isClass or isLib) and lv == 0 then
			d = {
				type = isClass and DEFTYPE_CLASS or DEFTYPE_LIB,
				name = isClass and args[1]:sub(7,-1) or args[1]:sub(5,-1),
				typeName = args[2] and args[2]:Trim() or nil,
				entries = {},
			}
		elseif tr:sub(0,1) == "{" then
			lv = lv + 1
		elseif tr:sub(0,1) == "}" then
			lv = lv - 1
			if lv == 1 then table.insert(d.entries, d2) d2 = nil end
			if lv == 0 then table.insert(def, d) d = nil end
		elseif lv == 1 and d then
			if d.type == DEFTYPE_ENUM then
				local k = {
					key = args[1]:Trim(),
					desc = table.concat(args, ",", 2):Trim(),
				}
				k.desc = k.desc:len() > 0 and k.desc or nil

				local srch = (k.desc or ""):lower()
				if srch:find("deprecated") ~= nil then k.deprecated = true end
				if srch:find("warning") ~= nil then k.unsafe = true end
				table.insert(d.entries, k)
				d.lookup[k.key] = #d.entries
			elseif d.type == DEFTYPE_CLASS then
				local params = string.Explode(" ", args[1])
				d2 = {
					type = nodetypeLookup[params[1]],
					role = roleLookup[params[2]],
					func = params[3],
					pins = {},
					desc = "",
				}
			elseif d.type == DEFTYPE_LIB then
				local params = string.Explode(" ", args[1])
				d2 = {
					type = nodetypeLookup[params[1]],
					role = roleLookup[params[2]],
					func = params[3],
					pins = {},
					desc = "",
				}
			end
		elseif lv == 2 and d2 then
			if args[1]:sub(1,4) == "DESC" then
				d2.desc = args[1]:sub(6,-1)
			elseif args[1]:sub(1,2) == "IN" or args[1]:sub(1,3) == "OUT" then
				local params = {"type", "flags", "ex"}
				local pin = {
					dir = args[1]:sub(1,2) == "IN" and PD_In or PD_Out,
					name = args[1]:sub(4,-1):Trim(),
				}
				if string.find(pin.name, "=") then
					local t = string.Explode("=", pin.name)
					pin.name = t[1]:Trim()
					pin.default = t[2]:Trim()
				end
				for i=2, #args do
					local c = args[i]:Trim()
					if c:sub(1,1) == "#" then pin.desc = c:sub(2,-1) break else pin[params[i-1]] = c end
				end
				pin.type = pinTypeLookup[pin.type]
				pin.flags = pinFlagLookup[pin.flags] or PNF_None
				table.insert(d2.pins, pin)
			end
		end

	end
	return def

end

local function CreateReducedEnumKeys( enum )

	local blacklist = {
		"LAST",
		"FIRST",
		"ALL",
	}

	local blacklisted = {}

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

function CreateLibNodes( lib, output )

	for k,v in pairs(lib.entries) do

		local ntype = {}
		ntype.pins = {}

		ntype.name = lib.name .. "_" .. v.func
		if lib.type == DEFTYPE_CLASS then
			ntype.displayName = lib.name .. ":" .. v.func
		else
			ntype.displayName = lib.name == "GLOBAL" and v.func or lib.name .. "." .. v.func
			if lib.name == "GLOBAL" then ntype.name = v.func end
		end
		ntype.role = v.role
		ntype.type = v.type
		ntype.desc = v.desc
		ntype.code = ""
		ntype.defaults = {}
		ntype.category = lib.name
		ntype.isClass = lib.type == DEFTYPE_CLASS
		ntype.isLib = lib.type == DEFTYPE_LIB

		if lib.type == DEFTYPE_CLASS then
			table.insert(ntype.pins, {
				PD_In,
				PN_Ref,
				lib.typeName or lib.name,
				PNF_None,
				lib.name,
			})
		end

		for _, pin in pairs(v.pins) do

			table.insert(ntype.pins, {
				pin.dir,
				pin.type,
				pin.name,
				pin.flags,
				pin.ex,
			})

			local base = ntype.type == NT_Function and 1 or 0
			if pin.default then
				ntype.defaults[#ntype.pins + base] = pin.default
				print("DEFAULT[" .. (#ntype.pins + base) .. "]: " .. pin.default)
			end

		end

		local base = ntype.type == NT_Function and 2 or 1
		local pins = {[PD_In] = {}, [PD_Out] = {}}
		for k,v in pairs(ntype.pins) do
			table.insert(pins[v[1]], (v[1] == PD_In and "$" or "#") .. (base+#pins[v[1]]))
		end

		local ret = table.concat(pins[PD_Out], ",")
		local arg = table.concat(pins[PD_In], ",")
		local call = lib.name .. "_." .. v.func

		if lib.type == DEFTYPE_LIB then 
			call = lib.name == "GLOBAL" and v.func or lib.name .. "." .. v.func
		end

		ntype.code = ret .. (#pins[PD_Out] ~= 0 and " = " or "") .. call .. "(" .. arg .. ")"

		ConfigureNodeType(ntype)

		bpnodedef.NodeTypes[ntype.name] = ntype

	end

end

local foundDefs = {}
EnumerateDefs( "data/bpdefs/*", foundDefs, "THIRDPARTY" )
EnumerateDefs( "data/bpdefs/*", foundDefs, "DOWNLOAD" )

for k,v in pairs(foundDefs) do
	if SERVER then resource.AddFile( v[1] ) end
	local parsed = ParseDef(v[1], v[2])
	table.Add(defs, parsed)
end

for k,v in pairs(defs) do
	if v.type == DEFTYPE_ENUM then CreateReducedEnumKeys(v) enums[v.enum] = v end
	if v.type == DEFTYPE_CLASS then classes[v.name] = v print(v.name) end
	if v.type == DEFTYPE_LIB then
		if libs[v.name] then
			table.Add(libs[v.name], v)
		else
			libs[v.name] = v
		end
	end
end

--PrintTable( foundDefs )