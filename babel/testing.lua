--@ module = true

--[[
Data definitions:

Testable enum type:
A representation of a enumerable type. It intentionally matches DFHack's
enum types.
  _first_item: A number. The minimum enumerable value.
  _last_item: A number. The maximum enumerable value.
All the numbers between `_first_item` and `_last_item` inclusive are
also valid keys, whose values are the enumerated values.
]]

--[[
Whether tests are enabled. Tests are run at load time.
]]
ENABLED = true

--[[
Whether slow tests are enabled. Slow tests are run at load time.
]]
ENABLED_SLOW = false

--[[
Asserts that two values are equal.

If the values are both tables, it compares the elements of the tables.

Args:
  actual: A value.
  expected: A value.
]]
function assert_eq(actual, expected, _k)
  if type(actual) == 'table' and type(expected) == 'table' then
    for k, v in pairs(expected) do
      assert_eq(actual[k], v, k)
    end
    for k, v in pairs(actual) do
      assert_eq(v, expected[k], k)
    end
  else
    local k = ''
    if _k then
      k = ', index: ' .. tostring(_k)
    end
    assert(expected == actual, 'expected: ' .. tostring(expected) ..
           ', actual: ' .. tostring(actual) .. k)
  end
end

--[[
Returns a value.

This is not a useful function per se. It exists to be a basic testing
function that does not actually do any testing.

Args:
  _: Ignored.
  a1: A value.
  a2: A value or nil. If it is not nil, `a1` is indexable.

Returns:
  If `a2` is nil, `a1`; otherwise, `a1[a2]`.
]]
local function test_off(_, a1, a2)
  return a2 and a1[a2] or a1
end

--[[
A testable enum type representing booleans.
]]
local boolean_type = {
  _first_item=1,
  _last_item=2,
  true,
  false,
}

--[[
Returns the next value for a functional coverage test.

Args:
  history! A sequence of values chosen in previous iterations of the
    functional coverage test.
  a1: A value. If `a2` is not nil, it is a testable enum type.
  a2: A value or nil.

Returns:
  The next value.
]]
local function test_on(history, a1, a2)
  print('test', history.index, history.last_nonfinal)
  for i, t in ipairs(history) do
    if i > history.last_nonfinal then
      dfhack.color(COLOR_CYAN)
    end
    if i == history.index then
      dfhack.color(COLOR_LIGHTGREEN)
    end
    print(i, t.item, t.type[t.item])
    dfhack.color()
  end
  print()
  local current = history[history.index]
  if current == nil then
    local type = a2 and a1 or boolean_type
    history[history.index] = {type=type, item=type._first_item}
    if type._first_item ~= type._last_item then
      history.last_nonfinal = history.index
    end
  elseif history.index == history.last_nonfinal then
    for i = #history, history.index + 1, -1 do
      history[i] = nil
    end
    current.item = current.item + 1
    if current.item == current.type._last_item then
      repeat
        history.last_nonfinal = history.last_nonfinal - 1
      until history.last_nonfinal == 0 or history[history.last_nonfinal].item < history[history.last_nonfinal].type._last_item
    end
  end
  local rv = history[history.index].type[history[history.index].item]
  history.index = history.index + 1
  return rv
end

--[[
A callable to wrap values in that should be tested for functional
coverage. To wrap a boolean or other value used as a condition, e.g.
`x == 1`, wrap the whole value: `coverage_test(x == 1)`. To wrap an
indexing of a enum, e.g. `df.job_skill[x]`, pass the enum and the index
to the wrapper as separate arguments: `coverage_test(df.job_skill, x)`.
]]
coverage_test = setmetatable({index=1, last_nonfinal=0}, {__call=test_off})

--[[
Tests functional coverage of a function.

This function exercises every possible pattern of control flow in `f`.
Everywhere that `f` uses `coverage_test` represents a new decision.
Using the one-argument version of `coverage_test` represents a choice of
`true` or `false`, so on one iteration the test will use `true` and on
another it will use `false`. Similarly, the two-argument version tries
each value of an enum in turn.

This function only tests for crashes. If it crashes, `f` is broken.

Because the test calls `f` once per iteration, `f` should not have any
side effects that could affect later runs of `f`.

Args:
  f: A function that can take no arguments. If the function to test has
    some required arguments, it should be wrapped in a function that
    passes in some values.
]]
function test_coverage(f)
  for i = #coverage_test, 1, -1 do
    coverage_test[i] = nil
  end
  setmetatable(coverage_test, {__call=test_on})
  coverage_test.last_nonfinal = 0
  local iters = 0
  repeat
    dfhack.color(COLOR_LIGHTRED)
    print('Iteration ' .. iters)
    dfhack.color()
    coverage_test.index = 1
    f()
    iters = iters + 1
  until coverage_test.last_nonfinal == 0
  setmetatable(coverage_test, {__call=test_off})
end

if ENABLED then
  local x_type = {
    _first_item=1,
    _last_item=3,
    'a',
    'b',
    'c',
  }
  local c = coverage_test
  local x_output = {}
  local function x()
    local t = {}
    x_output[#x_output + 1] = t
    if c(true) then
      t[#t + 1] = 1
    end
    if c(false) then
      t[#t + 1] = 2
      if c(true) then
        t[#t + 1] = 3
      end
    end
    t[#t + 1] = c(x_type, 2)
  end
  x()
  assert_eq(x_output, {{1, 'b'}})
  x_output = {}
  test_coverage(x)
  assert_eq(x_output, {
    {1, 2, 3, 'a'},
    {1, 2, 3, 'b'},
    {1, 2, 3, 'c'},
    {1, 2, 'a'},
    {1, 2, 'b'},
    {1, 2, 'c'},
    {1, 'a'},
    {1, 'b'},
    {1, 'c'},
    {2, 3, 'a'},
    {2, 3, 'b'},
    {2, 3, 'c'},
    {2, 'a'},
    {2, 'b'},
    {2, 'c'},
    {'a'},
    {'b'},
    {'c'},
  })
end
