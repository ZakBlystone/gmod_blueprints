TEST.Name = "Weak"
TEST.Libs = {
	"bpcommon",
	"bpnodetype",
	"bpnode",
	"bppintype",
	"bppin",
	"bpschema",
	"bpstream",
	"setmetatable",
	"collectgarbage",
	"print",
	"tostring",
	"rawequal",
	"getmetatable",
	"isbppin",
	"isbpnode",
	"isbpnodetype",
}

local externID0 = "\xA3\x05\x45\x7E\x3A\x67\xAB\xCA\x80\x00\x00\x0D\x16\xCF\x4F\x56"
local externID1 = "\xA3\x05\x45\x7E\xDF\xEC\xE6\x78\x80\x00\x00\x0E\x16\xF6\x15\x7E"
local externID2 = "\xA3\x05\x45\x7E\x04\xBC\x73\x22\x80\x00\x00\x0F\x17\x12\x77\x9A"

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
	stream:Finish()

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
	stream:Finish()

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
	stream:Finish()

	ASSERT(w ~= nil)
	ASSERT(w() == nil)

end

function LINKER_TEST_EXTERN()

	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	local pt = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt2 = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt3 = bppintype.New(bpschema.PN_Ref,nil,"Other")
	local w = bpcommon.Weak(pt3)
	stream:Extern( pt3, externID0 )
	stream:Object( pt )
	stream:Object( pt2 )
	stream:Object( w )
	local data = stream:Finish()

	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	stream:Extern(pt3, externID0)
	local rpt = stream:Object()
	local rpt2 = stream:Object()
	local w = stream:Object()
	stream:Finish()

	ASSERT(w ~= nil)
	ASSERT(rawequal(w(), pt3))

end

function LINKER_TEST_EXTERN_CONNECTIONS()

	-- Setup
	local baseType = bpnodetype.New()
	baseType:SetCodeType( bpschema.NT_Function )
	baseType:SetName("baseType")
	
	local baseType2 = bpnodetype.New()
	baseType2:SetCodeType( bpschema.NT_Function )
	baseType2:SetName("baseType2")

	local nodeA = bpnode.New(baseType) nodeA:PostInit()
	local nodeB = bpnode.New(baseType2) nodeB:PostInit()

	nodeA:FindPin(bpschema.PD_Out, "Thru"):MakeLink(nodeB:FindPin(bpschema.PD_In, "Exec"))

	-- Write
	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	stream:Extern(baseType, externID0)
	stream:Extern(baseType2, externID1)
	stream:Object(nodeA)
	stream:Object(nodeB)
	local data = stream:Finish()

	-- Read
	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	stream:Extern(nil, externID0)
	stream:Extern(nil, externID1)

	local readNodeA = stream:Object()
	local readNodeB = stream:Object()
	stream:Finish()

	ASSERT(isbpnode(readNodeA))
	ASSERT(isbpnode(readNodeB))

	readNodeA:PostInit()
	readNodeB:PostInit()

	ASSERT(isbpnodetype(readNodeA.nodeType()) or readNodeA.nodeType() == nil)
	ASSERT(isbpnodetype(readNodeB.nodeType()) or readNodeB.nodeType() == nil)

	for _, pin in ipairs(readNodeA:GetPins()) do
		ASSERT( isbppin( pin ) )
	end

	for _, pin in ipairs(readNodeB:GetPins()) do
		ASSERT( isbppin( pin ) )
	end

	local pins = readNodeA:FindPin(bpschema.PD_Out, "Thru"):GetConnectedPins()

	local found = false
	for _, pin in ipairs(pins) do
		if pin == readNodeB:FindPin(bpschema.PD_In, "Exec") then found = true end
	end

	ASSERT(found)

end

function LINKER_TEST_DEEP()

	-- First
	--print("****************WRITE TEST")
	local stream = bpstream.New("test", bpstream.MODE_String):Out()
	local pt = bppintype.New(bpschema.PN_Ref,nil,"Entity")
	local pt2 = bppintype.New(bpschema.PN_Exec,nil)
	local pin = bppin.New(bpschema.PD_Out, "TestPin", pt, "A Test Pin")
	local pin2 = bppin.New(bpschema.PD_Out, "TestPin2", pt2, "A Test Pin")
	stream:Object(pin)
	stream:Object(pin2)
	local data = stream:Finish()

	-- Second
	--print("****************READ TEST")
	stream = bpstream.New("test2", bpstream.MODE_String, data):In()
	local readPin = stream:Object()
	local readPin2 = stream:Object()
	stream:Finish()

	--print(readPin:ToString(true, true))
	--print(readPin2:ToString(true, true))

	-- Third
	--print("****************RE-WRITE TEST")
	stream = bpstream.New("test3", bpstream.MODE_String):Out()
	stream:Object(readPin)
	stream:Object(readPin2)
	data = stream:Finish()


	-- Fourth
	--print("****************RE-READ TEST")
	stream = bpstream.New("test4", bpstream.MODE_String, data):In()
	local reReadPin = stream:Object()
	local reReadPin2 = stream:Object()
	stream:Finish()

	--print(readPin:ToString(true, true))
	--print(readPin2:ToString(true, true))

	ASSERT( reReadPin:Equal(readPin) )
	ASSERT( reReadPin2:Equal(readPin2) )


end