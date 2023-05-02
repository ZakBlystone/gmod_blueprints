TEST.Name = "Observable"
TEST.Libs = {
	"bpcommon",
	"setmetatable",
	"collectgarbage",
	"print",
}

local function Create()

	local meta = {}
	meta.__index = meta

	function meta:Func()
		print("Hi")
	end

	bpcommon.MakeObservable(meta)

	return setmetatable({}, meta)

end

function SIMPLE_RAW()

	local inst = Create()

	local called = 0
	local function Observer()
		called = called + 1
	end

	-- ensure that basic observer works
	inst:BindRaw("event", "test", Observer)
	inst:Broadcast("event")

	EXPECT(called, 1)

end

function GC_TEST()

	inst = Create()

	local t = {}
	local w = bpcommon.Weak(t)

	-- Ensure that events for GC'd objects are removed
	local called = 0
	inst:BindRaw("event", t, function() called = called + 1 end)

	t = nil
	collectgarbage()

	inst:Broadcast("event")

	EXPECT( w:IsValid(), false )
	EXPECT( called, 0 )


	-- Ensure that events persist over GC
	local target = {}
	inst:BindRaw("event", target, function() called = called + 1 end)

	collectgarbage()

	inst:Broadcast("event")

	target.x = 1
	EXPECT( called, 1 )

end

function GC_TEST2()

	inst = Create()

	local t = {}
	local w = bpcommon.Weak(t)

	-- Ensure that an event's external references are collected
	local called = 0
	inst:BindRaw("event", t, function() called = called + 1 t.x = (t.x or 0) + 1 print("A: " .. t.x) end)
	inst:Broadcast("event")

	t = nil
	collectgarbage()

	t = {}
	inst:BindRaw("event", t, function() called = called + 1 t.x = (t.x or 0) + 1 print("B: " .. t.x) end)
	inst:Broadcast("event")
	EXPECT( called, 2 )

	called = 0

	local winst = bpcommon.Weak(inst)
	inst = nil

	collectgarbage()

	EXPECT( winst:IsValid(), false )

end

function GC_TEST3()

	inst = Create()

	-- Ensure self-referencing callbacks are collected properly
	inst:BindRaw("event", inst, function() inst:Func() end)
	inst:Broadcast("event")

	local winst = bpcommon.Weak(inst)
	inst = nil
	collectgarbage()

	EXPECT( winst:IsValid(), false )

end