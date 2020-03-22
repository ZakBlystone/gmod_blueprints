AddCSLuaFile()

module("node_classinformed", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup()

end

function NODE:GetDesiredType()

	local classPin = self:FindPin( PD_In, "Class" )
	if classPin then

		local conn = classPin:GetConnectedPins()
		if #conn ~= 0 then
			return conn[1]:GetSubType()
		end

		return classPin:GetLiteral()

	end

end

function NODE:UpdatePinType()

	local subType = self:GetDesiredType()
	local targetPin = self:FindPin( PD_Out, self:GetInformedOutput() )
	if targetPin and subType then
		local t = targetPin:GetType()
		local nt = bppintype.New(t:GetBaseType(), t:GetFlags(), subType)
		targetPin:SetType( nt )
	else
		print("Couldn't find target pin for: " .. self:GetInformedOutput())
	end

end

function NODE:UpdatePins()

	BaseClass.UpdatePins(self)

	self:UpdatePinType()

end

function NODE:GetOptions(tab)

	BaseClass.GetOptions(self, tab)

end

function NODE:ConnectionAdded(pin)

	print("CONNECTION ADDED TO INFORMED NODE ON PIN: " .. pin:ToString(true))
	self:UpdatePins()

end

function NODE:OnClassPinChanged(pin)

	print("CLASS CHANGED ON PIN: " .. pin:ToString(true))
	self:UpdatePins()

end

function NODE:GetInformedOutput()

	return self:GetType():GetNodeParam("target")

end

RegisterNodeClass("ClassInformed", NODE)