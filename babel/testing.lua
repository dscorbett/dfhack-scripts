--@ module = true

--[=[
Data definitions:

Testable enum type:
A representation of a enumerable type. It intentionally matches DFHack's
enum types.
  _first_item: A number. The minimum enumerable value.
  _last_item: A number. The maximum enumerable value.
All the numbers between `_first_item` and `_last_item` inclusive are
also valid keys, whose values are the enumerated values.

Choice:
A choice that was made in a previous iteration of a functional coverage
test, corresponding to a call of `coverage_test`.
  type: A testable enum type.
  item: The index in `type` corresponding to the value chosen on the
    previous iteration.
  group_id: A group ID. A group ID is any value that is equal to itself
    by `==` and not equal to anything else.
  dependent_set: A set of group IDs that depend on the value chosen by
    this choice. That is, changing the chosen value might change control
    flow such that the dependent groups never get fully tested. The
    value of a choice will only change on a given iteration if all the
    dependent groups are either done or not started.

Group:
A set of choices that are independent of all other choices, except
possibly because of control flow. For example, if choices with possible
values [1, 2] and [a, b, c] are in the same group and have no control
flow interdependencies, the functional coverage test will try [[1, a],
[1, b], [1, c], [2, a], [2, b], [2, c], [3, a], [3, b], [3, c]]. If the
choices are in different groups, the test will try [[1, a], [2, b], [X,
c]]. (X means an unspecified valid value, in this case 1 or 2. It is
unspecified because that group is done, so the value doesn't matter.)
  done: Whether every possible combination of choices in this group has
    been tested.
  last_nonfinal: The index in a history of the last choice whose `item`
    is not its `type._last_item`.

History:
A sequence of choices. It also has some non-numeric keys.
  index: The index of the current choice to make.
  groups: A map of group IDs to groups.
  not_done: How many groups in `groups` are not done.
]=]

--[[
Whether tests are enabled. Tests are run at load time.
]]
ENABLED = true

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
    if expected ~= actual then
      qerror('expected: ' .. tostring(expected) ..
        ', actual: ' .. tostring(actual) .. k .. '\n' ..
        debug.traceback())
    end
  end
end

--[[
The collection of all test functions declared to be slow.
]]
local SLOW_TESTS = {}

--[[
Declares a function to be a slow test.

Args:
  f: A nullipotent function that takes no arguments.

Returns:
  `f`.
]]
function slow_test(f)
  SLOW_TESTS[#SLOW_TESTS + 1] = f
end

--[[
Runs all slow tests previously declared using `slow_test`.
]]
function run_slow_tests()
  for _, slow_test in ipairs(SLOW_TESTS) do
    local start_time = os.time()
    slow_test()
    local end_time = os.time()
    print('Started test at ' .. os.date('!%Y-%m-%dT%H:%M:%SZ', start_time))
    print('Stopped test at ' .. os.date('!%Y-%m-%dT%H:%M:%SZ', end_time))
    print('Total time: ' .. end_time - start_time)
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
The group ID of the default group.
]]
local DEFAULT_GROUP_ID = {}

