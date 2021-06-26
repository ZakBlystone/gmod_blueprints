AddCSLuaFile()

local PIN = {}

function PIN:Setup()

	--BaseClass.Setup(self)

end

function PIN:GetDefault()

	return nil

end

function PIN:CanHaveLiteral()

	return true

end

function PIN:GetLiteralDisplay()

	local literal = self:GetLiteral()
	if type(literal) == "table" then

		return tostring(literal():GetName())

	end

	return bpcommon.ZipStringLeft(tostring(literal), 26)

end

function PIN:OnLiteralChanged( old, new )

	if old then 
		old:Unbind("destroyed", self) 
	end
	if new then
		print("CALLBACK OBJECT: " .. type(new) .. " : " .. tostring(new))
		new:Bind("destroyed", self, self.OnGraphDestroyed)
	end

end

function PIN:GetNetworkThunk()

	return {
		read = "net.",
		write = "net.(@)",
	}

end

function PIN:OnGraphDestroyed()
	self:SetLiteral(nil)
end

function PIN:OnClicked()

	local mod = self:FindOuter(bpmodule_meta)
	local callback = self:GetSubType()

	local entries = {
		"nil",
		"Create",
	}

	if mod ~= nil then

		for _, graph in mod:Graphs() do

			if callback:GraphMatches(graph) then
				entries[#entries+1] = bpcommon.Weak(graph)
			end

		end

	end

	local menu = bpuipickmenu.Create(nil, nil, 300, 200)
	menu:SetCollection( bpcollection.New():Add( entries ) )
	menu.OnEntrySelected = function(pnl, e) 

		if e == "Create" then
			local graph = mod:RequestGraphForCallback( callback )
			self:SetLiteral(bpcommon.Weak(graph))
		elseif e == "nil" then
			self:SetLiteral(nil)
		else
			self:SetLiteral(e)
		end

	end
	menu.GetDisplayName = function(pnl, e) return (type(e) == "table" and e:GetName() or e) end
	menu.GetTooltip = function(pnl, e) return (type(e) == "table" and e:GetName() or e) end
	menu:SetSorter( function(a,b)
		local aname = menu:GetDisplayName(a)
		local bname = menu:GetDisplayName(b)
		return aname:lower() < bname:lower()
	end
	)
	menu:Setup()
	return menu

end

function PIN:GetCode(compiler)

	if self:GetLiteral() ~= nil then

		return "function(...) return __self:" .. self:GetLiteral():GetName() .. "(...) end"

	end

	return "nil"

end

RegisterPinClass("Callback", PIN, "Enum")