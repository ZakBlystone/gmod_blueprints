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
	self.callbackGraphs = {}
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
	self.getterNodeType.GetCategory = function() return self:GetModule():GetName() end
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
				return { var = layout .. ".gpanels[" .. compiler:GetID(self, true) .. "]" }
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

function meta:GetRoot()

	local p = self:GetParent() or self
	for i=1, 1000 do
		local np = p:GetParent()
		if not np then break else p = np end
	end
	return p

end

function meta:RemoveCallbackGraph(callback)

	for k, v in ipairs(self.callbackGraphs) do
		if v:GetName() == callback.func then
			table.remove(self.callbackGraphs, k)
			self:Broadcast("callbacksChanged")
			return true
		end
	end
	return false

end

function meta:AddCallbackGraph(callback)

	local existing = self:GetCallbackGraph(callback)
	if existing then return existing end

	local graph = bpgraph.New(GT_Function):WithOuter(self)
	graph:SetName(callback.func)
	graph:SetFlag(bpgraph.FL_SERIALIZE_NAME)

	for _, pin in ipairs(callback.params) do
		if pin:IsIn() then graph.inputs:Add( pin ) end
		if pin:IsOut() then graph.outputs:Add( pin ) end
	end

	graph:CreateDefaults()
	self.callbackGraphs[#self.callbackGraphs+1] = graph
	self:Broadcast("callbacksChanged")
	return graph

end

function meta:GetCallbackGraph(callback)

	for _, v in ipairs(self.callbackGraphs) do
		if v:GetName() == callback.func then return v end
	end
	return nil

end

function meta:HasCallbackGraph(callback)

	return self:GetCallbackGraph(callback) ~= nil

end

function meta:GetCallbacks(t) end
function meta:SetupDefaultLayout() return self end

function meta:SetLayout(layout)

	local prevClass = nil
	if self.layout then prevClass = self.layout.class end

	self.layout = layout
	if self.layout then 
		self.layout:WithOuter( self:GetOuter() )
		self.layout.node:Set(self)

		if self.layout.class ~= prevClass then
			for _, child in ipairs(self.children) do
				child:SetupSlot()
			end
		end
	end

end

function meta:SetupSlot()

	if self:GetParent() == nil then return end
	local layout = self:GetParent():GetLayout()

	if layout then

		if layout:RequiresSlot() then
			local slot = self.data.slot
			if slot and slot.__layoutClass == layout.class then return end

			self.data.slot = { __layoutClass = layout.class }
			print("INIT SLOT: " .. layout.class)
			layout:InitSlotParams( self.data.slot )
			PrintTable(self.data.slot)
		end

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
	self:SetupSlot()
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

	local slot = edit:Index("slot", true)
	if slot ~= nil then
		slot:BindRaw("valueChanged", self, function(old, new, k)
			local pnl = self:GetPreview()
			if not IsValid(pnl) then return end
			pnl.slot[k] = new
			if pnl:GetParent() then pnl:GetParent():InvalidateLayout(true) end
		end)

		local cl = slot:Index("__layoutClass", true)
		if cl then cl:AddFlags( bpvaluetype.FL_READONLY + bpvaluetype.FL_DONT_EMIT ) end
	end

end

function meta:InitParams( params ) end
function meta:ApplyPanelValue( pnl, k, v, oldValue ) end

function meta:SetupClass()

	if self.class then

		dermaClasses:Install(self.class, self)
		--print("Install class: " .. self.class)

		local parms = {}
		self:InitParams( parms )

		self.data.params = self.data.params or {}
		for k, v in pairs(parms) do
			if self.data.params[k] == nil then self.data.params[k] = v end
		end

		--PrintTable(self.data)

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
	child:SetupSlot()
	child:SetupClass() -- temporary fix
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

	if stream:GetVersion() >= 6 then 
		self.callbackGraphs = stream:ObjectArray( self.callbackGraphs, self ) 
		if stream:IsReading() then
			for i=#self.callbackGraphs, 1, -1 do
				if self.callbackGraphs[i].name == nil then
					table.remove(self.callbackGraphs, i)
				end
			end
		end
	end

	if stream:IsReading() then
		self:SetupClass()
	end

	return stream

end

function meta:GenerateMemberCode(compiler, name)

	if name == "Init" then

		local id = compiler:GetID(self, true)

		compiler.emit("self.panels = {} self.ordered = {}")
		if self:GetParent() then
			compiler.emit("self.root = self:GetParent().root")
			compiler.emit("self.root.gpanels[" .. id .. "] = self")
		else
			compiler.emit("self.root = self")
			compiler.emit("self.gpanels = {}")
		end

		for _, child in ipairs(self:GetChildren()) do

			local childID = compiler:GetID(child, true)
			compiler.emit("self.panels[" .. childID .. "] = __makePanel(" .. childID .. ", self) self.ordered[#self.ordered+1] = " .. childID)

		end

		self:CompileInitializers(compiler)

		if self:GetLayout() then
			local edit = self:GetLayout():GetEdit()
			compiler.emitBlock("self.layout = " .. edit:ToString())
		end

		local parent = self:GetParent()
		if parent and parent:GetLayout() then
			local parentLayout = parent:GetLayout()
			compiler.emitBlock("self.slot = " .. self:GetEdit():Index("slot"):ToString())
		end

	elseif name == "PerformLayout" then

		compiler.emit( self.DermaBase .. ".PerformLayout(self, ...)" )
		compiler.emit( self:GetLayout():GetFunctionName() .. "(self, ...)" )
		--self:GetLayout():CompileLayout(compiler)

	end

end

function meta:CompileInitializers(compiler) end

function meta:CompileMember(compiler, name)

	compiler.emit("function meta:" .. name .. "(...)")
	compiler.pushIndent()
	self:GenerateMemberCode(compiler, name)
	compiler.popIndent()
	compiler.emit("end")

end

function meta:Compile(compiler, pass)

	local withinProject = compiler:FindOuter(bpcompiler_meta) ~= nil
	if pass == CP_PREPASS then

		self.cgraphs = {}
		if withinProject then
			self.uniqueKeys = {}
			for id, graph in ipairs(self.callbackGraphs) do
				local cgraph = graph:CopyInto( bpgraph.New():WithOuter( self ) )
				cgraph:PreCompile( compiler, self.uniqueKeys )
				self.cgraphs[#self.cgraphs+1] = cgraph
			end
		end

	elseif pass == CP_MAINPASS then

		for _, graph in ipairs(self.cgraphs) do
			graph:Compile( compiler, pass )
		end

		--print("COMPILE NODE: ", tostring(self))

		self.compiledID = compiler:GetID(self, true)

		compiler.begin("dermanode_" .. self.compiledID)

		for id, graph in ipairs(self.cgraphs) do
			compiler.emitContext( CTX_Graph .. compiler:GetID( graph ) )
		end

		compiler.emit("local meta = {Base = \"" .. self.DermaBase .. "\"} __panels[" .. self.compiledID .. "] = meta")
		self:CompileMember(compiler, "Init")

		if self:GetLayout() ~= nil then
			self:CompileMember(compiler, "PerformLayout")
		end

		for id, graph in ipairs(self.cgraphs) do
			compiler.emitContext( CTX_MetaEvents .. compiler:GetID(graph) )
		end

		compiler.finish()

	else

		--print("COMPILE NODE PASS: ", tostring(self), pass)

	end

	for _, child in ipairs(self:GetChildren()) do
		child:Compile(compiler, pass)
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