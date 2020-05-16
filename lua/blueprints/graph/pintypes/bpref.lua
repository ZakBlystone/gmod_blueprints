AddCSLuaFile()

local PIN = {}

function PIN:GetNetworkThunk()

	return {
		read = "net.",
		write = "net.(@)",
	}

end

function PIN:IsStaticReference()

	local mod = self:GetType():GetSubType()
	return mod and mod.IsStatic and mod:IsStatic()

end

function PIN:AlwaysAutoFill()

	return self:IsStaticReference()

end

function PIN:ShouldBeHidden()

	return self:IsStaticReference()

end

function PIN:GetCode(compiler)

	if #self:GetConnections() > 0 then return end
	local mod = self:GetType():GetSubType()
	if mod and mod:IsStatic() then
		return mod:GetStaticReference(compiler)
	end

end

RegisterPinClass("BPRef", PIN)