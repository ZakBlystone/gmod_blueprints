AddCSLuaFile()

if SERVER then

	local testPath = "autorun/tests/"
	local testSuites = {}

	local function RawFail(suite, msg, func, fl)

		local l = suite._log
		l[#l+1] = {str = msg, func = func, fl = fl or 0}

	end

	local function Fail(suite, msg, fl)

		local inf = debug.getinfo(4)
		local str = msg .. " on line: " .. inf.currentline .. " [" .. inf.source .. "]" .. "\n"
		local l = suite._log
		l[#l+1] = {str = str, func = inf.func, fl = fl or 0}

		print("ERR: [" .. msg .. "]" .. tostring(inf.func))
		PrintTable(inf)

	end

	local function Logs(suite, func)

		local l = suite._log
		local i = 0
		return function()
			i = i + 1
			while l[i] and (func ~= nil and l[i].func ~= func) do i = i + 1 end
			if l[i] and (func == nil or l[i].func == func) then return l[i].str, l[i].fl end
		end

	end

	local function TestAssert(suite, cond)
		if not cond then Fail(suite, "Assert failed") end
	end

	local function TestExpect(suite, value, expect)
		if value ~= expect then Fail(suite, "Expected " .. tostring(expect) .. " got " .. tostring(value)) end
	end

	local function TestExpectType(suite, value, expect)
		if type(value) ~= expect then Fail(suite, "Expected " .. tostring(expect) .. " got " .. tostring(value)) end
	end

	local function LoadTestSuite( file )

		local sm = nil
		local ident = file:sub(1, #file - 4)
		local test = {}
		local funcs = {}
		local m = {
			__newindex = function(s, k, v)
				if type(v) == "function" then
					s._funcs[#s._funcs+1] = {
						Name = k,
						Func = v,
					}
					s._funcs[v] = #s._funcs
				else
					rawset(s,k,v)
				end
			end
		}
		m.__index = {
			ASSERT = function(...) TestAssert(sm, ...) end,
			EXPECT = function(...) TestExpect(sm, ...) end,
			EXPECT_TYPE = function(...) TestExpectType(sm, ...) end,
			TEST = test,
			pairs = pairs,
			ipairs = ipairs,
		}

		local suite = CompileFile(testPath .. file)
		sm = setmetatable({_funcs = funcs, _log = {}}, m)
		setfenv(suite, sm)
		suite()

		for _, lib in ipairs(test.Libs or {}) do
			m.__index[lib] = _G[lib]
		end

		sm.Ident = ident
		sm.Name = test.Name or ident
		sm.After = test.After or {}
		sm.Funcs = funcs
		testSuites[#testSuites+1] = sm

		print("TEST NAME: " .. sm.Name)

		return sm

	end

	local function FindSuiteByName(name)

		for _, suite in ipairs(testSuites) do
			if suite.Ident == name then return suite end
		end

	end

	local function RunTestSuite(suite, ran)

		ran = ran or {}
		if table.HasValue(ran, suite) then return end

		for _, req in ipairs(suite.After) do RunTestSuite(FindSuiteByName(req), ran) end

		ran[#ran+1] = suite

		local count = 0
		local passok = true
		local res = {}

		for _, func in ipairs(suite.Funcs) do
			count = count + 1
			local b,e = xpcall(func.Func, function(x) RawFail(suite, debug.traceback(x), func.Func, 1); return x end)
			local ok = Logs(suite, func.Func)() == nil
			res[func] = ok
			if not ok then passok = false end
		end

		if passok then
			MsgC(Color(120,255,120), "PASSED " .. suite.Name .. ", " .. count .. " tests\n")
		else
			MsgC(Color(255,120,120), "FAILED " .. suite.Name .. ":\n")
		end

		if not passok then

			for _, func in ipairs(suite.Funcs) do
				if res[func] then
					MsgC(Color(120,255,120), " PASSED : " .. func.Name .. "\n")
				else
					MsgC(Color(255,120,120), " FAILED : " .. func.Name .. "\n")
					for msg, fl in Logs(suite, func.Func) do
						MsgC(fl == 1 and Color(255,100,20) or Color(255,100,100), "  " .. msg)
					end
				end
			end

		end

	end

	local files, folders = file.Find(testPath .. "*", "LUA")
	for _, file in ipairs(files) do

		LoadTestSuite(file)

	end

	local function RunAllTests()

		print("Running all tests:")

		local ran = {}
		for _, suite in ipairs(testSuites) do
			RunTestSuite(suite, ran)
		end

	end

	RunAllTests()

end