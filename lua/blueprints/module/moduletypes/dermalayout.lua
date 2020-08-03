AddCSLuaFile()

module("mod_dermalayout", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.CanBeSubmodule = true
MODULE.Name = LOCTEXT("module_dermalayout_name","Derma Layout")
MODULE.Description = LOCTEXT("module_dermalayout_desc","Custom UI Panel")
MODULE.Icon = "icon16/application_edit.png"
MODULE.EditorClass = "dermalayout"
MODULE.SelfPinSubClass = "DFrame"
MODULE.HasUIDClassname = true

function MODULE:Setup()

	BaseClass.Setup(self)

	self.createNodeType = bpnodetype.New():WithOuter(self)
	self.createNodeType:SetCodeType(NT_Function)
	self.createNodeType.GetDisplayName = function() return "Create " .. self:GetName() end
	self.createNodeType.GetGraphThunk = function() return self end
	self.createNodeType.GetRole = function() return ROLE_Client end
	self.createNodeType.GetCategory = function() return self:GetName() end
	self.createNodeType.GetRawPins = function()
		return {
			MakePin(PD_Out, "Panel", self:GetModulePinType()),
		}
	end
	self.createNodeType.Compile =  function(node, compiler, pass)

		if pass == bpcompiler.CP_ALLOCVARS then 

			compiler:CreatePinVar( node:FindPin(PD_Out, "Panel") )
			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			local mod = "__modules[" .. compiler:GetID(self, true) .. "]"
			local pin = compiler:GetPinCode( node:FindPin(PD_Out, "Panel") )

			compiler.emit( pin .. " = " .. mod .. ".create()")
			compiler.emit( pin .. ":MakePopup()")
			compiler.emit( pin .. ":Center()")
			compiler:CompileReturnPin( node )
			return true

		end

	end

	self.layoutRoot = nil

end

function MODULE:CreateDefaults()

	print("CREATE DEFAULTS")

	self.layoutRoot = bpdermanode.New("Window"):WithOuter(self)
	self.layoutRoot:SetupDefaultLayout()

end

function MODULE:Root()

	return self.layoutRoot

end

function MODULE:SerializeData( stream )

	BaseClass.SerializeData( self, stream )

	stream:Extern( self:GetCreateNodeType(), "\xBF\x9E\x45\x7E\x48\x60\x89\x98\x80\x00\x00\x94\xA3\x3D\xCC\x4E" )

	self.layoutRoot = stream:Object( self.layoutRoot, self )

	if stream:GetVersion() < 7 then
		for k, child in ipairs( self:Root():GetAllChildren() ) do
			stream:Extern( child:GetGetterNodeType(), "\x41\x70\x46\x7E\xDE\x59\x98\x0C\x80\x00\x00\x44\xAB\xF5\x5F\x6E" )
		end
	else
		for k, child in ipairs( self:GetAllPanels() ) do
			stream:Extern( child:GetGetterNodeType(), "\x41\x70\x46\x7E\xDE\x59\x98\x0C\x80\x00\x00\x44\xAB\xF5\x5F\x6E" )
		end
	end

end

function MODULE:GetCreateNodeType() return self.createNodeType end

function MODULE:CanAddNode(nodeType)

	if nodeType:GetRole() == ROLE_Server then return false end
	return BaseClass.CanAddNode( self, nodeType )

end

function MODULE:GetLocalNodeTypes( collection, graph )

	if isbpdermanode(graph:GetOuter()) then
		print("SKIP DERMA NODE")
		return
	end

	BaseClass.GetLocalNodeTypes( self, collection, graph )

end

function MODULE:GetNodeTypes( collection, graph )

	if isbpdermanode(graph:GetOuter()) then
		print("SKIP DERMA NODE")
		return
	end

	BaseClass.GetNodeTypes( self, collection, graph )

	local types = {}

	collection:Add( types )
	types["__Create"] = self:GetCreateNodeType()

	for k, child in ipairs( self:GetAllPanels() ) do
		local getter = child:GetGetterNodeType()
		types["__GetPanel" ..k] = getter
	end

	for k,v in pairs(types) do v.name = k end

end

function MODULE:CanHaveVariables() return true end
function MODULE:CanHaveStructs() return true end
function MODULE:CanHaveEvents() return false end
function MODULE:RequiresNetCode() return false end

function MODULE:GetAllPanels()

	local panels = { self:Root() } self:Root():GetAllChildren( panels )
	return panels

end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()
	local withinProject = compiler:FindOuter(bpcompiler_meta) ~= nil

	if self:Root() then
		self:Root():Compile(compiler, pass)
	else
		print("No root node")
	end

	if pass == CP_PREPASS then

		for k, v in ipairs( self:GetAllPanels() ) do
			local layout = v:GetLayout()
			if layout and not compiler.getContext( layout:GetCodeContext(), true ) then
				compiler.begin( layout:GetCodeContext() )
				compiler.emit(("local %s = function(self, w, h)"):format( layout:GetFunctionName() ))
				compiler.pushIndent()
				compiler.emitBlock( layout.Code )
				compiler.popIndent()
				compiler.emit("end")
				compiler.finish()
			end
		end

	elseif pass == CP_MAINPASS then

		compiler.begin("derma")
		compiler.emit("local __panels = {}")
		compiler.emit("local __makePanel = function(id, ...) return vgui.CreateFromTable(__panels[id], ...) end")

		for k, _ in pairs( compiler.getFilteredContexts("dermalayout") ) do
			compiler.emitContext( k )
		end

		for k, _ in pairs( compiler.getFilteredContexts("dermanode") ) do
			compiler.emitContext( k )
		end

		compiler.finish()

	elseif pass == CP_MODULECODE then

		local bDebug = compiler.debug and 1 or 0
		local bILP = compiler.ilp and 1 or 0
		local args = bDebug .. ", " .. bILP

		compiler.emit("_FR_HEAD(" .. args .. ")")   -- script header

		if not withinProject then
			compiler.emit("_FR_UTILS()") -- utilities
		end

		compiler.emit("_FR_MODHEAD(" .. bpcommon.EscapedGUID(self:GetUID()) .. ")")              -- header for module
		compiler.emitContext("derma")

	elseif pass == CP_MODULEMETA then

		return true

	elseif pass == CP_MODULEBPM then

		local errorHandler = bit.band(compiler.flags, CF_Standalone) ~= 0 and "1" or "0"

		-- infinite-loop-protection checker
		if compiler.ilp then
			compiler.emit("_FR_SUPPORT(1, " .. compiler.ilpmaxh .. ", " .. errorHandler .. ")")
		else
			compiler.emit("_FR_SUPPORT(0, 0, " .. errorHandler .. ")")
		end

		compiler.emit([[
__bpm.init = function() end
__bpm.postInit = function() end
__bpm.refresh = function() end
__bpm.shutdown = function() end
__bpm.create = function(...) return __makePanel(]] .. compiler:GetID(self:Root(), true) .. [[, ...) end]])

	elseif pass == CP_MODULEFOOTER then

		if bit.band(compiler.flags, CF_Standalone) ~= 0 then


		else

			compiler.emit("return __bpm")

		end

	end

end

RegisterModuleClass("DermaLayout", MODULE, "MetaType")