AddCSLuaFile()

module("mod_dermalayout", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local MODULE = {}

MODULE.Creatable = true
MODULE.CanBeSubmodule = true
MODULE.Name = LOCTEXT"module_dermalayout_name","Derma Layout"
MODULE.Description = LOCTEXT"module_dermalayout_desc","Custom UI Panel"
MODULE.Icon = "icon16/application_edit.png"
MODULE.EditorClass = "dermalayout"
MODULE.SelfPinSubClass = "Panel"
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

			local mod = "__modules[" .. compiler:GetOuter():GetID(self) .. "]"
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

	for k, child in ipairs(self:Root():GetAllChildren()) do
		stream:Extern( child:GetGetterNodeType(), "\x41\x70\x46\x7E\xDE\x59\x98\x0C\x80\x00\x00\x44\xAB\xF5\x5F\x6E" )
	end

end

function MODULE:GetCreateNodeType() return self.createNodeType end
function MODULE:GetNodeTypes( collection, graph )

	BaseClass.GetNodeTypes( self, collection, graph )

	local types = {}

	collection:Add( types )
	types["__Create"] = self:GetCreateNodeType()

	for k, child in ipairs(self:Root():GetAllChildren()) do
		local getter = child:GetGetterNodeType()
		types["__GetPanel" ..k] = getter
	end

	for k,v in pairs(types) do v.name = k end

end

function MODULE:CanHaveVariables() return true end
function MODULE:CanHaveStructs() return true end
function MODULE:CanHaveEvents() return false end
function MODULE:RequiresNetCode() return false end

function MODULE:Compile(compiler, pass)

	local edit = self:GetConfigEdit()

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MAINPASS then

		compiler.begin("derma")
		compiler.emit("local __panels = {}")
		compiler.emit("local __makePanel = function(id, ...) return vgui.CreateFromTable(__panels[id], ...) end")
		if self:Root() then
			print("Compile root: ", tostring(self:Root()))
			self:Root():Compile(compiler, pass)
		else
			print("No root node")
		end
		compiler.finish()


	elseif pass == CP_MODULECODE then

		compiler.emitContext("derma")


	elseif pass == CP_MODULEMETA then

		return true

	elseif pass == CP_MODULEBPM then

		compiler.emit([[
__bpm.init = function() end
__bpm.postInit = function() end
__bpm.refresh = function() end
__bpm.shutdown = function() end
__bpm.create = function(...) return __makePanel(]] .. compiler:GetID(self:Root()) .. [[, ...) end]])

	end

end

RegisterModuleClass("DermaLayout", MODULE, "MetaType")