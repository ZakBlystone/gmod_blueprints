TEST.Name = "Stream"
TEST.Libs = {
	"bpdata",
	"math",
	"string",
}

local function TestRange( t, bytes )

	for i=bpdata["MAX_SIGNED_" .. t] - 100, bpdata["MAX_SIGNED_" .. t] do
		local byte = bpdata.Str2Num( bpdata.Num2Str( i, true, bytes ), true, bytes )
		EXPECT(i, byte)
	end

	for i=bpdata["MIN_SIGNED_" .. t], bpdata["MIN_SIGNED_" .. t] + 100 do
		local byte = bpdata.Str2Num( bpdata.Num2Str( i, true, bytes ), true, bytes )
		EXPECT(i, byte)
	end

	for i=0, 100 do
		local byte = bpdata.Str2Num( bpdata.Num2Str( i, false, bytes ), false, bytes )
		EXPECT(i, byte)
	end

	for i=bpdata["MAX_UNSIGNED_" .. t] - 100, bpdata["MAX_UNSIGNED_" .. t] do
		local byte = bpdata.Str2Num( bpdata.Num2Str( i, false, bytes ), false, bytes )
		EXPECT(i, byte)
	end

end

function DATA_BYTE() TestRange("BYTE", 1) end
function DATA_SHORT() TestRange("SHORT", 2) end
function DATA_LONG() TestRange("LONG", 4) end

function DATA_FLOAT()

	for i=-30000,30000 do
		local f = i / 100
		local f2 = bpdata.Str2Float( bpdata.Float2Str( f ) )
		ASSERT(math.abs(f - f2) < bpdata.FLOAT_ACCURACY)
	end

end

function DATA_BASE64()

	local encodeBytes = ""
	for i=0, 255 do encodeBytes = encodeBytes .. string.char(i) end

	EXPECT(encodeBytes, bpdata.base64_decode( bpdata.base64_encode(encodeBytes) ))

end