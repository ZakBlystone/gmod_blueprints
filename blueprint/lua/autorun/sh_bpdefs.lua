AddCSLuaFile()

include("sh_bpcommon.lua")

-- since this is included in multiple places, debounce
if _G.LastDefReload ~= nil and (SysTime() - _G.LastDefReload) < 0.2 then
	return
end
_G.LastDefReload = SysTime()

module("bpdefs", package.seeall, bpcommon.rescope(bpschema))

local defs = {}
local enums = {}
local classes = {}
local libs = {}
local callbacks = {}
local structs = {}

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

DEFPACK_LOCATION = "blueprints/bp_definitionpack.txt"

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
		local isEnum = tr:sub(0,4) == "ENUM"
		local isCallback = tr:sub(0,8) == "CALLBACK"
		local isStruct = tr:sub(0,6) == "STRUCT"
		if isStruct and lv == 0 then
			d = {
				type = DEFTYPE_STRUCT,
				name = args[1]:sub(8,-1),
				desc = table.concat(args, ",", 2):Trim(),
				pins = {},
				nameMap = {},
				invNameMap = {},
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
		elseif (lv == 2 and d2) or (lv == 1 and (d.type == DEFTYPE_CALLBACK or d.type == DEFTYPE_STRUCT)) then
			if args[1]:sub(1,4) == "DESC" then
				d2.desc = args[1]:sub(6,-1)
			elseif args[1]:sub(1,4) == "NAME" then
				local a = args[1]:sub(6,-1)
				local b = args[2]:Trim()
				d2.nameMap[a] = b
				d2.invNameMap[b] = a
			elseif args[1]:sub(1,9) == "METATABLE" then
				d2.metatable = args[1]:sub(11,-1)
			elseif args[1]:sub(1,2) == "IN" or args[1]:sub(1,3) == "OUT" or args[1]:sub(1,3) == "PIN" then

				local params = {"type", "flags", "ex"}
				local pin = {}

				if d.type == DEFTYPE_STRUCT then
					pin.name = args[1]:sub(4,-1):Trim()
				else
					pin.dir = args[1]:sub(1,2) == "IN" and PD_In or PD_Out
					pin.name = args[1]:sub(4,-1):Trim()
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

local function PinRetArg( nodeType, infmt, outfmt, concat )

	concat = concat or ","
	--print(nodeType.name)
	local base = nodeType.type == NT_Function and 2 or 1
	local pins = {[PD_In] = {}, [PD_Out] = {}}
	for k,v in pairs(nodeType.pins) do
		local s = (v[1] == PD_In and "$" or "#") .. (base+#pins[v[1]])
		if infmt and v[1] == PD_In then s = infmt(s, v) end
		if outfmt and v[1] == PD_Out then s = outfmt(s, v) end
		table.insert(pins[v[1]], s)
	end

	local ret = table.concat(pins[PD_Out], concat)
	local arg = table.concat(pins[PD_In], concat)
	return ret, arg, pins

end

local function StructBreakNode( struct )

	local ntype = { pins = {} }
	ntype.name = "Break" .. struct.name
	ntype.type = NT_Pure
	ntype.desc = struct.desc
	ntype.code = ""
	ntype.defaults = {}
	ntype.category = struct.name
	ntype.isStruct = true

	table.insert(ntype.pins, {
		PD_In,
		PN_Struct,
		struct.name,
		PNF_None,
		struct.name,
	})

	for _, pin in pairs(struct.pins) do

		table.insert(ntype.pins, {
			PD_Out,
			pin.type,
			pin.name,
			pin.flags,
			pin.ex,
		})

		if pin.default then
			ntype.defaults[#ntype.pins - 1] = pin.default
		end

	end

	local ret, arg = PinRetArg( ntype, nil, function(s,pin)
		return "\n" .. s .. " = $1." .. (struct.invNameMap[pin[3]] or pin[3]) .. ""
	end, "")
	if ret[1] == '\n' then ret = ret:sub(2,-1) end
	ntype.code = ret

	for _, pin in pairs(ntype.pins) do pin[3] = bpcommon.Camelize(pin[3]) end

	ConfigureNodeType(ntype)

	--print(ntype.code)

	return ntype

end

local function StructMakeNode( struct )

	local ntype = { pins = {} }
	ntype.name = "Make" .. struct.name
	ntype.type = NT_Pure
	ntype.desc = struct.desc
	ntype.code = ""
	ntype.defaults = {}
	ntype.category = struct.name
	ntype.isStruct = true

	table.insert(ntype.pins, {
		PD_Out,
		PN_Struct,
		struct.name,
		PNF_None,
		struct.name,
	})

	for _, pin in pairs(struct.pins) do

		table.insert(ntype.pins, {
			PD_In,
			pin.type,
			pin.name,
			pin.flags,
			pin.ex,
		})

		if pin.default then
			ntype.defaults[#ntype.pins - 1] = pin.default
		end

	end

	local ret, arg = PinRetArg( ntype, function(s,pin)
		return "\n " .. (struct.invNameMap[pin[3]] or pin[3]) .. " = " .. s
	end)
	local argt = "{ " .. arg .. "\n}"
	ntype.code = ret .. " = "
	if struct.metatable then ntype.code = ntype.code .. "setmetatable(" end
	ntype.code = ntype.code .. argt
	if struct.metatable then ntype.code = ntype.code .. ", " .. struct.metatable .. "_)" end

	for _, pin in pairs(ntype.pins) do pin[3] = bpcommon.Camelize(pin[3]) end

	ConfigureNodeType(ntype)

	--print(ntype.code)

	return ntype

end

function CreateStructNodes( struct, output )

	local breaker = StructBreakNode( struct )
	local maker = StructMakeNode( struct )

	bpnodedef.NodeTypes[maker.name] = maker
	bpnodedef.NodeTypes[breaker.name] = breaker

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
				bpcommon.Camelize(lib.typeName or lib.name),
				PNF_None,
				lib.name,
			})
		end

		for _, pin in pairs(v.pins) do

			table.insert(ntype.pins, {
				pin.dir,
				pin.type,
				bpcommon.Camelize(pin.name),
				pin.flags,
				pin.ex,
			})

			local base = ntype.type == NT_Function and 1 or 0
			if pin.default then
				ntype.defaults[#ntype.pins + base] = pin.default
				--print("DEFAULT[" .. (#ntype.pins + base) .. "]: " .. pin.default)
			end

		end

		local ret, arg, pins = PinRetArg( ntype )
		local call = lib.name .. "_." .. v.func

		if lib.type == DEFTYPE_LIB then 
			call = lib.name == "GLOBAL" and v.func or lib.name .. "." .. v.func
		end

		ntype.code = ret .. (#pins[PD_Out] ~= 0 and " = " or "") .. call .. "(" .. arg .. ")"

		ConfigureNodeType(ntype)

		bpnodedef.NodeTypes[ntype.name] = ntype

	end

end

function Init()

	defs = {}
	enums = {}
	classes = {}
	libs = {}
	callbacks = {}
	structs = {}

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
		local stream = bpdata.OutStream(false, true)
		WriteTable("Structs", structs, stream)
		WriteTable("Callbacks", callbacks, stream)
		WriteTable("Classes", classes, stream)
		WriteTable("Libraries", libs, stream)
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

	local filename = DEFPACK_LOCATION
	local filehandle = nil
	if file.Exists(filename, "DATA") then filehandle = file.Open(filename, "r", "DATA") end
	if file.Exists(filename, "THIRDPARTY") then filehandle = file.Open(filename, "r", "THIRDPARTY") end
	if file.Exists(filename, "DOWNLOAD") then filehandle = file.Open(filename, "r", "DOWNLOAD") end

	if filehandle == nil then error("Failed to load definitions, file not found") end

	Init()

	local co = coroutine.create( function()
		local stream = bpdata.InStream(false, true)
		stream:LoadFile(filehandle, true, true)
		MsgC(Color(100,255,100), "Reading Blueprint Definitions")
		ReadTable("Structs", structs, stream)
		ReadTable("Callbacks", callbacks, stream)
		ReadTable("Classes", classes, stream)
		ReadTable("Libraries", libs, stream)
		MsgC(Color(100,255,100), " Done\n")
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
		resource.AddFile(DEFPACK_LOCATION)
	end

	concommand.Add("bp_rebuildDefinitions", function() RebuildDefinitionPack(
		function() timer.Simple(.1, LoadDefinitionPack) end
	) end)

else

	hook.Add("Initialize", "bpdef_init", function()
		LoadDefinitionPack()
	end)

end

concommand.Add("bp_reloadDefinitions", LoadDefinitionPack )