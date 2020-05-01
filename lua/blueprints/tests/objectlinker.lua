TEST.Name = "ObjectLinker"
TEST.Libs = {
	"bpstream",
	"setmetatable",
	"collectgarbage",
	"print",
	"tostring",
	"rawequal",
	"getmetatable",
	"isbplinkertest1",
	"isbplinkertest2",
}

local m1 = bpcommon.MetaTable("bplinkertest1")
local m2 = bpcommon.MetaTable("bplinkertest2")

local function ThroughStream( func )

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	stream:GetLinker():DSetDebug(true)
	func(stream)
	local data = stream:Finish()
	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	stream:GetLinker():DSetDebug(true)
	func(stream)

end

function m1:Init() self.sub = {} return self end local function NewM1(...) return bpcommon.MakeInstance(m1, ...) end
function m2:Init() return self end local function NewM2(...) return bpcommon.MakeInstance(m2, ...) end

function m1:Add( sub )

	self.sub[#self.sub+1] = bpcommon.Weak(sub)

end

function m1:Serialize( stream )

	self.sub = stream:ObjectArray( self.sub )

end

function MAKE_OBJECTS()

	ASSERT( isbplinkertest1( NewM1() ) )
	ASSERT( isbplinkertest2( NewM2() ) )

end

function STREAM_TEST()

	local test = NewM1()
	local prev = test

	ThroughStream( function(s)
		test = s:Object(test)
	end )

	ASSERT( test ~= prev )
	ASSERT( isbplinkertest1( test ) )

end

function EXTERN_SUBOBJECTS()

	local A = NewM2()
	local B = NewM2()

	local test = NewM1()
	for i=1, 10 do
		if i == 5 then test:Add( A ) else test:Add( B ) end
	end

	ThroughStream( function(s)
		test = s:Object(test)
		s:Extern(A)
		s:Extern(B)
	end )

	ASSERT( isbplinkertest1( test ) )

	for i, sub in ipairs( test.sub ) do
		if i == 5 then 
			EXPECT( sub(), A, i ) 
		else 
			EXPECT( sub(), B, i ) 
		end
		print( sub() )
		--ASSERT( isbplinkertest2( sub() ) )
	end

end

function CROSS_LINK()

	local objects = {}

	for i=1, 10 do
		objects[i] = NewM1()
	end

	for i=1, 10 do
		for j=1, 10 do
			objects[i]:Add( objects[j] )
		end
	end

	ThroughStream( function(s)
		objects = s:ObjectArray(objects)
	end )

	for i=1, 10 do
		for j=1, 10 do
			EXPECT( objects[i].sub[j](), objects[j] )
		end
	end

end