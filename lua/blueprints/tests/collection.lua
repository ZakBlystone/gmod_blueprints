TEST.Name = "Collections"
TEST.Libs = {
	"bpcollection",
	"math",
	"string",
}

function BASIC_TEST()

	local c = bpcollection.New()
	local a = {
		["X"] = 10,
		["Y"] = 30,
		["Z"] = 520,
	}

	local b = {
		["A"] = 50,
		["B"] = 100,
		["C"] = 400,
	}

	c:Add(a)
	c:Add(b)

	EXPECT( c:Find("Z"), 520 )

	local max = 10
	for x, y in c:Items() do
		max = max - 1
		if max <= 0 then break end
	end

end