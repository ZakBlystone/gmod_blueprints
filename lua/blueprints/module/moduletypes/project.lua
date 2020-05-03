AddCSLuaFile()

module("mod_projectmodule", package.seeall, bpcommon.rescope(bpcommon, bpschema, bpcompiler))

local assetMeta = bpcommon.MetaTable("bpprojectasset")
function assetMeta:Init( name, asset )

	self.name = name
	self.asset = asset
	return self

end

function assetMeta:GetName() return self.name end
function assetMeta:GetAsset() return self.asset end
function assetMeta:Serialize( stream )

	self.name = stream:String( self.name )
	self.asset = stream:Object( self.asset, self )
	return stream

end

local MODULE = {}

MODULE.Creatable = true
MODULE.Name = LOCTEXT"module_project_name","Project"
MODULE.Description = LOCTEXT"module_project_desc","Project"
MODULE.Icon = "icon16/wrench.png"
MODULE.EditorClass = "projectmodule"

function MODULE:Setup()

	BaseClass.Setup(self)

	self.assets = {}

end

function MODULE:GetAssets()

	return self.assets

end

function MODULE:UniqueAssetName(name)

	local lut = {}
	for k, v in pairs(self.assets) do lut[v.name] = 1 end

	local newName = name
	local k = 1
	while lut[newName] ~= nil do
		newName = name .. "_" .. k
		k = k + 1
	end

	return newName

end

function MODULE:AddAsset(name, asset)

	name = self:UniqueAssetName( name )
	self.assets[#self.assets+1] = bpcommon.MakeInstance(assetMeta, name, asset)
	self:Broadcast("addedAsset", name, asset)

end

function MODULE:RemoveAsset(asset)

	for k, v in ipairs(self.assets) do
		if v == asset or v:GetAsset() == asset then
			table.remove(self.assets, k)
			self:Broadcast("removedAsset", v)
			return true
		end
	end
	return false

end

function MODULE:FindAssetName(asset)

	for _, v in ipairs(self.assets) do
		if v:GetAsset() == asset then return v:GetName() end
	end
	return nil

end

function MODULE:FindAssetByName(name)

	for _, v in ipairs(self.assets) do
		if v:GetName() == name then return v:GetAsset() end
	end
	return nil

end

function MODULE:GetModuleName(mod)

	local assetName = self:FindAssetName(mod)
	if assetName ~= nil then return assetName end
	return "submodule"

end

function MODULE:EnumerateAllPinTypes( collection )

	for _, asset in ipairs(self:GetAssets()) do
		if isbpmodule(asset:GetAsset()) then
			asset:GetAsset():GetPinTypes( collection )
		end
	end

end

function MODULE:EnumerateAllNodeTypes( collection )

	for _, asset in ipairs(self:GetAssets()) do
		if isbpmodule(asset:GetAsset()) then
			asset:GetAsset():GetNodeTypes( collection )
		end
	end

end

function MODULE:AddModule(mod)

	assert(mod:GetOuter() == nil)

	self:AddAsset( tostring(mod.Name or mod:GetType()), mod:WithOuter(self) )

end

function MODULE:RemoveModule(mod)

	self:RemoveAsset(mod)

end

function MODULE:SerializeData(stream)

	BaseClass.SerializeData( self, stream )

	self.assets = stream:ObjectArray( self.assets, self )

end

function MODULE:CompileAll( pass )

	for k, asset in ipairs(self:GetAssets()) do
		if isbpmodule(asset:GetAsset()) then
			local mod = asset:GetAsset()
			mod:Compile( self.compilers[mod], pass )
		end
	end

end

function MODULE:Compile( compiler, pass )

	print("COMPILE PASS: " .. pass)

	if pass == CP_PREPASS then

		self.compilers = {}

		for k, asset in ipairs(self:GetAssets()) do
			if isbpmodule(asset:GetAsset()) then
				local mod = asset:GetAsset()
				self.compilers[mod] = bpcompiler.New( mod, compiler.flags )
				self.compilers[mod]:Compile( mod )
			end
		end

	elseif pass == CP_MODULECODE then

		compiler.emit("local __modules = {}")

		for k, asset in ipairs(self:GetAssets()) do
			if isbpmodule(asset:GetAsset()) then
				local mod = asset:GetAsset()
				local cmp = self.compilers[mod]
				local ctx = cmp.getContext(CTX_Code)
				compiler.emit("do")
				compiler.emitIndented(ctx, 0)
				compiler.emit("__modules[#__modules+1] = __bpm")
				compiler.emit("end")
			end
		end

	elseif pass == CP_MODULEMETA then
	elseif pass == CP_MODULEBPM then
	elseif pass == CP_MODULEFOOTER then

		compiler.emit("_FR_PROJECTFOOTER()")
		compiler.emit("return __bpm")

	end

end

RegisterModuleClass("ProjectModule", MODULE, "Configurable")