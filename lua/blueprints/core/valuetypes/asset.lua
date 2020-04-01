AddCSLuaFile()

module("value_asset", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:CheckType( v )

	return type(v) == "string"

end

function VALUE:Setup()

	BaseClass.Setup(self)
	self:AddFlag( bpvaluetype.FL_HINT_BROWSER )

end

function VALUE:SetAssetType( type )

	self.assetType = type

end

function VALUE:SetupPinType( pinType )

	self:SetAssetType( pinType:GetSubType() )

end

function VALUE:BrowserClick( panel, textEntry )

	local priorityFunc = self.GetPriority
	local browser = bpuiassetbrowser.New( self.assetType, function( bSelected, value )
		if bSelected then self:Set( value ) end
	end ):SetCookie("configure")

	if priorityFunc then
		browser.SearchRanker = function( b, node )
			return priorityFunc(self, node.file)
		end
	end

	browser:Open()

end

RegisterValueClass("asset", VALUE, "string")