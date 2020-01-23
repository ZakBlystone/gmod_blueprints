TEST.Name = "String Table"
TEST.Libs = {
	"bpstringtable",
	"bpdata",
}
TEST.After = {
	"data"
}

local strings = {
	"String One",
	"String Two",
	[[Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
	Donec facilisis, tortor ac pretium consectetur, nunc sapien euismod ipsum, 
	at iaculis est metus hendrerit mauris. Morbi porttitor dolor velit, 
	a tempor metus pellentesque a. Donec et volutpat sapien. 
	Vivamus sollicitudin risus a orci hendrerit, ut imperdiet lacus faucibus. 
	Aenean sit amet sem quis est viverra blandit non non arcu. 
	Etiam aliquet dui at nisi venenatis, eu convallis lorem blandit. 
	Sed rhoncus, odio quis fringilla rutrum, dolor libero ornare lacus, at condimentum lacus diam quis turpis. 
	Sed pharetra placerat leo, ac dignissim leo fringilla quis. Maecenas eget orci nulla. 
	Praesent et felis ac arcu posuere sagittis nec sit amet sapien. Nulla porta ut odio a rutrum.]]
}

function CONSTRUCT()

	local t = bpstringtable.New()
	EXPECT_TYPE(t, "table")

end

function STRING_ADD()

	local value = strings[1]
	local t = bpstringtable.New()
	local id = t:Add(value)
	EXPECT_TYPE(id, "number")
	EXPECT(t:Get(id), value)

end

function INVALID_STRINGS()

	local t = bpstringtable.New()
	EXPECT( t:Add(), bpstringtable.INVALID_STRING )
	EXPECT( t:Get(bpstringtable.INVALID_STRING), nil )

end

function TRANSMIT()

	ASSERT(strings[3]:len() > 256)

	local from = bpstringtable.New()
	local dest = bpstringtable.New()
	local fromIds = {}
	for _, str in ipairs(strings) do fromIds[#fromIds+1] = from:Add(str) end

	local outs = bpdata.OutStream(false, false, false)
	from:WriteToStream(outs)

	local ins = bpdata.InStream(false, false)
	local str = outs:GetString()
	ins:LoadString(str)
	dest:ReadFromStream(ins)

	for i, id in ipairs(fromIds) do
		EXPECT( dest:Get(id), strings[i] )
	end

end