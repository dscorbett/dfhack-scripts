--@ module = true

WORD_ID_CHAR = '/'

function cc(callback_name, key)
  return {context_key=key, context_callback=callback_name, features={}}
end

--[[
Constructs a constituent from a constituent key.

Args:
  x: A constituent key or a feature table.

Returns:
  If `x` is a constituent key, a constituent using that key as a `ref`
    and with no features. Otherwise, a function that given a constituent
    key returns a constituent with that key as a `ref` and `x` as the
    features.
]]
function r(x)
  return type(x) == 'string' and {ref=x, features={}} or function(s)
    return {ref=s, features=x}
  end
end

--[[
Constructs a constituent from a constituent key.

Args:
  x: A constituent key or a feature table.

Returns:
  The same as `r`, except the constituent key has `WORD_ID_CHAR`
    prepended to it.
]]
function k(x)
  return type(x) == 'string' and r(WORD_ID_CHAR .. x) or function(s)
    return r(x)(WORD_ID_CHAR .. s)
  end
end

--[[
Constructs a constituent generator from its theta roles.

Args:
  key: A constituent key.

Returns:
  A function:
    Constructs a constituent from its theta roles.
    Args:
      args: A mapping of theta role strings to constituents.
    Returns:
      A constituent using `args` as the arguments and `key` appended to
      `WORD_ID_CHAR` as the constituent key.
]]
function t(key)
  -- TODO: map some keys to other keys
  -- TODO: Ensure that `args[1] == nil`, which is currently sometimes false.
  return function(args)
    local constituent = r(WORD_ID_CHAR .. key)
    constituent.args = args
    return constituent
  end
end

--[[
Constructs a morpheme.

Args:
  m: A string or a table.

Returns:
  If `m` is a string, a morpheme with `id` and `text` set to `m`.
    Otherwise, a morpheme with `id` set to `m[1]`, `text` set to `m[2]`,
    and all other morpheme keys set to their values in `m`. Either way,
    unspecified required keys (like `fusion`) are initialized to
    reasonable defaults.
]]
function m(m)
  return type(m) ~= 'table' and
    {id=m, text=m, pword={}, fusion={}, features={}} or
    {id=m[1], text=m[2], pword=m.pword or {}, features=m.features or {},
     affix=m.affix, after=m.after, initial=m.initial, fusion=m.fusion or {},
     dummy=m.dummy}
end

--[[
Constructs a constituent.

Args:
  c: A table.

Returns:
  A constituent using values from `c`, with reasonable defaults when
    required but not specified. `[1]` becomes `n1`; `[2]`, `n2`; `f`,
    `features`; `m`, `morphemes`; and `moved_to`, `moved_to`.
]]
function x(c)
  return {n1=c[1], n2=c[2], features=c.f or {}, morphemes=c.m or {},
          moved_to=c.moved_to}
end

--[[
Constructs a phrase.

Args:
  c: A table.

Returns:
  Whatever `x` would return, but marked as a phrase.
]]
function xp(c)
  c = x(c)
  c.is_phrase = true
  return c
end
