--@ module = true

local trees = reqscript('babel/trees')

local cc = trees.cc
local k = trees.k
local m = trees.m
local r = trees.r
local t = trees.t
local x = trees.x
local xp = trees.xp

--[[
Gets a context-dependent possessive pronoun.

Args:
  c: A sequence of objects. The number of elements determines the
    number of the pronoun. Whether `context.speaker`, and whether an
    element in `context.hearers`, is in the sequence determines the
    person of the pronoun.
  context: The full context.

Returns:
  The constituent for the possessive pronoun corresponding to `c`.
]]
function possessive_pronoun(c, context)
  local first_person = false
  local second_person = false
  local third_person = false
  for i, e in ipairs(c) do
    if e == context.speaker then
      first_person = true
    elseif utils.linear_index(context.hearers, e) then
      second_person = true
    else
      third_person = true
    end
  end
  -- TODO: gender, distance, formality, social status, bystanderness
  return xp{
    false,
    k{
      first_person=first_person,
      second_person=second_person,
      third_person=third_person,
      number=#c,
    }'PRONOUN',
  }
end

function pronoun(c, context)
  return ps.xp{  --DP
    x{cc.possessive_pronoun(c, context)},
  }
end
