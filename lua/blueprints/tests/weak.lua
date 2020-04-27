TEST.Name = "Weak"
TEST.Libs = {
	"bpcommon",
	"bppintype",
	"bpschema",
	"bpstream",
	"setmetatable",
	"collectgarbage",
	"print",
	"tostring",
	"rawequal"
}

function GC_TEST()

	local t = {}
	local w = bpcommon.Weak(t)

	t = nil

	collectgarbage()

	EXPECT(w:IsValid(), false)

end

function LINKER_TEST_PRE()

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	local pt = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt2 = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local w = bpcommon.Weak(pt)
	stream:Object( w )
	stream:Object( pt )
	stream:Object( pt2 )
	local data = stream:Finish()

	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	local w = stream:Object()
	local rpt = stream:Object()
	local rpt2 = stream:Object()

	ASSERT(w ~= nil)
	ASSERT(w() ~= nil)
	ASSERT(w() == rpt)

end

function LINKER_TEST_POST()

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	local pt = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt2 = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local w = bpcommon.Weak(pt)
	stream:Object( pt )
	stream:Object( pt2 )
	stream:Object( w )
	local data = stream:Finish()

	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	local rpt = stream:Object()
	local rpt2 = stream:Object()
	local w = stream:Object()

	ASSERT(w ~= nil)
	ASSERT(w() ~= nil)
	ASSERT(w() == rpt)

end

function LINKER_TEST_NON_RELEVANT()

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	local pt = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt2 = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt3 = bppintype.New(bpschema.PN_Ref,nil,"Other")
	local w = bpcommon.Weak(pt3)
	stream:Object( pt )
	stream:Object( pt2 )
	stream:Object( w )
	local data = stream:Finish()

	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	local rpt = stream:Object()
	local rpt2 = stream:Object()
	local w = stream:Object()

	ASSERT(w ~= nil)
	ASSERT(w() == nil)

end

function LINKER_TEST_EXTERN()

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	local pt = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt2 = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt3 = bppintype.New(bpschema.PN_Ref,nil,"Other")
	local w = bpcommon.Weak(pt3)
	stream:Extern( pt3 )
	stream:Object( pt )
	stream:Object( pt2 )
	stream:Object( w )
	local data = stream:Finish()

	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	stream:Extern(pt3)
	local rpt = stream:Object()
	local rpt2 = stream:Object()
	local w = stream:Object()

	ASSERT(w ~= nil)
	ASSERT(rawequal(w(), pt3))

end