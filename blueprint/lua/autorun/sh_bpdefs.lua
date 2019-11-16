AddCSLuaFile()

print("LOADED BPDEFS")

include("sh_bpcommon.lua")
include("sh_bpstruct.lua")

module("bpdefs", package.seeall, bpcommon.rescope(bpschema))

local defs = {}
local enums = {}
local classes = {}
local libs = {}
local callbacks = {}
local structs = {}
local hooksets = {}
local hooks = {}
local ready = true

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
DEFTYPE_STRUCT = 3
DEFTYPE_HOOKS = 4

DEFPACK_LOCATION = "blueprints/bp_definitionpack8.txt"

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

function GetStruct( name )

	return structs[name]

end

function GetClasses()

	return classes

end

function GetLibs()

	return libs

end

function GetStructs()

	return structs

end

function GetHookSets()

	return hooksets

end

function GetHooks()

	return hooks

end

local function ParseDef( filePath, search )

	local str = file.Read( filePath, search )
	if str == nil then return end

	local lines = string.Explode("\n", str)
	local d = nil
	local d2 = nil
	local d3 = nil
	local lv = 0
	local inCodeBlock = false
	local def = {}
	for _, l in pairs(lines) do

		local tr = l:Trim()
		local args = string.Explode(",", tr)
		local isClass = tr:sub(0, 5) == "CLASS"
		local isLib = tr:sub(0,3) == "LIB"
		local isEnum = tr:sub(0,4) == "ENUM"
		local isCallback = tr:sub(0,8) == "CALLBACK"
		local isStruct = tr:sub(0,6) == "STRUCT"
		local isHooks = tr:sub(0,5) == "HOOKS"
		if isStruct and lv == 0 then
			d = {
				type = DEFTYPE_STRUCT,
				name = args[1]:sub(8,-1),
				desc = table.concat(args, ",", 2):Trim(),
				pins = {},
				nameMap = {},
				invNameMap = {},
				pinTypeOverride = args[2] and args[2]:Trim():sub(1,3) == "PN_" and pinTypeLookup[args[2]:Trim()] or nil,
			}
			d2 = d
		elseif isCallback and lv == 0 then
			d = {
				type = DEFTYPE_CALLBACK,
				name = args[1]:sub(10,-1),
				pins = {},
			}
			d2 = d
		elseif isEnum and lv == 0 then
			d = {
				type = DEFTYPE_ENUM,
				enum = args[1]:sub(6,-1),
				desc = table.concat(args, ",", 2):Trim(),
				entries = {},
				lookup = {},
			}
			d.name = d.enum
		elseif (isClass or isLib or isHooks) and lv == 0 then
			d = {
				type = isHooks and DEFTYPE_HOOKS or (isClass and DEFTYPE_CLASS or DEFTYPE_LIB),
				name = isHooks and args[1]:sub(7,-1) or (isClass and args[1]:sub(7,-1) or args[1]:sub(5,-1)),
				typeName = args[2] and args[2]:Trim() or nil,
				pinTypeOverride = args[3] and pinTypeLookup[args[3]:Trim()] or nil,
				entries = {},
			}
		elseif tr:sub(0,1) == "{" then
			lv = lv + 1
		elseif tr:sub(0,1) == "}" then
			lv = lv - 1
			if lv == 1 then if not d2.protected and not d2.tbd then table.insert(d.entries, d2) end d2 = nil end
			if lv == 0 then table.insert(def, d) d = nil end
		elseif lv == 3 and inCodeBlock then
			d2.code = d2.code .. tr .. "\n"
		elseif (lv == 2 and d2) or (lv == 1 and (d.type == DEFTYPE_CALLBACK or d.type == DEFTYPE_STRUCT)) then
			if args[1]:sub(1,4) == "DESC" then
				d2.desc = args[1]:sub(6,-1)
			elseif args[1]:sub(1,4) == "NAME" then
				local a = args[1]:sub(6,-1)
				local b = args[2]:Trim()
				d2.nameMap[a] = b
				d2.invNameMap[b] = a
			elseif args[1]:sub(1,6) == "NOHOOK" then
				d2.nohook = true
			elseif args[1]:sub(1,4) == "CODE" then
				inCodeBlock = true
				d2.code = table.concat(args, ","):sub(6,-1):gsub("\\n", "\n")
			elseif args[1]:sub(1,6) == "LATENT" then
				d2.latent = true
			elseif args[1]:sub(1,7) == "DISPLAY" then
				d2.displayName = args[1]:sub(9,-1):Trim()
			elseif args[1]:sub(1,5) == "CLASS" then
				d2.nodeClass = args[1]:sub(7,-1):Trim()
			elseif args[1]:sub(1,5) == "PARAM" then
				local param = args[1]:sub(7,-1):Trim()
				local value = args[2]:Trim()
				d2.params = d2.params or {}
				d2.params[param] = value
			elseif args[1]:sub(1,11) == "REDIRECTPIN" then
				local pinFrom = args[1]:sub(13,-1):Trim()
				local pinTo = args[2]:Trim()
				d2.pinRedirects = d2.pinRedirects or {}
				d2.pinRedirects[pinFrom] = pinTo
			elseif args[1]:sub(1,4) == "JUMP" then
				d2.jumpSymbols = d2.jumpSymbols or {}
				table.insert(d2.jumpSymbols, table.concat(args, ","):sub(6,-1):Trim())
			elseif args[1]:sub(1,5) == "LOCAL" then
				d2.locals = d2.locals or {}
				table.insert(d2.locals, table.concat(args, ","):sub(6,-1):Trim())
			elseif args[1]:sub(1,4) == "WARN" then
				d2.warn = table.concat(args, ","):sub(6,-1):gsub("\\n", "\n")
			elseif args[1]:sub(1,9) == "PROTECTED" then
				d2.protected = true
			elseif args[1]:sub(1,10) == "DEPRECATED" then
				d2.deprecated = true
			elseif args[1]:sub(1,3) == "TBD" then
				d2.tbd = true
			elseif args[1]:sub(1,7) == "COMPACT" then
				d2.compact = true
				local arg = args[1]:sub(9,-1):Trim():lower()
				if arg == "true" then d2.compact = true end
				if arg == "false" then d2.compact = false end
			elseif args[1]:sub(1,6) == "INFORM" then
				d2.informs = d2.informs or {}
				for x in string.gmatch(tr, "%d+") do table.insert(d2.informs, tonumber(x)) end 
			elseif args[1]:sub(1,9) == "METATABLE" then
				d2.metatable = args[1]:sub(11,-1)
			elseif args[1]:sub(1,2) == "IN" or args[1]:sub(1,3) == "OUT" or args[1]:sub(1,3) == "PIN" then

				if d2.tbd then continue end
				local params = {"type", "flags", "ex"}
				local pin = {}

				if d.type == DEFTYPE_STRUCT then
					pin.name = args[1]:sub(4,-1):Trim()
				else
					pin.dir = args[1]:sub(1,2) == "IN" and PD_In or PD_Out
					pin.name = args[1]:sub(4,-1):Trim()
				end

				if pin.dir == PD_Out and d.type == DEFTYPE_HOOKS then
					d2.returnsValues = true
				end

				if string.find(pin.name, "=") then
					local t = string.Explode("=", pin.name)
					pin.name = t[1]:Trim()
					pin.default = t[2]:Trim()
				end
				for i=2, #args do
					local c = args[i]:Trim()
					if c:sub(1,1) == "#" then pin.desc = c:sub(2,-1) break else pin[params[i-1]] = c end
				end

				if pin.flags ~= nil and string.find(pin.flags, "|") then
					local t = string.Explode("|", pin.flags)
					pin.flags = 0
					for _, fl in pairs(t) do
						pin.flags = bit.bor(pin.flags, pinFlagLookup[fl])
					end
				else
					pin.flags = pinFlagLookup[pin.flags] or PNF_None
				end

				pin.type = pinTypeLookup[pin.type]
				table.insert(d2.pins, pin)
			end
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
			elseif d.type == DEFTYPE_HOOKS then
				local params = string.Explode(" ", args[1])
				d2 = {
					role = roleLookup[params[1]],
					hook = params[2],
					pins = {},
					desc = "",
					returnsValues = false,
				}
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

