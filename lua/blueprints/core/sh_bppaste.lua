AddCSLuaFile()

module("bppaste", package.seeall, bpcommon.rescope(bpcommon))

if SERVER then return end

local API_URL = "https://us-central1-gmod-blueprints.cloudfunctions.net/api/paste"
local API_KEY = "KJK0r5PoHHnNwIcvgQzZ"

function IsValidKey( key )

	return type(key) == "string" and key:find("^bp%-([%w%d_]+)") ~= nil

end

function Upload( text, callback )

	http.Post(API_URL,
	{
		["key"] = API_KEY,
		["paste"] = text,
		["steamid"] = LocalPlayer():SteamID(),
	},

	function( result )
		if not result then callback( false, "Unknown error" ) return end
		local _, _, code = result:find("^(bp%-[%w%d_]+)")
		if code then
			callback( true, tostring( code ) )
		else
			callback( false, tostring( result ) )
		end
	end,
	function( err )
		callback( false, tostring( err ) )
	end)

end

function Download( key, callback )

	_, _, key = key:find("^bp%-([%w%d_]+)")

	if not key then callback( false, "Key is invalid" ) return end

	local url = ("%s/%s"):format(API_URL, key)

	http.Fetch( url,
	function( body, len, headers, code )
		callback( true, tostring( body ) )
	end,
	function( err )
		callback( false, tostring( err ) )
	end
	)

end

-- Test
--[[Upload( "This is totally blueprint data", function( ok, ures )

	print( "Upload Result: ", tostring(ok), tostring( ures ) )

	if ok then

		Download( ures, function( ok, dres )

			print( "Download Result: ", tostring(ok), tostring(dres) )

		end )

	end


end )]]