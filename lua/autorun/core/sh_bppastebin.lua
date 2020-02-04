AddCSLuaFile()

module("bppastebin", package.seeall, bpcommon.rescope(bpcommon))

function Upload( text, callback )

	http.Post("https://pastebin.com/api/api_post.php",
	{
		["api_dev_key"] = "c72d797ab0aa752778a8dc72a1a125c6",
		["api_paste_code"] = text,
		["api_paste_private"] = "1",
		["api_paste_name"] = "PastedText",
		["api_paste_expire_date"] = "1D",
		["api_option"] = "paste",
	},

	function( result )
		if not result then callback( false, "Unknown error" ) return end
		local _, _, code = result:find("^https://pastebin.com/([%w%d_]+)")
		if code then
			local url = "https://pastebin.com/raw/" .. code
			callback( true, tostring( url ) )
		else
			callback( false, tostring( result ) )
		end
	end, 
	function( err )
		callback( false, tostring( err ) )
	end)

end

function Download( url, callback )

	_, _, url = url:find("^(https://pastebin.com/raw/[%w%d_]+)")

	if not url then callback( false, "Invalid URL" ) return end

	print("Download URL: " .. tostring(url))

	http.Fetch( url,
	function( body, len, headers, code )
		callback( true, tostring( body ) )
	end,
	function( err )
		callback( false, tostring( err ) )
	end
	)

end