local function FixupStructNames( struct )

	for k,v in pairs(struct.pins) do

		local nm = struct.nameMap[v.name]
		if nm then v.name = nm end

	end

end

local PinRetArg = bpschema.PinRetArg

function CreateStructNodes( struct, output )

	local obj = bpstruct.New()
	obj.name = struct.name
	obj.pins:PreserveNames( true )
	for k, v in pairs(struct.nameMap) do obj:RemapName(k, v) end
	for _, pin in pairs(struct.pins) do obj:NewPin(pin.name, pin.type, pin.default, pin.flags, pin.ex) end
	obj.pins:PreserveNames( false )
	obj:SetMetaTable(struct.metatable)

	local breaker = obj:BreakerNodeType(struct.pinTypeOverride)
	local maker = obj:MakerNodeType(struct.pinTypeOverride)

	output[maker.name] = maker
	output[breaker.name] = breaker

end

function CreateLibNodes( lib, output )

	for k,v in pairs(lib.entries) do

		local ntype = {}
		ntype.pins = {}

		ntype.name = lib.name .. "_" .. v.func
		if lib.type == DEFTYPE_CLASS then
			ntype.displayName = v.displayName or (lib.name .. ":" .. v.func)
		else
			ntype.displayName = v.displayName or (lib.name == "GLOBAL" and v.func or lib.name .. "." .. v.func)
			if lib.name == "GLOBAL" then ntype.name = v.func end
		end
		ntype.type = v.type
		ntype.desc = v.desc
		ntype.code = ""
		ntype.defaults = {}
		ntype.category = lib.name
		ntype.isClass = lib.type == DEFTYPE_CLASS
		ntype.isLib = lib.type == DEFTYPE_LIB
		ntype.jumpSymbols = v.jumpSymbols
		ntype.deprecated = v.deprecated
		ntype.locals = v.locals
		ntype.nodeClass = v.nodeClass
		ntype.params = v.params
		ntype.pinRedirects = v.pinRedirects
		ntype.meta = {
			informs = v.informs or {},
			compact = v.compact,
			role = v.role,
			latent = v.latent,
		}

		if lib.type == DEFTYPE_CLASS then

			if lib.pinTypeOverride then
				table.insert(ntype.pins, {
					PD_In,
					lib.pinTypeOverride,
					bpcommon.Camelize(lib.typeName or lib.name),
					PNF_None,
					nil,
				})
			else
				table.insert(ntype.pins, {
					PD_In,
					PN_Ref,
					bpcommon.Camelize(lib.typeName or lib.name),
					PNF_None,
					lib.name,
				})
			end

		end

		for _, pin in pairs(v.pins) do

			table.insert(ntype.pins, {
				pin.dir,
				pin.type,
				bpcommon.Camelize(pin.name),
				pin.flags or PNF_None,
				pin.ex,
			})

			if pin.default then
				ntype.defaults[#ntype.pins] = pin.default
				--print("DEFAULT[" .. (#ntype.pins + base) .. "]: " .. pin.default)
			end

		end

		local ret, arg, pins = PinRetArg( ntype )
		local call = lib.name .. "_." .. v.func

		if lib.type == DEFTYPE_LIB then 
			call = lib.name == "GLOBAL" and v.func or lib.name .. "." .. v.func
		end

		if #pins[PD_In] == 1 and ntype.type == NT_Pure and ntype.meta.compact == nil then
			ntype.meta.compact = true
		end

		ntype.code = v.code or (ret .. (#pins[PD_Out] ~= 0 and " = " or "") .. call .. "(" .. arg .. ")")

		ConfigureNodeType(ntype)

		output[ntype.name] = ntype

	end

end

function CreateHooksetNodes( hookset, output )
	--returnsValues

	for k,v in pairs(hookset.entries) do

		local ntype = {}
		ntype.pins = {}
		ntype.name = hookset.name .. "_" .. v.hook
		ntype.displayName = hookset.name .. ":" .. v.hook
		if not v.nohook then ntype.hook = v.hook end
		ntype.isHook = true
		ntype.type = NT_Event
		ntype.desc = v.desc
		ntype.category = hookset.name
		ntype.returns = v.returnsValues
		ntype.pinRedirects = v.pinRedirects
		ntype.meta = {
			role = v.role,
		}

		for _, pin in pairs(v.pins) do

			table.insert(ntype.pins, {
				ntype.returns and pin.dir or PD_Out,
				pin.type,
				bpcommon.Camelize(pin.name),
				pin.flags or PNF_None,
				pin.ex,
			})

		end

		local ret, arg, pins = PinRetArg( ntype, nil, function(s,v,k)
			return s.. " = " .. "arg[" .. (k-1) .. "]"
		end, "\n" )
		ConfigureNodeType(ntype)

		ntype.code = ret

		output[ntype.name] = ntype

	end

end

function Init()

	defs = {}
	enums = {}
	classes = {}
	libs = {}
	callbacks = {}
	structs = {}
	hooksets = {}
	hooks = {}

end

function LoadAndParseDefs()

	Init()
	local foundDefs = {}
	EnumerateDefs( "data/bpdefs/*", foundDefs, "THIRDPARTY" )

	for k,v in pairs(foundDefs) do
		local parsed = ParseDef(v[1], v[2])
		table.Add(defs, parsed)
	end

	for k,v in pairs(defs) do
		if v.type == DEFTYPE_HOOKS then hooksets[v.name] = v end
		if v.type == DEFTYPE_STRUCT then FixupStructNames(v) structs[v.name] = v end
		if v.type == DEFTYPE_CALLBACK then callbacks[v.name] = v end
		if v.type == DEFTYPE_ENUM then CreateReducedEnumKeys(v) enums[v.enum] = v end
		if v.type == DEFTYPE_CLASS then classes[v.name] = v end
		if v.type == DEFTYPE_LIB then
			if libs[v.name] then
				table.Add(libs[v.name], v)
			else
				libs[v.name] = v
			end
		end
	end

	for _,set in pairs(hooksets) do
		for k,v in pairs(set.entries) do
			hooks[set.name .. "_" .. v.hook] = v
		end
	end


	--[[for k,v in pairs(enums) do
		MsgC(Color(100,255,80), k .. "\n")
	end]]

	for k,v in pairs(classes) do
		for _,func in pairs(v.entries) do
			for _,pin in pairs(func.pins) do
				if pin.type == PN_Enum then 
					if enums[pin.ex] == nil then
						print("INVALID ENUM: " .. v.name .. ":" .. func.func .. "." .. pin.name .. "[" .. pin.ex .. "]")
					end
				end
				if pin.type == PN_Struct then
					if structs[pin.ex] == nil then
						print("INVALID STRUCT: " .. v.name .. ":" .. func.func .. "." .. pin.name .. "[" .. pin.ex .. "]")
					end
				end
			end
		end
	end

end

local function WriteTable(name, t, stream)
	local count = 0
	for k,v in pairs(t) do count = count + 1 end
	stream:WriteInt(count, false)
	MsgC(Color(100,255,100), "\n Writing " .. name .. "[" .. count .. "]")
	for k,v in pairs(t) do
		MsgC(Color(255,155,100), "\n  - " .. k)
		bpdata.WriteValue(k, stream, true)
		bpdata.WriteValue(v, stream, true)
	end
end

local function ReadTable(name, t, stream)
	local count = stream:ReadInt(false)
	MsgC(Color(100,255,100), "\n Reading " .. name .. "[" .. count .. "]")
	for i=1, count do
		local k = bpdata.ReadValue(stream, true)
		local v = bpdata.ReadValue(stream, true)
		MsgC(Color(255,155,100), "\n  - " .. k)
		t[k] = v
	end
end

function RebuildDefinitionPack( callback )

	LoadAndParseDefs()

	local start = os.clock()
	local co = coroutine.create( function()
		MsgC(Color(100,255,100), "Writing Blueprint Definitions")
		local stream = bpdata.OutStream(false, true, true)
		WriteTable("Hooks", hooksets, stream)
		WriteTable("Structs", structs, stream)
		WriteTable("Callbacks", callbacks, stream)
		WriteTable("Classes", classes, stream)
		WriteTable("Libraries", libs, stream)
		WriteTable("Enums", enums, stream)
		MsgC(Color(100,255,100), "\n Writing to file")
		stream:WriteToFile(DEFPACK_LOCATION, true, true)
		MsgC(Color(100,255,100), " Done\n")
		if callback then callback() end
	end)

	local iter = 0
	timer.Create("DefWriter", 0, 0, function()
		coroutine.resume(co)
		iter = iter + 1
		if iter % 5 == 0 then MsgC(Color(100,255,100), ".") end
		if coroutine.status(co) == "dead" then
			timer.Remove("DefWriter")
		end
	end)

end

function LoadDefinitionPack()

	ready = false

	local filename = DEFPACK_LOCATION
	local filehandle = nil
	if file.Exists(filename, "DATA") then filehandle = file.Open(filename, "r", "DATA") end
	if file.Exists("data/" .. filename, "THIRDPARTY") then filehandle = file.Open("data/" .. filename, "r", "THIRDPARTY") end
	if file.Exists("data/" .. filename, "DOWNLOAD") then filehandle = file.Open("data/" .. filename, "r", "DOWNLOAD") end

	if filehandle == nil then error("Failed to load definitions, file not found") end

	Init()

	local co = coroutine.create( function()
		local stream = bpdata.InStream(false, true)
		stream:LoadFile(filehandle, true, true)
		MsgC(Color(100,255,100), "Reading Blueprint Definitions")
		ReadTable("Hooks", hooksets, stream)
		ReadTable("Structs", structs, stream)
		ReadTable("Callbacks", callbacks, stream)
		ReadTable("Classes", classes, stream)
		ReadTable("Libraries", libs, stream)
		ReadTable("Enums", enums, stream)
		MsgC(Color(100,255,100), " Done\n")
		ready = true
	end)

	local iter = 0
	timer.Create("DefLoader", 0, 0, function()
		coroutine.resume(co)
		iter = iter + 1
		if iter % 5 == 0 then MsgC(Color(100,255,100), ".") end
		if coroutine.status(co) == "dead" then
			bpnodedef.InstallDefs()
			timer.Remove("DefLoader")
		end
	end)

end

if SERVER then

	if not file.Exists(DEFPACK_LOCATION, "DATA") then
		print("Definition pack missing, generating now...")
		RebuildDefinitionPack( function()
			resource.AddFile(DEFPACK_LOCATION)
			LoadDefinitionPack()
		end )
	else
		resource.AddFile("data/" .. DEFPACK_LOCATION)
	end

	concommand.Add("bp_rebuildDefinitions", function() RebuildDefinitionPack(
		function() timer.Simple(.1, LoadDefinitionPack) end
	) end)

else

	hook.Add("Initialize", "bpdef_init", function()
		LoadDefinitionPack()
	end)

end

if CLIENT then concommand.Add("bp_reloadDefinitions", LoadDefinitionPack ) end

LoadAndParseDefs()
timer.Simple(.1, function() 
	bpnodedef.InstallDefs()
end )


function Ready()
	return ready
end