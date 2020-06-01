AddCSLuaFile()

module("bpdermanode", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local meta = bpcommon.MetaTable("bpdermanode")

print("DEFINED BPDERMANODE METATABLE: " .. tostring(meta))

meta.DermaBase = ""
meta.CanHaveChildren = false

dermaClasses = bpclassloader.Get("DermaNode", "blueprints/derma/nodetypes/", "BPDermaClassRefresh", meta)

function GetClassLoader() return dermaClasses end

function meta:Init(class, parent, position)

	bpcommon.MakeObservable(self)

	self.layout = nil
	self.parent = Weak()
	self.children = {}
	self.data = {}
	self.class = class
	self:SetName( self.class or "Unnamed" )
	self.preview = nil
	self.compiledID = nil

	if self.class ~= nil then self:SetupClass() end
	if parent then
		parent:AddChild(self, position)
	end

	self.getterNodeType = bpnodetype.New():WithOuter(self)
	self.getterNodeType:SetCodeType(NT_Pure)
	self.getterNodeType.GetDisplayName = function() return "Get " .. self:GetName() end
	self.getterNodeType.GetGraphThunk = function() return self end
	self.getterNodeType.GetRole = function() return ROLE_Client end
	self.getterNodeType.GetCategory = function() return self:GetName() end
	self.getterNodeType.GetRawPins = function()
		return {
			MakePin(PD_In, "Layout", self:GetModule():GetModulePinType()),
			MakePin(PD_Out, "Panel", PN_Ref, PNF_None, self.DermaBase),
		}
	end
	self.getterNodeType.Compile = function(node, compiler, pass)

		if pass == bpcompiler.CP_ALLOCVARS then 

			compiler:CreatePinRouter( node:FindPin(PD_Out, "Panel"), function(pin)
				local layout = compiler:GetPinCode( node:FindPin(PD_In, "Layout") )
				return { var = layout .. ".gpanels[" .. self.compiledID .. "]" }
			end )

			return true

		elseif pass == bpcompiler.CP_MAINPASS then

			compiler:CompileReturnPin( node )
			return true

		end

	end

	return self

end

function meta:Destroy()

	self:Broadcast("destroyed")
	self.getterNodeType:Destroy()

end

function meta:GetGetterNodeType() return self.getterNodeType end
function meta:GetModule() return self:FindOuter(bpmodule_meta) end

function meta:GetEdit() return self.edit end
function meta:SetPreview(preview) self.preview = preview end
function meta:GetPreview() return self.preview end
function meta:SetName(name) 

	local oldname = self.name 
	self.name = bpcommon.Camelize(name) 
	self:Broadcast("nameChanged", oldname, name) 

end
function meta:GetName() return self.name end
function meta:GetCompiledID() return self.compiledID end
function meta:GetParent() return self.parent() end
function meta:SetupDefaultLayout() return self end

function meta:SetLayout(layout)

	self.layout = layout
	if self.layout then 
		self.layout:WithOuter( self:GetOuter() )
		self.layout.node:Set(self)
	end

end

function meta:GetLayout()

	return self.layout

end

function meta:PostLoad()

	for _, child in ipairs(self.children) do
		if child then
			child.parent:Set(self)
		end
	end

	self:SetLayout( self:GetLayout() )
	self:SetupClass()

end

function meta:CustomizeEdit( edit ) 

	local params = edit:Index("params")
	if params == nil then print("No params!") return end
	params:BindRaw("valueChanged", self, function(old, new, k)
		local pnl = self:GetPreview()
		if not IsValid(pnl) then return end
		self:ApplyPanelValue(pnl, k, new, old )
	end)

end

function meta:InitParams( params ) end
function meta:ApplyPanelValue( pnl, k, v, oldValue ) end

function meta:SetupClass()

	if self.class then

		dermaClasses:Install(self.class, self)
		print("Install class: " .. self.class)

		local parms = {}
		self:InitParams( parms )

		self.data.params = self.data.params or {}
		for k, v in pairs(parms) do
			if self.data.params[k] == nil then self.data.params[k] = v end
		end

		self.edit = bpvaluetype.FromValue(self.data, function() return self.data end)
		self.edit:AddCosmeticChild("name",
			bpvaluetype.New("string", 
				function() return self:GetName() end,
				function(x) self:SetName(x) end ),
			1
		)
		self:CustomizeEdit( self.edit )

	end

end

function meta:GetChildIndex( child )

	assert( isbpdermanode(child) )

	for i=#self.children, 1, -1 do
		if self.children[i] == child then
			return i
		end
	end
	return -1

end

function meta:GetChildByCompiledID( id )

	for _, child in ipairs(self.children) do
		if child and child:GetCompiledID() == id then return child end
	end
	return nil

end

function meta:AddChild( child, position )

	assert( isbpdermanode(child) )

	if not position then
		self.children[#self.children+1] = child
	else
		table.insert(self.children, position, child)
	end

	child.parent:Set(self)
	self:Broadcast("childAdded", child, self:GetChildIndex(child) )

end

function meta:RemoveChild( child )

	assert( isbpdermanode(child) )

	for i=#self.children, 1, -1 do
		if self.children[i] == child then
			table.remove(self.children, i)
			child.parent:Reset()
			self:Broadcast("childRemoved", child, i)
		end
	end

end

function meta:GetChildren( out )

	out = out or {}
	for _, child in ipairs(self.children) do
		out[#out+1] = child
	end
	return out

end

function meta:GetAllChildren( out )

	out = out or {}
	for _, child in ipairs(self.children) do
		out[#out+1] = child
		child:GetAllChildren(out)
	end
	return out

end

function meta:Swap( childA, childB )

	assert( isbpdermanode(childA) and isbpdermanode(childB) )

	local idxA = self:GetChildIndex(childA)
	local idxB = self:GetChildIndex(childB)

	assert( idxA ~= -1 and idxB ~= -1 )

	self.children[idxA] = childB
	self.children[idxB] = childA

	self:Broadcast("childrenSwapped", childA, childB, idxA, idxB)

end

function meta:Serialize(stream)

	self.layout = stream:Object(self.layout, self)
	self.children = stream:ObjectArray( self.children, self )
	self.data = stream:Value(self.data)
	self.name = stream:String(self.name)
	self.class = stream:String(self.class)

	return stream

end

function meta:GenerateMemberCode(compiler, name)

	if name == "Init" then

		local id = compiler:GetID(self)

		compiler.emit("self.panels = {} self.ordered = {}")
		if self:GetParent() then
			compiler.emit("self.root = self:GetParent().root")
			compiler.emit("self.root.gpanels[" .. id .. "] = self")
		else
			compiler.emit("self.root = self")
			compiler.emit("self.gpanels = {}")
		end

		for _, child in ipairs(self:GetChildren()) do

			local childID = compiler:GetID(child)
			compiler.emit("self.panels[" .. childID .. "] = __makePanel(" .. childID .. ", self) self.ordered[#self.ordered+1] = " .. childID)

		end

		self:CompileInitializers(compiler)

		if self:GetLayout() then
			local edit = self:GetLayout():GetEdit()
			compiler.emitBlock("self.layout = " .. edit:ToString())
		end

	elseif name == "PerformLayout" then

		compiler.emit( self.DermaBase .. ".PerformLayout(self, ...)" )
		self:GetLayout():CompileLayout(compiler)

	end

end

function meta:CompileInitializers(compiler) end

function meta:CompileMember(compiler, name)

	compiler.emit("function PANEL:" .. name .. "(...)")
	compiler.pushIndent()
	self:GenerateMemberCode(compiler, name)
	compiler.popIndent()
	compiler.emit("end")

end

function meta:Compile(compiler, pass)

	if pass == CP_MAINPASS then

		print("COMPILE NODE: ", tostring(self))

		self.compiledID = compiler:GetID(self)

		for _, child in ipairs(self:GetChildren()) do
			child:Compile(compiler, pass)
		end

		compiler.emit("local PANEL = {Base = \"" .. self.DermaBase .. "\"} __panels[" .. compiler:GetID(self) .. "] = PANEL")
		self:CompileMember(compiler, "Init")

		if self:GetLayout() ~= nil then
			self:CompileMember(compiler, "PerformLayout")
		end

	else

		print("COMPILE NODE PASS: ", tostring(self), pass)

	end

end

function meta:MapToPreview( preview )

	self:SetPreview(preview)

	for k, panel in pairs(preview.panels or {}) do
		local node = self:GetChildByCompiledID(k)
		if node ~= nil then
			node:MapToPreview(panel)
		end
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end