--[[
Returns the next value for a functional coverage test.

Args:
  history! The history of this test.
  a1: A value. If `a2` is not nil, it is a testable enum type.
    Otherwise, it is treated as a boolean.
  a2: A value or nil.
  group_id: The group ID of the current choice.
  dependent_group_ids: The set of group IDs of groups dependent on this
    choice, or nil if there are none.

Returns:
  The next value.
]]
local function test_on(history, a1, a2, group_id, dependent_group_ids)
  --[[DEBUG
  dfhack.print(history.index, group_id)
  if dependent_group_ids then
    dfhack.print('\t{')
    for i, dependent_group_id in ipairs(dependent_group_ids) do
      if i ~= 1 then
        dfhack.print(', ')
      end
      dfhack.print(dependent_group_id)
    end
    dfhack.print('}')
  end
  print()
  dfhack.color(COLOR_WHITE)
  print(history.not_done)
  for group_id, group in pairs(history.groups) do
    print(group_id == DEFAULT_GROUP_ID and 'default' or group_id,
      group.last_nonfinal, group.done or '')
  end
  dfhack.color()
  --]]
  if group_id == nil then
    group_id = DEFAULT_GROUP_ID
  end
  local current = history[history.index]
  local current_group = history.groups[group_id]
  --[[DEBUG
  for i, choice in ipairs(history) do
    if (history.groups[choice.group_id] and
        i > history.groups[choice.group_id].last_nonfinal) then
      dfhack.color(COLOR_CYAN)
    end
    if i == history.index then
      dfhack.color(COLOR_LIGHTGREEN)
    end
    dfhack.print(i, choice.item, choice.type[choice.item],
      choice.group_id == DEFAULT_GROUP_ID and '' or choice.group_id)
    if next(choice.dependent_set) then
      dfhack.print('\t{')
      local first = true
      for dependent_group_id in pairs(choice.dependent_set) do
        if first then
          first = false
        else
          dfhack.print(', ')
        end
        dfhack.print(dependent_group_id)
      end
      dfhack.print('}')
    end
    print()
    dfhack.color()
    if choice.item > choice.type._last_item then
      qerror('item too high for type: ' .. choice.type)
    end
  end
  print()
  --]]

  if current == nil or current.group_id ~= group_id then
    -- If this is a new choice, never before seen in this run of the
    -- coverage test, add it to the history.
    local type = a2 and a1 or boolean_type
    current = {
      type=type,
      item=type._first_item,
      group_id=group_id,
      dependent_set={},
    }
    table.insert(history, history.index, current)
    -- Set up this choice's dependents.
    -- Also make sure dependency is transitive.
    if dependent_group_ids then
      for _, choice in ipairs(history) do
        if choice == current or choice.dependent_set[group_id] then
          for _, dependent_group_id in ipairs(dependent_group_ids) do
            choice.dependent_set[dependent_group_id] = true
          end
        end
      end
    end
    -- Fix all `non_final`s invalidated by insert this new choice into
    -- the middle of a history.
    for _, group in pairs(history.groups) do
      if group.last_nonfinal >= history.index then
        group.last_nonfinal = group.last_nonfinal + 1
      end
    end
    -- Set up a new group, if necessary.
    if not current_group then
      history.groups[group_id] = {last_nonfinal=0}
      history.not_done = history.not_done + 1
    end
    -- In the unlikely event this choice's type only has one item,
    -- update the group accordingly.
    if type._first_item ~= type._last_item then
      history.groups[group_id].last_nonfinal = history.index
    end

  elseif history.index == current_group.last_nonfinal then
    -- If the current choice is the last non-final one in its group,
    -- increment it to its next item.
    local all_dependents_done = true
    local current_dependent_set = current.dependent_set
    if current_dependent_set then
      for dependent_group_id in pairs(current_dependent_set) do
        local dependent_group = history.groups[dependent_group_id]
        -- If any of its dependents are not finished, incrementing the
        -- item might bypass them and they might never be finished. In
        -- that case, abort: incrementing the choice will have to wait.
        if dependent_group and not dependent_group.done then
          all_dependents_done = false
          break
        end
      end
    end
    if all_dependents_done then
      -- If all dependents are done, delete their following choices.
      -- Also delete this group's following choices.
      local maximum_history_index = #history
      local total_deleted = 0
      for i = history.index + 1, maximum_history_index do
        local g = history[i].group_id
        if g == group_id or current_dependent_set[g] then
          history[i] = nil
          total_deleted = total_deleted + 1
        elseif total_deleted ~= 0 then
          -- If some choices were deleted, `history` has holes in it.
          -- Compact the sequence and update groups.
          if history.groups[history[i].group_id].last_nonfinal == i then
             history.groups[history[i].group_id].last_nonfinal =
              history.groups[history[i].group_id].last_nonfinal - total_deleted
          end
          history[i - total_deleted] = history[i]
          history[i] = nil
        end
      end
      -- Increment this choice's item.
      current.item = current.item + 1
      if current.item == current.type._last_item then
        -- If incrementing it put it at the final item, find the new
        -- last non-final choice in the group. If they are all final,
        -- set `last_nonfinal` to 0.
        repeat
          current_group.last_nonfinal = current_group.last_nonfinal - 1
        until (current_group.last_nonfinal == 0 or
          history[current_group.last_nonfinal].group_id == group_id and
          history[current_group.last_nonfinal].item <
          history[current_group.last_nonfinal].type._last_item)
      end
    end
  end

  -- Increment the sequence pointer to prepare for the next iteration.
  history.index = history.index + 1
  -- Return the chosen value (finally!).
  return current.type[current.item]
