TEST.Name = "ObjectLinker"
TEST.Libs = {
	"bpstream",
	"bplist",
	"setmetatable",
	"collectgarbage",
	"print",
	"tostring",
	"rawequal",
	"getmetatable",
	"isbplinkertest1",
	"isbplinkertest2",
	"isbplinkertest3",
}

local m1 = bpcommon.MetaTable("bplinkertest1")
local m2 = bpcommon.MetaTable("bplinkertest2")
local m3 = bpcommon.MetaTable("bplinkertest3")

local function ThroughStream( func, debugEnable )

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	stream:GetLinker():DSetDebug(debugEnable)
	func(stream)
	local data = stream:Finish()
	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	stream:GetLinker():DSetDebug(debugEnable)
	func(stream)

end

function m1:Init() self.ident = bpcommon.Weak() self.sub = {} return self end local function NewM1(...) return bpcommon.MakeInstance(m1, ...) end
function m2:Init() return self end local function NewM2(...) return bpcommon.MakeInstance(m2, ...) end
function m3:Init() return self end local function NewM3(...) return bpcommon.MakeInstance(m3, ...) end

function m1:Add( sub )

	self.sub[#self.sub+1] = bpcommon.Weak(sub)

end

function m1:GetName() return self.name end
function m1:Serialize( stream )
	self.ident = stream:Object( self.ident )
	self.name = stream:String(self.name)
	self.sub = stream:ObjectArray( self.sub )
end
function m3:SetString( str ) self.string = str end
function m3:Serialize( stream ) self.string = stream:String( self.string ) end

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
		ASSERT( isbplinkertest2( sub() ) )
		if i == 5 then 
			EXPECT( sub(), A, i )
		else 
			EXPECT( sub(), B, i )
		end
	end

end

function CROSS_LINK()

	local objects = {}
	local A = NewM3()
	local num = 10

	for i=1, num do
		objects[i] = NewM1()
		objects[i].ident = NewM3()
	end

	for i=1, num do
		for j=1, num do
			objects[i]:Add( objects[j] )
		end
	end

	ThroughStream( function(s)
		objects = s:ObjectArray(objects)
	end )

	for i=1, num do
		for j=1, num do
			ASSERT( isbplinkertest1( objects[i].sub[j]() ), " " .. i .. " " .. tostring( objects[i].sub[j]() ) )
			EXPECT( objects[i].sub[j](), objects[j] )
		end
		ASSERT( isbplinkertest3( objects[i].ident ) )
	end

end

function CROSS_SUBLINK()

	local A = NewM1()
	local B = NewM1()

	A.ident = NewM3()
	B.ident = NewM3()

	A:Add(B.ident)
	B:Add(A.ident)

	ThroughStream( function(s)
		A = s:Object(A)
		B = s:Object(B)
	end, false )

	ASSERT( isbplinkertest3( A.ident ) )
	ASSERT( isbplinkertest3( B.ident ) )
	EXPECT(A.sub[1](), B.ident)
	EXPECT(B.sub[1](), A.ident)

end

function LIST_TEST()

	local A = NewM1()
	local B = NewM1()
	local C = NewM1()
	local D = NewM1()
	local list = bplist.New():NamedItems("Item")

	list:Add(A)
	list:Add(B)
	list:Add(C)
	list:Add(D)

	ThroughStream( function(s)
		list:Serialize(s)
		--list = s:Object( list )
	end, false )

	ASSERT( isbplinkertest1( list:Get(1) ) )
	ASSERT( isbplinkertest1( list:Get(2) ) )
	ASSERT( isbplinkertest1( list:Get(3) ) )
	ASSERT( isbplinkertest1( list:Get(4) ) )

	ASSERT( list:Get(1):GetName() == "Item_1" )
	ASSERT( list:Get(2):GetName() == "Item_2" )
	ASSERT( list:Get(3):GetName() == "Item_3" )
	ASSERT( list:Get(4):GetName() == "Item_4" )

end