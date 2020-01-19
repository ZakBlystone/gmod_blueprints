AddCSLuaFile()

module("bpcompiledmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema))

local meta = bpcommon.MetaTable("bpcompiledmodule")

function meta:Init( mod, code, debugSymbols )

	self.type = mod:GetType()
	self.uniqueID = mod:GetUID()
	self.code = code
	self.debugSymbols = debugSymbols
	self.unit = nil
	return self

end

function meta:GetType()

	return self.type

end

function meta:GetUID()

	return self.uniqueID

end

function meta:GetCode()

	return self.code

end

function meta:IsValid()

	return self.unit ~= nil

end

function meta:Get()

	return self.unit

end

function meta:Load()

	if self.unit then return self end
	local result = CompileString(self.code, "bpmodule[" .. bpcommon.GUIDToString( self:GetUID() ) .. "]")
	if result then self.unit = result() end
	return self

end

function meta:TryLoad()

	local result, err = CompileString(self.code, "bpmodule[" .. bpcommon.GUIDToString( self:GetUID() ) .. "]", false)
	if not result then return false, err end
	self.unit = result()
	return true

end

local imeta = {}

function imeta:__GetModule()

	return self.__module

end

function imeta:__BindGamemodeHooks()

	local meta = getmetatable(self)

	if self.CORE_Init then self:CORE_Init() end
	local bpm = self.__bpm

	for k,v in pairs(bpm.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local function call(...) return self[k](self, ...) end
		local key = "bphook_" .. GUIDToString(self.guid, true)
		--print("BIND KEY: " .. v.hook .. " : " .. key)
		hook.Add(v.hook, key, call)
	end

end

function imeta:__UnbindGamemodeHooks()

	local meta = getmetatable(self)

	if self.shuttingDown then ErrorNoHalt("!!!!!Recursive shutdown!!!!!") return end
	local bpm = self.__bpm

	for k,v in pairs(bpm.events) do
		if not v.hook or type(meta[k]) ~= "function" then continue end
		local key = "bphook_" .. GUIDToString(self.guid, true)
		--print("UNBIND KEY: " .. v.hook .. " : " .. key)
		hook.Remove(v.hook, key, false)
	end

	self.shuttingDown = true
	if self.CORE_Shutdown then self:CORE_Shutdown() end
	self.shuttingDown = false

end

function imeta:__Init( )

	self:netInit()
	self:__BindGamemodeHooks()

end

function imeta:__Shutdown()

	self:netShutdown()
	self:__UnbindGamemodeHooks()

end

function meta:Instantiate( forceGUID )

	local instance = self:Get().new()
	local meta = table.Copy(getmetatable(instance))
	for k,v in pairs(imeta) do meta[k] = v end
	setmetatable(instance, meta)
	instance.__module = self
	if forceGUID then instance.guid = forceGUID end
	return instance

end

function meta:AttachErrorHandler()

	if self.errorHandler ~= nil then
		self:Get().onError = function(msg, mod, graph, node)
			self.errorHandler(self, msg, graph, node)
		end
	end

end

function meta:SetErrorHandler(errorHandler)

	self.errorHandler = errorHandler

	if self:IsValid() then
		self:AttachErrorHandler()
	end

end

function meta:WriteToStream(stream, mode)

	stream:WriteInt( self.type, false )
	stream:WriteStr( self.uniqueID )
	bpdata.WriteValue( self.code, stream )
	return self

end

function meta:ReadFromStream(stream, mode)

	self.type = stream:ReadInt( false )
	self.uniqueID = stream:ReadStr( 16 )
	self.code = bpdata.ReadValue(stream)
	return self

end

function New(...)
	return setmetatable({}, meta):Init(...)
end