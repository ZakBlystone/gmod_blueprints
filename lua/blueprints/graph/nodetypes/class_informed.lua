AddCSLuaFile()

module("node_classinformed", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup()

end

function NODE:UpdatePins()

	BaseClass.UpdatePins(self)

	local targetPin = self:FindPin( PD_Out, self:GetInformedOutput() )
	if targetPin then

		local type = targetPin:GetType()
		local p = type.GetSubType
		type.GetSubType = function( pt )

			local classPin = self:FindPin( PD_In, "Class" )
			if classPin then

				local conn = classPin:GetConnectedPins()
				if #conn ~= 0 then
					return conn[1]:GetSubType()
				end

				return classPin:GetLiteral()

			end
			return p(pt)

		end

	else

		print("Couldn't find target pin for: " .. self:GetInformedOutput())

	end

end

function NODE:GetOptions(tab)

	BaseClass.GetOptions(self, tab)

end

function NODE:ConnectionAdded(pin)

	print("CONNECTION ADDED TO INFORMED NODE ON PIN: " .. pin:ToString(true))

end

function NODE:OnClassPinChanged(pin)

	print("CLASS CHANGED ON PIN: " .. pin:ToString(true))

end

function NODE:GetInformedOutput()

	return self:GetType():GetNodeParam("target")

end

RegisterNodeClass("ClassInformed", NODE)