end

local unit_type = {
  _first_item=1,
  _last_item=1,
  '()',
}

--[[
A callable to wrap values in that should be tested for functional
coverage. To wrap a boolean or other value used as a condition, e.g.
`x == 1`, wrap the whole value: `coverage_test(x == 1)`. To wrap an
indexing of a enum, e.g. `df.job_skill[x]`, pass the enum and the index
to the wrapper as separate arguments: `coverage_test(df.job_skill, x)`.
  active: Whether a functional coverage test is on-going.
]]
coverage_test = setmetatable({}, {__call=test_off})

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
  coverage_test.active = true
  coverage_test.groups = {[DEFAULT_GROUP_ID]={last_nonfinal=0, dependent_set={}}}
  coverage_test.not_done = 1
  --[[DEBUG
  local iters = 0
  --]]
  repeat
    --[[DEBUG
    dfhack.color(COLOR_LIGHTRED)
    print(string.rep('=', 79))
    print('Iteration ' .. iters)
    dfhack.color()
    --]]
    coverage_test.index = 1
    f()
    --[[DEBUG
    iters = iters + 1
    --]]
    for _, group in pairs(coverage_test.groups) do
      if group.last_nonfinal == 0 and not group.done then
        group.done = true
        coverage_test.not_done = coverage_test.not_done - 1
      end
    end
  until coverage_test.not_done == 0
  setmetatable(coverage_test, {__call=test_off})
  coverage_test.active = nil
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

  local x1_output = {}
  local function x1()
    local t = {}
    x1_output[#x1_output + 1] = t
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
  x1()
  assert_eq(x1_output, {{1, 'b'}})
  x1_output = {}
  test_coverage(x1)
  assert_eq(x1_output, {
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

  local x2_output = {}
  local function x2()
    local t = {}
    x2_output[#x2_output + 1] = t
    if c(true) then
      t[#t + 1] = 0
    end
    if c(false, nil, nil, {1}) then
      t[#t + 1] = 1
      if c(true) then
        t[#t + 1] = 2
      end
      if c(true, nil, 1) then
        t[#t + 1] = 10
      elseif c(true, nil, 1) then
        t[#t + 1] = 11
      elseif c(true, nil, 1) then
        t[#t + 1] = 12
      elseif c(true, nil, 1) then
        t[#t + 1] = 13
     end
     if c(true, nil, 1) then
       t[#t + 1] = 14
     end
    end
    t[#t + 1] = c(x_type, 2)
  end
  x2()
  assert_eq(x2_output, {{0, 'b'}})
  x2_output = {}
  test_coverage(x2)
  assert_eq(x2_output, {
    {0, 1, 2, 10, 14, 'a'},
    {0, 1, 2, 10,     'b'},
    {0, 1, 2, 11, 14, 'c'},
    {0, 1,    11,     'a'},
    {0, 1,    12, 14, 'b'},
    {0, 1,    12,     'c'},
    {0, 1,    13, 14, 'c'},  --
    {0, 1,    13,     'c'},  --
    {0, 1,        14, 'c'},  --
    {0, 1,            'c'},  --
    {0,               'a'},
    {0,               'b'},
    {0,               'c'},
    {   1, 2, 10, 14, 'a'},
    {   1, 2, 10,     'b'},
    {   1, 2, 11, 14, 'c'},
    {   1,    11,     'a'},
    {   1,    12, 14, 'b'},
    {   1,    12,     'c'},
    {                 'a'},
    {                 'b'},
    {                 'c'},
  })
end
