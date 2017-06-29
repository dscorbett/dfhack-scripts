-- Add random languages to the game
--@ enable = true

local utils = require('utils')

--[[
TODO:
* Use df2console for portable printing.
* Split this giant file up into smaller pieces.
* Find names for anon and unk fields.
* Put words in GEN_DIVINE.
* Update any new names in GEN_DIVINE to point to the moved GEN_DIVINE.
* Get more dimension values if none have positive scores in the cross-product.
* Change the adventurer's forced goodbye response to "I don't understand you".
* Sign languages
* Accents and dialects
* Calquing
* Taboo syllables, e.g. those present in the king's name
* Mother-in-law language
* Audibility: loud sibilants, quiet whispers, silent signs
* [LISP] (which is not lisping but hissing)
* [UTTERANCES]
* Lisping, stuttering, Broca's aphasia, Wernicke's aphasia, muteness
* Language acquisition: babbling, jargon, holophrastic stage, telegraphic stage
* Effects of missing the critical period
* Creolization by kidnapped children
* Pidgins for merchants
* Orthography and spelling pronunciations
]]

local TEST = true
local HACK_FOR_QUICK_TEST = true

local REPORT_LINE_LENGTH = 73
local DEFAULT_NODE_PROBABILITY_GIVEN_PARENT = 0.5
local MINIMUM_FLUENCY = -32768
local MAXIMUM_FLUENCY = 32767
local UTTERANCES_PER_XP = 16
local MINIMUM_DIMENSION_CACHE_SIZE = 32
local WORD_SEPARATOR = ' '
local MORPHEME_SEPARATOR = nil
local WORD_ID_CHAR = '/'
local STANDARD_AMBIENT_TEMPERATURE = 10045
local NO_TEMPERATURE = 60001

local FEATURE_CLASS_NEUTRAL = 0
local FEATURE_CLASS_VOWEL = 1
local FEATURE_CLASS_CONSONANT = 2

local total_handlers = {
  get={},
  process_new={},
  types={
    -- TODO: Track buildings.
    'historical_figures',
    'entities',
    'sites',
    'artifacts',
    'regions',
    'events',
  }
}
local next_report_index = 0
local region_x = -1
local region_y = -1
local region_z = -1
local unit_count = -1

local phonologies = nil
local lects = nil
local fluency_data = nil

local context_callbacks = {}

if enabled == nil then
  enabled = false
end
local dirty = true
local timer

--[[
Data definitions:

Lect:
A language or dialect.
  parent: A lect to look constituents and morphemes up in if they are
    not in this lect, or nil.
  seed: A random number generator seed for generating the lect's
    language parameter table.
  parameters: A language parameter table generated with `seed`, or nil
    if it hasn't been generated yet.
  lemmas: A translation containing the lemmas of this lect.
  community: The civilization that speaks this lect.
  phonology: The phonology this lect uses.
  morphemes: A map of morphemes IDs to morphemes containing all the
    morphemes used in this lect, including those only used in other
    morphemes.
  constituents: A lexicon, i.e. a map of constituent IDs to constituents
    containing only the top-level constituents of this lect.
All the IDs, features, feature values, and theta roles of all morphemes
and constituents in a lect must contain no characters invalid in raw
subtags. Morpheme IDs must be positive integers such that `morphemes` is
a sequence, and the others must be strings.

Phonology:
  name: A name, for internal use.
  constraints: A sequence of constraints.
  scalings: A sequence of scalings.
  dispersions: A sequence of dispersions.
  nodes: A sequence of nodes.
  dimension: An optional dimension tree. If it is nil, a dimension tree
    will be automatically generated.
  symbols: A sequence of symbols.
  articulators: A sequence of articulators.

Symbol:
  symbol: A string.
  features: The phoneme the symbol represents.

Constraint:
-- TODO

Articulator:
A conjunction of conditions which can apply to a unit. Each key in the
table can be nil, in which case that condition always applies. If all
the conditions apply to a unit, the articulator is present in that unit.
  bp: A body part token string. The unit must have a body part with this
    token. Example: 'U_LIP'.
  bp_category: A body part category string. The unit must have a body
    part with this category. Example: 'LIP'.
  bp_flag: A body part flag. The unit must have a body part with this
    flag. Example: 'HEAR'. At most one of `bp`, `bp_category`, and
    `bp_flag` can be non-nil.
  creature: A `creature_raw` from `df.global.world.raws.creatures.all`.
    The unit must be an instance of this creature.
  creature_class: A creature class string. The unit must be an instance
    of a creature of this creature class. Example: 'GENERAL_POISON'.
  creature_flag: A creature flag. The unit must be an instance of a
    creature with this flag. Example: 'FANCIFUL'. At most one of
    `creature`, `creature_class`, and `creature_flag` can be non-nil.
  caste_index: An index into `creature.caste`. The unit's caste must be
    at this index. If `creature` is nil, this field must be too.
  caste_flag: A caste flag. The unit's caste must have this flag.
    Example: 'EXTRAVISION'. At most one of `caste_index` and
    `caste_flag` can be non-nil.
  -- TODO: sex

Node:
  name: A string, used only for parsing the phonology raw file.
  parent: The index of the node's parent node in the associated
    phonology, or 0 if the parent is the root node.
  add: A string to append to the symbol of a phoneme that does not
    have this node to denote a phoneme that does have it but is
    otherwise identical.
  remove: The opposite of `add`.
  sonority: How much sonority this node adds to a phoneme. The number is
    only meaningful in relation to other nodes' sonorities.
  feature_class: TODO: This should be used or removed.
  feature: Whether this node is a feature node, as opposed to a class
    node.
  prob: The probability that a phoneme has this node. It is 1 for class
    nodes.
  articulators: A sequence of articulators. At least one must be present
    in a unit for that unit to produce a phoneme with this node.

Environment:
A table whose keys are indices of features and whose values are feature
environments for those features.

Feature environment:
A sequence of two sequences, each of whose keys are variable indices and
whose values are assignments. The two subsequences correspond to two
patterns in the scope of which the feature environment is being used.

Assignment:
A table representing a value bound to an variable name in an
environment.
  val: A boolean for whether this variable has the same value as the
    value of the variable that this variable is defined in terms of.
  var: The index of the variable that this variable is defined in
    terms of.

Phoneme:
A table whose keys are feature indices and whose values are booleans.

Dimension value:
A sequence of node indices sorted in increasing order.
  score: A score of how good this dimension value is. It only has
    meaning in comparison to other scores. A higher score means the
    dimension value is more likely to be chosen.

Indexed dimension value:
A pair of a dimension value and an index.
  i: The index of `candidate` in some unspecified sequence. This is only
    useful if a function specifies what the index means.
  candidate: A dimension value.

Bitfield:
A sequence of 32-bit unsigned integers representing a bitfield. Bit `b`
of element `e` represents bit `(e - 1) * 32 + b` in that bitfield. The
minimum bit is 0. There is no maximum bit; the bitfield will grow when
needed.

Grid metadata object:
Metadata about rows or columns in a grid.
  values: A sequence of dimension values associated with the rows or
    columns.
  mask: A bitfield representing the dimensions associated with this
    row or column.
Plus a sequence of the following, one per row or column:
  score: The total score of the row or column.
  value: The dimension value associated with the row or column.
  family: A sequence of the indices of all the rows or columns split
    from the same original row or column as this one, or nil if this
    row or column has not been split.

Grid:
A grid of dimension values and metadata for the rows and columns.
  grid: A sequence of sequences, each of which is the same length and
    represents a row. The values in the grid are numbers, representing
    the scores of dimension values.
  rows: A grid metadata object for the rows.
  cols: A grid metadata object for the columns.

Scaling:
A scaling factor to apply to the score of dimension value if it matches
a pattern of specific feature values.
  mask: A bitfield. If and only if bit `b` is set, this scaling depends
    on the value of node `b + 1` in the appropriate sequence of nodes.
  values: A bitfield. If and only if bit `b` is set here and in `mask`,
    this scaling applies only when the feature is present.
  scalar: How much to scale the score when this scaling applies. It is
    non-negative.
  strength: How strong the scaling factor is as a function of scalar.
    A scalar of 0 gets the maximum strength, then the strength decreases
    monotonically for scalars from 0 to 1, with a minimum strength at 1,
    then increases monotonically for scalars greater than 1.

Dispersion:
A scaling factor to apply to the score of a dimension value if another
dimension value is picked.
  mask: A bitfield. If and only if bit `b` is set, this dispersion
    depends on the value of `b + 1` in the appropriate sequence of
    nodes.
  values_1: A bitfield. If and only if bit `b` is set here and in
    `mask`, this dispersion applies only when the feature is present.
  values_2: The same as `values_1`, but for the other dimension value.
  scalar: How much to scale the score when this dispersion applies. It
    is non-negative.

Dimension:
A producer of dimension values. A dimension may have two subdimensions
from whose cross product its values are drawn.
  id: A sequence of one or two node indices. If there is only one, this
    dimension corresponds to only one node. If there are two, they are
    the indices of the two nodes in `nodes` which are most separated
    from each other in the dimension tree.
  cache: A sequence of dimension values.
  nodes: A sequence of the node indices covered by this dimension.
  mask: A bitfield corresponding to `nodes`.
  d1: A dimension or nil.
  d2: A dimension or nil. It is nil if and only if `d1` is.
  values_1: A sequence of values chosen from `d1`, or nil if `d1` is
    nil.
  values_2: A sequence of values chosen from `d2`, or nil if `d2` is
    nil.
  scalings: A sequence of scalings which apply to the nodes of this
    dimension but not to either of its subdimensions'. That is, each
    scaling's `node_1` and `node_2` are present in `d1.nodes` and
    `d2.nodes`, respectively or vice versa. If `d1` is nil, so is
    `scalings`.
  dispersions: Like `scalings`, but for dispersions.
  peripheral: Whether to use a different algorithm to choose dimension
    values based on picking from the periphery of the dimension's grid
    and ignoring the interior.

Link:
A relationship between two dimensions, and how close the relationship
is. The details of the relationship are not specified here.
  d1: A dimension.
  d2: A dimension.
  scalings: A sequence of scalings which apply between the two
    dimensions. See `scalings` in dimension.
  dispersions: A sequence of dispersions which apply between the two
    dimensions. See `dispersions` in dimension.
  strength: How strong the link is. See `strength` in scaling.

Boundary:
A string representing a boundary.
-- TODO: Enumerate them.

Pword:
A sequence of phonemes.

Mword:
A sequence of morphemes.

Utterable:
An mword or string.

SFI:
A syntactic feature instance.
  feature: A feature.
  head: The constituent this instance of `feature` is on.
  depth: The depth of `head`.

Language parameter table:
  inventory: A sequence of phoneme/sonority pairs used in this language.
    [1]: A phoneme.
    [2]: Its sonority.
  min_sonority: The minimum sonority of all phonemes in `inventory`.
  max_sonority: The maximum sonority of all phonemes in `inventory`.
  constraints: TODO
  strategies: A map from features to movement strategies.
  overt_trace: Whether the language keeps traces in the phonological
    form.
  swap: Whether the language is head-final.

Movement strategy:
What sort of movement to do when checking a certain feature.
  lower: Whether to lower rather than raise.
  pied_piping: Whether to pied-pipe the constituents dominated by the
    maximal projection of the moving constituent along with it.
A movement strategy can also be nil, which means that no movement should
be done, i.e. only agreement should be done.

Context:
A table containing whatever is necessary to complete a syntax tree based
on the speaker, hearers, and any other non-constant information which
may differ between utterances of basically the same sentence. See
`context_key` and `context_callback` in constituent.
-- TODO: Should the keys be standardized?

Constituent:
A node in a syntax tree.
  n1: A child constituent.
  n2: A child constituent, which is nil if `n1` is.
  features: A map of features to feature values.
  morphemes: A sequence of morphemes. Unspecified if `ref` is not nil.
  is_phrase: Whether this constituent is a phrase, i.e. a maximal
    projection.
  depth: The depth of the constituent from the root, where the root has
    a depth of 0 and all others have depths one greater than their
    parents'.
  ref: The key of another constituent in the lexicon that this
    constituent is to be replaced with.
  args: A mapping of theta role strings to constituents. It is nil if
    `ref` is.
  arg: A theta role string. A constituent with this key is meant to be
    replaced from the `args` of another constituent; it does not make
    sense for it to be present in the final output.
  maximal: The maximal projection of this constituent, or nil if none.
  moved_to: The constituent to which this constituent was moved, or nil
    if none.
  text: A string to use verbatim in the output. If this is non-nil, then
    `features` and `morphemes` must both be empty.
  context_key: A key to look up in a context. At most one of `n1`,
    `word`, `text`, `arg`, and `context_key` can be non-nil.
  context_callback: A string key in `context_callbacks` whose value is a
    function returning a constituent to replace this one given
    `context[context_key]` and `context` where `context` is a context.
    It is nil if and only if `context_key` is.

Morpheme:
  id: A unique ID for this morpheme within its language.
  text: A string to print for debugging.
  pword: A sequence of phonemes.
  features: A map of features to feature values.
  affix: Whether this is a bound morpheme.
  after: Whether this morpheme goes after (as opposed to before) another
    morpheme when dislocating.
  initial: Whether `after` should be taken in reference to the first
    subunit of the unit relative to which this morpheme is dislocated.
  fusion: A map of morpheme IDs to morphemes, representing the fusion of
    this morpheme and the key to produce the value.
  dummy: A morpheme to insert if this is a bound morpheme but there are
    no morphemes to bind to, or nil if this morpheme should just be
    deleted in that case.

Translation:
A sequence of tag strings in the format of the values of
`df.global.world.raws.language.translations`.

Loan:
A sequence of tables, each with the keys:
  prefix: The string to prepend to the ID of the referent.
  type: The DFHack struct type of the referent.
  id: The name of the field where a referent of type `type` has an ID.
  get: A function:
    Gets the referents of type `type` from a civilization.
    Args:
      civ: A civilization.
    Returns:
      The array of referents.
]]

--[[
Prints a help message.
]]
local function usage()
  print[[
Usage:
  babel start
    Start the script.
  babel stop
    Stop the script.
]]
end

--[[
Asserts that two values are equal.

If the values are both tables, it compares the elements of the tables.

Args:
  actual: A value.
  expected: A value.
]]
local function assert_eq(actual, expected, _k)
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
Concatenates two sequences.

Args:
  a: A sequence.
  b: A sequence.

Returns:
  The concatenation of `a` and `b`.
]]
local function concatenate(a, b)
  local length = #a
  local rv = copyall(a)
  for i, v in ipairs(b) do
    rv[length + i] = v
  end
  return rv
end

if TEST then
  assert_eq(concatenate({1, '2'}, {{n=3}, false}), {1, '2', {n=3}, false})
end

--[[
Shuffles a sequence randomly.

Args:
  t! A sequence.
  rng! A random number generator.

Returns:
  `t`, randomly shuffled.
]]
local function shuffle(t, rng)
  local j
  for i = #t, 2, -1 do
    j = rng:random(i) + 1
    t[i], t[j] = t[j], t[i]
  end
  return t
end

--[[
Finds the last instance of an element in a vector.

Args:
  vector: A vector or sequence.
  key: What to search for.
  field: The field which is equal to `key` in the sought element, or
    nil to compare the element itself to `key`.

Returns:
  The last index of a matching element, or nil if not found.
  The last matching element, or nil if none is found.
]]
local function reverse_linear_index(vector, key, field)
  local min, max
  if df.isvalid(vector) then
    min, max = 0, #vector - 1
  else
    min, max = 1, #vector
  end
  if field then
    for i = max, min, -1 do
      local obj = vector[i]
      if obj[field] == key then
        return i, obj
      end
    end
  else
    for i = max, min, -1 do
      local obj = vector[i]
      if obj == key then
        return i, obj
      end
    end
  end
end

if TEST then
  assert_eq({reverse_linear_index({1, 2, 1}, 3)}, {})
  assert_eq({reverse_linear_index({1, 2, 1}, 1)}, {3, 1})
  assert_eq({reverse_linear_index({{k=1}, {j=1}, {j=1, k=1}, {k=2}}, 1, 'k')},
            {3, {j=1, k=1}})
end

local function escape(str)
  return (str:gsub('[\x00\n\r\x1a%%:%]]', function(c)
    return '%' .. string.format('%02X', string.byte(c))
  end))
end

if TEST then
  assert_eq(escape('<]:\r\n|%\x1a\x00>'), '<%5D%3A%0D%0A|%25%1A%00>')
end

local function unescape(str)
  return (str:gsub('%%[%da-fA-F][%da-fA-F]', function(c)
    return string.char(tonumber(c:sub(2), 16))
  end))
end

if TEST then
  assert_eq(unescape('(%5D%3A%0a|%25%1A)'), '(]:\n|%\x1a)')
end

--[[
Serializes a pword.

Args:
  nodes: A sequence of the nodes used in `pword`'s lect.
  pword: A pword.

Returns:
  An opaque string serialization of the pword, which can be deserialized
    with `deserialize_pword`.
]]
local function serialize_pword(nodes, pword)
  local str = ''
  local features_per_phoneme = #nodes
  for _, phoneme in ipairs(pword) do
    local byte = 0
    local bi = 1
    for ni = 1, features_per_phoneme do
      if nodes[ni].feature then
        if phoneme[ni] then
          byte = byte + 2 ^ ((8 - bi) % 8)
        end
        bi = bi + 1
      end
      if ni == features_per_phoneme or bi == 9 then
        str = str .. string.format('%c', byte)
        byte = 0
        bi = 1
      end
    end
  end
  return str
end

if TEST then
  local fn = {feature=true}
  local cn = {feature=false}
  local nodes = {fn, fn, fn, fn, fn, fn, fn, fn}
  assert_eq(serialize_pword(nodes, {}), '')
  assert_eq(serialize_pword(nodes, {{}}), '\x00')
  assert_eq(serialize_pword(nodes, {{[1]=true}}), '\x80')
  assert_eq(serialize_pword(nodes, {{[2]=true}}), '\x40')
  assert_eq(serialize_pword(nodes, {{[3]=true}}), '\x20')
  assert_eq(serialize_pword(nodes, {{[4]=true}}), '\x10')
  assert_eq(serialize_pword(nodes, {{[5]=true}}), '\x08')
  assert_eq(serialize_pword(nodes, {{[6]=true}}), '\x04')
  assert_eq(serialize_pword(nodes, {{[7]=true}}), '\x02')
  assert_eq(serialize_pword(nodes, {{[8]=true}}), '\x01')
  assert_eq(serialize_pword(concatenate(nodes, {fn}), {{[9]=true}}), '\x00\x80')
  assert_eq(serialize_pword(concatenate(nodes, {cn, fn}),
                            {{[9]=true, [10]=true}}),
            '\x00\x80')
  assert_eq(serialize_pword(concatenate(nodes, concatenate(nodes, nodes)),
                            {{[12]=true}}),
            '\x00\x10\x00')
  assert_eq(serialize_pword(nodes, {{false, true, true, true, true, true}}),
            '\x7c')
  assert_eq(serialize_pword(nodes, {{true}, {true}}), '\x80\x80')
end

--[[
Deserializes a pword.

Args:
  nodes: A sequence of the nodes used in the target lect.
  str: A serialized pword.

Returns:
  A pword.
]]
local function deserialize_pword(nodes, str)
  local pword = {}
  local phoneme = {}
  local ni = 1
  for i = 1, #str do
    local code = str:byte(i)
    local b = 8
    while b >= 1 do
      if not nodes[ni] then
        b = 0
      elseif nodes[ni].feature then
        table.insert(phoneme, (code % (2 ^ b)) >= (2 ^ (b - 1)))
        b = b - 1
      else
        table.insert(phoneme, true)
      end
      ni = ni + 1
    end
    if ni >= #nodes then
      pword[#pword + 1] = phoneme
      phoneme = {}
      ni = 1
    end
  end
  return pword
end

if TEST then
  local fn = {feature=true}
  local cn = {feature=false}
  local n1 = {fn, fn, fn, fn, fn, fn, fn, fn}
  local n2 = concatenate(n1, n1)
  local n3 = concatenate(n1, n2)
  assert_eq(deserialize_pword(n1, '\x00'),
            {{false, false, false, false, false, false, false, false}})
  assert_eq(deserialize_pword(n1, '\x80'),
            {{true, false, false, false, false, false, false, false}})
  assert_eq(deserialize_pword(n1, '\x40'),
            {{false, true, false, false, false, false, false, false}})
  assert_eq(deserialize_pword(n1, '\x20'),
            {{false, false, true, false, false, false, false, false}})
  assert_eq(deserialize_pword(n1, '\x10'),
            {{false, false, false, true, false, false, false, false}})
  assert_eq(deserialize_pword(n1, '\x08'),
            {{false, false, false, false, true, false, false, false}})
  assert_eq(deserialize_pword(n1, '\x04'),
            {{false, false, false, false, false, true, false, false}})
  assert_eq(deserialize_pword(n1, '\x02'),
            {{false, false, false, false, false, false, true, false}})
  assert_eq(deserialize_pword(n1, '\x01'),
            {{false, false, false, false, false, false, false, true}})
  assert_eq(deserialize_pword(n2, '\x00\x80'),
            {{false, false, false, false, false, false, false, false, true,
              false, false, false, false, false, false, false}})
  assert_eq(deserialize_pword(n3, '\x00\x10\x00'),
            {{false, false, false, false, false, false, false, false, false,
              false, false, true, false, false, false, false, false, false,
              false, false, false, false, false, false}})
  assert_eq(deserialize_pword(n1, '\x7c'),
            {{false, true, true, true, true, true, false, false}})
  assert_eq(deserialize_pword(n1, '\x80\x80'),
            {{true, false, false, false, false, false, false, false},
             {true, false, false, false, false, false, false, false}})
  assert_eq(deserialize_pword(concatenate({cn}, n1), '\x80'),
            {{true, true, false, false, false, false, false, false, false}})
end

--[[
Merges two sequences without duplicates sorted in increasing order.

Elements present in both input sequences are collapsed into one.

Args:
  s1: A sequence.
  s2: A sequence.
  cmpfun: A comparator function, or `utils.compare` by default.

Returns:
  A merged sorted sequence.
]]
local function merge_sorted_sequences(s1, s2, cmpfun)
  local rv = {}
  for _, e in ipairs(s1) do
    table.insert(rv, e)
  end
  for _, e in ipairs(s2) do
    utils.insert_sorted(rv, e, nil, cmpfun)
  end
  return rv
end

if TEST then
  assert_eq(merge_sorted_sequences({1, 2, 5}, {-1, 3, 4, 5, 100}),
            {-1, 1, 2, 3, 4, 5, 100})
  assert_eq(
    merge_sorted_sequences(
      {5, 2, 1}, {100, 5, 4, 3, -1},
      function(a, b) return utils.compare(b, a) end),
    {100, 5, 4, 3, 2, 1, -1})
end

--[[
Determines whether one node dominates another.

Every node dominates itself.

Args:
  index_1: The index of a node in `nodes`.
  index_2: The index of a node in `nodes`.
  nodes: A sequence of nodes.

Returns:
  Whether `nodes[index_1]` dominates `nodes[index_2]`.
]]
local function dominates(index_1, index_2, nodes)
  if index_1 == index_2 then
    return true
  elseif index_2 < index_1 then
    return false
  end
  return dominates(index_1, nodes[index_2].parent, nodes)
end

if TEST then
  local nodes = {{name='1', parent=0, sonority=0},
                 {name='2', parent=0, sonority=0},
                 {name='3', parent=2, sonority=0}}
  assert_eq(dominates(0, 0, nodes), true)
  assert_eq(dominates(0, 1, nodes), true)
  assert_eq(dominates(0, 2, nodes), true)
  assert_eq(dominates(0, 3, nodes), true)
  assert_eq(dominates(1, 0, nodes), false)
  assert_eq(dominates(1, 1, nodes), true)
  assert_eq(dominates(1, 2, nodes), false)
  assert_eq(dominates(1, 3, nodes), false)
  assert_eq(dominates(2, 0, nodes), false)
  assert_eq(dominates(2, 1, nodes), false)
  assert_eq(dominates(2, 2, nodes), true)
  assert_eq(dominates(2, 3, nodes), true)
  assert_eq(dominates(3, 0, nodes), false)
  assert_eq(dominates(3, 1, nodes), false)
  assert_eq(dominates(3, 2, nodes), false)
  assert_eq(dominates(3, 3, nodes), true)
end

local function optimize(parameters, input, is_loan)
  local output = copyall(input)
  --[[
  if is_loan then
    for _, phoneme in pairs(output) do
      if phoneme not in parameters.inventory then
        phoneme = closest_phoneme(phoneme, parameters.inventory)
      end
    end
  end
  output = best_candidate(1, parameters.constraints, input, output)
  --]]
  return output
end

--[[
Gets the lemma of a pword.

Args:
  phonology: A phonology.
  pword: A pword.

Returns:
  The lemma.
]]
local function get_lemma(phonology, pword)
  local str = ''
  for _, phoneme in ipairs(pword) do
    local best_symbol = ''
    local best_score = -1
    local best_base_score = -1
    for _, symbol_info in ipairs(phonology.symbols) do
      local symbol = symbol_info.symbol
      local symbol_features = symbol_info.features
      local base_score = 0
      for node_index, node in ipairs(phonology.nodes) do
        if (node.feature and (phoneme[node_index] or false) ==
            (symbol_features[node_index] or false)) then
          base_score = base_score + 1
        end
      end
      local score = base_score
      --[[
      for i, node in pairs(phonology.nodes) do
        if not phoneme[i] ~= not symbol_features[i] then
          if node.add and phoneme[i] then
            symbol = symbol .. node.add
            score = score + 1
          elseif node.remove and not phoneme[i] then
            symbol = symbol .. node.remove
            score = score + 1
          elseif phoneme[i] and node.feature then
            symbol = symbol .. '[+' .. node.name .. ']'
          elseif not phoneme[i] and node.feature then
            symbol = symbol .. '[-' .. node.name .. ']'
          end
        end
      end
      ]]
      if (score > best_score or
          (score == best_score and base_score > best_base_score)) then
        best_symbol = symbol
        best_score = score
        best_base_score = base_score
      end
    end
    str = str .. best_symbol
  end
  return str
end

if TEST and TODO then
  assert_eq(get_lemma({nodes={}, symbols={}}, {{}}), '')

  local phonology = {nodes={{name='a', parent=0, add='+a', remove='-a',
                             feature=true},
                            {name='b', parent=0, add='+b', remove='-b',
                             feature=true},
                            {name='c', parent=0, add='+c', remove='-c',
                             feature=true}},
                     symbols={{symbol='x', features={false, false, false}},
                              {symbol='abc', features={true, true, true}}}}
  assert_eq(get_lemma(phonology, {{false, false, false}}), 'x')
  assert_eq(get_lemma(phonology, {{false, false, true}}), 'x+c')
  assert_eq(get_lemma(phonology, {{false, true, false}}), 'x+b')
  assert_eq(get_lemma(phonology, {{false, true, true}}), 'abc-a')
  assert_eq(get_lemma(phonology, {{true, false, false}}), 'x+a')
  assert_eq(get_lemma(phonology, {{true, false, true}}), 'abc-b')
  assert_eq(get_lemma(phonology, {{true, true, false}}), 'abc-c')
  assert_eq(get_lemma(phonology, {{true, true, true}}), 'abc')
  assert_eq(get_lemma(phonology, {{true, false, true}, {true, true, false}}),
            'abc-babc-c')

  table.remove(phonology.symbols, 1)
  assert_eq(get_lemma(phonology, {{false, false, false}}), 'abc-a-b-c')
end

--[[
local function best_candidate(constraint_index, constraints, original,
                              candidate, violation_counts)
  local violations =
    violations(constraints[constraint_index], original, candidate)
  if #violations == 0 then
    if constraint_index == #constraints then
      return candidate, i, 0
    else
      return best_candidate(constraint_index + 1, constraints, original,
                            candidate)
    end
  end
  local actions =
    actions(constraint_index, constraints, candidate, violations[1])
  if #actions == 0 then
    return candidate, i, #violations
  end
  let best_violated_constraint_index = 1
  let best_violated_constraint_count = math.huge
  for action in actions do
    local new_candidate, new_constraint_index, new_constraint_count =
      best_candidate(constraint_index, apply_action(action, candidate))
  end
end
--]]

--[[
Updates a binding in an environment.

Does `feature_env[lvalue_i][lvalue_var] = new` and modifies
`feature_env` to be consistent with the new assignment.

Args:
  feature_env! A feature environment.
  lvalue_i: Which pattern (1 or 2) the identifier is from.
  lvalue_var: The identifier to bind to a new assignment.
  new: An assignment.

Returns:
  Whether the new binding is consistent with the original feature
    environment.
]]
local function update_binding(feature_env, lvalue_i, lvalue_var, new)
  if lvalue_i == new.i and lvalue_var == new.var then
    return new.val
  end
  feature_env[lvalue_i][lvalue_a] = new
  for i = 1, 2 do
    for _, other in pairs(feature_env[i]) do
      if other.i == lvalue_i and other.var == lvalue_var then
        other.i = new.i
        other.val = other.val == new.val
        other.var = new.var
      end
    end
  end
  return true
end

-- A feature assignment is a pair of a value and a var. A value is a
-- boolean. A var is a non-negative integer representing a variable.
-- The var 0 is always true.

-- Every assignment is one of:
-- * a literal boolean
-- * a variable with no prior information (i.e. nil in feature_env)
-- * a variable with a known boolean value
-- * a variable with a known relationship to another variable
-- i=0 means i=<don't care>
local function equalize(a1, a2, feature_env)
  if a1.var == 0 then
    if a2.var == 0 then
      return a1.val == a2.val
    elseif not feature_env[2][a2.var] then
      return update_binding(feature_env, 2, a2.var,
                            {i=0, val=a1.val, var=a1.var})
    elseif feature_env[2][a2.var].var == 0 then
      return a1.val == feature_env[2][a2.var].val
    else
      return equalize(a1, feature_env[2][a2.var], feature_env)
    end
  elseif not feature_env[1][a1.var] then
    if a2.var == 0 then
      return update_binding(feature_env, 1, a1.var,
                            {i=0, val=a2.val, var=a2.var})
    elseif not feature_env[2][a2.var] then
      return update_binding(feature_env, 1, a1.var,
                            {i=2, val=a2.val, var=a2.var})
    elseif feature_env[2][a2.var].var == 0 then
      return update_binding(feature_env, 1, a1.var, feature_env[2][a2.var])
    else
      return update_binding(feature_env, 1, a1.var, feature_env[2][a2.var])
    end
  elseif feature_env[1][a1.var].var == 0 then
    if a2.var == 0 then
      return feature_env[1][a1.var].val == a2.val
    elseif not feature_env[2][a2.var] then
      return update_binding(feature_env, 2, a2.var, feature_env[1][a1.var])
    elseif feature_env[2][a2.var].var == 0 then
      return feature_env[1][a1.var].val == feature_env[2][a2.var].val
    else
      return equalize(feature_env[1][a1.var], feature_env[2][a2.var],
                      feature_env)
    end
  else
    if a2.var == 0 then
      return equalize(feature_env[1][a1.var], a2, feature_env)
    elseif not feature_env[2][a2.var] then
      return update_binding(feature_env, 2, a2.var, feature[1][a1.var])
    elseif feature_env[2][a2.var].var == 0 then
      return equalize(feature_env[1][a1.var], feature_env[2][a2.var],
                      feature_env)
    else
      return equalize(feature_env[1][a1.var], feature_env[2][a2.var],
                      feature_env)
    end
  end
end

local function get_feature_set_overlap(overlap, phoneme_2, env)
  for i, a2 in pairs(phoneme2) do
    local a1 = overlap[i]
    if a1 then
      if not env[i] then
        env[i] = {{}, {}}
      end
      if not equalize(a1, a2, 1, 2, env[i]) then
        return nil
      end
    else
      overlap[i] = {i=2, val=a2.val, var=a2.var}
    end
  end
  return overlap
end

local function get_overlap(element_1, element_2, env)
  if element_1.type == 'phoneme' then
    if element_2.type == 'phoneme' then
      return get_feature_set_overlap(copyall(element_1), element_2, env)
    elseif element_2.type == 'boundary' then
      return nil
    else
      return get_feature_set_overlap({[element_2.feature]={val=false, var=0}},
                                     element_1, env)
    end
  elseif element_1.type == 'boundary' then
    if element_2.type == 'phoneme' then
      return nil
    elseif element_2.type == 'boundary' then
      return get_feature_set_overlap(copyall(element_1), element_2, {})
    else
      return get_feature_set_overlap(copyall(element_1), element_2.boundaries,
                                     {})
    end
  else
    if element_2.type == 'phoneme' then
      return get_feature_set_overlap({[element_1.feature]={val=false, var=0}},
                                     element_2, env)
    elseif element_2.type == 'boundary' then
      return get_feature_set_overlap(copyall(element_1.boundaries), element_2,
                                     {})
    else
      local overlap = {type='skip', boundaries=get_feature_set_overlap(
        copyall(element_1.boundaries), element_2.boundaries, {})}
      if dominates(element_1.feature, element_2.feature, element_1.nodes) then
        return element_1
      elseif dominates(element_2.feature, element_1.feature,
                       element_1.nodes) then
        return element_2
      end
      return nil
    end
  end
end

local function apply_unfix(alignment, unfix)
  local element_index = unfix.index + alignment.delta
  if unfix.type == 'Max' then
    table.insert(alignment, element_index, unfix.phoneme)
  elseif unfix.type == 'Dep' then
    table.remove(alignment, element_index)
  elseif unfix.type == 'Ident' then
    local assignment = alignment[element_index][unfix.feature_index]
    assignment.val = not assignment.val
  end
end

local function substitute(alignment, env)
  for _, element in pairs(alignment) do
    local i = element.i or 1
    for feature_index, assignment in pairs(element) do
      if env[feature_index] and env[feature_index][i] and env[feature_index][i][assignment.var] then
        local assignment_in_env = env[feature_index][i][assignment.var]
        assignment.var = assignment_in_env.var
        assignment.val = assignment.val == assignment_in_env.val
      end
    end
  end
end

local function get_alignments(index_1, constraint_1, index_2, constraint_2,
                              alignment, env, unfix, results)
  if index_1 > #constraint_1 or index_2 > #constraint_2 then
    if index_1 > #constraint_1 then
      if index_2 <= #constraint_2 then
        for i = index_2, #constraint_2 do
          table.insert(alignment, constraint_1[index_1])
        end
      end
    else
      for i = index_1, #constraint_1 do
        table.insert(alignment, constraint_2[index_2])
      end
    end
    apply_unfix(alignment, unfix)
    substitute(alignment, env)
    table.insert(results, alignment)
  else
    local overlap = get_overlap(constraint_1[index_1], constraint_2[index_2],
                                env)
    local next_indices_1 = {}
    local next_indices_2 = {}
    local type_1 = constraint_1[index_1].type
    local type_2 = constraint_1[index_2].type
    if overlap then
      table.insert(alignment, overlap)
      if type_1 == 'skip' then
        next_indices_1 = {index_1, index_1 + 1}
      else
        next_indices_1 = {index_1 + 1}
      end
      if type_2 == 'skip' then
        next_indices_2 = {index_2, index_2 + 1}
      else
        next_indices_2 = {index_2 + 1}
      end
    else
      if index_1 == 1 and index_2 ~= 1 and index_2 ~= #constraint_2 then
        alignment.delta = alignment.delta + 1
        table.insert(alignment, constraint_2[index_2])
        type_2 = 'skip'
      elseif index_2 == 1 and index_1 ~= 1 and index_1 ~= #constraint_1 then
        table.insert(alignment, constraint_1[index_1])
        type_1 = 'skip'
      end
      if type_1 == 'skip' then
        next_indices_1 = {index_1 + 1}
      else
        next_indices_1 = {index_1}
      end
      if type_2 == 'skip' then
        next_indices_2 = {index_2 + 1}
      else
        next_indices_2 = {index_2}
      end
    end
    for _, next_index_1 in pairs(next_indices_1) do
      for _, next_index_2 in pairs(next_indices_2) do
        if next_index_1 ~= index_1 or next_index_2 ~= index_2 then
          -- TODO: some of this copyalling is unnecessary
          get_alignments(next_index_1, constraint_1, next_index_2,
                         copyall(alignment), copyall(env), unfix, results)
        end
      end
    end
  end
end

-- Get the markedness constraint describing the result of applying
-- `unfix` to the overlap of `constraint_1` and `constraint_2`.
local function get_feeding_constraint(constraint_1, constraint_2, unfix)
  local feeding_constraints = {}
  get_alignments(1, constraint_1, 1, constraint_2, {delta=0}, {}, unfix,
                 feeding_constraints)
  return feeding_constraints
end

-- Get the markedness constraints describing the contexts in which
-- applying `fix` because of `constraints[original_constraint_index]`
-- feeds a violation of `fed_constraint`.
local function get_feeding_constraints(fix, fed_constraint, constraints,
                                       original_constraint_index)
  local fed_constraint = copyall(fed_constraint)
  local unfix = {type=fix.type, index=fix.element_index}
  if fix.type == 'Max' then
    unfix.phoneme = fed_constraint[fix.element_index]
    table.remove(fed_constraint, fix.element_index)
  elseif fix.type == 'Dep' then
    -- TODO: More than just the root node?
    table.insert(fed_constraint, fix.element_index, {})
  elseif fix.type == 'Ident' then
    local feature_and_element_indices = fix.features[fix.feature_index]
    local feature_index = feature_and_element_indices.feature_index
    local element_index = feature_and_element_indices.element_index
    unfix.feature_index = feature_index
    local assignment = fed_constraint[element_index][feature_index]
    assignment.val = not assignment.val
  end
  local feeding_constraints = {}
  for i, constraint in pairs(constraints) do
    if i ~= original_constraint_index then
      local feeding_constraint =
        get_feeding_constraint(fed_constraint, constraint, unfix)
      if feeding_constraint then
        table.insert(feeding_constraints,
                     {pattern=feeding_constraint, violation_index=i})
      end
    end
  end
  return feeding_constraints
end

local function features_worth_changing(pattern)
  local feature_and_element_indices = {}
  -- TODO: Figure out which of these are safe to change.
  --[[
  for element_index, element in pairs(pattern) do
    if element.type == 'phoneme' then
      for feature_index, _ in pairs(element) do
        table.insert(feature_and_element_indices,
                     {feature_index=feature_index, element_index=element_index})
      end
    end
  end
  ]]
  return feature_and_element_indices
end

local function next_fix(record, constraint_index, constraints)
  local fix = record.fix
  if fix.type == 'Ident' then
    if fix.feature_index < #fix.features then
      return {type=fix.type, constraint_index=fix.constraint_index,
              feature_index=fix.feature_index + 1, features=fix.features}
    end
  else
    if fix.element_index < fix.max_element_index then
      return {type=fix.type, constraint_index=fix.constraint_index,
              element_index=fix.element_index + 1,
              max_element_index=fix.max_element_index}
    end
  end
  local min_violation_index = record.min_violation_index
  for i = fix.constraint_index, constraint_index + 1, -1 do
    local constraint = constraints[i]
    local type = constraint.type
    if type == 'Max' then
      return {type=type, constraint_index=i, element_index=1,
              max_element_index=#constraint}
    elseif type == 'Dep' then
      return {type=type, constraint_index=i, element_index=2,
              max_element_index=#constraint}
    elseif type == 'Ident' then
      return {type=type, constraint_index=i, feature_index=1,
              features=features_worth_changing(constraint)}
    end
  end
  return nil
end

local function constraint_to_rules(constraint_index, constraints)
  local records = {{pattern=constraints[constraint_index], fix=nil,
                    min_violation_index=i, done=false}}
  while utils.linear_search(records, false, 'done') do
    local record_index, record = utils.linear_search(records, false, 'done')
    local fix = next_fix(record, constraint_index, constraints)
    if fix then
      local feeding_constraints =
        get_feeding_constraints(fix, record.pattern, constraints,
                                constraint_index)
      for _, feeding_constraint in pairs(feeding_constraints) do
        local new_record = copyall(record)
        if feeding_constraint.violation_index > record.min_violation_index then
          new_record.pattern = feeding_constraint.pattern
          new_record.fix = fix
          new_record.min_violation_index = feeding_constraint.violation_index
        end
        table.insert(records, record_index, new_record)
      end
      record.fix = fix
    end
    record.done = true
  end
  return records
end

local function constraints_to_rules(constraints)
  local rules = {}
  for i, constraint in pairs(constraints) do
    if constraint.type == '*' then
      for _, rule in pairs(constraint_to_rules(i, constraints)) do
        table.insert(rules, rule)
      end
    end
  end
  return rules
end

--[[
Merges links that are between the same two dimensions.

If two links have the same dimensions, their `scalings` sequences are
merged. After merging, the whole sequence is sorted in increasing order
by link strength.

Args:
  links! A sequence of links.
]]
local function merge_links(links)
  utils.sort_vector(links, nil, function(a, b)
      if a.d1.id[1] > a.d2.id[1] then
        a.d1, a.d2 = a.d2, a.d1
      end
      if b.d1.id[1] > b.d2.id[1] then
        b.d1, b.d2 = b.d2, b.d1
      end
      if a.d1.id[1] < b.d1.id[1] then
        return -1
      elseif a.d1.id[1] > b.d1.id[1] then
        return 1
      elseif a.d2.id[1] < b.d2.id[1] then
        return -1
      elseif a.d2.id[1] > b.d2.id[1] then
        return 1
      else
        return 0
      end
    end)
  local i = 2
  while i <= #links do
    local prev = links[i - 1]
    local link = links[i]
    if prev.d1 == link.d1 and prev.d2 == link.d2 then
      prev.strength = prev.strength + link.strength
      for _, scaling in ipairs(link.scalings) do
        table.insert(prev.scalings, scaling)
      end
      table.remove(links, i)
    else
      i = i + 1
    end
  end
  utils.sort_vector(links, 'strength')
end

if TEST then
  local dim_1 = {id={1}}
  local dim_2 = {id={2}}
  local dim_3 = {id={3}}
  local links = {{d1=dim_1, d2=dim_2, dispersions={}, scalings={}, strength=1},
                 {d1=dim_1, d2=dim_3, dispersions={}, scalings={}, strength=1},
                 {d1=dim_2, d2=dim_1, dispersions={}, scalings={}, strength=2}}
  merge_links(links)
  assert_eq(links,
            {{d1=dim_1, d2=dim_3, dispersions={}, scalings={}, strength=1},
             {d1=dim_1, d2=dim_2, dispersions={}, scalings={}, strength=3}})
end

--[[
Calculates the disjunction of two bitfields.

Args:
  a: A bitfield.
  b: A bitfield.

Returns:
  The bitwise disjunction of `a` and `b`.
]]
local function bitfield_or(a, b)
  local rv = copyall(a)
  for i = 1, #b do
    rv[i] = a[i] and bit32.bor(a[i], b[i]) or b[i]
  end
  return rv
end

if TEST then
  assert_eq(bitfield_or({0x1}, {0x3}), {0x3})
  assert_eq(bitfield_or({0x3}, {0x1}), {0x3})
  assert_eq(bitfield_or({0x2}, {0x1}), {0x3})
  assert_eq(bitfield_or({0x0, 0x1}, {0x2}), {0x2, 0x1})
  assert_eq(bitfield_or({0x2}, {0x0, 0x1}), {0x2, 0x1})
end

--[[
Determines whether two bitfields are equal.

Args:
  a: A bitfield.
  b: A bitfield.
  ...: Any number of bitfields.

Returns:
  Whether `a` and `b` are equal, when both masked by the union of all
    the masks in `...`.
]]
local function bitfield_equals(a, b, ...)
  local m = math.max(#a, #b)
  local masks_inside_out = {}
  for _, mask in ipairs({...}) do
    m = math.min(#mask)
    for i = 1, m do
      if not masks_inside_out[i] then
        masks_inside_out[i] = {}
      end
      masks_inside_out[i][#masks_inside_out[i] + 1] = mask[i]
    end
  end
  for i = 1, m do
    if bit32.btest(bit32.bxor(a[i] or 0, b[i] or 0),
                   table.unpack(masks_inside_out[i] or {})) then
      return false
    end
  end
  return true
end

if TEST then
  assert_eq(bitfield_equals({0x8C}, {0x8C}), true)
  assert_eq(bitfield_equals({0x8C}, {0x0, 0x8C}), false)
  assert_eq(bitfield_equals({0x5}, {0x3}, {0x9}), true)
  assert_eq(bitfield_equals({0x6}, {0xA7}, {0x7}), false)
  assert_eq(bitfield_equals({0x6}, {0xA7}, {0x7}, {0xA0}), true)
end

--[[
Merges two dimensions, preferring those which are strongly linked.

Merging dimensions means creating a new dimension with them as its `d1`
and `d2`.

If `links` is not empty, it merges the dimensions linked by the last
link, i.e. the strongest one. It appends the new dimension to
`dimensions`.

If `links` is empty, it merges the last two dimensions and inserts the
new dimension at the beginning of `dimensions`. This is arbitrary, but
helps keep the final dimension tree dense.

In either case, the two merged dimensions are removed from `dimensions`.

Args:
  dimensions! A sequence of dimensions of length at least 2.
  links: A sequence of links between those dimensions, sorted in
    increasing order by link strength.
]]
local function merge_dimensions(dimensions, links)
  if next(links) then
    local link = table.remove(links)
    local dimension = {id={link.d1.id[1], link.d2.id[#link.d2.id]},
                       cache={}, d1=link.d1, d2=link.d2,
                       mask=bitfield_or(link.d1.mask, link.d2.mask),
                       nodes=concatenate(link.d1.nodes, link.d2.nodes),
                       values_1={}, values_2={}, scalings={}, dispersions={}}
    for _, sods in ipairs({'scalings', 'dispersions'}) do
      local sods_seen = {}
      for _, sod in ipairs(link[sods]) do
        if (not sods_seen[sod] and
            bitfield_equals(dimension.mask, sod.mask, sod.mask)) then
          sods_seen[sod] = true
          dimension[sods][#dimension[sods] + 1] = sod
        end
      end
    end
    local i = 1
    while i <= #links do
      local l = links[i]
      if l.d1 == link.d1 or l.d1 == link.d2 then
        l.d1 = dimension
      elseif l.d2 == link.d1 or l.d2 == link.d2 then
        l.d2 = dimension
      end
      if l.d1 == l.d2 then
        table.remove(links, i)
      else
        i = i + 1
      end
    end
    merge_links(links)
    dimensions[#dimensions + 1] = dimension
    i = 1
    while i <= #dimensions do
      if dimensions[i] == link.d1 or dimensions[i] == link.d2 then
        table.remove(dimensions, i)
      else
        i = i + 1
      end
    end
  else
    local d1 = table.remove(dimensions)
    local d2 = table.remove(dimensions)
    table.insert(dimensions, 1,
                 {id={d1.id[1], d2.id[#d2.id]}, cache={}, d1=d1, d2=d2,
                  nodes=concatenate(d1.nodes, d2.nodes),
                  mask=bitfield_or(d1.mask, d2.mask),
                  values_1={}, values_2={}, scalings={}, dispersions={}})
  end
end

if TEST then
  local dim_1 = {id={1}, mask={0x1}, nodes={1}}
  local dim_2 = {id={2}, mask={0x2}, nodes={2}}
  local dim_3 = {id={3}, mask={0x3}, nodes={3}}
  local dim_5 = {id={5}, mask={0x5}, nodes={5}}
  local dimensions = {dim_3, dim_2, dim_5}
  local s12 = {mask={0x3}}
  local s23 = {mask={0x6}}
  local links =
    {{d1=dim_1, d2=dim_2, scalings={s12}, dispersions={}, strength=1},
     {d1=dim_2, d2=dim_3, scalings={s23}, dispersions={}, strength=1}}
  merge_dimensions(dimensions, links)
  local dim_23 =
    {id={2, 3}, cache={}, nodes={2, 3}, mask={0x3}, d1=dim_2, d2=dim_3,
     values_1={}, values_2={}, scalings={}, dispersions={}}
  assert_eq({dim_5, dim_23}, dimensions)
  assert_eq({{d1=dim_1, d2=dim_23, scalings={s12}, dispersions={}, strength=1}},
            links)
  merge_dimensions(dimensions, {})
  assert_eq({{id={2, 5}, cache={}, nodes={2, 3, 5}, mask={0x7}, d1=dim_23,
              d2=dim_5, values_1={}, values_2={}, scalings={}, dispersions={}}},
            dimensions)
end

--[[
Determines whether a creature has at least one of a set of articulators.

Args:
  creature: A `creature_raw`, as from
    `df.global.world.raws.creatures.all`.
  articulators: A sequence of articulators.

Returns:
  Whether at least one articulator from `articulators` would be present
    in an unwounded `creature`, of no matter what caste; or true, if
    `articulators` is empty.
]]
local function can_articulate(creature, articulators)
  if not next(articulators) then
    return true
  end
  for _, articulator in ipairs(articulators) do
    local castes_okay = true
    for caste_index, caste in ipairs(creature.caste) do
      if ((articulator.creature and creature ~= articulator.creature) or
          (articulator.caste_index and
           caste_index ~= articulator.caste_index) or
          (articulator.creature_flag and
           not creature.flags[articulator.creature_flag]) or
          (articulator.caste_flag and
           not caste.flags[articulator.caste_flag]) or
          (articulator.creature_class and not utils.linear_index(
           caste.creature_class, articulator.creature_class, 'value'))) then
        castes_okay = false
        break
      end
      local bp_applies = not articulator.bp
      local bp_category_applies = not articulator.bp_category
      local bp_flag_applies = not articulator.bp_flag
      if not (bp_applies and bp_category_applies and bp_flag_applies) then
        for _, bp in ipairs(caste.body_info.body_parts) do
          if bp.token == articulator.bp then
            bp_applies = true
            break
          elseif bp.category == articulator.bp_category then
            bp_category_applies = true
            break
          elseif articulator.bp_flag and bp.flags[articulator.bp_flag] then
            bp_flag_applies = true
            break
          end
        end
      end
      if not (bp_applies and bp_category_applies and bp_flag_applies) then
        castes_okay = false
        break
      end
    end
    if castes_okay then
      return true
    end
  end
  return false
end

if TEST then
  local c1 =
    {caste={{body_info={body_parts={{token='BP1', category='BC1',
                                     flags={BFT1=true, BFF1=false}},
                                    {token='BP2', category='BC2',
                                     flags={BFT2=true, BFF2=false}}}},
             creature_class={{value='CC1'}},
             flags={CFT1=true, CFF1=false}}},
     flags={FT1=true, FF1=false}}
  local c2 = copyall(c1)
  assert_eq(can_articulate(c1, {}), true)
  assert_eq(can_articulate(c1, {{}}), true)
  assert_eq(can_articulate(c1, {{bp='x'}}), false)
  assert_eq(can_articulate(c1, {{bp_category='x'}}), false)
  assert_eq(can_articulate(c1, {{bp_flag='BFF1'}}), false)
  assert_eq(can_articulate(c1, {{creature=c2}}), false)
  assert_eq(can_articulate(c1, {{creature_class='x'}}), false)
  assert_eq(can_articulate(c1, {{creature_flag='FF1'}}), false)
  assert_eq(can_articulate(c1, {{caste_index=2}}), false)
  assert_eq(can_articulate(c1, {{caste_flag='CFF1'}}), false)
  assert_eq(can_articulate(c1, {{bp='BP1'}}), true)
  assert_eq(can_articulate(c1, {{bp_category='BC1'}}), true)
  assert_eq(can_articulate(c1, {{bp_flag='BFT2'}}), true)
  assert_eq(can_articulate(c1, {{creature=c1}}), true)
  assert_eq(can_articulate(c1, {{creature_class='CC1'}}), true)
  assert_eq(can_articulate(c1, {{creature_flag='FT1'}}), true)
  assert_eq(can_articulate(c1, {{caste_index=1}}), true)
  assert_eq(can_articulate(c1, {{caste_flag='CFT1'}}), true)
  assert_eq(can_articulate(c1, {{bp='x'}, {}}), true)
  assert_eq(can_articulate(c1, {{bp='BP1', bp_category='x'}}), false)
  assert_eq(
    can_articulate(c1, {{bp='BP1', creature_flag='FT1', caste_flag='CFT1'}}),
    true)
end

--[[
Extracts a bit from a bitfield.

Args:
  bitfield: A bitfield.
  b: The bit to get, from 0 up.

Returns:
  The value of bit `b` in `bitfield` (0 or 1).
]]
local function bitfield_get(bitfield, b)
  local int = bitfield[math.floor(b / 32) + 1]
  return int and bit32.extract(int, b % 32) or 0
end

if TEST then
  assert_eq(bitfield_get({}, 158), 0)
  assert_eq(bitfield_get({0x0, 0x0, 0x2}, 65), 1)
end

--[[
Sets a bit in a bitfield.

Args:
  bitfield! A bitfield.
  b: The bit to set, from 0 up.
  v: The value (0 or 1) to set it to.

Returns:
  `bitfield`.
]]
local function bitfield_set(bitfield, b, v)
  local e = math.floor(b / 32) + 1
  local int = bitfield[e]
  if not int then
    for i = #bitfield + 1, e do
      bitfield[i] = 0
    end
  end
  bitfield[e] = bit32.replace(bitfield[e], v, b % 32)
  return bitfield
end

if TEST then
  assert_eq(bitfield_set({}, 0, 1), {0x1})
  assert_eq(bitfield_set({}, 1, 1), {0x2})
  assert_eq(bitfield_set({}, 31, 1), {0x80000000})
  assert_eq(bitfield_set({}, 32, 1), {0x0, 0x1})
  assert_eq(bitfield_set({0xA0}, 0, 1), {0xA1})
  assert_eq(bitfield_set({0xA0}, 5, 0), {0x80})
end

--[[
Converts a set of scalings to a set of links.

Args:
  scalings: A sequence of scalings.
  dispersions: A sequence of dispersions.
  node_to_dimension: A map of node indices to dimensions.
  node_count: The number of nodes in the phonology.

Returns:
  A sequence of links sorted in increasing order by strength.
]]
local function make_links(scalings, dispersions, node_to_dimension, node_count)
  local links = {}
  local links_map = {}
  for sods, seq in pairs({scalings=scalings, dispersions=dispersions}) do
    for _, sod in ipairs(seq) do
      for n1 = 1, node_count - 1 do
        local d1 = node_to_dimension[n1]
        if d1 and bitfield_get(sod.mask, n1 - 1) == 1 then
          for n2 = n1 + 1, node_count do
            local d2 = node_to_dimension[n2]
            if d2 and bitfield_get(sod.mask, n2 - 1) == 1 then
              local link = {d1=d1, d2=d2, scalings={}, dispersions={},
                            [sods]={sod}, strength=sod.strength or 0}
              if not links_map[d1] then
                links_map[d1] = {[d2]=link}
              elseif not links_map[d1][d2] then
                links_map[d1][d2] = link
              else
                link = links_map[d1][d2]
                link[sods][#link[sods] + 1] = sod
                link.strength = link.strength + (sod.strength or 0)
                link = nil
              end
              links[#links + 1] = link
            end
          end
        end
      end
    end
  end
  return utils.sort_vector(links, 'strength')
end

if TEST then
  local node_to_dimension = {}
  for i = 1, 5 do
    node_to_dimension[i] = {id=i}
  end
  assert_eq(make_links({}, {}, node_to_dimension, 5), {})
  local s123_3 = {mask={0x7}, values={}, scalar=0.25, strength=3}
  local s23_7 = {mask={0x6}, values={}, scalar=0.125, strength=7}
  local s23_9 = {mask={0x6}, values={}, scalar=0.1, strength=9}
  local s34_4 = {mask={0xC}, values={}, scalar=0.2, strength=4}
  local d123 = {mask={0x7}, values_1={}, values_2={}, scalar=0.25}
  local d24 = {mask={0xA}, values_1={}, values_2={}, scalar=0.2}
  local d34 = {mask={0xC}, values_1={}, values_2={}, scalar=0.2}
  assert_eq(make_links({s123_3, s23_7, s23_9, s34_4}, {d123, d24, d34},
                       node_to_dimension, 5),
            {{d1={id=2}, d2={id=4}, dispersions={d24}, scalings={},
              strength=0},
             {d1={id=1}, d2={id=3}, dispersions={d123}, scalings={s123_3},
              strength=3},
             {d1={id=1}, d2={id=2}, dispersions={d123}, scalings={s123_3},
              strength=3},
             {d1={id=3}, d2={id=4}, dispersions={d34}, scalings={s34_4},
              strength=4},
             {d1={id=2}, d2={id=3}, dispersions={d123},
              scalings={s123_3, s23_7, s23_9}, strength=19}})
end

--[[
Adds scalings and dispersions to a dimension and its descendants.

Args:
  dimension! A dimension.
  phonology: A phonology to get scalings and dispersions from.

Returns:
  `dimension`.
]]
local function add_scalings_and_dispersions(dimension, phonology)
  if dimension.d1 then
    for _, sods in ipairs({'scalings', 'dispersions'}) do
      for _, sod in ipairs(phonology[sods]) do
        if (bitfield_equals(dimension.mask, sod.mask, sod.mask) and
            not bitfield_equals(dimension.d1.mask, sod.mask, sod.mask) and
            not bitfield_equals(dimension.d2.mask, sod.mask, sod.mask)) then
          dimension[sods][#dimension[sods] + 1] = sod
        end
      end
    end
    add_scalings_and_dispersions(dimension.d1, phonology)
    add_scalings_and_dispersions(dimension.d2, phonology)
  end
  return dimension
end

if TEST then
  -- TODO
end

--[[
Randomly generates a dimension for a phonology given a target creature.

Args:
  rng! A random number generator.
  phonology: A phonology.
  creature: A `creature_raw`, as from
    `df.global.world.raws.creatures.all`.

Returns:
  A dimension which is the root of a binary tree of dimensions. The
    children of a node in the tree are in `d1` and `d2`.
]]
local function get_dimension(rng, phonology, creature)
  if not can_articulate(creature, phonology.articulators) then
    -- TODO: Handle this problem by choosing another phonology.
    -- TODO: Don't bother doing this until sign languages are in though.
    qerror(creature.creature_id .. ' cannot use its assigned phonology.')
  elseif phonology.dimension then
    return add_scalings_and_dispersions(phonology.dimension, phonology)
  end
  local nodes = phonology.nodes
  local dimensions = {}
  local node_to_dimension = {}
  local inarticulable_node_index = nil
  for i, node in ipairs(nodes) do
    if not (inarticulable_node_index and
            dominates(inarticulable_node_index, i, nodes)) then
      if can_articulate(creature, node.articulators) then
        local dimension =
          {id={i}, nodes={i}, mask=bitfield_set({}, i - 1, 1),
           cache=node.feature and {{score=1 - node.prob}, {score=node.prob, i}}
           or {{score=1, i}}}
        dimensions[#dimensions + 1] = dimension
        node_to_dimension[i] = dimension
      else
        inarticulable_node_index = i
      end
    end
  end
  local links = make_links(phonology.scalings, phonology.dispersions,
                           node_to_dimension, #nodes)
  while #dimensions > 1 do
    merge_dimensions(dimensions, links)
  end
  return dimensions[1]
end

--[[
Converts a dimension value to a bitfield.

Args:
  value: A dimension value.

Returns:
  A bitfield.
]]
local function dimension_value_to_bitfield(value)
  local value_bitfield = {}
  for _, n in ipairs(value) do
    bitfield_set(value_bitfield, n - 1, 1)
  end
  return value_bitfield
end

--[[
Compares dimension values.

Args:
  a: A dimension value.
  b: A dimension value.

Returns:
  -1 if a < b, 1 if a > b, and 0 otherwise. The comparison relation is a
    partial order but is otherwise unspecified.
]]
local function compare_dimension_values(a, b)
  a = dimension_value_to_bitfield(a)
  b = dimension_value_to_bitfield(b)
  if #a < #b then
    return -1
  elseif #b < #a then
    return 1
  end
  for i = 1, #a do
    if a[i] < b[i] then
      return -1
    elseif b[i] < a[i] then
      return 1
    end
  end
  return 0
end

-- TODO: Remove this when done debugging.
local function print_val(val)
  if not phonologies then return end
  local ph = {}
  for i, ni in pairs(val) do
    if type(i) == 'number' then
      ph[ni] = true
    end
  end
  print(get_lemma(phonologies[1], {ph}), val.score)
  for ni in pairs(ph) do
    if phonologies[1].nodes[ni].feature then
      --print('\t'..phonologies[1].nodes[ni].name)
    end
  end
end

--[[
Creates a grid.

The grid's row and column metadata objects' total scores are not set.

Args:
  mask_1: A bitfield.
  mask_2: A bitfield.
  values_1: A sequence of dimension values.
  values_2: A sequence of dimension values.

Returns:
  A grid using `mask_1` and `values_1` for the rows and `mask_2` and
    `values_2` for the columns. The scores in the grid are the products
    of the dimension values' scores from the relevant row and column.
]]
local function make_grid(mask_1, mask_2, values_1, values_2)
  local grid = {rows={mask=mask_1, values=values_1},
                cols={mask=mask_2, values=values_2}, grid={}}
  for j, value_2 in ipairs(values_2) do
    grid.cols[j] = {score=0, value=value_2}
  end
  for i, value_1 in ipairs(values_1) do
    grid.rows[i] = {score=0, value=value_1}
    grid.grid[i] = {}
    for j, value_2 in ipairs(values_2) do
      grid.grid[i][j] = value_1.score * value_2.score
    end
  end
  return grid
end

if TEST then
  local mask_1 = {0x1}
  local mask_2 = {0x2}
  local values_1 = {{1, score=2}}
  local values_2 = {{2, score=3}, {3, score=5}}
  assert_eq(make_grid(mask_1, mask_2, values_1, values_2),
            {rows={mask=mask_1, values=values_1, {score=0, value=values_1[1]}},
             cols={mask=mask_2, values=values_2,
                   {score=0, value=values_2[1]}, {score=0, value=values_2[2]}},
             grid={{6, 10}}})
end

--[[
Finds scalings which are as satisfied as possible by a row or column.

Args:
  roc_values: A bitfield representing the dimensions associated with a
    row or column.
  le: Whether to use the `<=` operator when comparing indexes in
    `scalings` to `pivot`.
  pivot: A number in [0, `#scalings`]. If `le` is true, only scalings in
    [1, `pivot`] may be returned; otherwise, only scalars in [`pivot +
    1`, `#scalings`] may be returned.
  scalings: A sequence of scalings.
  roc_mask: A bitfield representing the dimensions that could possibly
    be in `roc_values`.

Returns:
  A sequence of those scalings in `scalings` which could possibly apply
    to dimension values in this row or column.
]]
local function get_satisfied_scalings(roc_values, le, pivot, scalings, roc_mask)
  local rv = {}
  for i, scaling in ipairs(scalings) do
    if ((i <= pivot) == le and
        bitfield_equals(roc_values, scaling.values, roc_mask, scaling.mask))
    then
      rv[#rv + 1] = scaling
    end
  end
  return rv
end

if TEST then
  local scalings = {{values={0xB}, mask={0x1B}, scalar=0, strength=math.huge},
                    {values={0x8}, mask={0x1B}, scalar=0, strength=math.huge},
                    {values={0x1B}, mask={0x1B}, scalar=0, strength=math.huge}}
  assert_eq(get_satisfied_scalings({0xD}, true, 2, scalings, {0x2D}),
            {scalings[1]})
  assert_eq(get_satisfied_scalings({0xD}, false, 2, scalings, {0x2D}),
            {scalings[3]})
end

--[[
Adds a modified copy of a row or column for each scaling in a sequence.

The following assumes `row` is true. When it is false, everything is the
same except rows and columns are switched.

Each scaling's new row is a based on the original row. For each score in
the row, the score is the original score scaled by the scaling if the
scaling applies, or 0 if the scaling does not apply. A score in the
original row is set to 0 if any scaling applies to that column.

The point is to let `get_dimension_values` treat rows with identical
dimension values distinctly if different scalings apply to them. It can
choose dimension value/scaling pairs instead of just dimension values.

The grid's row and column metadata objects' total scores are not kept
synchronized with the splitting and must be fixed by the caller.

Args:
  grid! The grid to split.
  is_row: Whether to split a row, as opposed to a column.
  x: The index of the row or column to split.
  scalings: A sequence of scalings to make new rows or columns for.
]]
local function split_roc(grid, is_row, x, scalings)
  local this, that = 'cols', 'rows'
  if is_row then
    this, that = that, this
  end
  local old_roc = grid[this][x]
  old_roc.family = {x}
  local mask = grid[that].mask
  local zeroes = {}
  for _, scaling in ipairs(scalings) do
    local new = {}
    for y, roc in ipairs(grid[that]) do
      local score = (
        bitfield_equals(dimension_value_to_bitfield(roc.value),
                        scaling.values, mask, scaling.mask) and
        grid.grid[is_row and x or y][is_row and y or x] * scaling.scalar or 0)
      new[y] = score
      if score ~= 0 then
        zeroes[y] = true
      end
    end
    if is_row then
      grid.grid[#grid.grid + 1] = new
    else
      for i, row in ipairs(grid.grid) do
        row[#row + 1] = new[i]
      end
    end
    grid[this][#grid[this] + 1] =
      {score=0, value=old_roc.value, family=old_roc.family}
    old_roc.family[#old_roc.family + 1] = #grid[this]
  end
  for y = 1, #grid[that] do
    if zeroes[y] then
      grid.grid[is_row and x or y][is_row and y or x] = 0
    end
  end
end

if TEST then
  local scalings = {{values={0x3}, mask={0x3}, scalar=0.5, strength=2},
                    {values={0x16}, mask={0x16}, scalar=0.1, strength=10}}
  local grid = {grid={{1, 10, 0.25}, {1, 1, 1}},
                rows={values={1, 3}, mask={0x5},
                      {score=6, value={1, 3}}, {score=3, value={}}},
                cols={values={2, 5}, mask={0x12}, {score=2, value={}},
                      {score=11, value={2}}, {score=1.25, value={2, 5}}}}
  split_roc(grid, true, 1, scalings)
  local f = {1, 3, 4}
  assert_eq(grid,
            {grid={{1, 0, 0}, {1, 1, 1}, {0, 5, 0.125}, {0, 0, 0.025}},
             rows={values={1, 3}, mask={0x5},
                   {score=6, value={1, 3}, family=f}, {score=3, value={}},
                   {score=0, value={1, 3}, family=f},
                   {score=0, value={1, 3}, family=f}},
             cols={values={2, 5}, mask={0x12}, {score=2, value={}},
                   {score=11, value={2}}, {score=1.25, value={2, 5}}}})
  grid = {grid={{1, 1}, {10, 1}, {0.25, 1}},
          rows={values={2, 5}, mask={0x12}, {score=2, value={}},
                {score=11, value={2}}, {score=1.25, value={2, 5}}},
          cols={values={1, 3}, mask={0x5},
                {score=6, value={1, 3}}, {score=3, value={}}}}
  split_roc(grid, false, 1, scalings)
  assert_eq(grid,
            {grid={{1, 1, 0, 0}, {0, 1, 5, 0}, {0, 1, 0.125, 0.025}},
             rows={values={2, 5}, mask={0x12}, {score=2, value={}},
                   {score=11, value={2}}, {score=1.25, value={2, 5}}},
             cols={values={1, 3}, mask={0x5},
                   {score=6, value={1, 3}, family=f}, {score=3, value={}},
                   {score=0, value={1, 3}, family=f},
                   {score=0, value={1, 3}, family=f}}})
end

--[[
Sets the scores of a grid to their initial values.

The grid comes in with scores equal to the products of the appropriate
rows and columns. This function multiplies each score by the scalar of
every applicable scaling.

Args:
  grid! A grid.
  scalings: The scalings that apply to this grid.

Returns:
  `grid`, with new scores.
]]
local function initialize_grid_scores(grid, scalings)
  local col_scalings = {}
  for j, col in ipairs(grid.cols) do
    col_scalings[j] = get_satisfied_scalings(
      dimension_value_to_bitfield(col.value), false, 0, scalings,
      grid.cols.mask)
  end
  for i, row in ipairs(grid.grid) do
    for j, score in ipairs(row) do
      local row_scalings = get_satisfied_scalings(
        dimension_value_to_bitfield(grid.rows[i].value), false, 0, scalings,
        grid.rows.mask)
      local scalings_intersection = {}
      local start = 1
      for _, scaling in ipairs(col_scalings[j]) do
        for i = start, #row_scalings do
          if scaling == row_scalings[i] then
            scalings_intersection[#scalings_intersection + 1] = scaling
            start = i
            break
          end
        end
        start = start + 1
      end
      for _, scaling in ipairs(scalings) do
        if bitfield_equals(
          dimension_value_to_bitfield(
            concatenate(grid.rows[i].value, grid.cols[j].value)),
          scaling.values, scaling.mask)
        then
          row[j] = row[j] * scaling.scalar
        end
      end
    end
  end
  return grid
end

if TEST then
  local grid = {grid={{1, 2, 3}, {4, 5, 6}},
                rows={values={1}, mask={0x1},
                      {score=0, value={}}, {score=0, value={1}}},
                cols={values={2, 3}, mask={0x6}, {score=0, value={}},
                      {score=0, value={2}}, {score=0, value={2, 3}}}}
  assert_eq(initialize_grid_scores(grid, {{mask={0x3}, values={0x2}, scalar=0,
                                           strength=math.huge}}),
            {grid={{1, 0, 0}, {4, 5, 6}},
             rows={values={1}, mask={0x1},
                   {score=0, value={}}, {score=0, value={1}}},
             cols={values={2, 3}, mask={0x6}, {score=0, value={}},
                   {score=0, value={2}}, {score=0, value={2, 3}}}})
end

--[[
Makes a grid's metadata match the actual scores in the grid.

Args:
  grid! A grid.

Returns:
  `grid`.
]]
local function fix_grid_score_totals(grid)
  for i = 1, #grid.rows do
    grid.rows[i].score = 0
  end
  for j = 1, #grid.cols do
    grid.cols[j].score = 0
  end
  for i, row in ipairs(grid.grid) do
    for j, score in ipairs(row) do
      grid.rows[i].score = grid.rows[i].score + score
      grid.cols[j].score = grid.cols[j].score + score
    end
  end
  return grid
end

--[[
Splits a grid's rows and columns.

Args:
  grid! A grid.
  pivot: The number of scalings to use for splitting rows, as opposed to
    splitting columns.
  scalings: A sequence of scalings.

Returns:
  `grid`.
]]
local function split_grid(grid, pivot, scalings)
  for x, rocs in ipairs({'rows', 'cols'}) do
    local is_row = x == 1
    for i = 1, #grid[rocs] do
      local roc = grid[rocs][i]
      local scalings_for_splitting = get_satisfied_scalings(
        dimension_value_to_bitfield(roc.value), is_row, pivot, scalings,
        grid[rocs].mask)
      split_roc(grid, is_row, i, scalings_for_splitting)
    end
  end
  return fix_grid_score_totals(grid)
end

--[[
Zeroes every cell in a grid sharing a family with a given row or column.

Args:
  grid! A grid.
  i: A row index.
  j: A column index.
]]
local function clear_roc_family(grid, i, j)
  for _, i0 in ipairs(grid.rows[i].family) do
    grid.grid[i0][j] = 0
  end
  for _, j0 in ipairs(grid.cols[j].family) do
    grid.grid[i][j0] = 0
  end
end

--[[
Updates a grid's scores based on its dispersions.

After a dimension value has been picked from a grid, other dimension
values in that grid may change their scores accordingly. This is called
dispersion.

Args:
  grid! A grid.
  dispersions: A sequence of dispersions.
  i: The index of the picked row.
  j: The index of the picked column.
]]
local function apply_dispersions(grid, dispersions, i, j)
  -- TODO: Once a value is chosen, revert it to its predispersion score.
  local picked_value = dimension_value_to_bitfield(
    concatenate(grid.rows[i].value, grid.cols[j].value))
  for _, dispersion in ipairs(dispersions) do
    local v
    if bitfield_equals(dispersion.values_1, picked_value) then
      v = 'values_2'
    elseif bitfield_equals(dispersion.values_2, picked_value) then
      v = 'values_1'
    end
    if v then
      for i2, row in ipairs(grid.grid) do
        for j2, score in ipairs(row) do
          if ((i ~= i2 or j ~= j2) and
              bitfield_equals(
                dispersion[v],
                dimension_value_to_bitfield(concatenate(
                  grid.rows[i2].value, grid.cols[j2].value)),
                dispersion.mask)) then
            grid.grid[i2][j2] = score * dispersion.scalar
          end
        end
      end
    end
  end
end

if TEST then
  local grid = {grid={{0, 1}, {1, 1}},
                rows={values={1}, mask={0x1},
                      {score=2, value={1}}, {score=2, value={}}},
                cols={values={2}, mask={0x2},
                      {score=2, value={2}}, {score=2, value={}}}}
  apply_dispersions(
    grid, {{scalar=0.5, mask={0x3}, values_1={0x3}, values_2={0x0}}}, 1, 1)
  assert_eq(grid.grid, {{0, 1}, {1, 0.5}})
end

--[[
Randomly chooses dimension values from a grid without replacement.

If a dispersion applies to the chosen value, the other value in the
dispersion is scaled accordingly.

Args:
  rng! A random number generator.
  grid! A grid.
  dispersions: A sequence of the dispersions that might apply when a
    dimension value is chosen in this grid.

Returns:
  A sequence of dimension values from the grid, or nil if there is
    nothing left.
]]
local function pick_from_grid(rng, grid, dispersions)
  local rocs = grid.rows
  if grid.n == 1 then
    rocs = grid.cols
  elseif grid.n then
    rocs = concatenate(rocs, grid.cols)
  end
  local total = 0
  for _, roc in ipairs(rocs) do
    total = total + roc.score
  end
  local target = rng:drandom() * total
  local sum = 0
  for x, roc in ipairs(rocs) do
    sum = sum + roc.score
    if sum > target then
      local rv = {}
      if x <= #grid.rows and grid.n ~= 1 then
        for j = 1, #grid.cols do
          if grid.grid[x][j] ~= 0 then
            rv[#rv + 1] = utils.sort_vector(
              concatenate(grid.rows[x].value, grid.cols[j].value))
            rv[#rv].score = grid.grid[x][j]
            clear_roc_family(grid, x, j)
            apply_dispersions(grid, dispersions, x, j)
          end
        end
      else
        if grid.n ~= 1 then
          x = x - #grid.rows
        end
        for i = 1, #grid.rows do
          if grid.grid[i][x] ~= 0 then
            rv[#rv + 1] = utils.sort_vector(
              concatenate(grid.rows[i].value, grid.cols[x].value))
            rv[#rv].score = grid.grid[i][x]
            clear_roc_family(grid, i, x)
            apply_dispersions(grid, dispersions, i, x)
          end
        end
      end
      fix_grid_score_totals(grid)
      grid.n = (grid.n or 0) + 1
      return rv
    end
  end
end

local function seq_join(sequence)
  local s = ''
  for i, e in ipairs(sequence) do
    if i ~= 1 then
      s = s .. ':'
    end
    s = s .. phonologies[1].nodes[e].name
  end
  return s
end

-- TODO: Remove this when done debugging.
local function print_dimension(nodes, dimension, indent, nonrecursive)
  if not dimension then
    return
  end
  if indent == '' then
    print()
  end
  print(indent .. (dimension.id and (dimension.id[1] .. ':' .. (dimension.id[2] or '-') .. '\t' .. seq_join(dimension.id)) or '---'))
  if not nonrecursive then
    indent = indent .. '.'
    print_dimension(nodes, dimension.d1, indent)
    print_dimension(nodes, dimension.d2, indent)
  end
end

--[[
Randomly chooses dimension values from a dimension without replacement.

Args:
  rng! A random number generator.
  dimension: A dimension.

Returns:
  A set of dimension values from the given dimension.
]]
local function get_dimension_values(rng, dimension)
  if dimension.d1 then
    local values_1 = get_dimension_values(rng, dimension.d1)
    local values_2 = get_dimension_values(rng, dimension.d2)
    local grid = split_grid(
      initialize_grid_scores(
        make_grid(dimension.d1.mask, dimension.d2.mask, values_1, values_2),
        dimension.scalings),
      rng:random(#dimension.scalings + 1), shuffle(dimension.scalings, rng))
    if dimension.peripheral then
      while #dimension.cache < MINIMUM_DIMENSION_CACHE_SIZE do
        local value = table.remove(values_1, 1)
        if value then
          dimension.cache[#dimension.cache + 1] = value
          values_1, values_2 = values_2, values_1
        elseif next(values_2) then
          values_1 = values_2
        else
          break
        end
      end
    else
      while #dimension.cache < MINIMUM_DIMENSION_CACHE_SIZE do
        local values = pick_from_grid(rng, grid, dimension.dispersions)
        if values then
          dimension.cache = merge_sorted_sequences(
            dimension.cache,
            utils.sort_vector(values, nil, compare_dimension_values),
            compare_dimension_values)
        else
          break
        end
      end
    end
  end
  return dimension.cache
end

--[[
Gets a dimension value's sonority.

Args:
  dimension_value: A dimension value.
  phonology: A phonology.

Returns:
  The sum of the sonorities of the features in the dimension value.
]]
local function get_sonority(dimension_value, phonology)
  local sonority = 0
  for _, i in ipairs(dimension_value) do
    sonority = sonority + phonology.nodes[i].sonority
  end
  return sonority
end

--[[
Converts a dimension value to a phoneme.

Args:
  dimension_value: A dimension value.
  node_count: The number of nodes in the phonology that produced the
    dimension value.

Returns:
  `dimension_value` as a phoneme.
]]
local function dimension_value_to_phoneme(dimension_value, node_count)
  local phoneme = {}
  for i = 1, node_count do
    phoneme[i] = false
  end
  for _, i in ipairs(dimension_value) do
    phoneme[i] = true
  end
  return phoneme
end

if TEST then
  assert_eq(dimension_value_to_phoneme({}, 3), {false, false, false})
  assert_eq(dimension_value_to_phoneme({1, 3}, 4), {true, false, true, false})
end

--[[
Returns a value unchanged.

Args:
  x: A value.

Returns:
  `x`.
]]
local function _(x)
  return x
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
local function r(x)
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
local function k(x)
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
local function t(key)
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
local function m(m)
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
local function x(c)
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
local function xp(c)
  c = x(c)
  c.is_phrase = true
  return c
end

--[[
Randomly chooses dimension values from a phonology without replacement.

The difference between this and `get_dimension_values`, besides the
types of the inputs, is that the former tries to generate a
self-consistent inventory, whereas the latter picks values purely at
random from the list of phonetic symbols. Symbols are meant to be a
part of the UI, not part of the world, which is why this is hacky.

Args:
  rng! A random number generator.
  phonology: A phonology.
  size: A target inventory size.

Returns:
  A set of dimension values from the given phonology.
]]
local function random_hacky_inventory(rng, phonology, size)
  local inventory = {}
  for i, symbol in ipairs(shuffle(phonology.symbols, rng)) do
    if i > size then
      break
    end
    local dv = {}
    for n = 1, #phonology.nodes do
      if symbol.features[n] then
        dv[#dv + 1] = n
      end
    end
    inventory[#inventory + 1] = dv
  end
  return inventory
end

--[[
Randomly generates a language parameter table.

Args:
  phonology: The phonology of the language to generate.
  seed: The seed of the random number generator to use.
  creature: A `creature_raw`, as from
    `df.global.world.raws.creatures.all`.

Returns:
  A language parameter table.
]]
local function random_parameters(phonology, seed, creature)
  local rng = dfhack.random.new(seed)
  -- TODO: normal distribution of inventory sizes
  local size = 10 + rng:random(21)
  local inventory = random_hacky_inventory(rng, phonology, size)
    --get_dimension_values(rng, get_dimension(rng, phonology, creature))
  size = #inventory -- TODO: Don't assume!
  local parameters = {max_sonority=0, min_sonority=math.huge, inventory={},
                      constraints=shuffle(copyall(phonology.constraints), rng)}
  for i = 1, size do
    local dimension_value = table.remove(inventory, 1)
    local sonority = get_sonority(dimension_value, phonology)
    parameters.inventory[i] =
      {dimension_value_to_phoneme(dimension_value, #phonology.nodes), sonority}
    parameters.min_sonority = math.min(sonority, parameters.min_sonority)
    parameters.max_sonority = math.max(sonority, parameters.max_sonority)
  end
  parameters.strategies = {}  -- TODO: Fill in some movement strategies.
  return parameters
end

--[[
Gets the language parameter table of a lect.

If `lect` does not have its language parameter table set, then it is
first created using its seed.

Args:
  lect! A lect.

Returns:
  The language parameter table of `lect`.
]]
-- TODO: This function takes minutes to run. The cache helps when testing.
local cached_parameters
local function get_parameters(lect)
  lect.seed = 0
  if cached_parameters then
    return cached_parameters
  end
  if not lect.parameters then
    lect.parameters = random_parameters(
      lect.phonology, lect.seed, df.creature_raw.find(lect.community.race))
  end
  --cached_parameters = lect.parameters
  return lect.parameters
end

--[[
TODO
]]
local function contextualize(constituent, context)
  local context_key = constituent.context_key
  if context_key then
    return context_callbacks[constituent.context_callback](
      context[context_key], context)
  end
  return {
    n1=constituent.n1 and contextualize(constituent.n1, context),
    n2=constituent.n2 and contextualize(constituent.n2, context),
    features=constituent.features,
    morphemes=constituent.morphemes,
    is_phrase=constituent.is_phrase,
    ref=constituent.ref,
    text=constituent.text,
  }
end

if TEST then
  -- TODO
end

local function cc(callback_name, key)
  return {context_key=key, context_callback=callback_name}
end

local ps = {}

--[[

Args:
  arg:
  specifier or false
  adjunct*
  head+complement or false
]]
function ps.xp(arg)
  local c = arg[#arg] or x{}
  for i = #arg - 1, 2, -1 do
    c = x{arg[i], c}
  end
  return xp{arg[1] or x{}, c}
end

--[[


Args:
  arg!
  deg=
  q=
  adjunct*
  adjective+arguments
]]
function ps.adj(arg)
  table.insert(arg, 1, false)
  return ps.adv(arg)
end

--[[


Args:
  arg!
  false?
  deg=
  q=
  adjunct*
  adjective+arguments
]]
ps.adv = function(arg)
  if arg[1] then
    local deg = arg.deg
    local q = arg.q
    arg.deg = nil
    arg.q = nil
    return ps.xp{  -- DegP
      false,  -- TODO: measure, e.g. "two years"
      x{  -- Deg'
        deg or k'POS',  -- TODO: measure Deg
        ps.xp{  -- QP
          false,
          -- TODO: "than"
          x{  -- Q'
            q,
            ps.xp{  -- AdvP
              false,
              x{  --Adv'
                k'-ly',
                ps.adj(arg),
              },
            },
          },
        },
      },
    }
  else
    return ps.xp{  -- DegP
      false,  -- TODO: measure, e.g. "two years"
      x{  -- Deg'
        arg.deg or k'POS',  -- TODO: measure Deg
        ps.xp{  -- QP
          false,
          -- TODO: "than"
          x{  -- Q'
            arg.q,
            ps.xp(arg),  -- AP/AdvP
          },
        },
      },
    }
    end
end

--[[


Args:
  arg:
   x
   conjunction
   x
]]
function ps.conj(arg)
  return ps.xp{arg[1], x{arg[2], arg[3]}}
end

--[[


Args:
  arg!
    -- subject=
    -- mood=
    -- passive=
    -- tense=
    -- perfect=
    -- progressive=
    -- neg=
    -- adjunct*
    -- verb
]]
function ps.infl(arg)
  -- TODO:
  -- polite
  -- aspect
  -- sigma instead of neg
  if arg.subject then
    -- TODO: This is not how copulas work, though it works in a pinch.
    arg[1] = t'be'{
      agent=arg.subject,
      theme=arg[1],
    }
    arg.subject = nil
    return ps.infl(arg)
  end
  local rv
  table.insert(arg, 1, false)
  if arg.passive then
    local args = arg[#arg].args
    if args.theme then
      if args.agent then
        table.insert(arg, #arg - 2, t'by'{theme=args.agent})
        args.agent = nil
      end
      rv = ps.xp{false, x{k'PASSIVE', ps.xp(arg)}}
    else
      -- TODO: "I've been rained on." vs. "It has rained on me."
      -- What is "it" in those sentences? An expletive? A quasi-argument?
      -- Use active voice for such confusing cases for now.
    end
  else
    rv = ps.xp(arg)
  end
  if arg.progressive then
    rv = ps.xp{false, x{k'PROGRESSIVE', rv}}
  end
  if arg.perfect then
    rv = ps.xp{false, x{k'PERFECT', rv}}
  end
  if arg.mood then
    rv = ps.xp{false, x{arg.mood, rv}}
  end
  if arg.neg then
    rv = ps.xp{false, x{k'not', rv}}
  end
  -- TODO: Should k'INFINITIVE' create a different structure from +tense Ts?
  rv = ps.xp{false, x{arg.tense or k'PRESENT', rv}}
  return rv
end

--[[


Args:
  arg:
]]
function ps.ing(arg)
  return ps.xp{
    false,
    x{
      k'PRESENT_PARTICIPLE',
      arg[1],
    },
  }
end

--[[


Args:
  arg!
  -- amount=
  -- det=
  -- poss=
  -- rel=
  -- relative=
  -- adjuncts*
  -- noun/false
  -- plural=
]]
function ps.np(arg)
  -- TODO: What is the point of SpecNP if Det isn't in it?
  table.insert(
    arg, 1,
    arg.amount or arg.det or arg.poss or arg.rel or arg.relative or k'0,D')
  if arg.plural then
    arg[1].features.number = math.huge
  end
  if not arg[#arg] then
    arg[#arg] = k'0,N'
  end
  return ps.xp(arg)
end

--[[


Args:
  arg:
]]
function ps.past_participle(arg)
  -- adverb?
  -- verb
  -- TODO: adverb
  return ps.xp{
    false,
    x{
      k'PAST_PARTICIPLE',
      arg[#arg],
    },
  }
end

--[[


Args:
  arg!
]]
function ps.wh(arg)
  return xp{  -- CP
    x{f={wh=false}},
    x{
      k'that,C',
      ps.infl(arg),
    },
  }
end

ps.wh_bound = ps.wh

ps.wh_ever = ps.wh

--[[


Args:
  arg:
]]
function ps.fragment(arg)
  -- any
  return arg[1]
end

--[[


Args:
  arg:
]]
function ps.noise(arg)
  -- The point of this function is to mark noises. It isn't particularly
  -- useful on its own. Eventually there will be some way to ensure that
  -- "rawr" always sounds like a roar and "ah" like a gasp, for example.
  return arg
end

--[[


Args:
  arg:
]]
function ps.sentence(arg)
  -- any
  -- punct=
  -- TODO:
  -- vocative=
  -- [2]
  -- formality
  return ps.xp{false, x{k(arg.punct or 'SENTENCE SEPARATOR'), arg[1]}}
end

--[[


Args:
  arg!
]]
function ps.simple(arg)
  return ps.sentence{
    vocative=arg.vocative,
    ps.infl(arg),
    punct=arg.punct,
  }
end

--[[


Args:
  arg:
  sentence+
]]
function ps.utterance(arg)
  local c = arg[#arg]
  for i = #arg - 2, 1, -1 do
    c = ps.xp{arg[i], x{k'SENTENCE SEPARATOR', c}}
  end
  return c
end

--[[

]]
function ps.it()
  return k'it'
end

--[[

]]
function ps.me(context)
  context.me = {context.speaker}
  return cc('pronoun', 'me')
end

--[[

]]
function ps.that()
  return k'that'
end

--[[

]]
function ps.thee(context)
  context.thee = {context.hearers[0]}
  return cc('pronoun', 'thee')
end

--[[

]]
function ps.thee_inanimate(context)
  -- TODO: differentiate
  return ps.thee(context)
end

--[[

]]
function ps.them(context)
  context.them = {true, true}
  return cc('pronoun', 'them')
end

--[[

]]
function ps.this()
  return k'this'
end

--[[

]]
function ps.us_inclusive(context)
  context.us_inclusive = copyall(context.hearers)
  context.us_inclusive[#context.us_inclusive + 1] = context.speaker
  return cc('pronoun', 'us_inclusive')
end

--[[

]]
function ps.us_exclusive(context)
  context.us_inclusive = copyall(context.hearers)
  context.us_inclusive[#context.us_inclusive + 1] = true
  return cc('pronoun', 'us_inclusive')
end

--[[

]]
function ps.you(context)
  return cc('pronoun', 'hearers')
end

--[[


Args:
  arg!
  verb
]]
function ps.lets(arg)
  if not arg.args then
    arg.args = {}
  end
  arg.args.agent = ps.us_inclusive(context)
  return ps.simple{
    mood=k'IMPERATIVE',
    arg[1],
  }
end

--[[


Args:
  arg:
]]
function ps.there_is(arg)
  -- noun
  -- punct=
  return ps.simple{
    t'be'{
      theme=arg[0],
    },
    punct=arg.punct,
  }
end

--[[


Args:
  arg:
]]
function ps.artifact_name(arg)
  -- artifact_record ID
  return {text='\xae' ..
          dfhack.TranslateName(df.artifact_record.find(arg).name) .. '\xaf'}
end

--[[


Args:
  arg:
]]
function ps.building_type_name(arg)
  -- building_type
  return r('building_type' .. WORD_ID_CHAR .. df.building_type[arg])
end

--[[


Args:
  arg:
]]
function ps.hf_name(arg)
  -- historical_figure ID
  return {text='\xae' ..
          dfhack.TranslateName(df.artifact_record.find(arg).name) .. '\xaf'}
end

--[[


Args:
  arg:
]]
function ps.item(arg)
  -- item ID
  --[[
  TODO:
  Memorial: memorial to $name
  item_liquidst: water vs lye
  item_threadst: web vs non-web
  ]]
  local item = df.item.find(arg)
  local coin_entity, coin_ruler
  if item._type == df.item_coinst then
    local coin_batch = df.coin_batch.find(item.coin_batch)
    coin_entity = t'made by entity'{
      theme=r('ENTITY' .. WORD_ID_CHAR ..
              df.historical_entity.find(coin_batch.entity).id),
    }
    -- TODO: coin_ruler = df.historical_figure.find(coin_batch.ruler)
  end
  local matinfo = dfhack.matinfo.decode(item)
  local material = matinfo.mode
  if material == 'creature' then
    material = material .. WORD_ID_CHAR .. matinfo[material].creature_id
  elseif matinfo[material] then
    material = material .. WORD_ID_CHAR .. matinfo[material].id
  end
  material = material .. WORD_ID_CHAR .. matinfo.material.id
  local handedness
  if item._type == df.item_glovesst then
    if item.handedness[0] then
      handedness = ps.adj{k'right-hand'}
    elseif item.handedness[1] then
      handedness = ps.adj{k'left-hand'}
    end
  end
  local item_type = tostring(item._type):match('^<type: (.*)>$')
  local head_key = item_type .. WORD_ID_CHAR
  if item._type == df.item_slabst then
    head_key = head_key .. df.slab_engraving_type[item.engraving_type]
  else
    local no_error, subtype = dfhack.pcall(function() return item.subtype end)
    if no_error then
      head_key = head_key .. subtype.id
    else
      head_key = 'ITEM_TYPE' .. WORD_ID_CHAR .. item_type
    end
  end
  local t = {false}
  t[#t + 1] = coin_entity
  t[#t + 1] = coin_ruler
  t[#t + 1] = t'made of material'{theme=r(material)}
  t[#t + 1] = handedness
  t[#t + 1] = r(head_key)
  -- TODO: fallback: "object I can't remember"
  return ps.xp(t)
end

--[[


Args:
  arg:
]]
function ps.job_skill(arg)
  -- job_skill
  return r('job_skill' .. WORD_ID_CHAR .. df.job_skill[arg])
end

--[[


Args:
  arg:
]]
function ps.my_relationship_type_name(arg)
  -- unit_relationship_type
  return ps.np{
    t([[unit_relationship_type]] .. WORD_ID_CHAR ..
      df.unit_relationship_type[arg])
      {relative=ps.thee(context)}
  }
end

--[[


Args:
  arg:
]]
function ps.relationship_type_name(arg)
  -- unit_relationship_type
  return r('unit_relationship_type' .. WORD_ID_CHAR ..
           df.unit_relationship_type[arg])
end

--[[

]]
function ps.world_name()
  return {text='\xae' ..
          dfhack.TranslateName(df.global.world.world_data.name) .. '\xaf'}
end

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
function context_callbacks.possessive_pronoun(c, context)
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

function context_callbacks.pronoun(c, context)
  return ps.xp{  --DP
    x{cc.possessive_pronoun(c, context)},
  }
end

--[[
Gets a constituent for an utterance.

Args:
  should_abort: Whether to abort the conversation.
  topic: A `talk_choice_type`.
  topic1: An integer whose exact interpretation depends on `topic`.
  topic2: Ditto.
  topic3: Ditto.
  topic4: Ditto.
  english: The English text of the utterance.
  speakers: The speaker of the report as a unit.
  hearers: The hearers of the report as a sequence of units.

Returns:
  The constituent corresponding to the utterance.
  The context in which the utterance was produced.
]]
local function get_constituent(should_abort, topic, topic1, topic2, topic3,
                               topic4, english, speaker, hearers)
  english = english:lower()  -- Normalize case. Assume English only uses ASCII.
    :gsub('s+', 's')  -- Counteract [LISP].
    :gsub(' +', ' ')  -- Double spaces are collapsed on report boundaries.
  local constituent
  local context = {
    speaker=speaker,
    hearers=hearers,
  }
  -- TODO: announcement_type TRAVEL_COMPLAINT
  -- name ' says, "' ComplainAgreement '"'
  if should_abort then
    constituent = k'goodbye'
  elseif (topic == df.talk_choice_type.Greet or
          topic == df.talk_choice_type.ReplyGreeting) then
    ----1
    -- greet*.txt
    local sentences = {}
    local hello
    if english:find('^hey') then
      hello = k'hey'
    elseif english:find('^greetings%. my name is ') then  -- [SPEAKER:TRANS_NAME]
    elseif english:find('^greetings') then
      hello = k'greetings'
    elseif english:find('^salutations') then
      hello = k'salutations'
    elseif english:find('^hello[ .]') then
      hello = k'hello'
    elseif english:find('^hellooo!') then
    elseif english:find('^look at you!') then
    elseif english:find('^a baby! how adorable!') then
    elseif english:find("^ah, hello%. i'm ") then  -- [SPEAKER:TRANS_NAME]
    elseif english:find('^i am .*%. can i be of some help%?') then -- [SPEAKER:TRANS_NAME]
    elseif english:find('^i am .*%. how can i be of service%?') then  -- [SPEAKER:TRANS_NAME]
    elseif english:find('^hello, .*%. i am .*%.') then  -- [AUDIENCE:RACE] [SPEAKER:TRANS_NAME]
    elseif english:find('%.%.%. your parents must have been interesting!') then  -- [AUDIENCE:FIRST_NAME]
    elseif english:find("^you know, you don't meet many people with the name .*%.") then  -- [AUDIENCE:FIRST_NAME]
    elseif english:find('^so, .*%.%.%. .*, was it%?') then  -- [AUDIENCE:FIRST_NAME] [AUDIENCE:FIRST_NAME]
    elseif english:find('%. does that mean something%?') then  -- [AUDIENCE:FIRST_NAME]
    elseif english:find("%. i can't say i've heard that before%.") then  -- [AUDIENCE:FIRST_NAME]
    elseif english:find('^praise be to ') then  -- [SPEAKER:HF_LINK:DEITY:TRANS_NAME]
    elseif english:find('^praise ') then  -- [SPEAKER:HF_LINK:DEITY:RANDOM_DEF_SPHERE]
    elseif english:find('^life is, in a word, ') then  -- [SPEAKER:HF_LINK:DEITY:RANDOM_DEF_SPHERE]
    elseif english:find('^this servant of .* greets you%.') then  -- [SPEAKER:HF_LINK:DEITY:TRANS_NAME]/[SPEAKER:HF_LINK:DEITY:RANDOM_DEF_SPHERE]
    end
    if hello then
      if english:find('^%l* ') then
        sentences[1] = hello
        -- TODO: hearer's name
      else
        sentences[1] = hello
      end
    end
    if english:find('%. it is good to see you%.') then
      -- TODO
    end
    if english:find(' is dumbstruck for a moment%.') then
      local name  -- TODO
      sentences[#sentences + 1] =
        {text='[' .. name .. ' is dumbstruck for a moment.]'}
    end
    if english:find(' a legend%? here%? i can scarcely believe it%.') then
      sentences[#sentences + 1] = ps.sentence{
        ps.fragment{ps.np{det=k'a', k'legend'}},
        punct='??',
      }
      sentences[#sentences + 1] = ps.sentence{
        -- TODO: split 'here' into 'this place'?
        ps.fragment{k'here'},
        punct='??',
      }
      sentences[#sentences + 1] = ps.sentence{
        ps.infl{
          mood=k'can',
          k'scarcely',
          t'believe'{
            agent=ps.me(context),
            theme=ps.it(),
          },
        },
      }
    end
    if english:find(' i am honored to be in your presence%.') then
    end
    if english:find(' it is an honor%.') then
      sentences[#sentences + 1] = ps.sentence{
        ps.infl{
          subject=ps.it(),
          ps.np{det='a', k'honor'},
        },
      }
    end
    if english:find(' your name precedes you%. thank you for all that you have done%.') then
    end
    if english:find(' it is good to finally meet you!') then
    end
    if english:find(' welcome to ') then
      -- structure
    elseif english:find(' welcome home, my child%.') then
    elseif english:find(' you are welcome at ') then
    elseif english:find('%. what can i do for you%?') then
      -- "This is " structure ".  What can I do for you?"
    end
    if english:find(' how are you, my ') then
    end
    if english:find(" it's great to have a friend like you!") then
    elseif english:find(' and what exactly do you want%?') then
    elseif english:find(' are you ready to learn%?') then
    elseif english:find(' been in any good scraps today%?') then
    elseif english:find(" let's not hurt anybody%.") then
    elseif english:find(' make any good deals lately%?') then
    elseif english:find(' long live the cause!') then
    elseif english:find(' thank you for keeping us safe%.') then
    elseif english:find(" don't let the enemy rest%.") then
    elseif english:find(' thank you for all you do%.') then
    elseif english:find(" don't try to throw your weight around%.") then
    elseif english:find(' i have nothing for you%.') then
    elseif english:find(' i value your loyalty%.') then
    elseif english:find(' it really is a pleasure to speak with you again%.') then
    elseif english:find(' do you have a story to tell%?') then
    elseif english:find(' have you written a new poem%?') then
    elseif english:find(' is it time to make music%?') then
    elseif english:find(' are you still dancing%?') then
    elseif english:find(' are in a foul mood%?') then  -- sic
    elseif english:find(" you'll get nothing from me with your flattery%.") then
    elseif english:find(' are you stalking a dangerous beast%?') then
    end
    if english:find(" it is amazing how far you've come%. welcome home%.") then
    elseif english:find(" it's good to see you have companions to travel with on your adventures%.") then
    elseif english:find(' i know you can handle yourself, but be careful out there%.') then
    elseif english:find(' hopefully your friends can disuade you from this foolishnes%.') then
    elseif english:find(' traveling alone in the wilds%?! you know better than that%.') then
    elseif english:find(' only a hero such as yourself can travel at night%. the bogeyman would get me%.') then
    elseif english:find(" i know you've seen your share of adventure, but be careful or the bogeyman may get you%.") then
    elseif english:find(" night is falling%. you'd better stay indoors, or the bogeyman will get you%.") then
    elseif english:find(" the sun will set soon%. be careful that the bogeyman doesn't get you%.") then
    elseif english:find(" don't travel alone at night, or the bogeyman will get you%.") then
    elseif english:find(' only a fool would travel alone at night! take shelter or the bogeyman will get you%.') then
    end
    if english:find(' i hate you%.') then
      sentences[#sentences + 1] = ps.sentence{
        ps.infl{
          t'hate'{
            experiencer=ps.me(context),
            stimulus=ps.thee(context),
          },
        },
      }
    elseif english:find(' vile creature!') then
    elseif english:find(' the enemy!') then
    elseif english:find(' murderer!') then
    elseif english:find(' i must obey the master!') then
    elseif english:find(' gwargh!') then
    elseif english:find(' ahhh...') then
    elseif english:find(" don't talk to me%.") then
    end
    constitent = ps.utterance(sentences)
  -- Nevermind: N/A
  elseif topic == df.talk_choice_type.Trade then
    -- "Let's trade."
    constituent = ps.lets{k'trade,V'}
  -- AskJoin: N/A
  elseif (topic == df.talk_choice_type.AskSurroundings or
          topic == df.talk_choice_type.AskFamily or
          topic == df.talk_choice_type.AskStructure) then
    -- "Tell me about this area."
    -- "Tell me about your family."
    -- "Tell me about this hall/keep/temple/library."
    local theme
    if topic == df.talk_choice_type.AskFamily then
      theme = ps.np{t'family'{relative=ps.thee(context)}}
    else
      local n
      if topic == df.talk_choice_type.AskSurroundings then
        n = k'area'
      elseif english:find('hall') then
        n = k'hall'
      elseif english:find('keep') then
        n = k'keep,N'
      elseif english:find('library') then
        n = k'library'
      elseif english:find('temple') then
        n = k'temple'
      end
      theme = ps.np{det=k'this', n}
    end
    constituent =
      ps.simple{
        mood=k'IMPERATIVE',
        t'tell about'{
          agent=ps.thee(context),
          experiencer=ps.me(context),
          theme=theme,
        },
      }
  elseif (topic == df.talk_choice_type.SayGoodbye or
          topic == df.talk_choice_type.Goodbye2) then
    -- "Goodbye."
    constituent = k'goodbye'
  -- AskStructure: see AskSurroundings
  -- AskFamily: see AskSurroundings
  elseif topic == df.talk_choice_type.AskProfession then
    -- "You look like a mighty warrior indeed."
    constituent =
      ps.simple{
        k'indeed',
        t'look like'{
          stimulus=ps.thee(context),
          theme=ps.np{det=k'a', k'mighty', k'warrior'},
        },
      }
  elseif topic == df.talk_choice_type.AskPermissionSleep then
    -- crash!
  elseif topic == df.talk_choice_type.AccuseNightCreature then
    -- "Whosoever would blight the world, preying on the helpless, fear me!  I call you a child of the night and will slay you where you stand."
    constituent =
      ps.utterance{
        ps.sentence{
          vocative=ps.wh_ever{
            mood=k'would',
            ps.ing{
              t'prey'{theme=ps.np{det=k'the', k'helpless', false}},
            },
            t'blight'{
              agent=k'who',
              theme=ps.np{det=k'the', k'world'},
            },
          },
          ps.infl{
            mood=k'IMPERATIVE',
            t'fear,V'{
              experiencer=ps.thee(context),
              stimulus=ps.me(context),
            },
          },
          punct='!',
        },
        -- TODO: factoring out the common part, in this case "I"
        ps.sentence{
          ps.conj{
            ps.infl{
              t'call'{
                agent=ps.me(context),
                theme=ps.thee(context),
                theme2=ps.np{det=k'a', k'child of the night'},
              },
            },
            k'and',
            ps.infl{
              tense=k'FUTURE',
              ps.wh{
                t'stand'{
                  theme=ps.thee(context),
                  location=k'where',
                },
              },
              t'slay'{
                agent=ps.me(context),
                theme=ps.thee(context),
              },
            },
          },
        },
      }
  elseif topic == df.talk_choice_type.AskTroubles then
    -- "How have things been?" / "How's life here?"
    if english:find('^how have things been%?$') then
    elseif english:find("^how's life here%?$") then
    end
  elseif topic == df.talk_choice_type.BringUpEvent then
    -- ?
  elseif topic == df.talk_choice_type.SpreadRumor then
    -- ?
  -- ReplyGreeting: see Greet
  elseif topic == df.talk_choice_type.RefuseConversation then
    -- "You are my neighbor."
    -- ?
  elseif topic == df.talk_choice_type.ReplyImpersonate then
    -- "Behold mortal.  I am a divine being.  I know why you have come."
    constituent =
      ps.utterance{
        ps.sentence{
          vocative=ps.np{k'mortal,N'},
          ps.infl{
            mood=k'IMPERATIVE',
            t'behold'{experiencer=ps.thee(context)},
          },
        },
        ps.sentence{
          ps.infl{
            subject=ps.me(context),
            ps.np{det=k'a', k'divine', k'being'},
          },
        },
        ps.sentence{
          ps.infl{
            t'know'{
              experiencer=ps.me(context),
              stimulus=ps.wh{
                perfect=true,
                k'why',
                t'come'{agent=ps.thee(context)},
              },
            },
          },
        },
      }
  elseif topic == df.talk_choice_type.BringUpIncident then
    ----1
    -- ?
  elseif topic == df.talk_choice_type.TellNothingChanged then
    -- "It has been the same as ever."
    consituent = ps.simple{
      perfect=true,
      subject=ps.it(),
      ps.np{
        det=k'the',
        ps.adj{
          t'as'{theme=k'ever'},
          k'same',
        },
        false,
      },
    }
  -- Goodbye2: see SayGoodbye
  elseif topic == df.talk_choice_type.ReturnTopic then
    -- N/A
  elseif topic == df.talk_choice_type.ChangeSubject then
    -- N/A
  elseif topic == df.talk_choice_type.AskTargetAction then
    -- "What will you do about it?"
    constituent = ps.simple{
      tense=k'FUTURE',
      t'about'{t=ps.it()},
      t'do'{
        agent=ps.thee(context),
        theme=k'what',
      },
      punct='?',
    }
  elseif topic == df.talk_choice_type.RequestSuggestAction then
    -- "What should I do about it?"
    constituent = ps.simple{
      mood=k'should',
      t'about'{t=ps.it()},
      t'do'{
        agent=ps.me(context),
        theme=k'what',
      },
      punct='?',
    }
  elseif topic == df.talk_choice_type.AskJoinInsurrection then
    -- "Join me and we can shake off the yoke of "
    -- "the oppressors"
    -- " from "
    -- "the weary shoulders of the people of "
    -- "this place"
    -- " forever!"
  elseif topic == df.talk_choice_type.AskJoinRescue then
    -- "Join me and we'll bring "
    -- "this poor soul"
    -- " back home!"
  elseif (topic == df.talk_choice_type.StateOpinion or
          topic == df.talk_choice_type.ExpressOverwhelmingEmotion or
          topic == df.talk_choice_type.ExpressGreatEmotion or
          topic == df.talk_choice_type.ExpressEmotion or
          topic == df.talk_choice_type.ExpressMinorEmotion or
          topic == df.talk_choice_type.ExpressLackEmotion) then
    local topic_sentence, focus_sentence
    if topic2 == df.unit_thought_type.Conflict then
      -- "This is a fight!"
      -- / "Has the tide turned?"
      -- / "The battle rages..."
      -- / "In the midst of conflict..."
      if english:find('^this is a fight! ') then
        topic_sentence = ps.simple{
          subject=ps.this(),
          ps.np{det=k'a', k'fight'},
          punct='!',
        }
      elseif english:find('^has the tide turned%? ') then
        topic_sentence = ps.simple{
          -- idiom
          perfect=true,
          t'turn,V'{
            theme=ps.np{det=k'the', k'tide'},
          },
          punct='?',
        }
      elseif english:find('^the battle rages%.%.%. ') then
        topic_sentence = ps.simple{
          t'rage,V'{
            theme=ps.np{det=k'the', k'battle'},
          },
          punct='...',
        }
      elseif english:find('^in the midst of conflict%.%.%. ') then
        topic_sentence = ps.sentence{
          ps.fragment{
            t'in'{
              theme=ps.np{
                det=k'the',
                t'midst'{theme=k'conflict'},
              },
            },
          },
          punct='...',
        }
      end
    elseif topic2 == df.unit_thought_type.Trauma then
      -- "Gruesome wounds!"
      -- / "So easily broken..."
      -- / "Those injuries..."
      -- / "Can it all end so quickly?"
      -- / "Our time in " world name " is so brief..."
      -- / "How fleeting life is..."
      -- / "How fragile we are..."
      if english:find('^gruesome wounds! ') then
        topic_sentence = ps.sentence{
          ps.fragment{
            ps.np{k'gruesome', k'wound', plural=true},
          },
          punct='!',
        }
      elseif english:find('^so easily broken%.%.%. ') then
        topic_sentence = ps.sentence{
          ps.fragment{
            ps.past_participle{
              ps.adv{deg=k'so', k'easy'},
              k'break,V',
            },
          },
          punct='...',
        }
      elseif english:find('^those injuries%.%.%. ') then
        topic_sentence = ps.sentence{
          ps.fragment{
            ps.np{det=k'this', k'injury', plural=true},
          },
        }
      elseif english:find('^can it all end so quickly%? ') then
        topic_sentence = ps.simple{
          mood=k'can,X',
          ps.adv{deg=k'so', k'quick'},
          t'end,V'{
            theme=ps.np{k'all', ps.it()},
          },
          punct='?',
        }
      elseif english:find('^our time in .* is so brief%.%.%. ') then
        topic_sentence = ps.simple{
          subject=ps.np{
            poss=ps.us_inclusive(context),
            ps.np{
              t'in'{location=ps.world_name()},
              k'time (delimited)',
            },
          },
          ps.adj{deg=k'so', k'brief'},
        }
      elseif english:find('^how fleeting life is%.%.%. ') then
        topic_sentence = ps.simple{
          subject=k'life (in general)',
          ps.adj{deg=k'how', k'fleeting'},
          punct='...',
        }
      else
        topic_sentence = ps.simple{
          subject=k'we (in general)',
          ps.adj{deg=k'how', k'fragile'},
          punct='...',
        }
      end
    elseif topic2 == df.unit_thought_type.WitnessDeath then
      -- "Death is all around us."
      -- / "Death..."
      if english:find('^death is all around us%. ') then
        topic_sentence = ps.simple{
          subject=k'death',
          t'all around'{location=ps.us_inclusive(context)},
        }
      else
        topic_sentence = ps.sentence{
          ps.fragment{
            k'death',
          },
          punct='...',
        }
      end
    elseif topic2 == df.unit_thought_type.UnexpectedDeath then
      -- historical_figure " is dead?"
      -- / "I can't believe " historical_figure " is dead."
      if english:find("^i can't believe .* is dead%. ") then
        topic_sentence = ps.simple{
          subject=ps.hf_name(topic3),
          k'dead',
          punct='??',
        }
      else
        topic_sentence = ps.simple{
          mood=k'can,X',
          neg=true,
          t'believe'{
            experiencer=ps.me(context),
            stimulus=ps.simple{
              subject=ps.hf_name(topic3),
              k'dead',
            },
          },
        }
      end
    elseif topic2 == df.unit_thought_type.Death then
      -- historical_figure " is really dead."
      -- historical_figure " is dead."
      if english:find(' is really dead%. ') then
        topic_sentence = ps.simple{
          subject=ps.hf_name(topic3),
          ps.adj{deg=k'really', k'dead'},
        }
      else
        topic_sentence = ps.simple{
          subject=ps.hf_name(topic3),
          k'dead',
        }
      end
    elseif topic2 == df.unit_thought_type.Kill then
      -- "Slayer."
      -- / historical_figure ", slayer."
      -- / historical_figure ", slayer of " historical_figure "."
      -- / historical_figure " killed " historical_figure "."
    elseif topic2 == df.unit_thought_type.LoveSeparated then
      -- "Oh, where is " historical_figure "?"
      -- / "I am separated from " historical_figure "."
      if english:find('^oh, where is ') then
        topic_sentence = ps.simple{
          -- TODO: oh
          subject=ps.hf_name(topic3),
          k'where',
          punct='?',
        }
      else
        topic_sentence = ps.simple{
          passive=true,  -- TODO: Can this be automatically detected?
          t'separate'{
            theme=ps.me(context),
            goal=ps.hf_name(topic3),
          },
        }
      end
    elseif topic2 == df.unit_thought_type.LoveReunited then
      -- "I am reunited with my " historical_figure "."
      -- / "I am together with my " historical_figure "."
      if english:find('^i am reunited with my ') then
        topic_sentence = ps.simple{
          passive=true,
          t'reunite'{
            theme=ps.me(context),
            goal=ps.np{rel=ps.me(context), ps.hf_name()},
          },
        }
      else
        topic_sentence = ps.simple{
          subject=ps.me(context),
          t'together with'{
            theme=ps.np{rel=ps.me(context), ps.hf_name()},
          },
        }
      end
    elseif topic2 == df.unit_thought_type.JoinConflict then
      -- "I have a part in this."
      -- / "I cannot just stand by."
      if english:find('^i have a part in this%. ') then
        topic_sentence = ps.simple{
          t'have'{
            possessor=ps.me(context),
            theme=ps.np{det=k'a', t'in'{theme=ps.this()}, k'part'},
          },
        }
      else
        topic_sentence = ps.simple{
          -- TODO: "cannot" vs "can not"
          mood=k'can,X',
          neg=true,
          k'just',
          t'stand by'{agent=ps.me(context)},
        }
      end
    elseif topic2 == df.unit_thought_type.MakeMasterwork then
      -- "This is a masterpiece."
      topic_sentence = ps.simple{
        subject=ps.this(),
        ps.np{det=k'a', k'masterpiece'},
      }
    elseif topic2 == df.unit_thought_type.MadeArtifact then
      -- "I shall name you " artifact_record "."
      topic_sentence = ps.simple{
        mood=k'shall',
        t'name,V'{
          agent=ps.me(context),
          theme=ps.thee_inanimate(context),
          theme2=ps.artifact_name(topic3),
        },
      }
    elseif topic2 == df.unit_thought_type.MasterSkill then
      -- "I have mastered " job_skill "."
      topic_sentence = ps.simple{
        perfect=true,
        t'master,V'{
          agent=ps.me(context),
          theme=ps.job_skill(topic3),
        },
      }
    elseif topic2 == df.unit_thought_type.NewRomance then
      -- "I have fallen for " historical_figure "."
      -- / "Oh, " historical_figure "..."
      if english:find('^i have fallen for ') then
        topic_sentence = ps.simple{
          perfect=true,
          t'fall for'{
            agent=ps.hf_name(topic3),
            theme=ps.me(context),
          },
        }
      else
        topic_sentence = ps.sentence{
          ps.fragment{
            ps.noise{k'oh'},
          },
          ps.hf_name(topic3),
        }
      end
    elseif topic2 == df.unit_thought_type.BecomeParent then
      -- "I am a parent."
      -- / "Children."
      if english:find('^i am a parent%. ') then
        topic_sentence = ps.simple{
          subject=ps.me(context),
          ps.np{det=k'a', k'parent'},
        }
      else
        topic_sentence = ps.sentence{
          ps.fragment{
            ps.np{k'child', plural=true},
          },
        }
      end
    elseif topic2 == df.unit_thought_type.NearConflict then
      -- "There's fighting!"
      -- / "A battle!"
      if english:find("^there's fighting! ") then
        topic_sentence = ps.there_is{
          k'fighting',
          punct='!',
        }
      else
        topic_sentence = ps.sentence{
          ps.fragment{
            ps.np{det=k'a', k'battle'},
          },
          punct='!',
        }
      end
    elseif topic2 == df.unit_thought_type.CancelAgreement then
      -- N/A
    elseif topic2 == df.unit_thought_type.JoinTravel then
      -- N/A
    elseif topic2 == df.unit_thought_type.SiteControlled then
      -- N/A
    elseif topic2 == df.unit_thought_type.TributeCancel then
      -- N/A
    elseif topic2 == df.unit_thought_type.Incident then
      -- incident report TODO: whatever that is
    elseif topic2 == df.unit_thought_type.HearRumor then
      -- N/A
    elseif topic2 == df.unit_thought_type.MilitaryRemoved then
      -- N/A
    elseif topic2 == df.unit_thought_type.StrangerWeapon then
      -- "Is that a weapon?"
      -- / "Is this an attack?"
      if english:find('^is that a weapon%? ') then
        topic_sentence = ps.simple{
          subject=ps.that(),  -- TODO: specific item
          ps.np{det=k'a', k'weapon'},
          punct='?',
        }
      else
        topic_sentence = ps.simple{
          subject=ps.this(),
          ps.np{det=k'a', k'attack'},
          punct='?',
        }
      end
    elseif topic2 == df.unit_thought_type.StrangerSneaking then
      -- "Somebody up to no good..."
      -- / "Who's skulking around there?"
      if english:find('^somebody up to no good%.%.%. ') then
        topic_sentence = ps.sentence{
          ps.fragment{
            ps.np{
              t'up to'{
                theme=ps.np{det=k'no,DET', k'good,MN'}
              },
              k'somebody',
            },
          },
        }
      else
        topic_sentence = ps.simple{
          progressive=true,
          k'there',
          t'skulk'{
            agent=k'who',
          },
          punct='?',
        }
      end
    elseif topic2 == df.unit_thought_type.SawDrinkBlood then
      -- "It is drinking the blood of the living."
      -- / "It feeds on blood."
      if english:find('^it is drinking the blood of the living%. ') then
        topic_sentence = ps.simple{
          progressive=true,
          t'drink,V'{
            agent=ps.it(),  -- TODO: specific hf
            theme=ps.np{
              det=k'the',
              t'of'{
                theme=ps.np{det=k'the', k'living', false},
              },
              k'blood',
            },
          },
        }
      else
        topic_sentence = ps.simple{
          t'feed'{
            agent=ps.it(),
            theme=k'blood',
          },
        }
      end
    elseif topic2 == df.unit_thought_type.Complained then
      -- N/A
    elseif topic2 == df.unit_thought_type.ReceivedComplaint then
      -- N/A
    elseif topic2 == df.unit_thought_type.AdmireBuilding then
      -- "I was near to a " building_type "."
      topic_sentence = ps.simple{
        tense=k'PAST',
        subject=ps.me(context),
        t'near'{
          theme=ps.np{det=k'a', ps.building_type_name(topic3)},
        },
      }
    elseif topic2 == df.unit_thought_type.AdmireOwnBuilding then
      -- "I was near to my own " building_type "."
      topic_sentence = ps.simple{
        tense=k'PAST',
        subject=ps.me(context),
        t'near'{
          theme=ps.np{
            poss=ps.me(context),
            k'own',
            ps.building_type_name(topic3),
          },
        },
      }
    elseif topic2 == df.unit_thought_type.AdmireArrangedBuilding then
      -- "I was near to a arranged " building_type "." [sic]
      topic_sentence = ps.simple{
        tense=k'PAST',
        subject=ps.me(context),
        t'near'{
          theme=ps.np{det=k'a', k'arranged', ps.building_type_name(topic3)},
        },
      }
    elseif topic2 == df.unit_thought_type.AdmireOwnArrangedBuilding then
      -- "I was near to my own arranged " building_type "."
      topic_sentence = ps.simple{
        tense=k'PAST',
        subject=ps.me(context),
        t'near'{
          theme=ps.np{
            poss=ps.me(context),
            k'own',
            k'arranged',
            ps.building_type_name(topic3),
          },
        },
      }
    elseif topic2 == df.unit_thought_type.LostPet then
      -- "I lost a pet."
      topic_sentence = ps.simple{
        tense=k'PAST',
        k'lose'{
          agent=ps.me(context),
          theme=ps.np{det=k'a', k'pet'},
        },
      }
    elseif topic2 == df.unit_thought_type.ThrownStuff then
      -- "I threw something."
      topic_sentence = ps.simple{
        tense=k'PAST',
        t'throw'{
          agent=ps.me(context),
          theme=k'something',
        },
      }
    elseif topic2 == df.unit_thought_type.JailReleased then
      -- "I was released from confinement."
      topic_sentence = ps.simple{
        tense=k'PAST',
        passive=true,
        t'release'{
          theme=ps.me(context),
          location=k'confinement',
        },
      }
    elseif topic2 == df.unit_thought_type.Miscarriage then
      -- "I lost the baby."
      topic_sentence = ps.simple{
        tense=k'PAST',
        t'lose'{
          agent=ps.me(context),
          theme=ps.np{k'the', k'baby'},
        },
      }
    elseif topic2 == df.unit_thought_type.SpouseMiscarriage then
      -- "My spouse lost the baby."
      topic_sentence = ps.simple{
        tense=k'PAST',
        t'lose'{
          agent=ps.np{relative=ps.me(context), k'spouse'},  -- TODO: specific hf
          theme=ps.np{k'the', k'baby'},
        },
      }
    elseif topic2 == df.unit_thought_type.OldClothing then
      -- "I am wearing old clothes."
      topic_sentence = ps.simple{
        progressive=true,
        t'wear'{
          agent=ps.me(context),
          theme=ps.np{k'old', k'clothing'},
        },
      }
    elseif topic2 == df.unit_thought_type.TatteredClothing then
      -- "My clothes are in tatters."
      topic_sentence = ps.simple{
        subject=ps.np{poss=ps.me(context), k'clothing'},
        k'in tatters',
      }
    elseif topic2 == df.unit_thought_type.RottedClothing then
      -- "My clothes actually rotted right off my body."
      topic_sentence = ps.simple{
        tense=k'PAST',
        k'actually',
        k'right',
        t'off'{
          theme=ps.np{rel=ps.me(context), k'body'},
        },
        t'rot,V'{
          agent=ps.np{poss=ps.me(context), k'clothing'},
        },
      }
    elseif topic2 == df.unit_thought_type.GhostNightmare then
      -- "I had a nightmare about "
      -- "my deceased " unit_relationship_type
      -- / "the dead"
      -- "."
      local the_dead
      if english:find(' my deceased ') then
        the_dead = ps.np{
          relative=ps.me(context),
          k'deceased',
          ps.relationship_type_name(topic3),
        }
      else
        the_dead = ps{det=k'the', k'dead', false}
      end
      topic_sentence = ps.simple{
        tense=k'PAST',
        t'have (experience)'{
          experiencer=ps.me(context),
          stimulus=the_dead
        },
      }
    elseif topic2 == df.unit_thought_type.GhostHaunt then
      -- "I was "
      -- topic4: "haunted" / "tormented" / "possessed" / "tortured"
      -- " by the ghost of "
      -- topic3: unit_relationship_type
      local haunt
      if english:find(' haunted ') then
        haunt = 'haunt'
      elseif english:find(' tormented ') then
        haunt = 'torment'
      elseif english:find(' possessed ') then
        haunt = 'possess'
      else
        haunt = 'torture'
      end
      topic_sentence = ps.simple{
        tense=k'PAST',
        passive=true,
        t(haunt){
          agent=ps.np{
            det=k'the',
            t'of'{
              theme=ps.my_relationship_type_name(topic3),
            },
            k'ghost',
          },
          theme=ps.me(context),
        },
      }
    elseif topic2 == df.unit_thought_type.Spar then
      -- "I had a sparring session."
      topic_sentence = ps.simple{
        tense=k'PAST',
        t'have (experience)'{
          experiencer=ps.me(context),
          stimulus=ps.np{det=k'a', t'session'{theme=k'sparring'}},
        },
      }
    elseif topic2 == df.unit_thought_type.UnableComplain then
      -- N/A
    elseif topic2 == df.unit_thought_type.LongPatrol then
      -- "I've been on a long patrol."
      topic_sentence = ps.simple{
        perfect=true,
        subject=ps.me(context),
        t'on'{
          theme=ps.np{det=k'a', k'long', k'patrol'},
        },
      }
    elseif topic2 == df.unit_thought_type.SunNausea then
      -- "I was nauseated by the sun."
      topic_sentence = ps.simple{
        tense=k'PAST',
        passive=true,
        t'nauseate'{
          agent=ps.np{det=k'the', k'sun'},
          theme=ps.me(context),
        },
      }
    elseif topic2 == df.unit_thought_type.SunIrritated then
      -- "I've been out in the sunshine again after a long time away."
    elseif topic2 == df.unit_thought_type.Drowsy then
      -- "I'm sleepy."
    elseif topic2 == df.unit_thought_type.VeryDrowsy then
      -- "I haven't slept for a very long time."
    elseif topic2 == df.unit_thought_type.Thirsty then
      -- "I'm thirsty."
    elseif topic2 == df.unit_thought_type.Dehydrated then
      -- "I'm dehydrated."
    elseif topic2 == df.unit_thought_type.Hungry then
      -- "I'm hungry."
    elseif topic2 == df.unit_thought_type.Starving then
      -- "I'm starving."
    elseif topic2 == df.unit_thought_type.MajorInjuries then
      -- "I've been injured badly."
      topic_sentence = ps.simple{
        passive=true,
        perfect=true,
        ps.adv{k'grave,J'},
        t'injure'{
          theme=ps.me(context),
        },
      }
    elseif topic2 == df.unit_thought_type.MinorInjuries then
      -- "I've been wounded."
      topic_sentence = ps.simple{
        passive=true,
        perfect=true,
        t'wound,V'{
          theme=ps.me(context),
        },
      }
    elseif topic2 == df.unit_thought_type.SleepNoise then
      -- N/A
    elseif topic2 == df.unit_thought_type.Rest then
      -- "I was able to rest up."
    elseif topic2 == df.unit_thought_type.FreakishWeather then
      -- "I was caught in freakish weather."
    elseif topic2 == df.unit_thought_type.Rain then
      -- "I was out in the rain."
      -- / "It was raining on me."
      -- / "I've been rained on."
      if english:find('^i was out in the rain%. ') then
        topic_sentence = ps.simple{
          tense=k'PAST',
          subject=ps.me(context),
          t'out in'{
            theme=ps.np{det=k'the', k'rain,N'},
          },
        }
      elseif english:find('^it was raining on me%. ') then
        topic_sentence = ps.simple{
          tense=k'PAST',
          progressive=true,
          t'rain,V'{
            t'on'{theme=ps.me(context)},
          },
        }
      else
        topic_sentence = ps.simple{
          perfect=true,
          passive=true,
          t'rain,V'{
            t'on'{theme=ps.me(context)},
          },
        }
      end
    elseif topic2 == df.unit_thought_type.SnowStorm then
      -- "I was out in a blizzard."
      -- / "It was snowing on me."
      -- / "I was in a snow storm."
      if english:find('^i was out in a blizzard%. ') then
        topic_sentence = ps.simple{
          tense=k'PAST',
          subject=ps.me(context),
          t'out in'{
            theme=ps.np{det=k'a', k'blizzard'},
          },
        }
      elseif english:find('^it was snowing on me%. ') then
        topic_sentence = ps.simple{
          tense=k'PAST',
          progressive=true,
          t'snow,V'{
            t'on'{theme=ps.me(context)},
          },
        }
      else
        topic_sentence = ps.simple{
          tense=k'PAST',
          subject=ps.me(context),
          t'in'{
            theme={det=k'a', k'snow storm'},
          },
        }
      end
    elseif topic2 == df.unit_thought_type.Miasma then
      -- "I got caught in a miasma."
    elseif topic2 == df.unit_thought_type.Smoke then
      -- "I was caught in smoke underground."
    elseif topic2 == df.unit_thought_type.Waterfall then
      -- "I was close to a waterfall."
    elseif topic2 == df.unit_thought_type.Dust then
      -- "I got caught in dust underground."
    elseif topic2 == df.unit_thought_type.Demands then
      -- "I was considering the demands I've made."
    elseif topic2 == df.unit_thought_type.ImproperPunishment then
      -- "A criminal could not be properly punished."
    elseif topic2 == df.unit_thought_type.PunishmentReduced then
      -- "My punishment was reduced."
    elseif topic2 == df.unit_thought_type.Elected then
      -- "I won the election."
    elseif topic2 == df.unit_thought_type.Reelected then
      -- "I was re-elected."
    elseif topic2 == df.unit_thought_type.RequestApproved then
      -- "My request was approved."
    elseif topic2 == df.unit_thought_type.RequestIgnored then
      -- "My request was ignored."
    elseif topic2 == df.unit_thought_type.NoPunishment then
      -- "Nobody could be punished for failing to obey my commands."
    elseif topic2 == df.unit_thought_type.PunishmentDelayed then
      -- "My punishment was delayed."
    elseif topic2 == df.unit_thought_type.DelayedPunishment then
      -- "A criminal's punishment was delayed."
    elseif topic2 == df.unit_thought_type.ScarceCageChain then
      -- "There are not enough cages and chains."
    elseif topic2 == df.unit_thought_type.MandateIgnored then
      -- "My mandate was ignored."
    elseif topic2 == df.unit_thought_type.MandateDeadlineMissed then
      -- "A mandate deadline was missed."
    elseif topic2 == df.unit_thought_type.LackWork then
      -- "There wasn't enough work last season."
    elseif topic2 == df.unit_thought_type.SmashedBuilding then
      -- "I smashed up a building."
    elseif topic2 == df.unit_thought_type.ToppledStuff then
      -- "I toppled something over."
    elseif topic2 == df.unit_thought_type.NoblePromotion then
      -- "I have attained a higher rank of nobility."
    elseif topic2 == df.unit_thought_type.BecomeNoble then
      -- "I have entered the nobility."
    elseif topic2 == df.unit_thought_type.Cavein then
      -- "I was knocked out by a cave-in."
    elseif topic2 == df.unit_thought_type.MandateDeadlineMet then
      -- "My deadline was met."
    elseif topic2 == df.unit_thought_type.Uncovered then
      -- "I am uncovered."
    elseif topic2 == df.unit_thought_type.NoShirt then
      -- "I don't have a shirt."
    elseif topic2 == df.unit_thought_type.NoShoes then
      -- "I have no shoes."
    elseif topic2 == df.unit_thought_type.EatPet then
      -- "I had to eat my beloved pet to survive."
    elseif topic2 == df.unit_thought_type.EatLikedCreature then
      -- "I had to eat one of my favorite animals to survive."
    elseif topic2 == df.unit_thought_type.EatVermin then
      -- "I had to eat vermin to survive."
    elseif topic2 == df.unit_thought_type.FistFight then
      -- "I started a fist fight."
    elseif topic2 == df.unit_thought_type.GaveBeating then
      -- "I beat somebody as a punishment."
    elseif topic2 == df.unit_thought_type.GotBeaten then
      -- "I was beaten as a punishment."
    elseif topic2 == df.unit_thought_type.GaveHammering then
      -- "I was beat somebody with the hammer." [sic]
    elseif topic2 == df.unit_thought_type.GotHammered then
      -- "I was beaten with the hammer."
    elseif topic2 == df.unit_thought_type.NoHammer then
      -- "I could not find the hammer."
    elseif topic2 == df.unit_thought_type.SameFood then
      -- "I have been eating the same old food."
    elseif topic2 == df.unit_thought_type.AteRotten then
      -- "I ate rotten food."
    elseif topic2 == df.unit_thought_type.GoodMeal then
      -- "I ate a meal."
    elseif topic2 == df.unit_thought_type.GoodDrink then
      -- "I had a drink."
    elseif topic2 == df.unit_thought_type.MoreChests then
      -- "I don't have enough chests."
    elseif topic2 == df.unit_thought_type.MoreCabinets then
      -- "I don't have enough cabinets."
    elseif topic2 == df.unit_thought_type.MoreWeaponRacks then
      -- "I don't have enough weapon racks."
    elseif topic2 == df.unit_thought_type.MoreArmorStands then
      -- "I don't have enough armor stands."
    elseif topic2 == df.unit_thought_type.RoomPretension then
      -- "Somebody has better "
      -- topic3: unit_demand.T_place: "office" / "sleeping" / "dining" / "burial"
      -- " arrangements than I do."
    elseif topic2 == df.unit_thought_type.LackTables then
      -- "There aren't enough dining tables."
    elseif topic2 == df.unit_thought_type.CrowdedTables then
      -- "I ate at a crowded table."
    elseif topic2 == df.unit_thought_type.DiningQuality then
      -- "I ate in a dining room."
    elseif topic2 == df.unit_thought_type.NoDining then
      -- "I didn't have a dining room."
    elseif topic2 == df.unit_thought_type.LackChairs then
      -- "There aren't enough chairs."
    elseif topic2 == df.unit_thought_type.TrainingBond then
      -- "I formed a bond with my animal training partner."
    elseif topic2 == df.unit_thought_type.Rescued then
      -- "I was rescued."
    elseif topic2 == df.unit_thought_type.RescuedOther then
      -- "I brought somebody to rest in bed."
    elseif topic2 == df.unit_thought_type.SatisfiedAtWork then
      -- "I finished up some work."
    elseif topic2 == df.unit_thought_type.TaxedLostProperty then
      -- "The tax collector's escorts stole my property."
    elseif topic2 == df.unit_thought_type.Taxed then
      -- "I lost some property to taxes."
    elseif topic2 == df.unit_thought_type.LackProtection then
      -- "I do not have adequate protection."
    elseif topic2 == df.unit_thought_type.TaxRoomUnreachable then
      -- "I was unable to reach a room during tax collection."
    elseif topic2 == df.unit_thought_type.TaxRoomMisinformed then
      -- "I was misinformed about a room during tax collection."
    elseif topic2 == df.unit_thought_type.PleasedNoble then
      -- "I pleased the nobility."
    elseif topic2 == df.unit_thought_type.TaxCollectionSmooth then
      -- "Tax collection went smoothly."
    elseif topic2 == df.unit_thought_type.DisappointedNoble then
      -- "I disappointed the nobility."
    elseif topic2 == df.unit_thought_type.TaxCollectionRough then
      -- "The tax collection did not go smoothly."
    elseif topic2 == df.unit_thought_type.MadeFriend then
      -- "I made friends with " historical_figure "."
    elseif topic2 == df.unit_thought_type.FormedGrudge then
      -- "I am forming a grudge against " historical_figure "."
    elseif topic2 == df.unit_thought_type.AnnoyedVermin then
      -- "I was accosted by " creature_raw "."
    elseif topic2 == df.unit_thought_type.NearVermin then
      -- "I was near to " creature_raw "."
    elseif topic2 == df.unit_thought_type.PesteredVermin then
      -- "I was pestered by " creature_raw "."
    elseif topic2 == df.unit_thought_type.AcquiredItem then
      -- "I acquired something."
    elseif topic2 == df.unit_thought_type.AdoptedPet then
      -- "I adopted a new pet."
    elseif topic2 == df.unit_thought_type.Jailed then
      -- "I was confined."
    elseif topic2 == df.unit_thought_type.Bath then
      -- "I had a bath."
    elseif topic2 == df.unit_thought_type.SoapyBath then
      -- "I had a bath with soap!"
    elseif topic2 == df.unit_thought_type.SparringAccident then
      -- "I killed somebody in a sparring accident."
    elseif topic2 == df.unit_thought_type.Attacked then
      -- "I was attacked."
    elseif topic2 == df.unit_thought_type.AttackedByDead then
      -- "I was attacked by "
      -- topic3: "my own dead " histfig_relationship_type
      -- / "the dead"
      -- "."
    elseif topic2 == df.unit_thought_type.SameBooze then
      -- "I have been drinking the same old booze."
    elseif topic2 == df.unit_thought_type.DrinkBlood then
      -- "I drank bloody water."
    elseif topic2 == df.unit_thought_type.DrinkSlime then
      -- "I drank slime."
    elseif topic2 == df.unit_thought_type.DrinkVomit then
      -- "I drank vomit."
    elseif topic2 == df.unit_thought_type.DrinkGoo then
      -- "I drank gooey water."
    elseif topic2 == df.unit_thought_type.DrinkIchor then
      -- "I drank water mixed with ichor."
    elseif topic2 == df.unit_thought_type.DrinkPus then
      -- "I drank water mixed with pus."
    elseif topic2 == df.unit_thought_type.NastyWater then
      -- "I drank foul water."
    elseif topic2 == df.unit_thought_type.DrankSpoiled then
      -- "I had a drink, but it had gone bad."
    elseif topic2 == df.unit_thought_type.LackWell then
      -- "I drank water without a well."
    elseif topic2 == df.unit_thought_type.NearCaged then
      -- "I was near to a caged " creature_raw "."
    elseif topic2 == df.unit_thought_type.NearCaged2 then
      -- "I was near to a caged " creature_raw "."
    elseif topic2 == df.unit_thought_type.LackBedroom then
      -- "I slept without a proper room."
    elseif topic2 == df.unit_thought_type.BedroomQuality then
      -- "I slept in a bedroom."
    elseif topic2 == df.unit_thought_type.SleptFloor then
      -- "I slept on the floor."
    elseif topic2 == df.unit_thought_type.SleptMud then
      -- "I slept in the mud."
    elseif topic2 == df.unit_thought_type.SleptGrass then
      -- "I slept in the grass."
    elseif topic2 == df.unit_thought_type.SleptRoughFloor then
      -- "I slept on a rough cave floor."
    elseif topic2 == df.unit_thought_type.SleptRocks then
      -- "I slept on rocks."
    elseif topic2 == df.unit_thought_type.SleptIce then
      -- "I slept on ice."
    elseif topic2 == df.unit_thought_type.SleptDirt then
      -- "I slept in the dirt."
    elseif topic2 == df.unit_thought_type.SleptDriftwood then
      -- "I slept on a pile of driftwood."
    elseif topic2 == df.unit_thought_type.ArtDefacement then
      -- "My artwork was defaced."
    elseif topic2 == df.unit_thought_type.Evicted then
      -- "I was evicted."
    elseif topic2 == df.unit_thought_type.GaveBirth then
      -- "I gave birth to "
      -- topic3, topic4
      -- "."
    elseif topic2 == df.unit_thought_type.SpouseGaveBirth then
      -- "I have a new sibling."
      -- / "I have new siblings."
      -- / "I have become a parent."
      -- TODO: What about "I got married."?
    elseif topic2 == df.unit_thought_type.ReceivedWater then
      -- "I received water."
    elseif topic2 == df.unit_thought_type.GaveWater then
      -- "I gave somebody water."
    elseif topic2 == df.unit_thought_type.ReceivedFood then
      -- "I received food."
    elseif topic2 == df.unit_thought_type.GaveFood then
      -- "I gave somebody food."
    elseif topic2 == df.unit_thought_type.Talked then
      -- "I visited with my pet."
      -- / "I talked to "
      -- "my " unit_relationship_type / "somebody"
      -- "."
    elseif topic2 == df.unit_thought_type.OfficeQuality then
      -- "I conducted a meeting in "
      -- "a good setting"
      -- / "a very good setting"
      -- / "a great setting"
      -- / "a fantastic setting"
      -- / "a setting worthy of legends"
      -- "."
    elseif topic2 == df.unit_thought_type.MeetingInBedroom then
      -- "I conducted an official meeting in a bedroom."
    elseif topic2 == df.unit_thought_type.MeetingInDiningRoom then
      -- "I conducted an official meeting in a dining room."
    elseif topic2 == df.unit_thought_type.NoRooms then
      -- "I had no room for an official meeting."
    elseif topic2 == df.unit_thought_type.TombQuality then
      -- "I thought about my tomb."
    elseif topic2 == df.unit_thought_type.TombLack then
      -- "I do not have a tomb."
    elseif topic2 == df.unit_thought_type.TalkToNoble then
      -- "I talked to somebody important to our traditions."
    elseif topic2 == df.unit_thought_type.InteractPet then
      -- "I played with my pet."
    elseif topic2 == df.unit_thought_type.ConvictionCorpse then
      -- "Somebody dead was convicted of a crime."
    elseif topic2 == df.unit_thought_type.ConvictionAnimal then
      -- "An animal was convicted of a crime."
    elseif topic2 == df.unit_thought_type.ConvictionVictim then
      -- "The victim of a crime was somehow convicted of that very offense."
    elseif topic2 == df.unit_thought_type.ConvictionJusticeSelf then
      -- "The criminal was convicted and I received justice."
    elseif topic2 == df.unit_thought_type.ConvictionJusticeFamily then
      -- "My family received justice when the criminal was convicted."
    elseif topic2 == df.unit_thought_type.Decay then
      -- "The body of my "
      -- topic3: unit_relationship_type
      -- " decayed without burial."
    elseif topic2 == df.unit_thought_type.NeedsUnfulfilled then
      if topic3 == df.need_type.Socialize then
        -- "I have been away from people for a long time."
      elseif topic3 == df.need_type.DrinkAlcohol then
        -- "I need a drink."
      elseif topic3 == df.need_type.PrayOrMedidate then
        if topic4 == -1 then
          -- "I need time to contemplate."
        else
          -- "I must pray to "
          -- historical_figure
          -- "."
        end
      elseif topic3 == df.need_type.StayOccupied then
        -- "I need something to do."
      elseif topic3 == df.need_type.BeCreative then
        -- "It has been long time since I've done something creative."
      elseif topic3 == df.need_type.Excitement then
        -- "I need some excitement in my life."
      elseif topic3 == df.need_type.LearnSomething then
        -- "I need to learn something new."
      elseif topic3 == df.need_type.BeWithFamily then
        -- "I want to spend some time with family."
      elseif topic3 == df.need_type.BeWithFriends then
        -- "I want to see my friends."
      elseif topic3 == df.need_type.HearEloquence then
        -- "I'd like to hear somebody eloquent."
      elseif topic3 == df.need_type.UpholdTradition then
        -- "I long to uphold the traditions."
      elseif topic3 == df.need_type.SelfExamination then
        -- "I need to pause and reflect upon myself."
      elseif topic3 == df.need_type.MakeMerry then
        -- "We must make merry again."
      elseif topic3 == df.need_type.CraftObject then
        -- "I wish to make something."
      elseif topic3 == df.need_type.MartialTraining then
        -- "I must practice the fighting arts."
      elseif topic3 == df.need_type.PracticeSkill then
        -- "I need to perfect my skills."
      elseif topic3 == df.need_type.TakeItEasy then
        -- "I just want to slow down and take it easy for a while."
      elseif topic3 == df.need_type.MakeRomance then
        -- "I long to make romance."
      elseif topic3 == df.need_type.SeeAnimal then
        -- "It would nice to get out in nature and see some creatures." [sic]
      elseif topic3 == df.need_type.SeeGreatBeast then
        -- "I want to see a great beast."
      elseif topic3 == df.need_type.AcquireObject then
        -- "I need more."
      elseif topic3 == df.need_type.EatGoodMeal then
        -- "I could really use a good meal."
      elseif topic3 == df.need_type.Fight then
        -- "I just want to fight somebody."
      elseif topic3 == df.need_type.CauseTrouble then
        -- "This place could really use some more trouble."
      elseif topic3 == df.need_type.Argue then
        -- "I'm feeling argumentative."
      elseif topic3 == df.need_type.BeExtravagant then
        -- "I need to wear fine things."
      elseif topic3 == df.need_type.Wander then
        -- "I need to get away from here and wander the world."
      elseif topic3 == df.need_type.HelpSomebody then
        -- "I just wish to help somebody."
      elseif topic3 == df.need_type.ThinkAbstractly then
        -- "I want to puzzle over something."
      elseif topic3 == df.need_type.AdmireArt then
        -- "I miss having art in my life."
      else
        -- "I have unmet needs."
      end
    elseif topic2 == df.unit_thought_type.Prayer then
      -- "I have communed with "
      -- topic3: historical_figure
      -- "."
    elseif topic2 == df.unit_thought_type.DrinkWithoutCup then
      -- "I had a drink without using a goblet."
    elseif topic2 == df.unit_thought_type.ResearchBreakthrough then
      -- "I've made a breakthrough regarding "
      -- topic3, topic4
      -- "."
    elseif topic2 == df.unit_thought_type.ResearchStalled then
      -- "I just don't understand "
      -- topic3, topic4 (short form)
      -- "."
    elseif topic2 == df.unit_thought_type.PonderTopic then
      -- "I've been mulling over "
      -- topic3, topic4 (short form)
      -- "."
    elseif topic2 == df.unit_thought_type.DiscussTopic then
      -- "I've been discussing "
      -- topic3, topic4 (short form)
      -- "."
    elseif topic2 == df.unit_thought_type.Syndrome then
      -- TODO
    elseif topic2 == df.unit_thought_type.Perform then
      -- "I performed "
      -- TODO
      -- "."
    elseif topic2 == df.unit_thought_type.WatchPerform then
      -- TODO
    elseif topic2 == df.unit_thought_type.RemoveTroupe then
      -- TODO
    elseif topic2 == df.unit_thought_type.LearnTopic then
      -- "I learned about "
      -- topic3, topic4
      -- "."
    elseif topic2 == df.unit_thought_type.LearnSkill then
      -- "I learned about "
      -- topic3: job_skill
      -- "."
    elseif topic2 == df.unit_thought_type.LearnBook then
      -- "I learned "
      -- topic3: written_content
      -- "."
    elseif topic2 == df.unit_thought_type.LearnInteraction then
      -- "I learned "
      -- topic3: interaction / "powerful knowledge"
      -- "."
    elseif topic2 == df.unit_thought_type.LearnPoetry then
      -- "I learned "
      -- topic3: poetic_form
      -- "."
    elseif topic2 == df.unit_thought_type.LearnMusic then
      -- "I learned "
      -- topic3: poetic_form
      -- "."
    elseif topic2 == df.unit_thought_type.LearnDance then
      -- "I learned "
      -- topic3: dance_form
      -- "."
    elseif topic2 == df.unit_thought_type.TeachTopic then
      -- "I taught "
      -- topic3, topic4
      -- "."
    elseif topic2 == df.unit_thought_type.TeachSkill then
      -- "I taught "
      -- topic3: job_skill
      -- "."
    elseif topic2 == df.unit_thought_type.ReadBook then
      -- "I read "
      -- topic3: written_content
      -- "."
    elseif topic2 == df.unit_thought_type.WriteBook then
      -- "I wrote "
      -- topic3: written_content
      -- "."
    elseif topic2 == df.unit_thought_type.BecomeResident then
      -- "I can now reside in "
      -- topic3: world_site / "an unknown site"
      -- "."
    elseif topic2 == df.unit_thought_type.BecomeCitizen then
      -- "I am now a part of "
      -- topic3: historical_entity
      -- "."
    elseif topic2 == df.unit_thought_type.DenyResident then
      -- "I was denied residency in "
      -- topic3: world_site / "an unknown site"
      -- "."
    elseif topic2 == df.unit_thought_type.DenyCitizen then
      -- "I was rejected by "
      -- topic3: historical_entity
      -- "."
    elseif topic2 == df.unit_thought_type.LeaveTroupe then
      -- TODO
    elseif topic2 == df.unit_thought_type.MakeBelieve then
      -- "I played make believe."
    elseif topic2 == df.unit_thought_type.PlayToy then
      -- "I played with "
      -- topic3: itemdef_toyst
      -- "."
    elseif topic2 == 209 then
    elseif topic2 == 210 then
    elseif topic2 == 211 then
    elseif topic2 == df.unit_thought_type.Argument then
      -- "I got into an argument with "
      -- topic3: historical_figure
      -- "."
      topic_sentence = ps.simple{
        tense=k'PAST',
        t'get into situation'{
          agent=ps.me(context),
          theme=ps.np{
            det=k'a',
            t'with'{
              theme=ps.hf_name(topic3),
            },
            k'argument',
          },
        },
      }
    elseif topic2 == df.unit_thought_type.CombatDrills then
      -- "I did my combat drills."
    elseif topic2 == df.unit_thought_type.ArcheryPractice then
      -- "I practiced at the archery target."
    elseif topic2 == df.unit_thought_type.ImproveSkill then
      -- "I have improved my "
      -- topic3: job_skill
      topic_sentence = ps.simple{
        perfect=true,
        t'improve'{
          agent=ps.me(context),
          theme=ps.np{
            rel=ps.me(context),
            ps.job_skill(topic3),
          },
        },
      }
    elseif topic2 == df.unit_thought_type.WearItem then
      -- "I put on a "
      -- "truly splendid"
      -- / "well-crafted
      -- / "finely-crafted"
      -- / "superior"
      -- / "n exceptional"
      -- " item."
    elseif topic2 == df.unit_thought_type.RealizeValue then
      -- "I am awoken to "
      -- topic4: "the value" / "nuances" / "the worthlessness"
      -- " of "
      -- topic3: value_type
      -- "."
      local realization
      if english:find(' the value ') then
        realization = ps.np{det=k'the', k'value'}
      elseif english:find(' the worthlessness') then
        realization = ps.np{det=k'the', k'worthlessness'}
      else
        realization = ps.np{det=k'the', k'nuance', plural=true}
      end
      topic_sentence = ps.simple{
        perfect=true,
        passive=true,  -- TODO: not really, but "I am X-en" ~ "I've been X-en"
        t'to'{realization},
        t'awake'{
          theme=ps.me(context),
        },
      }
    elseif topic2 == df.unit_thought_type.OpinionStoryteller then
      ----1
      -- TODO
    elseif topic2 == df.unit_thought_type.OpinionRecitation then
      ----1
      -- TODO
    elseif topic2 == df.unit_thought_type.OpinionInstrumentSimulation then
      ----1
      -- TODO
    elseif topic2 == df.unit_thought_type.OpinionInstrumentPlayer then
      ----1
      -- TODO
    elseif topic2 == df.unit_thought_type.OpinionSinger then
      ----1
      -- TODO
    elseif topic2 == df.unit_thought_type.OpinionChanter then
      ----1
      -- TODO
    elseif topic2 == df.unit_thought_type.OpinionDancer then
      ----1
      -- TODO
    end
    if topic == df.talk_choice_type.StateOpinion then
      if topic1 == 0 then
        -- "This must be stopped by any means at our disposal."
        -- / "They must be stopped by any means at our disposal."
        local this_or_they
        if english:find(' this must be stopped by any means at our disposal%.') then
          this_or_they = ps.it()
        else
          this_or_they = ps.them(context)
        end
        focus_sentence = ps.simple{
          mood=k'must',
          passive=true,
          t'stop'{
            agent=ps.np{
              det=k'any',
              t'at'{
                theme=ps.np{
                  t'disposal'{agent=ps.us_inclusive(context)},
                },
              },
              k'means',
            },
            theme=this_or_they,
          },
        }
      elseif topic1 == 1 then
        -- "It's not my problem."
        focus_sentence = ps.simple{
          neg=true,
          subject=ps.it(),
          ps.np{rel=ps.me(context), k'problem'},
        }
      elseif topic1 == 2 then
        -- "It was inevitable."
        focus_sentence = ps.simple{
          tense=k'PAST',
          subject=ps.it(),
          k'inevitable',
        }
      elseif topic1 == 3 then
        ----2
        -- "This is the life for me."
        focus_sentence = ps.simple{
          subject=ps.it(),
          ps.np{
            det=k'the',
            t'for'{theme=ps.me(context)},
            k'life',
          },
        }
      elseif topic1 == 4 then
        -- "It is terrifying."
        focus_sentence = ps.simple{
          subject=ps.it(),
          k'terrifying',
        }
      elseif topic1 == 5 then
        -- "I don't know anything about that."
        focus_sentence = ps.simple{
          neg=true,
          t'know'{
            experiencer=ps.me(context),
            stimulus=ps.np{
              det=k'any',  -- TODO: negative polarity items
              t'about'{theme=ps.it()},  -- TODO: 'that'
              'thing',
            },
          },
        }
      elseif topic1 == 6 then
        ----2
        -- "We are in the right in all matters."
      elseif topic1 == 7 then
        ----2
        -- "It's for the best."
        focus_sentence = ps.simple{
          subject=ps.it(),
          t'for'{
            theme=ps.np{det=k'the', k'best', false},
          },
        }
      elseif topic1 == 8 then
        -- "I don't care one way or another."
        focus_sentence = ps.simple{
          neg=true,
          t'care'{
            experiencer=ps.me(context),
            t'in way'{
              theme=ps.conj{
                ps.np{det=k'a', k'way'},
                k'or',
                ps.np{det=k'a', k'other', k'way'},  -- TODO: omit repeated word
              },
            },
          },
        }
      elseif topic1 == 9 then
        -- "I hate it." / "I hate them."
        local it_or_them
        if english:find('it%.$') then
          it_or_them = ps.it()
        else
          it_or_them = ps.them(context)
        end
        focus_sentence = ps.simple{
          t'hate'{
            experiencer=ps.me(context),
            stimulus=it_or_them,
          },
        }
      elseif topic1 == 10 then
        -- "I am afraid of it." / "I am afraid of them."
        local it_or_them
        if english:find('it%.$') then
          it_or_them = ps.it()
        else
          it_or_them = ps.them(context)
        end
        focus_sentence = ps.simple{
          t'fear'{
            experiencer=ps.me(context),
            stimulus=it_or_them,
          },
        }
      elseif topic1 == 11 then
        -- "That is sad but not unexpected."
        focus_sentence = ps.simple{
          ps.it(),
          ps.conj{
            k'sad',
            k'but',
            ps.adj{
              k'not',
              k'unexpected',
            },
          },
        }
      elseif topic1 == 12 then
        -- "That is terrible."
        focus_sentence = ps.simple{
          subject=ps.it(),
          k'terrible',
        }
      elseif topic1 == 13 then
        -- "That's terrific!"
        focus_sentence = ps.simple{
          subject=ps.it(),
          k'terrific',
          punct='!',
        }
      elseif topic1 == 14 then
        -- "I enjoyed performing."
      elseif topic1 == 15 then
        -- "It was legendary."
      elseif topic1 == 16 then
        -- "It was fantastic."
      elseif topic1 == 17 then
        -- "It was great."
      elseif topic1 == 18 then
        -- "It was good."
      elseif topic1 == 19 then
        -- "It was okay."
      elseif topic1 == 20 then
        -- "I agree completely."
        -- / "So true, so true."
        -- / "No doubt."
        -- / "Truly."
        -- / "I concur!"
        if english == 'so true, so true.' then
          focus_sentence = ps.utterance{
            ps.sentence{ps.fragment{ps.adj{deg=k'so', k'true'}}},
            ps.sentence{ps.fragment{ps.adj{deg=k'so', k'true'}}},
          }
        elseif english == 'no doubt.' then
          focus_sentence = ps.sentence{
            ps.fragment{
              ps.np{
                amount=k'none',
                k'doubt',
              },
            },
          }
        elseif english == 'truly.' then
          focus_sentence = ps.sentence{
            ps.fragment{
              ps.adv{k'true'},
            },
          }
        elseif english == 'i concur!' then
          focus_sentence = ps.simple{
            t'concur'{
              agent=ps.me(context),
            },
            punct='!',
          }
        else
          focus_sentence = ps.simple{
            ps.adv{k'complete'},
            t'agree'{
              agent=ps.me(context),
            },
          }
        end
      elseif topic1 == 21 then
        ----1
        -- "This "
        -- TODO: subject
        -- "is fantastic!"
        -- / "is awesome!"
        -- / "is magnificant!" [sic]
        -- "?  Unbelievable talent!"
        -- / ".  How can I even describe the skill?"
        -- / "is legendary."
        -- / "! Amazing ability."
      elseif topic1 == 22 then
        ----1
        -- "This "
        -- subject
        -- "is great."
        -- / "is really quite good!"
        -- / "shows such talent."
      elseif topic1 == 23 then
        ----1
        -- "This "
        -- subject
        -- "is good."
        -- / "is pretty good."
        -- / "is alright!"
        -- / "has promise."
      elseif topic1 == 24 then
        ----1
        -- "This "
        -- subject
        -- "is okay."
        -- / "is fine."
        -- / "is alright."
        -- / "could be better."
        -- / "could be worse."
        -- / "is middling."
      elseif topic1 == 25 then
        ----1
        -- "This "
        -- subject
        -- "is no good."
        -- / "stinks!"
        -- / "is lousy."
        -- / "is a waste of time."
        -- / "couldn't be much worse."
        -- / "is terrible."
        -- / "is just bad."
        -- / "doesn't belong here."
        -- / "makes me retch."
        -- / "?  Awful."
      elseif topic1 == 26 then
        -- "This is my favorite dance."
      elseif topic1 == 27 then
        -- "This is my favorite music."
        -- / "The accompaniment is my favorite music."
      elseif topic1 == 28 then
        -- "This is my favorite poetry."
        -- / "The lyrics of the accompaniment are my favorite poetry."
        -- / "The lyrics are my favorite poetry."
      elseif topic1 == 29 then
        -- "I love reflective poetry."
        -- / "I love the reflective lyrics."
        -- / "I love the reflective lyrics of the accompaniment."
      elseif topic1 == 30 then
        -- "I hate self-absorbed poetry."
        -- / "I hate the self-absorbed lyrics."
        -- / "I hate the self-absorbed lyrics of the accompaniment."
      elseif topic1 == 31 then
        -- "I love riddles."
        -- / "I love the riddle in the lyrics."
        -- / "I love the riddle in the lyrics of the accompaniment."
      elseif topic1 == 32 then
        -- "I hate riddles."
        -- / "Why is there a riddle in the lyrics?  I hate riddles."
        -- / "Why is there a riddle in the lyrics of the accompaniment?  I hate riddles."
      elseif topic1 == 33 then
        -- "This poetry is so embarrassing!"
        -- / "The lyrics are so embarrassing!"
        -- / "The lyrics of the accompaniment are so embarrassing!"
      elseif topic1 == 34 then
        -- "This poetry is so funny!"
        -- / "The lyrics are so funny!"
        -- / "The lyrics of the accompaniment are so funny!"
      elseif topic1 == 35 then
        -- "I love raunchy poetry!"
        -- / "I love the raunchy lyrics!"
        -- / "I love the raunchy lyrics of the accompaniment!"
      elseif topic1 == 36 then
        -- "I love ribald poetry."
        -- / "I love the ribald lyrics."
        -- / "I love the ribald lyrics of the accompaniment."
      elseif topic1 == 37 then
        -- "I hate this sleazy sort of poetry."
        -- / "These lyrics are simply unacceptable."
        -- / "Must the lyrics of the accompaniment be so off-putting?"
      elseif topic1 == 38 then
        -- "I love light poetry."
        -- / "I love the light lyrics."
        -- / "I love the light lyrics of the accompaniment."
      elseif topic1 == 39 then
        -- "I prefer more weighty subject matter myself."
        -- / "These lyrics are too breezy."
        -- / "Couldn't the lyrics of the accompaniment be a bit more somber?"
      elseif topic1 == 40 then
        -- "I love solemn poetry."
        -- / "I love the solemn lyrics."
        -- / "I love the solemn lyrics of the accompaniment."
      elseif topic1 == 41 then
        -- "I can't stand poetry this serious."
        -- "These lyrics are too austere."
        -- "The lyrics of the accompaniment are way too serious."
      elseif topic1 == 42 then
        -- "This legendary hunt has saved us from a mighty enemy!"
      elseif topic1 == 43 then
        -- "This magnificent hunt has saved us from a fearsome enemy!"
      elseif topic1 == 44 then
        -- "This great hunt has saved us from a dangerous enemy!"
      elseif topic1 == 45 then
        -- "This worthy hunt has rid us of an enemy."
      elseif topic1 == 46 then
        -- "This hunt has rid us of a nuisance."
      elseif topic1 == 47 then
        -- "That was a legendary hunt!"
      elseif topic1 == 48 then
        -- "That was a magnificent hunt!"
      elseif topic1 == 49 then
        -- "That was a great hunt!"
      elseif topic1 == 50 then
        -- "That was a worthy hunt."
      elseif topic1 == 51 then
        -- "That was hunter's work."
      elseif topic1 == 52 then
        -- "We are saved from a mighty enemy!"
      elseif topic1 == 53 then
        -- "We are saved from a fearsome enemy!"
      elseif topic1 == 54 then
        -- "We are saved from a dangerous enemy!"
      elseif topic1 == 55 then
        -- "We are rid of an enemy."
      elseif topic1 == 56 then
        -- "We are rid of a nuisance."
      elseif topic1 == 57 then
        -- "They are outlaws." ?
      elseif topic1 == 58 then
        -- "The defenseless are safer from outlaws."
      end
    elseif topic == df.talk_choice_type.ExpressOverwhelmingEmotion then
      if (topic1 == df.emotion_type.AGONY or
          topic1 == df.emotion_type.ANGUISH) then
        -- "The pain!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.np{det=k'the', k'pain'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.ALARM then
        -- "Somebody help!"
        focus_sentence = ps.simple{
          mood=k'IMPERATIVE',
          t'help'{
            agent=k'somebody',
            -- TODO: implicit theme "me"
          },
          punct='!',
        }
      -- ANGUISH: see AGONY
      elseif topic1 == df.emotion_type.ANGST then
        -- "What is the meaning of it all?!"
        -- "The pain!"
        -- TODO: Check "The pain!"
      elseif topic1 == df.emotion_type.BLISS then
        -- "Such sweet bliss!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.np{k'such', k'sweet', k'bliss'},
          },
          punct='!',
        }
      elseif (topic1 == df.emotion_type.DESPAIR or
              topic1 == df.emotion_type.GRIEF or
              topic1 == df.emotion_type.MISERY or
              topic1 == df.emotion_type.MORTIFICATION or
              topic1 == df.emotion_type.SADNESS or
              topic1 == df.emotion_type.SHAKEN) then
        -- "Waaaaa..."
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.noise{k'wa'},
          },
          punct='...',
        }
      elseif (topic1 == df.emotion_type.DISMAY or
              topic1 == df.emotion_type.DISTRESS or
              topic1 == df.emotion_type.FEAR or
              topic1 == df.emotion_type.TERROR) then
        -- "Ahhhhhhh!  No!"
        focus_sentence = ps.utterance{
          ps.sentence{
            ps.fragment{
              ps.noise{k'ah (fear)'},
            },
            punct='!',
          },
          ps.sentence{
            ps.fragment{
              k'no',
            },
            punct='!',
          },
        }
      -- DISTRESS: see DISMAY
      elseif topic1 == df.emotion_type.EUPHORIA then
        -- "I can't believe how great I feel!"
        focus_sentence = ps.simple{
          mood=k'can,X',
          neg=true,
          t'believe'{
            experiencer=ps.me(context),
            stimulus=ps.wh{
              t'feel condition'{
                experiencer=ps.me(context),
                stimulus=ps.adj{
                  deg=h'how',
                  k'euphoric',
                },
              },
            },
          },
        }
      -- FEAR: see DISMAY
      elseif topic1 == df.emotion_type.FRIGHT then
        -- "Eek!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.noise{k'eek'},
          },
          punct='!',
        }
      -- GRIEF: see DESPAIR
      elseif topic1 == df.emotion_type.HORROR then
        -- "The horror..."
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.np{det=k'the', k'horror'},
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.JOY then
        -- "Oh joyous occasion!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.noise{k'oh'},
            ps.np{k'joyous', k'occasion'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.LOVE then
        -- "The love overwhelms me!"
        focus_sentence = ps.simple{
          t'overwhelm'{
            stimulus=ps.np{det=k'the', k'love,N'},
            experiencer=ps.me(context),
          },
          punct='!',
        }
      -- MISERY: see DESPAIR
      -- MORTIFICATION: see DESPAIR
      elseif topic1 == df.emotion_type.RAGE then
        -- "Rawr!!!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.noise{k'rawr'},
          },
          punct='!',
        }
      -- SADNESS: see DESPAIR
      elseif topic1 == df.emotion_type.SATISFACTION then
        -- "How incredibly satisfying!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', ps.adv{k'incredible'}, k'satisfying'},
          },
          punct='!',
        }
      -- SHAKEN: see DESPAIR
      elseif topic1 == df.emotion_type.SHOCK then
        -- "Ah...  uh..."
        focus_sentence = ps.utterance{
          ps.sentence{
            ps.fragment{
              ps.noise{k'ah (shock)'},
            },
            punct='...',
          },
          ps.sentence{
            ps.fragment{
              ps.noise{k'uh (shock)'},
            },
            punct='...',
          },
        }
      -- TERROR: see DISMAY
      elseif topic1 == df.emotion_type.VENGEFULNESS then
        -- "Every last one of you will pay with your lives!"
        focus_sentence = ps.simple{
          tense=k'FUTURE',
          t'pay'{
            agent=ps.np{
              amount=k'all',  -- TODO: 'every last one'
              ps.you(context),
            },
            theme=ps.np{
              rel=ps.you(context),
              k'life',
              plural=true,
            },
          },
        }
      end
    elseif topic == df.talk_choice_type.ExpressGreatEmotion then
      ----1
      if topic1 == df.emotion_type.ACCEPTANCE then
        -- "I am in complete accord with this!"
        focus_sentence = ps.simple{
          t'agree'{
            -- idiom
            experiencer=ps.me(context),
            stimulus=ps.this(),
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.ADORATION then
        -- "Such adoration I feel!"
        -- TODO: topic-fronting
        focus_sentence = ps.simple{
          t'feel emotion'{
            experiencer=ps.me(context),
            stimulus=ps.np{k'such', k'adoration'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.AFFECTION then
        -- "How affectionate I am!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.wh{
              subject=ps.me(context),
              ps.adj{
                deg=k'how',
                k'affectionate',
              },
            },
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.AGITATION then
        -- "How agitating!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'agitating'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.AGGRAVATION then
        -- "This is so aggravating!"
        focus_sentence = ps.simple{
          subject=ps.this(),
          ps.adj{deg=k'so', 'aggravating'},
          punct='!',
        }
      elseif topic1 == df.emotion_type.AGONY then
        -- "The agony is too much!"
        focus_sentence = ps.simple{
          subject=ps.np{det=k'the', k'agony'},
          k'too much',
          punct='!',
        }
      elseif topic1 == df.emotion_type.ALARM then
        -- "What's going on?!"
        focus_sentence = ps.simple{
          progressive=true,
          t'happen'{
            theme=k'what',
          },
          punct='?!',
        }
      elseif topic1 == df.emotion_type.ALIENATION then
        -- "I feel so alienated..."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'alienated'},
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.AMAZEMENT then
        -- "Wow!  That's amazing!"
        focus_sentence = ps.utterance{
          ps.sentence{
            ps.fragment{
              ps.noise{k'wow'},
            },
            punct='!',
          },
          ps.sentence{
            ps.infl{
              subject=ps.that(),
              k'amazing',
            },
            punct='!',
          },
        }
      elseif topic1 == df.emotion_type.AMBIVALENCE then
        -- "I am so torn over this..."
        focus_sentence = ps.simple{
          passive=true,
          t'tear'{
            stimulus=ps.this(),
            theme=ps.me(context),
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.AMUSEMENT then
        -- "Ha ha!  So amusing!"
        focus_sentence = ps.utterance{
          ps.sentence{
            ps.fragment{
              ps.noise{k'haha'},
            },
            punct='!',
          },
          ps.sentence{
            ps.fragment{
              ps.adj{deg=k'so', k'amusing'},
            },
            punct='!',
          },
        }
      elseif topic1 == df.emotion_type.ANGER then
        -- "I am so angry!"
        consituent = ps.simple{
          subject=ps.me(context),
          ps.adj{deg=k'so', k'angry'},
          punct='!',
        }
      elseif topic1 == df.emotion_type.ANGST then
        -- "What am I even doing here?"
        ----1
      elseif topic1 == df.emotion_type.ANGUISH then
        -- "The anguish is overwhelming..."
        focus_sentence = ps.simple{
          subject=ps.np{det=k'the', k'anguish'},
          k'overwhelming',
          punct='...',
        }
      elseif topic1 == df.emotion_type.ANNOYANCE then
        -- "How annoying!"
        -- / "It's annoying."
        -- / "I'm annoyed."
        -- / "That's annoying."
        -- / "So annoying!"
        if english:find('how annoying!') then
          focus_sentence = ps.sentence{
            ps.fragment{
              ps.adj{deg=k'how', k'annoying'},
            },
            punct='!',
          }
        elseif english:find("it's annoying%.") then
          focus_sentence = ps.simple{
            subject=ps.it(),
            k'annoying',
          }
        elseif english:find("that's annoying%.") then
          focus_sentence = ps.simple{
            subject=ps.that(),
            k'annoying',
          }
        elseif english:find('so annoying!') then
          focus_sentence = ps.sentence{
            ps.fragment{
              ps.adj{deg=k'so', k'annoying'},
            },
            punct='!',
          }
        else
          focus_sentence = ps.simple{
            subject=ps.me(context),
            k'annoyed',
          }
        end
      elseif topic1 == df.emotion_type.ANXIETY then
        -- "I'm so anxious!"
        focus_sentence = ps.simple{
          subject=ps.me(context),
          ps.adj{deg=k'so', k'anxious'},
          punct='!',
        }
      elseif topic1 == df.emotion_type.APATHY then
        -- "I could not care less."
        focus_sentence = ps.simple{
          mood=k'could',
          neg=true,
          k'less',
          t'care'{
            experiencer=ps.me(context),
          },
        }
      elseif topic1 == df.emotion_type.AROUSAL then
        -- "I am very aroused!"
        focus_sentence = ps.simple{
          subject=ps.me(context),
          ps.adj{q=k'very', k'aroused'},
          punct='!',
        }
      elseif topic1 == df.emotion_type.ASTONISHMENT then
        -- "Astonishing!"
        focus_sentence = ps.sentence{
          ps.fragment{
            k'astonishing',
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.AVERSION then
        -- "I really need to get away from this."
        focus_sentence = ps.simple{
          k'really',
          t'need'{
            experiencer=ps.me(context),
            stimulus=ps.infl{
              tense=k'INFINITIVE',
              t'get away from'{
                agent=ps.me(context),  -- TODO: PRO?
                theme=ps.this(),
              },
            },
          },
        }
      elseif topic1 == df.emotion_type.AWE then
        -- "I'm awe-struck!"
        focus_sentence = ps.simple{
          subject=ps.me(context),
          k'awe-struck',
          punct='!',
        }
      elseif topic1 == df.emotion_type.BITTERNESS then
        -- "I'm terribly bitter about this..."
        focus_sentence = ps.simple{
          subject=ps.me(context),
          ps.adj{
            q=k'terribly',
            t'about'{
              theme=ps.this(),
            },
            k'bitter',
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.BLISS then
        -- "How blissful!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'blissful'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.BOREDOM then
        -- "This is so boring!"
        focus_sentence = ps.simple{
          subject=ps.this(),
          ps.adj{deg=k'so', k'boring'},
          punct='!',
        }
      elseif topic1 == df.emotion_type.CARING then
        -- "I care so much!"
        focus_sentence = ps.simple{
          ps.adv{deg=k'so', false, k'much'},
          t'care'{
            experiencer=ps.me(context),
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.CONFUSION then
        -- "I'm so incredibly confused..."
        focus_sentence = ps.simple{
          subject=ps.me(context),
          ps.adj{deg=k'so', ps.adv{k'incredible'}, k'confused'},
        }
      elseif topic1 == df.emotion_type.CONTEMPT then
        -- "I can't describe the contempt I feel..."
        focus_sentence = ps.simple{
          mood=k'can,X',
          neg=true,
          t'describe'{
            agent=ps.me(context),
            theme=ps.np{
              det=k'the',
              ps.wh_bound{
                t'feel emotion'{
                  experiencer=ps.me(context),
                  stimulus=k'which',
                },
              },
              k'contempt',
            },
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.CONTENTMENT then
        -- "I am so content about this."
        focus_sentence = ps.simple{
          subject=ps.me(context),
          ps.adj{
            deg=k'so',
            t'about'{theme=ps.this()},
            k'content',
          },
        }
      elseif topic1 == df.emotion_type.DEFEAT then
        -- "I feel so defeated..."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'defeated'},
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.DEJECTION then
        -- "I feel so dejected..."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'dejected'},
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.DELIGHT then
        -- "How very delightful!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', q=k'very', k'delightful'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.DESPAIR then
        -- "I despair at this!"
        focus_sentence = ps.simple{
          t'despair'{
            agent=ps.me(context),
            theme=ps.this(),
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.DISAPPOINTMENT then
        -- "My disappointment is palpable!"
        focus_sentence = ps.simple{
          subject=ps.np{
            t'disappointment'{
              experiencer=ps.me(context),
            },
          },
          k'palpable',
          punct='!',
        }
      elseif topic1 == df.emotion_type.DISGUST then
        -- "How disgusting!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'disgusting'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.DISILLUSIONMENT then
        -- "How naive I was...  this strikes me to the core."
        focus_sentence = ps.utterance{
          ps.sentence{
            ps.fragment{
              ps.wh{
                tense=k'PAST',
                subject=ps.me(context),
                ps.adj{
                  deg=k'how',
                  k'naive',
                },
              },
            },
            punct='...',
          },
          ps.sentence{
            ps.infl{
              t'to'{
                theme=ps.np{k'the', k'core'},
                -- TODO: Some languages might explicitly say "my core".
              },
              t'strike'{
                agent=ps.this(),
                theme=ps.me(context),
              },
            },
          },
        }
      elseif topic1 == df.emotion_type.DISLIKE then
        -- "I feel such an intense dislike..."
        focus_sentence = ps.simple{
          t'feel emotion'{
            experiencer=ps.me(context),
            stimulus=ps.np{det=k'a', k'such', k'intense', k'dislike'},
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.DISMAY then
        -- "Everything is coming apart!"
        focus_sentence = ps.simple{
          progressive=true,
          t'come apart'{
            agent=k'everything',
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.DISPLEASURE then
        -- "I am very, very displeased."
        focus_sentence = ps.simple{
          subject=ps.me(context),
          -- TODO: double Q
          ps.adj{q=k'very', q=k'very', k'displeased'},
        }
      elseif topic1 == df.emotion_type.DISTRESS then
        -- "What shall I do?  This is a disaster!"
        focus_sentence = ps.utterance{
          ps.sentence{
            ps.infl{
              mood=k'shall',
              t'do'{
                agent=ps.me(context),
                theme=k'what',
              },
            },
            punct='?',
          },
          ps.sentence{
            ps.infl{
              subject=ps.this(),
              ps.np{det=k'a', k'disaster'},
            },
            punct='!',
          },
        }
      elseif topic1 == df.emotion_type.DOUBT then
        -- "I am wracked by doubts!"
        focus_sentence = ps.simple{
          passive=true,
          t'wrack'{
            agent=ps.np{k'doubt', plural=true},
            theme=ps.me(context),
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.EAGERNESS then
        -- "I can't wait to get to it!"
      elseif topic1 == df.emotion_type.ELATION then
        -- "Such elation I feel!"
      elseif topic1 == df.emotion_type.EMBARRASSMENT then
        -- "How embarrassing!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'embarrassing'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.EMPATHY then
        -- "I feel such empathy!"
      elseif topic1 == df.emotion_type.EMPTINESS then
        -- "I feel so empty inside..."
      elseif topic1 == df.emotion_type.ENJOYMENT then
        -- "How enjoyable!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'enjoyable'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.ENTHUSIASM then
        -- "Let's go!"
      elseif topic1 == df.emotion_type.EUPHORIA then
        -- "I feel so good!"
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'good'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.EXASPERATION then
        -- "So exasperating!"
      elseif topic1 == df.emotion_type.EXCITEMENT then
        -- "This is so exciting!"
      elseif topic1 == df.emotion_type.EXHILARATION then
        -- "How exhilarating!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'exhilarating'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.EXPECTANCY then
        -- "I know it will come to pass!"
      elseif topic1 == df.emotion_type.FEAR then
        -- "I must not succumb to fear!"
      elseif topic1 == df.emotion_type.FEROCITY then
        -- "You will know my ferocity!"
      elseif topic1 == df.emotion_type.FONDNESS then
        -- "I'm feeling so fond!"
      elseif topic1 == df.emotion_type.FREEDOM then
        -- "Such freedom I feel!"
      elseif topic1 == df.emotion_type.FRIGHT then
        -- "Such a fright!"
      elseif topic1 == df.emotion_type.FRUSTRATION then
        -- "How frustrating!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'frustrating'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.GAIETY then
        -- "Such gaiety!"
      elseif topic1 == df.emotion_type.GLEE then
        -- "Glee!"
      elseif topic1 == df.emotion_type.GLOOM then
        -- "The gloom blankets me..."
      elseif topic1 == df.emotion_type.GLUMNESS then
        -- "How glum I am..."
      elseif topic1 == df.emotion_type.GRATITUDE then
        -- "I am so grateful!"
      elseif topic1 == df.emotion_type.GRIEF then
        -- "I cannot be overwhelmed by grief!"
      elseif topic1 == df.emotion_type.GRIM_SATISFACTION then
        -- "Yes!  It is done."
      elseif topic1 == df.emotion_type.GROUCHINESS then
        -- "It makes me so grouchy!"
      elseif topic1 == df.emotion_type.GRUMPINESS then
        -- "Not that it's your business!  Harumph!"
      elseif topic1 == df.emotion_type.GUILT then
        -- "The guilt is almost unbearable!"
      elseif topic1 == df.emotion_type.HAPPINESS then
        -- "Such happiness!"
      elseif topic1 == df.emotion_type.HATRED then
        -- "I am consumed by hatred."
      elseif topic1 == df.emotion_type.HOPE then
        -- "I am filled with such hope!"
      elseif topic1 == df.emotion_type.HOPELESSNESS then
        -- "There is no hope!"
      elseif topic1 == df.emotion_type.HORROR then
        -- "The horror consumes me!"
      elseif topic1 == df.emotion_type.HUMILIATION then
        -- "The humiliation!"
      elseif topic1 == df.emotion_type.INSULT then
        -- "Such an offense!"
      elseif topic1 == df.emotion_type.INTEREST then
        -- "How incredibly interesting!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', ps.adv{k'incredible'}, k'interesting'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.IRRITATION then
        -- "How irritating!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'irritating'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.ISOLATION then
        -- "I feel so isolated!"
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'isolated'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.JOLLINESS then
        -- "Such a jolly time!"
      elseif topic1 == df.emotion_type.JOVIALITY then
        -- "How jovial I feel!"
      elseif topic1 == df.emotion_type.JOY then
        -- "I am so happy!"
      elseif topic1 == df.emotion_type.JUBILATION then
        -- "Such jubilation I feel!"
      elseif topic1 == df.emotion_type.LOATHING then
        -- "I crawl with such unbearable loathing!"
      elseif topic1 == df.emotion_type.LONELINESS then
        -- "I'm so terribly lonely!"
      elseif topic1 == df.emotion_type.LOVE then
        -- "I feel such love!"
      elseif topic1 == df.emotion_type.LUST then
        -- "I'm overcome by lust!"
      elseif topic1 == df.emotion_type.MISERY then
        -- "Such misery!"
      elseif topic1 == df.emotion_type.MORTIFICATION then
        -- "The mortification overwhelms me!"
      elseif topic1 == df.emotion_type.NERVOUSNESS then
        -- "I am so nervous!"
      elseif topic1 == df.emotion_type.NOSTALGIA then
        -- "Such nostalgia!"
      elseif topic1 == df.emotion_type.OPTIMISM then
        -- "My optimism is unshakeable!"
      elseif topic1 == df.emotion_type.OUTRAGE then
        -- "This is such an outrage!"
      elseif topic1 == df.emotion_type.PANIC then
        -- "I'm panicking!  I'm panicking!"
      elseif topic1 == df.emotion_type.PATIENCE then
        -- "My patience is as the still waters."
      elseif topic1 == df.emotion_type.PASSION then
        -- "I burn with such passion!"
      elseif topic1 == df.emotion_type.PESSIMISM then
        -- "This cannot possibly end well..."
      elseif topic1 == df.emotion_type.PLEASURE then
        -- "How pleasurable!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'pleasurable'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.PRIDE then
        -- "I am so proud!"
      elseif topic1 == df.emotion_type.RAGE then
        -- "I am so enraged!"
      elseif topic1 == df.emotion_type.RAPTURE then
        -- "Such total rapture!"
      elseif topic1 == df.emotion_type.REJECTION then
        -- "Such rejection!  I cannot stand it."
      elseif topic1 == df.emotion_type.RELIEF then
        -- "Such a relief!"
      elseif topic1 == df.emotion_type.REGRET then
        -- "I have so many regrets..."
      elseif topic1 == df.emotion_type.REMORSE then
        -- "I feel such remorse!"
      elseif topic1 == df.emotion_type.REPENTANCE then
        -- "I repent!  I repent!"
      elseif topic1 == df.emotion_type.RESENTMENT then
        -- "I am overcome by such resentment..."
      elseif topic1 == df.emotion_type.RIGHTEOUS_INDIGNATION then
        -- "I have been so wronged!"
      elseif topic1 == df.emotion_type.SADNESS then
        -- "I feel such unbearable sadness..."
      elseif topic1 == df.emotion_type.SATISFACTION then
        -- "That was very satisfying!"
      elseif topic1 == df.emotion_type.SELF_PITY then
        -- "Why does it keep happening to me?  Why me?!"
      elseif topic1 == df.emotion_type.SERVILE then
        -- "I live to serve...  my dear master..."
      elseif topic1 == df.emotion_type.SHAKEN then
        -- "I can't take it!"
      elseif topic1 == df.emotion_type.SHAME then
        -- "I am so ashamed!"
      elseif topic1 == df.emotion_type.SHOCK then
        -- "What's that?!"
      elseif topic1 == df.emotion_type.SUSPICION then
        -- "That's incredibly suspicious!"
      elseif topic1 == df.emotion_type.SYMPATHY then
        -- "I feel such sympathy!"
      elseif topic1 == df.emotion_type.TENDERNESS then
        -- "The tenderness I feel!"
      elseif topic1 == df.emotion_type.TERROR then
        -- "I must press on!"
      elseif topic1 == df.emotion_type.THRILL then
        -- "It's so thrilling!"
      elseif topic1 == df.emotion_type.TRIUMPH then
        -- "Fantastic!"
      elseif topic1 == df.emotion_type.UNEASINESS then
        -- "I feel so uneasy!"
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'uneasy'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.UNHAPPINESS then
        -- "Such unhappiness!"
      elseif topic1 == df.emotion_type.VENGEFULNESS then
        -- "I will take revenge!"
      elseif topic1 == df.emotion_type.WONDER then
        -- "The wonder!"
      elseif topic1 == df.emotion_type.WORRY then
        -- "I'm so worried!"
      elseif topic1 == df.emotion_type.WRATH then
        -- "I am filled with such wrath!"
      elseif topic1 == df.emotion_type.ZEAL then
        -- "Nothing shall stand in my way!"
      elseif topic1 == df.emotion_type.RESTLESS then
        -- "I feel so restless!"
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'restless'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.ADMIRATION then
        -- "How admirable!"
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'admirable'},
          },
          punct='!',
        }
      end
    elseif topic == df.talk_choice_type.ExpressEmotion then
      ----1
      if topic1 == df.emotion_type.ACCEPTANCE then
        -- "I accept this."
      elseif topic1 == df.emotion_type.ADORATION then
        -- "I adore this."
      elseif topic1 == df.emotion_type.AFFECTION then
        -- "I'm feeling affectionate."
      elseif topic1 == df.emotion_type.AGITATION then
        -- "This is driving me to agitation."
      elseif topic1 == df.emotion_type.AGGRAVATION then
        -- "I'm very aggravated."
      elseif topic1 == df.emotion_type.AGONY then
        -- "The agony I feel..."
      elseif topic1 == df.emotion_type.ALARM then
        -- "That's alarming!"
      elseif topic1 == df.emotion_type.ALIENATION then
        -- "I feel alienated."
      elseif topic1 == df.emotion_type.AMAZEMENT then
        -- "That's amazing!"
      elseif topic1 == df.emotion_type.AMBIVALENCE then
        -- "I have strong feelings of ambivalence."
      elseif topic1 == df.emotion_type.AMUSEMENT then
        -- "That's very amusing."
      elseif topic1 == df.emotion_type.ANGER then
        -- "I'm very angry."
      elseif topic1 == df.emotion_type.ANGST then
        -- "What is the meaning of life..."
      elseif topic1 == df.emotion_type.ANGUISH then
        -- "I feel so anguished..."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'anguished'},
          },
          punct='!',
        }
      elseif topic1 == df.emotion_type.ANNOYANCE then
        -- "That's very annoying."
      elseif topic1 == df.emotion_type.ANXIETY then
        -- "It makes me very anxious."
      elseif topic1 == df.emotion_type.APATHY then
        -- "It would be hard to care less."
      elseif topic1 == df.emotion_type.AROUSAL then
        -- "I'm aroused!"
      elseif topic1 == df.emotion_type.ASTONISHMENT then
        -- "It's quite astonishing."
      elseif topic1 == df.emotion_type.AVERSION then
        -- "I'm very averse to this."
      elseif topic1 == df.emotion_type.AWE then
        -- "Awe-inspiring..."
      elseif topic1 == df.emotion_type.BITTERNESS then
        -- "It makes me very bitter."
      elseif topic1 == df.emotion_type.BLISS then
        -- "How blissful I am."
      elseif topic1 == df.emotion_type.BOREDOM then
        -- "It's really boring."
      elseif topic1 == df.emotion_type.CARING then
        -- "I really care."
      elseif topic1 == df.emotion_type.CONFUSION then
        -- "I'm so confused."
      elseif topic1 == df.emotion_type.CONTEMPT then
        -- "Contemptible!"
      elseif topic1 == df.emotion_type.CONTENTMENT then
        -- "I'm very content."
      elseif topic1 == df.emotion_type.DEFEAT then
        -- "I've been defeated."
      elseif topic1 == df.emotion_type.DEJECTION then
        -- "I'm feeling very dejected."
      elseif topic1 == df.emotion_type.DELIGHT then
        -- "This is delightful!"
      elseif topic1 == df.emotion_type.DESPAIR then
        -- "I feel such despair..."
      elseif topic1 == df.emotion_type.DISAPPOINTMENT then
        -- "I am very disappointed."
      elseif topic1 == df.emotion_type.DISGUST then
        -- "So disgusting..."
      elseif topic1 == df.emotion_type.DISILLUSIONMENT then
        -- "I've become so disillusioned.  What now?"
      elseif topic1 == df.emotion_type.DISLIKE then
        -- "I really don't like this."
      elseif topic1 == df.emotion_type.DISMAY then
        -- "It has all gone wrong!"
      elseif topic1 == df.emotion_type.DISPLEASURE then
        -- "This is quite displeasing."
      elseif topic1 == df.emotion_type.DISTRESS then
        -- "I'm so distressed about this!"
      elseif topic1 == df.emotion_type.DOUBT then
        -- "I'm very doubtful."
      elseif topic1 == df.emotion_type.EAGERNESS then
        -- "I'm very eager to get started."
      elseif topic1 == df.emotion_type.ELATION then
        -- "I'm so elated."
      elseif topic1 == df.emotion_type.EMBARRASSMENT then
        -- "This is so embarrassing..."
      elseif topic1 == df.emotion_type.EMPATHY then
        -- "I'm very empathetic."
      elseif topic1 == df.emotion_type.EMPTINESS then
        -- "I feel such emptiness."
      elseif topic1 == df.emotion_type.ENJOYMENT then
        -- "I really enjoyed that!"
      elseif topic1 == df.emotion_type.ENTHUSIASM then
        -- "I feel enthusiastic!"
      elseif topic1 == df.emotion_type.EUPHORIA then
        -- "I'm feeling great!"
      elseif topic1 == df.emotion_type.EXASPERATION then
        -- "I'm quite exasperated."
      elseif topic1 == df.emotion_type.EXCITEMENT then
        -- "This is really exciting!"
      elseif topic1 == df.emotion_type.EXHILARATION then
        -- "That was very exhilarating!"
      elseif topic1 == df.emotion_type.EXPECTANCY then
        -- "Things are going to happen."
      elseif topic1 == df.emotion_type.FEAR then
        -- "Begone fear!"
      elseif topic1 == df.emotion_type.FEROCITY then
        -- "I'm feeling so ferocious!"
      elseif topic1 == df.emotion_type.FONDNESS then
        -- "I'm very fond."
      elseif topic1 == df.emotion_type.FREEDOM then
        -- "I feel so free."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'free'},
          },
        }
      elseif topic1 == df.emotion_type.FRIGHT then
        -- "That was so frightful."
      elseif topic1 == df.emotion_type.FRUSTRATION then
        -- "This is very frustrating."
      elseif topic1 == df.emotion_type.GAIETY then
        -- "The gaiety I'm feeling!"
      elseif topic1 == df.emotion_type.GLEE then
        -- "I'm so gleeful."
      elseif topic1 == df.emotion_type.GLOOM then
        -- "It makes me so gloomy."
      elseif topic1 == df.emotion_type.GLUMNESS then
        -- "I feel so glum."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'glum'},
          },
        }
      elseif topic1 == df.emotion_type.GRATITUDE then
        -- "I'm very grateful."
      elseif topic1 == df.emotion_type.GRIEF then
        -- "I am almost overcome by grief."
      elseif topic1 == df.emotion_type.GRIM_SATISFACTION then
        -- "It is done."
      elseif topic1 == df.emotion_type.GROUCHINESS then
        -- "It makes me very grouchy."
      elseif topic1 == df.emotion_type.GRUMPINESS then
        -- "Harumph!"
      elseif topic1 == df.emotion_type.GUILT then
        -- "I feel so guilty."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'guilty'},
          },
        }
      elseif topic1 == df.emotion_type.HAPPINESS then
        -- "I am so happy."
      elseif topic1 == df.emotion_type.HATRED then
        -- "The hate burns within me."
      elseif topic1 == df.emotion_type.HOPE then
        -- "I am very hopeful."
      elseif topic1 == df.emotion_type.HOPELESSNESS then
        -- "I feel hopeless."
      elseif topic1 == df.emotion_type.HORROR then
        -- "This is truly horrifying."
      elseif topic1 == df.emotion_type.HUMILIATION then
        -- "This is so humiliating."
      elseif topic1 == df.emotion_type.INSULT then
        -- "I am very insulted."
      elseif topic1 == df.emotion_type.INTEREST then
        -- "It's very interesting."
      elseif topic1 == df.emotion_type.IRRITATION then
        -- "I'm very irritated by this."
      elseif topic1 == df.emotion_type.ISOLATION then
        -- "I feel very isolated."
      elseif topic1 == df.emotion_type.JOLLINESS then
        -- "I'm feeling so jolly."
      elseif topic1 == df.emotion_type.JOVIALITY then
        -- "I'm very jovial."
      elseif topic1 == df.emotion_type.JOY then
        -- "This is a joyous time."
      elseif topic1 == df.emotion_type.JUBILATION then
        -- "I feel much jubilation."
      elseif topic1 == df.emotion_type.LOATHING then
        -- "I feel so much loathing..."
      elseif topic1 == df.emotion_type.LONELINESS then
        -- "I'm very lonely."
      elseif topic1 == df.emotion_type.LOVE then
        -- "This is love."
      elseif topic1 == df.emotion_type.LUST then
        -- "I feel such lust."
      elseif topic1 == df.emotion_type.MISERY then
        -- "I'm so miserable."
      elseif topic1 == df.emotion_type.MORTIFICATION then
        -- "I'm so mortified..."
      elseif topic1 == df.emotion_type.NERVOUSNESS then
        -- "I'm very nervous."
      elseif topic1 == df.emotion_type.NOSTALGIA then
        -- "I'm feeling very nostalgic."
      elseif topic1 == df.emotion_type.OPTIMISM then
        -- "I'm quite optimistic."
      elseif topic1 == df.emotion_type.OUTRAGE then
        -- "This is an outrage!"
      elseif topic1 == df.emotion_type.PANIC then
        -- "I'm really starting to panic."
      elseif topic1 == df.emotion_type.PATIENCE then
        -- "I'm very patient."
      elseif topic1 == df.emotion_type.PASSION then
        -- "I feel such passion."
      elseif topic1 == df.emotion_type.PESSIMISM then
        -- "I really don't see this working out."
      elseif topic1 == df.emotion_type.PLEASURE then
        -- "I'm very pleased."
      elseif topic1 == df.emotion_type.PRIDE then
        -- "I am very proud."
      elseif topic1 == df.emotion_type.RAGE then
        -- "I am about to lose it!"
      elseif topic1 == df.emotion_type.RAPTURE then
        -- "I am so spiritually moved!"
      elseif topic1 == df.emotion_type.REJECTION then
        -- "I feel so rejected."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'rejected'},
          },
        }
      elseif topic1 == df.emotion_type.RELIEF then
        -- "I'm so relieved."
      elseif topic1 == df.emotion_type.REGRET then
        -- "I'm so regretful."
      elseif topic1 == df.emotion_type.REMORSE then
        -- "I'm truly remorseful."
      elseif topic1 == df.emotion_type.REPENTANCE then
        -- "I must repent."
      elseif topic1 == df.emotion_type.RESENTMENT then
        -- "I'm very resentful."
      elseif topic1 == df.emotion_type.RIGHTEOUS_INDIGNATION then
        -- "I feel so wronged."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{deg=k'so', k'wronged'},
          },
        }
      elseif topic1 == df.emotion_type.SADNESS then
        -- "I cannot give in to sadness."
      elseif topic1 == df.emotion_type.SATISFACTION then
        -- "I am very satisfied."
      elseif topic1 == df.emotion_type.SELF_PITY then
        -- "This is such a hardship for me!"
      elseif topic1 == df.emotion_type.SERVILE then
        -- "I live to serve."
      elseif topic1 == df.emotion_type.SHAKEN then
        -- "This leaves me so shaken."
      elseif topic1 == df.emotion_type.SHAME then
        -- "I feel such shame."
      elseif topic1 == df.emotion_type.SHOCK then
        -- "Most shocking!"
      elseif topic1 == df.emotion_type.SUSPICION then
        -- "That's suspicious!"
      elseif topic1 == df.emotion_type.SYMPATHY then
        -- "I'm very sympathetic."
      elseif topic1 == df.emotion_type.TENDERNESS then
        -- "I feel such tenderness."
      elseif topic1 == df.emotion_type.TERROR then
        -- "I am not scared!"
      elseif topic1 == df.emotion_type.THRILL then
        -- "This is quite a thrill!"
      elseif topic1 == df.emotion_type.TRIUMPH then
        -- "This is great!"
      elseif topic1 == df.emotion_type.UNEASINESS then
        -- "I feel very uneasy."
      elseif topic1 == df.emotion_type.UNHAPPINESS then
        -- "I'm very unhappy."
      elseif topic1 == df.emotion_type.VENGEFULNESS then
        -- "I will have my revenge."
      elseif topic1 == df.emotion_type.WONDER then
        -- "I am filled with wonder."
      elseif topic1 == df.emotion_type.WORRY then
        -- "I'm very worried."
      elseif topic1 == df.emotion_type.WRATH then
        -- "I am wrathful."
      elseif topic1 == df.emotion_type.ZEAL then
        -- "I shall accomplish much!"
      elseif topic1 == df.emotion_type.RESTLESS then
        -- "I'm really restless."
      elseif topic1 == df.emotion_type.ADMIRATION then
        -- "I admire this."
      end
    elseif topic == df.talk_choice_type.ExpressMinorEmotion then
      ----1
      if topic1 == df.emotion_type.ACCEPTANCE then
        -- "I can accept this."
      elseif topic1 == df.emotion_type.ADORATION then
        -- "I can adore this."
      elseif topic1 == df.emotion_type.AFFECTION then
        -- "That might be affection I feel."
      elseif topic1 == df.emotion_type.AGITATION then
        -- "This is agitating."
      elseif topic1 == df.emotion_type.AGGRAVATION then
        -- "This is aggravating."
      elseif topic1 == df.emotion_type.AGONY then
        -- "This is agonizing."
      elseif topic1 == df.emotion_type.ALARM then
        -- "That was alarming."
      elseif topic1 == df.emotion_type.ALIENATION then
        -- "I feel somewhat alienated."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{q=k'somewhat', k'alienated'},
          },
        }
      elseif topic1 == df.emotion_type.AMAZEMENT then
        -- "That is amazing."
      elseif topic1 == df.emotion_type.AMBIVALENCE then
        -- "I'm ambivalent."
      elseif topic1 == df.emotion_type.AMUSEMENT then
        -- "Amusing."
      elseif topic1 == df.emotion_type.ANGER then
        -- "That makes me angry."
      elseif topic1 == df.emotion_type.ANGST then
        -- "I just don't know."
      elseif topic1 == df.emotion_type.ANGUISH then
        -- "I'm anguished."
      elseif topic1 == df.emotion_type.ANNOYANCE then
        -- "It's annoying."
        focus_sentence = ps.simple{
          subject=ps.it(),
          k'annoying',
        }
      elseif topic1 == df.emotion_type.ANXIETY then
        -- "I'm anxious."
      elseif topic1 == df.emotion_type.APATHY then
        -- "Who cares?"
      elseif topic1 == df.emotion_type.AROUSAL then
        -- "Arousing..."
      elseif topic1 == df.emotion_type.ASTONISHMENT then
        -- "It's astonishing, really."
      elseif topic1 == df.emotion_type.AVERSION then
        -- "I'd like to get away from it."
      elseif topic1 == df.emotion_type.AWE then
        -- "It fills one with awe."
      elseif topic1 == df.emotion_type.BITTERNESS then
        -- "It makes me bitter."
      elseif topic1 == df.emotion_type.BLISS then
        -- "This could be bliss."
      elseif topic1 == df.emotion_type.BOREDOM then
        -- "It's boring."
      elseif topic1 == df.emotion_type.CARING then
        -- "I care."
      elseif topic1 == df.emotion_type.CONFUSION then
        -- "This is confusing."
      elseif topic1 == df.emotion_type.CONTEMPT then
        -- "I feel only contempt."
      elseif topic1 == df.emotion_type.CONTENTMENT then
        -- "I'm content."
      elseif topic1 == df.emotion_type.DEFEAT then
        -- "I'm beat."
      elseif topic1 == df.emotion_type.DEJECTION then
        -- "I'm dejected."
      elseif topic1 == df.emotion_type.DELIGHT then
        -- "I feel some delight."
      elseif topic1 == df.emotion_type.DESPAIR then
        -- "I feel despair."
      elseif topic1 == df.emotion_type.DISAPPOINTMENT then
        -- "This is disappointing."
      elseif topic1 == df.emotion_type.DISGUST then
        -- "That's disgusting."
      elseif topic1 == df.emotion_type.DISILLUSIONMENT then
        -- "This makes me question it all."
      elseif topic1 == df.emotion_type.DISLIKE then
        -- "I dislike this."
      elseif topic1 == df.emotion_type.DISMAY then
        -- "What has happened?"
      elseif topic1 == df.emotion_type.DISPLEASURE then
        -- "I am not pleased."
      elseif topic1 == df.emotion_type.DISTRESS then
        -- "This is distressing."
      elseif topic1 == df.emotion_type.DOUBT then
        -- "I have my doubts."
      elseif topic1 == df.emotion_type.EAGERNESS then
        -- "I'm eager to go."
      elseif topic1 == df.emotion_type.ELATION then
        -- "I'm elated."
      elseif topic1 == df.emotion_type.EMBARRASSMENT then
        -- "I'm embarrassed."
      elseif topic1 == df.emotion_type.EMPATHY then
        -- "I feel empathy."
      elseif topic1 == df.emotion_type.EMPTINESS then
        -- "I feel empty."
      elseif topic1 == df.emotion_type.ENJOYMENT then
        -- "I enjoyed that."
      elseif topic1 == df.emotion_type.ENTHUSIASM then
        -- "Let's do this."
      elseif topic1 == df.emotion_type.EUPHORIA then
        -- "I feel pretty good."
      elseif topic1 == df.emotion_type.EXASPERATION then
        -- "That was exasperating."
      elseif topic1 == df.emotion_type.EXCITEMENT then
        -- "I'm excited."
      elseif topic1 == df.emotion_type.EXHILARATION then
        -- "That's exhilarating."
      elseif topic1 == df.emotion_type.EXPECTANCY then
        -- "It could happen!"
      elseif topic1 == df.emotion_type.FEAR then
        -- "This doesn't scare me."
      elseif topic1 == df.emotion_type.FEROCITY then
        -- "I burn with ferocity."
      elseif topic1 == df.emotion_type.FONDNESS then
        -- "I feel fond."
      elseif topic1 == df.emotion_type.FREEDOM then
        -- "I'm free."
      elseif topic1 == df.emotion_type.FRIGHT then
        -- "That was frightening."
      elseif topic1 == df.emotion_type.FRUSTRATION then
        -- "It's frustrating."
      elseif topic1 == df.emotion_type.GAIETY then
        -- "This is gaiety."
      elseif topic1 == df.emotion_type.GLEE then
        -- "There's some glee here!"
      elseif topic1 == df.emotion_type.GLOOM then
        -- "I'm a little gloomy."
      elseif topic1 == df.emotion_type.GLUMNESS then
        -- "I'm glum."
      elseif topic1 == df.emotion_type.GRATITUDE then
        -- "I'm grateful."
      elseif topic1 == df.emotion_type.GRIEF then
        -- "I must let grief pass me by."
      elseif topic1 == df.emotion_type.GRIM_SATISFACTION then
        -- "It has come to pass."
      elseif topic1 == df.emotion_type.GROUCHINESS then
        -- "I'm a little grouchy."
      elseif topic1 == df.emotion_type.GRUMPINESS then
        -- "Harumph."
      elseif topic1 == df.emotion_type.GUILT then
        -- "I feel guilty."
      elseif topic1 == df.emotion_type.HAPPINESS then
        -- "I'm happy."
      elseif topic1 == df.emotion_type.HATRED then
        -- "I feel hate."
      elseif topic1 == df.emotion_type.HOPE then
        -- "I have hope."
      elseif topic1 == df.emotion_type.HOPELESSNESS then
        -- "I cannot find hope."
      elseif topic1 == df.emotion_type.HORROR then
        -- "This cannot horrify me."
      elseif topic1 == df.emotion_type.HUMILIATION then
        -- "This is humiliating."
      elseif topic1 == df.emotion_type.INSULT then
        -- "I take offense."
      elseif topic1 == df.emotion_type.INTEREST then
        -- "It's interesting."
      elseif topic1 == df.emotion_type.IRRITATION then
        -- "It's irritating."
      elseif topic1 == df.emotion_type.ISOLATION then
        -- "I feel isolated."
      elseif topic1 == df.emotion_type.JOLLINESS then
        -- "It makes me jolly."
      elseif topic1 == df.emotion_type.JOVIALITY then
        -- "I feel jovial."
      elseif topic1 == df.emotion_type.JOY then
        -- "This is nice."
      elseif topic1 == df.emotion_type.JUBILATION then
        -- "I feel jubilation."
      elseif topic1 == df.emotion_type.LOATHING then
        -- "I feel loathing."
      elseif topic1 == df.emotion_type.LONELINESS then
        -- "I'm lonely."
      elseif topic1 == df.emotion_type.LOVE then
        -- "Is this love?"
      elseif topic1 == df.emotion_type.LUST then
        -- "I'm lustful."
      elseif topic1 == df.emotion_type.MISERY then
        -- "I feel miserable."
      elseif topic1 == df.emotion_type.MORTIFICATION then
        -- "This is mortifying."
      elseif topic1 == df.emotion_type.NERVOUSNESS then
        -- "I'm nervous."
      elseif topic1 == df.emotion_type.NOSTALGIA then
        -- "I feel nostalgia."
      elseif topic1 == df.emotion_type.OPTIMISM then
        -- "I'm optimistic."
      elseif topic1 == df.emotion_type.OUTRAGE then
        -- "It is an outrage."
      elseif topic1 == df.emotion_type.PANIC then
        -- "I feel a little panic."
      elseif topic1 == df.emotion_type.PATIENCE then
        -- "I'm patient."
      elseif topic1 == df.emotion_type.PASSION then
        -- "I feel passion."
      elseif topic1 == df.emotion_type.PESSIMISM then
        -- "Things usually don't work out" [sic]
      elseif topic1 == df.emotion_type.PLEASURE then
        -- "It pleases me."
      elseif topic1 == df.emotion_type.PRIDE then
        -- "I'm proud."
      elseif topic1 == df.emotion_type.RAGE then
        -- "I'm a little angry."
      elseif topic1 == df.emotion_type.RAPTURE then
        -- "My spirit moves."
      elseif topic1 == df.emotion_type.REJECTION then
        -- "I feel rejected."
      elseif topic1 == df.emotion_type.RELIEF then
        -- "I'm relieved."
      elseif topic1 == df.emotion_type.REGRET then
        -- "I feel regret."
      elseif topic1 == df.emotion_type.REMORSE then
        -- "I feel remorse."
      elseif topic1 == df.emotion_type.REPENTANCE then
        -- "I repent of my deeds."
      elseif topic1 == df.emotion_type.RESENTMENT then
        -- "I feel resentful."
      elseif topic1 == df.emotion_type.RIGHTEOUS_INDIGNATION then
        -- "I've been wronged."
      elseif topic1 == df.emotion_type.SADNESS then
        -- "I feel somewhat sad."
        focus_sentence = ps.simple{
          t'feel condition'{
            experiencer=ps.me(context),
            stimulus=ps.adj{q=k'somewhat', k'sad'},
          },
        }
      elseif topic1 == df.emotion_type.SATISFACTION then
        -- "That was satisfying."
      elseif topic1 == df.emotion_type.SELF_PITY then
        -- "Why me?"
      elseif topic1 == df.emotion_type.SERVILE then
        -- "I will serve."
      elseif topic1 == df.emotion_type.SHAKEN then
        -- "This has shaken me."
      elseif topic1 == df.emotion_type.SHAME then
        -- "I am ashamed."
      elseif topic1 == df.emotion_type.SHOCK then
        -- "I will master myself."
      elseif topic1 == df.emotion_type.SUSPICION then
        -- "How suspicious..."
        focus_sentence = ps.sentence{
          ps.fragment{
            ps.adj{deg=k'how', k'suspicious'},
          },
          punct='...',
        }
      elseif topic1 == df.emotion_type.SYMPATHY then
        -- "I'm sympathetic."
      elseif topic1 == df.emotion_type.TENDERNESS then
        -- "I feel tenderness."
      elseif topic1 == df.emotion_type.TERROR then
        -- "Thrilling."
      elseif topic1 == df.emotion_type.THRILL then
        -- "Thrilling."
      elseif topic1 == df.emotion_type.TRIUMPH then
        -- "I feel like a victor."
      elseif topic1 == df.emotion_type.UNEASINESS then
        -- "I'm uneasy."
      elseif topic1 == df.emotion_type.UNHAPPINESS then
        -- "I'm unhappy."
      elseif topic1 == df.emotion_type.VENGEFULNESS then
        -- "This might require an answer."
      elseif topic1 == df.emotion_type.WONDER then
        -- "It's wondrous."
      elseif topic1 == df.emotion_type.WORRY then
        -- "It's worrisome."
      elseif topic1 == df.emotion_type.WRATH then
        -- "The wrath rises within me..."
      elseif topic1 == df.emotion_type.ZEAL then
        -- "I am ready for this."
      elseif topic1 == df.emotion_type.RESTLESS then
        -- "I feel restless."
      elseif topic1 == df.emotion_type.ADMIRATION then
        -- "I find this somewhat admirable."
      end
    elseif topic == df.talk_choice_type.ExpressLackEmotion then
      ----1
      if topic1 == df.emotion_type.ACCEPTANCE then
        -- "I do not accept this."
      elseif topic1 == df.emotion_type.ADORATION then
        -- "I suppose I should be feel adoration."
      elseif topic1 == df.emotion_type.AFFECTION then
        -- "I'm not feeling very affectionate."
      elseif topic1 == df.emotion_type.AGITATION then
        -- "I don't feel agitated."
      elseif topic1 == df.emotion_type.AGGRAVATION then
        -- "I'm not feeling aggravated."
      elseif topic1 == df.emotion_type.AGONY then
        -- "I can take this."
      elseif topic1 == df.emotion_type.ALARM then
        -- "What is it this time..."
      elseif topic1 == df.emotion_type.ALIENATION then
        -- "I guess that would be alienating."
      elseif topic1 == df.emotion_type.AMAZEMENT then
        -- "That wasn't amazing."
      elseif topic1 == df.emotion_type.AMBIVALENCE then
        -- "I guess I should be feeling ambivalent right now."
      elseif topic1 == df.emotion_type.AMUSEMENT then
        -- "That was not amusing."
      elseif topic1 == df.emotion_type.ANGER then
        -- "I'm not angry."
      elseif topic1 == df.emotion_type.ANGST then
        -- "I could be questioning my life right now."
      elseif topic1 == df.emotion_type.ANGUISH then
        -- "This is nothing."
      elseif topic1 == df.emotion_type.ANNOYANCE then
        -- "No, that's not annoying."
      elseif topic1 == df.emotion_type.ANXIETY then
        -- "I'm not anxious."
      elseif topic1 == df.emotion_type.APATHY then
        -- "If I thought about it more, I guess I'd be apathetic."
      elseif topic1 == df.emotion_type.AROUSAL then
        -- "That is not in the least bit arousing."
      elseif topic1 == df.emotion_type.ASTONISHMENT then
        -- "Astonished?  No."
      elseif topic1 == df.emotion_type.AVERSION then
        -- "I'm not averse to it."
      elseif topic1 == df.emotion_type.AWE then
        -- "I am not held in awe."
      elseif topic1 == df.emotion_type.BITTERNESS then
        -- "That's nothing to be bitter about."
      elseif topic1 == df.emotion_type.BLISS then
        -- "I do not see the bliss in this."
      elseif topic1 == df.emotion_type.BOREDOM then
        -- "It isn't boring."
      elseif topic1 == df.emotion_type.CARING then
        -- "I don't care."
      elseif topic1 == df.emotion_type.CONFUSION then
        -- "This isn't confusing."
      elseif topic1 == df.emotion_type.CONTEMPT then
        -- "I don't feel contempt."
      elseif topic1 == df.emotion_type.CONTENTMENT then
        -- "I am not contented."
      elseif topic1 == df.emotion_type.DEFEAT then
        -- "This isn't a defeat."
      elseif topic1 == df.emotion_type.DEJECTION then
        -- "There's nothing to be dejected about."
      elseif topic1 == df.emotion_type.DELIGHT then
        -- "I am not filled with delight."
      elseif topic1 == df.emotion_type.DESPAIR then
        -- "I will not despair."
      elseif topic1 == df.emotion_type.DISAPPOINTMENT then
        -- "I'm not disappointed."
      elseif topic1 == df.emotion_type.DISGUST then
        -- "It'll take more than that to disgust me."
      elseif topic1 == df.emotion_type.DISILLUSIONMENT then
        -- "This won't make me lose faith."
      elseif topic1 == df.emotion_type.DISLIKE then
        -- "I don't dislike that."
      elseif topic1 == df.emotion_type.DISMAY then
        -- "I'm not dismayed."
      elseif topic1 == df.emotion_type.DISPLEASURE then
        -- "I feel no displeasure."
      elseif topic1 == df.emotion_type.DISTRESS then
        -- "This isn't distressing."
      elseif topic1 == df.emotion_type.DOUBT then
        -- "I have no doubts."
      elseif topic1 == df.emotion_type.EAGERNESS then
        -- "I am not eager."
      elseif topic1 == df.emotion_type.ELATION then
        -- "I'm not elated."
      elseif topic1 == df.emotion_type.EMBARRASSMENT then
        -- "This isn't embarrassing."
      elseif topic1 == df.emotion_type.EMPATHY then
        -- "I don't feel very empathetic."
      elseif topic1 == df.emotion_type.EMPTINESS then
        -- "What's inside me isn't emptiness exactly..."
      elseif topic1 == df.emotion_type.ENJOYMENT then
        -- "I'm not enjoying this."
      elseif topic1 == df.emotion_type.ENTHUSIASM then
        -- "I'm just not enthusiastic."
      elseif topic1 == df.emotion_type.EUPHORIA then
        -- "I should be feeling great."
      elseif topic1 == df.emotion_type.EXASPERATION then
        -- "This isn't exasperating."
      elseif topic1 == df.emotion_type.EXCITEMENT then
        -- "This doesn't excite me."
      elseif topic1 == df.emotion_type.EXHILARATION then
        -- "I am not exhilarated."
      elseif topic1 == df.emotion_type.EXPECTANCY then
        -- "I'm not expecting anything."
      elseif topic1 == df.emotion_type.FEAR then
        -- "This does not scare me."
      elseif topic1 == df.emotion_type.FEROCITY then
        -- "I should be feeling ferocious right now."
      elseif topic1 == df.emotion_type.FONDNESS then
        -- "I am not fond of this."
      elseif topic1 == df.emotion_type.FREEDOM then
        -- "I don't feel free."
      elseif topic1 == df.emotion_type.FRIGHT then
        -- "I guess that could have given me a fright."
      elseif topic1 == df.emotion_type.FRUSTRATION then
        -- "This isn't frustrating."
      elseif topic1 == df.emotion_type.GAIETY then
        -- "There is no gaiety."
      elseif topic1 == df.emotion_type.GLEE then
        -- "I'm not gleeful."
      elseif topic1 == df.emotion_type.GLOOM then
        -- "I'm not feeling gloomy."
      elseif topic1 == df.emotion_type.GLUMNESS then
        -- "I don't feel glum."
      elseif topic1 == df.emotion_type.GRATITUDE then
        -- "I'm not feeling very grateful."
      elseif topic1 == df.emotion_type.GRIEF then
        -- "Grief?  I feel nothing."
      elseif topic1 == df.emotion_type.GRIM_SATISFACTION then
        -- "I guess it could be considered grimly satisfying."
      elseif topic1 == df.emotion_type.GROUCHINESS then
        -- "No, I'm not grouchy."
      elseif topic1 == df.emotion_type.GRUMPINESS then
        -- "That doesn't make me grumpy."
      elseif topic1 == df.emotion_type.GUILT then
        -- "I don't feel guilty about it."
      elseif topic1 == df.emotion_type.HAPPINESS then
        -- "I am not happy."
      elseif topic1 == df.emotion_type.HATRED then
        -- "I feel no hatred."
      elseif topic1 == df.emotion_type.HOPE then
        -- "I am not hopeful."
      elseif topic1 == df.emotion_type.HOPELESSNESS then
        -- "I will not lose hope."
      elseif topic1 == df.emotion_type.HORROR then
      elseif topic1 == df.emotion_type.HUMILIATION then
        -- "No, this isn't humiliating."
      elseif topic1 == df.emotion_type.INSULT then
        -- "That doesn't insult me."
      elseif topic1 == df.emotion_type.INTEREST then
        -- "No, I'm not interested."
      elseif topic1 == df.emotion_type.IRRITATION then
        -- "This isn't irritating."
      elseif topic1 == df.emotion_type.ISOLATION then
        -- "I don't feel isolated."
      elseif topic1 == df.emotion_type.JOLLINESS then
        -- "I'm not jolly."
      elseif topic1 == df.emotion_type.JOVIALITY then
        -- "This doesn't put me in a jovial mood."
      elseif topic1 == df.emotion_type.JOY then
        -- "I suppose this would be a joyous occasion."
      elseif topic1 == df.emotion_type.JUBILATION then
        -- "This isn't the time for jubilation."
      elseif topic1 == df.emotion_type.LOATHING then
        -- "I am not filled with loathing."
      elseif topic1 == df.emotion_type.LONELINESS then
        -- "I'm not lonely."
      elseif topic1 == df.emotion_type.LOVE then
        -- "There is no love."
      elseif topic1 == df.emotion_type.LUST then
        -- "I am not burning with lust."
      elseif topic1 == df.emotion_type.MISERY then
        -- "I'm not miserable."
      elseif topic1 == df.emotion_type.MORTIFICATION then
        -- "I am not mortified."
      elseif topic1 == df.emotion_type.NERVOUSNESS then
        -- "I don't feel nervous."
      elseif topic1 == df.emotion_type.NOSTALGIA then
        -- "I'm not feeling nostalgic."
      elseif topic1 == df.emotion_type.OPTIMISM then
        -- "I'm not optimistic."
      elseif topic1 == df.emotion_type.OUTRAGE then
        -- "This doesn't outrage me."
      elseif topic1 == df.emotion_type.PANIC then
        -- "I'm not panicking."
      elseif topic1 == df.emotion_type.PATIENCE then
        -- "I am not feeling patient."
      elseif topic1 == df.emotion_type.PASSION then
        -- "I'm not feeling passionate."
      elseif topic1 == df.emotion_type.PESSIMISM then
        -- "There's no reason to be pessimistic."
      elseif topic1 == df.emotion_type.PLEASURE then
        -- "I take no pleasure in this."
      elseif topic1 == df.emotion_type.PRIDE then
        -- "I am not proud."
      elseif topic1 == df.emotion_type.RAGE then
        -- "I have no feelings of rage."
      elseif topic1 == df.emotion_type.RAPTURE then
        -- "This does not move me."
      elseif topic1 == df.emotion_type.REJECTION then
        -- "I don't feel rejected."
      elseif topic1 == df.emotion_type.RELIEF then
        -- "I don't feel relieved."
      elseif topic1 == df.emotion_type.REGRET then
        -- "I have no regrets."
      elseif topic1 == df.emotion_type.REMORSE then
        -- "I feel no remorse."
      elseif topic1 == df.emotion_type.REPENTANCE then
        -- "I am not repentant."
      elseif topic1 == df.emotion_type.RESENTMENT then
        -- "I do not resent this."
      elseif topic1 == df.emotion_type.RIGHTEOUS_INDIGNATION then
        -- "There's nothing to be indignant about."
      elseif topic1 == df.emotion_type.SADNESS then
        -- "I am not feeling sad right now."
      elseif topic1 == df.emotion_type.SATISFACTION then
        -- "That was not satisfying."
      elseif topic1 == df.emotion_type.SELF_PITY then
        -- "I don't feel sorry for myself."
      elseif topic1 == df.emotion_type.SERVILE then
        -- "I bow to no one."
      elseif topic1 == df.emotion_type.SHAKEN then
        -- "I can keep it together."
      elseif topic1 == df.emotion_type.SHAME then
        -- "I have no shame."
      elseif topic1 == df.emotion_type.SHOCK then
        -- "That did not shock me."
      elseif topic1 == df.emotion_type.SUSPICION then
        -- "Takes all kinds these days."
      elseif topic1 == df.emotion_type.SYMPATHY then
        -- "There will be no sympathy from me."
      elseif topic1 == df.emotion_type.TENDERNESS then
        -- "I don't feel tenderness."
      elseif topic1 == df.emotion_type.TERROR then
        -- "I laugh in the face of death!"
      elseif topic1 == df.emotion_type.THRILL then
        -- "There was no thrill in it."
      elseif topic1 == df.emotion_type.TRIUMPH then
        -- "There is no need for celebration."
      elseif topic1 == df.emotion_type.UNEASINESS then
        -- "I'm not uneasy."
      elseif topic1 == df.emotion_type.UNHAPPINESS then
        -- "That doesn't make me unhappy."
      elseif topic1 == df.emotion_type.VENGEFULNESS then
        -- "There is no need to feel vengeful."
      elseif topic1 == df.emotion_type.WONDER then
        -- "There is no sense of wonder."
      elseif topic1 == df.emotion_type.WORRY then
        -- "I'm not worried."
      elseif topic1 == df.emotion_type.WRATH then
        -- "Wrath has not risen within me."
      elseif topic1 == df.emotion_type.ZEAL then
        -- "I have no zeal for this."
      elseif topic1 == df.emotion_type.RESTLESS then
        -- "I don't feel restless."
      elseif topic1 == df.emotion_type.ADMIRATION then
        -- "There's not much to admire here."
      end
    end
    constituent = ps.utterance{topic_sentence, focus_sentence}
    -- TODO: some of those are multiple sentences
  elseif topic == df.talk_choice_type.RespondJoinInsurrection then
    -- topic1: invitation response
  elseif topic == 28 then
    -- "I'm with you on this."
  elseif topic == df.talk_choice_type.AllowPermissionSleep then
    -- "Certainly.  It would be terrible to leave someone to fend for themselves after sunset."
  elseif topic == df.talk_choice_type.DenyPermissionSleep then
    -- "Ah, I'm sorry.  Permission is not mine to give."
  elseif topic == 31 then
    -- Seems to do nothing, like Nevermind?
  elseif topic == df.talk_choice_type.AskJoinAdventure then
    -- "Come, join me on my adventures!"
  elseif topic == df.talk_choice_type.AskGuideLocation then
    -- N/A
  elseif topic == df.talk_choice_type.RespondJoin then
    -- topic1: invitation response
  elseif topic == df.talk_choice_type.RespondJoin2 then
    -- topic1: invitation response
  elseif topic == df.talk_choice_type.OfferCondolences then
    -- "My condolences."
  elseif topic == df.talk_choice_type.StateNotAcquainted then
    -- "We weren't personally acquainted."
  elseif topic == df.talk_choice_type.SuggestTravel then
    -- "You should travel to "
    -- topic1: world_site key
    -- "."
  elseif topic == df.talk_choice_type.SuggestTalk then
    -- "You should talk to "
    -- topic1: historical_figure key
    -- "."
  elseif topic == df.talk_choice_type.RequestSelfRescue then
    -- "Please help me!"
    constituent = ps.simple{
      polite=true,
      mood=k'IMPERATIVE',
      t'help'{
        agent=ps.thee(context),
        stimulus=ps.me(context),
      },
      punct='!',
    }
  elseif topic == df.talk_choice_type.AskWhatHappened then
    -- "What happened?"
    constituent = ps.simple{
      tense=k'PAST',
      t'happen'{
        theme=k'what',
      },
      punct='?',
    }
  elseif topic == df.talk_choice_type.AskBeRescued then
    -- "Come with me and I'll bring you to safety."
    -- TODO: This is a conditional sentence but not transparently so in English.
    constituent = ps.utterance{
      ps.conj{
        ps.sentence{
          ps.infl{
            mood=k'IMPERATIVE',
            t'accompany'{
              agent=ps.thee(context),
              theme=ps.me(context),
            },
          },
        },
        k'and if so then',
        ps.sentence{
          ps.infl{
            tense=k'FUTURE',
            t'bring'{
              agent=ps.me(context),
              theme=ps.thee(context),
              goal=k'safety',
            },
          },
        },
      },
    }
  elseif topic == df.talk_choice_type.SayNotRemember then
    -- "I don't remember clearly."
  elseif topic == 44 then
    -- "Thank you!"
  elseif topic == df.talk_choice_type.SayNoFamily then
    -- no_family.txt
    -- "I have no family to speak of."
  elseif topic == df.talk_choice_type.StateUnitLocation then
    -- topic1: historical_figure key
    -- " lives in "
    -- topic2: world_site key
    -- "."
  elseif topic == df.talk_choice_type.ReferToElder then
    -- "You'll have to talk to somebody older."
  elseif topic == df.talk_choice_type.AskComeCloser then
    -- "Fantastic!  Please come closer and ask again."
  elseif topic == df.talk_choice_type.DoBusiness then
    -- "Of course.  Let's do business."
  elseif topic == df.talk_choice_type.AskComeStoreLater then
    -- "Come see me in my store sometime."
  elseif topic == df.talk_choice_type.AskComeMarketLater then
    -- "Come see me in the market sometime."
  elseif topic == df.talk_choice_type.TellTryShopkeeper then
    -- "You should probably try a shopkeeper."
  elseif topic == df.talk_choice_type.DescribeSurroundings then
    -- ?
  elseif topic == df.talk_choice_type.AskWaitUntilHome then
    -- "Ask me when I've returned to my home!"
  elseif topic == df.talk_choice_type.DescribeFamily then
    -- family_relationship_no_spec.txt
    -- "I have [CONTEXT:INDEF_FAMILY_RELATIONSHIP] named [CONTEXT:HIST_FIG:TRANS_NAME]"
    -- family_relationship_no_spec_dead.txt
    -- "I had [CONTEXT:INDEF_FAMILY_RELATIONSHIP] named [CONTEXT:HIST_FIG:TRANS_NAME]"
    -- family_relationship_spec.txt
    -- "my [CONTEXT:FAMILY_RELATIONSHIP] is named [CONTEXT:HIST_FIG:TRANS_NAME]"
    -- family_relationship_spec_dead.txt
    -- "my [CONTEXT:FAMILY_RELATIONSHIP] was named [CONTEXT:HIST_FIG:TRANS_NAME]"
    -- family_relationship_additional.txt
    -- "[CONTEXT:HIST_FIG:PRO_SUB] is also my [CONTEXT:FAMILY_RELATIONSHIP]"
    -- family_relationship_additional_dead.txt
    -- "[CONTEXT:HIST_FIG:PRO_SUB] was also my [CONTEXT:FAMILY_RELATIONSHIP]"
    -- historical event involving the family member
  elseif topic == df.talk_choice_type.StateAge then
    -- child_age_proclamation.txt
    -- "I'm [CONTEXT:NUMBER]!"
  elseif topic == df.talk_choice_type.DescribeProfession then
    -- current_profession_no_year.txt
    -- "I am a [CONTEXT:UNIT_NAME]."
    -- current_profession_year.txt
    -- "This is my [CONTEXT:ORDINAL] year as a [CONTEXT:UNIT_NAME]."
    -- guard_profession.txt
    -- "I am a guard."
    -- hunting_profession.txt
    -- "I hunt great beasts in [CONTEXT:PLACE:TRANS_NAME]."
    -- hunting_profession_year.txt
    -- "I have hunted great beasts in [CONTEXT:PLACE:TRANS_NAME] for [CONTEXT:NUMBER] of my years."
    -- mercenary_profession.txt
    -- "I seek fortune and glory by offering my skill at arms in [CONTEXT:PLACE:TRANS_NAME]."
    -- mercenary_profession_year.txt
    -- "I have sought fortune and glory by offering my skill at arms in [CONTEXT:PLACE:TRANS_NAME] for [CONTEXT:NUMBER] of my years."
    -- scouting_profession.txt
    -- "It is my duty to scout the area around [CONTEXT:PLACE:TRANS_NAME]."
    -- scouting_profession_year.txt
    -- "I have been scouting the area around [CONTEXT:PLACE:TRANS_NAME] for [CONTEXT:NUMBER] of my years."
    -- snatcher_profession.txt
    -- "I rescue lost children and bring them back to [CONTEXT:PLACE:TRANS_NAME]."
    -- snatcher_profession_year.txt
    -- "For [CONTEXT:NUMBER] of my years, I have been rescuing lost children and bringing them back to [CONTEXT:PLACE:TRANS_NAME]."
    -- soldier_profession.txt
    -- "I am a soldier."
    -- thief_profession.txt
    -- "I seek treasures and bring them back to [CONTEXT:PLACE:TRANS_NAME]."
    -- thief_profession_year.txt
    -- "I seek treasures and bring them back to [CONTEXT:PLACE:TRANS_NAME] and have done so for [CONTEXT:NUMBER] of the years of my life."
    -- wandering_profession.txt
    -- "I wander [CONTEXT:PLACE:TRANS_NAME]."
    -- wandering_profession_year.txt
    -- "I have wandered [CONTEXT:PLACE:TRANS_NAME] for [CONTEXT:NUMBER] of my years."
    -- TODO: past_*_profession.txt?
  elseif topic == df.talk_choice_type.AnnounceNightCreature then
    -- "Fool!"
    -- Brag
  elseif topic == df.talk_choice_type.StateIncredulity then
    -- "What is this madness?  Calm yourself!"
  elseif topic == df.talk_choice_type.BypassGreeting then
    -- N/A
  elseif topic == df.talk_choice_type.AskCeaseHostilities then
    -- "Let us stop this pointless fighting!"
    constituent = ps.simple{
      mood=k'HORTATIVE',
      t'stop'{
        agent=ps.us_inclusive(context),
        theme=ps.np{
          det=k'this',  -- TODO: more precise deixis
          k'pointless',
          k'fighting',
        },
      },
    }
  elseif topic == df.talk_choice_type.DemandYield then
    -- "You must yield!"
    constituent = ps.simple{
      mood=k'must',
      t'yield'{
        agent=ps.thee(context),
      },
      punct='!',
    }
  elseif topic == df.talk_choice_type.HawkWares then
    ----1
    -- "try" / "get your" / "your very own"
    -- "real" / "authentic"
    -- topic1: item key
    -- "clear" / "all the way"
    -- "from"
    -- "distant" / "faraway" / "fair" / "the great"
    -- "here" / "right here"
    -- "!  Today only" / "!  Limited supply" / "!  Best price in town"
    -- " were " / " was "
    -- "tanned" / "cut" / "made"
    -- "town" / "the surrounding area" / "just outside town" / "a village nearby" / "the settlements"
    -- " out to the"
    -- "some of my kind " / "some of our kind "
    -- "Are you interested in " / "Might I interest you in "
    -- "Great" / "Splendid" / "Good" / "Decent" / "Fantastic" / "Excellent"
    -- "right there"
    -- "my good "
    -- "man" / "woman" / "person"
    -- topic2: ?
    -- topic3: ?
  elseif topic == df.talk_choice_type.YieldTerror then
    -- "Stop!  This isn't happening!"
    constituent = ps.utterance{
      ps.sentence{
        ps.infl{
          mood=k'IMPERATIVE',
          t'stop'{
            agent=ps.thee_inanimate(context),
          }
        },
        punct='!',
      },
      ps.sentence{
        ps.infl{
          progressive=true,
          neg=true,
          t'happen'{
            theme=ps.it(),
          },
        },
        punct='!',
      },
    }
  elseif topic == df.talk_choice_type.Yield then
    -- "I yield!  I yield!" / "We yield!  We yield!"
    local i_or_we
    if english:find('i yield') then
      i_or_we = ps.me(context)
    else
      i_or_we = ps.us_exclusive(context)
    end
    constituent = ps.utterance{
      ps.sentence{
        ps.infl{
          t'yield'{
            agent=i_or_we,
          }
        },
      },
      ps.sentence{
        ps.infl{
          t'yield'{
            agent=i_or_we,
          }
        },
      },
    }
  -- ExpressOverwhelmingEmotion: see StateOpinion
  -- ExpressGreatEmotion: see StateOpinion
  -- ExpressEmotion: see StateOpinion
  -- ExpressMinorEmotion: see StateOpinion
  -- ExpressLackEmotion: see StateOpinion
  elseif topic == df.talk_choice_type.OutburstFleeConflict then
    -- "Help!  Save me!"
    -- TODO: Does this utterances have any hearers?
    constituent = ps.utterance{
      ps.sentence{
        ps.infl{
          mood=k'IMPERATIVE',
          t'help'{
            agent=ps.thee(context),
          },
        },
        punct='!',
      },
      ps.sentence{
        ps.infl{
          mood=k'IMPERATIVE',
          t'save'{
            agent=ps.thee(context),
            theme=ps.me(context),
          },
        },
        punct='!',
      },
    }
  elseif topic == df.talk_choice_type.StateFleeConflict then
    -- "I must withdraw!"
    constituent = ps.simple{
      mood=k'must',
      t'withdraw'{
        agent=ps.me(context),
      },
    }
  elseif topic == df.talk_choice_type.MentionJourney then
    ----1
    -- "Now we will have to build our own future."
    -- / "Are we close?"
    -- / "You are bound to obey me."
    -- / "How are you enjoying the adventure?"
    -- / "Where should I take you?"
    -- / "Soon the world will be set right."
    -- / "We shall bring " historical_figure " home safely."
    -- / " Are you looking forward to the performance?"
    -- / " I've forgotten what I was going to say..."
  elseif topic == df.talk_choice_type.SummarizeTroubles then
    -- "Well, let's see..."
    -- ?
    -- / incident summary
  elseif topic == df.talk_choice_type.AskAboutIncident then
    -- "Tell me about "
    -- topic1: trouble type
    -- topic2: number of troubles
    -- "."
  elseif topic == df.talk_choice_type.AskDirectionsPerson then
    -- N/A
  elseif topic == df.talk_choice_type.AskDirectionsPlace then
    -- "Can you tell me the way to "
    -- topic1: world_site key
    -- "?"
  elseif topic == df.talk_choice_type.AskWhereabouts then
    -- "Can you tell me where I can find "
    -- topic1: historical_figure key
    -- "?"
  elseif topic == df.talk_choice_type.RequestGuide then
    -- "Please guide me to "
    -- topic1: world_site key
    -- "."
  elseif topic == df.talk_choice_type.RequestGuide2 then
    -- "Please guide me to "
    -- topic1: historical_figure key
    -- "."
  elseif topic == df.talk_choice_type.ProvideDirections then
    -- "We are in "
    -- topic1: world_site key
    -- " is "
    -- "far"?
    -- " to the "
    -- compass direction
    -- ".  [You receive a detailed description.]  "
    -- historical event involving the site
    -- / "No such place exists."
  elseif topic == df.talk_choice_type.ProvideWhereabouts then
    -- topic1: historical_figure key
    -- " is in "
    -- whereabouts
    -- "."
  elseif topic == df.talk_choice_type.TellTargetSelf then
    -- "That's me.  I'm right here."
  elseif topic == df.talk_choice_type.TellTargetDead then
    -- topic1: historical_figure key
    -- " is dead."
  elseif topic == df.talk_choice_type.RecommendGuide then
    -- topic1: historical_figure key
    -- " is well-traveled and would probably have that information."
  elseif topic == df.talk_choice_type.ProfessIgnorance then
    -- ?
  elseif topic == df.talk_choice_type.TellAboutPlace then
    -- "This is "
    -- structure name
    -- "."
    -- arch_info_justification.txt
    -- "It is said that the [CONTEXT:ARCH_ELEMENT] of [CONTEXT:ABSTRACT_BUILDING:TRANS_NAME] [CONTEXT:JUSTIFICATION] [CONTEXT:DEF_SPHERE] for the glory of [CONTEXT:HIST_FIG:TRANS_NAME]."
    -- historical event involving the site
  elseif topic == df.talk_choice_type.AskFavorMenu then
    -- N/A
  elseif topic == df.talk_choice_type.AskWait then
    -- "Wait here until I return."
  elseif topic == df.talk_choice_type.AskFollow then
    -- "Let's continue onward together."
  elseif topic == df.talk_choice_type.ApologizeBusy then
    -- "Sorry, I'm otherwise occupied."
  elseif topic == df.talk_choice_type.ComplyOrder then
    -- "Of course."
  elseif topic == df.talk_choice_type.AgreeFollow then
    -- "Yes, let's go."
  elseif topic == df.talk_choice_type.ExchangeItems then
    -- "Here's something you might be interested in..."
  elseif topic == df.talk_choice_type.AskComeCloser2 then
    -- "Really?  Please come closer."
  elseif topic == df.talk_choice_type.InitiateBarter then
    -- "Really?  Alright."
  elseif topic == df.talk_choice_type.AgreeCeaseHostile then
    -- "I will fight no more."
    -- / "We will fight no more."
  elseif topic == df.talk_choice_type.RefuseCeaseHostile then
    -- "I am compelled to continue!"
    -- ? / "Over my dead body!"
  elseif topic == df.talk_choice_type.RefuseCeaseHostile2 then
    -- "Never!"
  elseif topic == df.talk_choice_type.RefuseYield then
    -- "I am compelled to continue!"
    -- ? / "Over my dead body!"
  elseif topic == df.talk_choice_type.RefuseYield2 then
    -- "You first, coward!"
  elseif topic == df.talk_choice_type.Brag then
    -- animal_slayer.txt
    -- "I have taken down [CONTEXT:NUMBER] [CONTEXT:RACE:NUMBERED_NAME] while stalking [CONTEXT:PLACE:TRANS_NAME]."
    -- hist_fig_slayer.txt
    -- "It is I that felled [CONTEXT:HIST_FIG:TRANS_NAME] the [CONTEXT:HIST_FIG:RACE]."
    -- / "I've defeated many fearsome opponents!"
  elseif topic == df.talk_choice_type.DescribeRelation then
    -- ?
  elseif topic == df.talk_choice_type.ClaimSite then
    -- "I'm in charge of "
    -- this site
    -- " now.  Make way for "
    -- speaker's title
    -- " "
    -- speaker's name
    -- " and "
    -- new group
    -- "!"
  elseif topic == df.talk_choice_type.AnnounceLairHunt then
    -- ?
  elseif topic == df.talk_choice_type.RequestDuty then
    -- "I am your loyal "
    -- hearthperson
    -- ".  What do you command?"
  elseif topic == df.talk_choice_type.AskJoinService then
    -- "I would be honored to serve as a "
    -- hearthperson / "lieutenant"
    -- ".  Will you have me?"
  elseif topic == df.talk_choice_type.AcceptService then
    -- "Gladly.  You are now one of my "
    -- hearthpeople
    -- "."
  elseif topic == df.talk_choice_type.TellRemainVigilant then
    -- "You may enjoy these times of peace, but remain vigilant."
  elseif topic == df.talk_choice_type.GiveServiceOrder then
    -- ?
  elseif topic == df.talk_choice_type.WelcomeSelfHome then
    -- "This is my new home."
  elseif topic == 112 then
    -- topic1: invitation response
  elseif topic == df.talk_choice_type.AskTravelReason then
    ----1
    -- "Why are you traveling?"
  elseif topic == df.talk_choice_type.TellTravelReason then
    ----1
    -- "I'm returning to my home in"
    -- "I'm going to "
    -- " to take up my position"
    -- " as "
    -- " to move into my new home with "
    -- "spouse"
    -- "wife"
    -- "husband"
    -- " to start a new life"
    -- " in search of a thrilling adventure"
    -- " in search of excitement"
    -- " in search of adventure"
    -- " in search of work"
    -- ", and wealth and pleasures beyond measure!"
    -- ".   Perhaps I'll finally make my fortune!"
    -- " and maybe something to drink as well!"
    -- "I'm on an important mission."
    -- "I'm returning from my patrol."
    -- "I'm just out for a stroll."
    -- "I was just out for some water."
    -- "I was out visiting the temple."
    -- "I was just out at the tavern."
    -- "I was out visiting the library."
    -- "I'm walking my patrol."
    -- "I'm going out for some water."
    -- "I'm going to visit the temple."
    -- "I'm going out to the tavern."
    -- "I'm going to visit the library."
    -- "I'm not planning a journey."
  elseif topic == df.talk_choice_type.AskLocalRuler then
    -- "Tell me about the local ruler."
  elseif topic == df.talk_choice_type.ComplainAgreement then
    -- "We should have made it there by now."
    -- "We should be making better progress."
    -- "We are going the wrong way."
    -- "We haven't performed for some time."
    -- "We have arrived at our destination."
    -- "The oppressor has been overthrown!"
    -- "We must not abandon "
    -- "We must go back."
  elseif topic == df.talk_choice_type.CancelAgreement then
    -- "We can no longer travel together."
    -- ? "  I'm giving up on this hopeless venture."
    -- / "  We were going to entertain the world!  It's a shame, but I'll have to make my own way now."
    -- / "  I'm returning on my own."
  elseif topic == df.talk_choice_type.SummarizeConflict then
    ----1
    -- ?
  elseif topic == df.talk_choice_type.SummarizeViews then
    ----1
    -- topic1: historical_figure key
    -- " rules "
    -- site
    -- "."
    -- / " is a group of "
    -- race
    -- "I don't know anything else about them."
    -- "I don't care one way or another."
    -- "The seat of "
    -- HF
    -- " is also located here."
  elseif topic == df.talk_choice_type.AskClaimStrength then
    -- "Do they have a firm grip on these lands?"
  elseif topic == df.talk_choice_type.AskArmyPosition then
    -- "Where are their forces?  Are there patrols or guards?"
  elseif topic == df.talk_choice_type.AskOtherClaims then
    -- "Does anybody else still have a stake in these lands?"
  elseif topic == df.talk_choice_type.AskDeserters then
    -- "Did anybody flee the attack?"
  elseif topic == df.talk_choice_type.AskSiteNeighbors then
    -- "Does this settlement engage in trade?  Tell me about those places."
  elseif topic == df.talk_choice_type.DescribeSiteNeighbors then
    -- " trades directly with no fewer than "
    -- " other major settlements."
    -- "  The largest of these is "
    -- " engages in trade with"
    -- "There are "
    -- " villages which utilize the market here."
    -- "The villages"
    -- "The village"
    -- " is the only other settlement to utilize the market here."
    -- " utilize the market here."
    -- "This place is insulated from the rest of the world, at least in terms of trade."
    -- "The people of "
    -- " go to "
    -- " to trade."
    -- " other villages which utilize the market there."
    -- " is the only other settlement to utilize the market there."
    -- " also utilize the market there."
    -- ? "There's nothing organized here."
  elseif topic == df.talk_choice_type.RaiseAlarm then
    -- "Intruder!  Intruder!"
    constituent = ps.utterance{
      ps.sentence{
        ps.fragment{
          k'intruder',
        },
        punct='!',
      },
      ps.sentence{
        ps.fragment{
          k'intruder',
        },
        punct='!',
      },
    }
  elseif topic == df.talk_choice_type.DemandDropWeapon then
    -- "Drop the "
    -- topic1: item key
    -- "!"
    constituent = ps.simple{
      mood=k'IMPERATIVE',
      t'drop'{
        agent=ps.thee(context),
        theme=ps.np{det=k'the', ps.item(topic1)},
      },
    }
  elseif topic == df.talk_choice_type.AgreeComplyDemand then
    -- "Okay!  I'll do it."
    constituent = ps.utterance{
      ps.sentence{
        ps.fragment{
          k'okay',
        },
        punct='!',
      },
      ps.sentence{
        ps.infl{
          tense=k'FUTURE',
          t'do'{
            agent=ps.me(context),
            theme=ps.it(),
          }
        },
      },
    }
  elseif topic == df.talk_choice_type.RefuseComplyDemand then
    -- "Over my dead body!"
    constituent = k'over my dead body'
  elseif topic == df.talk_choice_type.AskLocationObject then
    -- "Where is the "
    -- topic1: item key
    -- / "object I can't remember"
    -- "?"
  elseif topic == df.talk_choice_type.DemandTribute then
    -- topic1: historical_entity key
    -- " must pay homage to "
    -- topic2: historical_entity key
    -- " or suffer the consequences."
  elseif topic == df.talk_choice_type.AgreeGiveTribute then
    -- "I agree to submit to your request."
  elseif topic == df.talk_choice_type.RefuseGiveTribute then
    -- "I will not bow before you."
  elseif topic == df.talk_choice_type.OfferGiveTribute then
    -- topic1: historical_entity key
    -- " offers to pay homage to "
    -- topic2: historical_entity key
    -- "."
  elseif topic == df.talk_choice_type.AgreeAcceptTribute then
    -- "I accept your offer."
  elseif topic == df.talk_choice_type.RefuseAcceptTribute then
    -- "I have no reason to accept this."
  elseif topic == df.talk_choice_type.CancelTribute then
    -- topic1: historical_entity key
    -- " will no longer pay homage to "
    -- topic2: historical_entity key
    -- "."
  elseif topic == df.talk_choice_type.OfferPeace then
    -- "Let there be peace between "
    -- topic1: historical_entity key
    -- " and "
    -- topic1: historical_entity key
    -- "."
  elseif topic == df.talk_choice_type.AgreePeace then
    -- "Gladly.  May this new age of harmony last a thousand year."
  elseif topic == df.talk_choice_type.RefusePeace then
    -- "Never."
  elseif topic == df.talk_choice_type.AskTradeDepotLater then
    -- "Come see me at the trade depot sometime."
  elseif topic == df.talk_choice_type.ExpressAstonishment then
    -- topic1: historical_figure key
    -- ", is it really you?" / "!"
    -- / other strings for specific family members
  elseif topic == df.talk_choice_type.CommentWeather then
    ----1
    -- "It is scorching hot!"
    -- "It is freezing cold!"
    -- "Is that"
    -- " falling outside?"
    -- "Looks like rain outside."
    -- "Looks to be snowing outside."
    -- "Look at the fog out there!"
    -- "There is fog outside."
    -- "There is a mist outside."
    -- "Seems a pleasant enough"
    -- "day"
    -- "night"
    -- "dawn"
    -- "sunset"
    -- " out there."
    -- "I wonder what the weather is like outside."
    -- "What is this?"
    -- "It is raining."
    -- "It is snowing."
    -- "Curse this fog!  I cannot see a thing."
    -- "I hope this fog lifts soon."
    -- "I hope this mist passes."
    -- "Look at those clouds!"
    -- "The weather does not look too bad today."
    -- "The weather looks to be fine today."
    -- "The stars are bold tonight."
    -- "It is a starless night."
    -- "It is hot."
    -- "It is cold."
    -- "What a wind!"
    -- "  And what a wind!"
    -- "It is a nice temperature today."
  elseif topic == df.talk_choice_type.CommentNature then
    ----1
    -- "Look at the sky!  Are we in the Underworld?"
    -- "What an odd glow!"
    -- "At least it doesn't rain down here."
    -- "Is it raining?"
    -- "What a strange place!"
    -- "It is invigorating to be out in the wilds!"
    -- "It is good to be outdoors."
    -- "Indoors, outdoors.  It's all the same to me as long as the weather's fine."
    -- "How I long for civilization..."
    -- "I would prefer to be indoors."
    -- "How sinister the glow..."
    -- "I would prefer to be outdoors."
    -- "It is good to be indoors."
    -- "It sure is dark down here."
  elseif topic == df.talk_choice_type.SummarizeTerritory then
    -- "I don't really know."
    -- ?
  elseif topic == df.talk_choice_type.SummarizePatrols then
    -- "I have no idea."
    -- ?
  elseif topic == df.talk_choice_type.SummarizeOpposition then
    -- entity 1
    -- " and "
    -- entity 2
    -- " are vying for control."
  elseif topic == df.talk_choice_type.DescribeRefugees then
    -- "Nobody I remember."
    -- ?
  elseif topic == df.talk_choice_type.AccuseTroublemaker then
    -- "You sound like a troublemaker."
    constituent = ps.simple{
      t'sound like'{
        stimulus=ps.thee(context),
        theme=ps.np{det=k'a', k'troublemaker'},
      },
    }
  elseif topic == df.talk_choice_type.AskAdopt then
    -- "Would you please adopt "
    -- ?
    -- / "this poor nameless child"
    -- "?"
  elseif topic == df.talk_choice_type.AgreeAdopt then
    -- ?
  elseif topic == df.talk_choice_type.RefuseAdopt then
    -- "I'm sorry, but I'm unable to help."
    constituent = ps.utterance{
      ps.conj{
        ps.infl{
          subject=ps.me(context),
          k'sorry',
        },
        k'but',
        ps.infl{
          neg=true,
          subject=ps.me(context),
          t'able'{
            theme=ps.infl{
              tense=k'INFINITIVE',
              t'help'{
                agent=ps.me(context),  -- TODO: PRO?
              },
            },
          },
        },
      },
    }
  elseif topic == df.talk_choice_type.RevokeService then
    -- ?
  elseif topic == df.talk_choice_type.InviteService then
    -- ?
  elseif topic == df.talk_choice_type.AcceptInviteService then
    -- ?
  elseif topic == df.talk_choice_type.RefuseShareInformation then
    -- "I'd rather not say."
  elseif topic == df.talk_choice_type.RefuseInviteService then
    -- "I cannot accept this honor.  I am sorry."
    constituent = ps.utterance{
      ps.sentence{
        ps.infl{
          mood=k'can,X',
          neg=true,
          t'accept'{
            agent=ps.me(context),
            theme=ps.np{
              det=k'this',
              k'honor',
            },
          },
        },
      },
      ps.sentence{
        ps.infl{
          subject=ps.me(context),
          k'sorry',
        },
      },
    }
  elseif topic == df.talk_choice_type.RefuseRequestService then
    -- "You are not worthy of such an honor yet.  I am sorry."
  elseif topic == df.talk_choice_type.OfferService then
    -- "Would you agree to become "
    -- "someone"
    -- " of "
    -- topic1: historical_entity key
    -- ", taking over my duties and responsibilities?"
  elseif topic == df.talk_choice_type.AcceptPositionService then
    -- "I accept this honor."
    constituent = ps.simple{
      t'accept'{
        agent=ps.me(context),
        theme=ps.np{
          det=k'this',
          k'honor',
        },
      },
    }
  elseif topic == df.talk_choice_type.RefusePositionService then
    -- "I am sorry, but I am otherwise disposed."
    constituent = ps.utterance{
      ps.conj{
        ps.sentence{
          ps.infl{
            subject=ps.me(context),
            k'sorry',
          },
        },
        k'but',
        ps.sentence{
          ps.infl{
            subject=ps.me(context),
            ps.adj{k'otherwise', k'disposed'},
          },
        },
      },
    }
  elseif topic == df.talk_choice_type.InvokeNameBanish then
    -- topic2: identity key
    -- "!  The bond is broken!  Return to the Underworld and trouble us no more!"
  elseif topic == df.talk_choice_type.InvokeNameService then
    -- topic2: identity key
    -- "!"  You are bound to me!"
  elseif topic == df.talk_choice_type.GrovelMaster then
    -- "Yes, master.  Ask and I shall obey."
  elseif topic == df.talk_choice_type.DemandItem then
    -- N/A
  elseif topic == df.talk_choice_type.GiveServiceReport then
    -- ?
  elseif topic == df.talk_choice_type.OfferEncouragement then
    -- "I have confidence in your abilities."
  elseif topic == df.talk_choice_type.PraiseTaskCompleter then
    -- "Commendable!  Your loyalty and bravery cannot be denied."
  elseif topic == df.talk_choice_type.AskAboutPersonMenu then
    -- N/A
  elseif topic == df.talk_choice_type.AskAboutPerson then
    -- "What can you tell me about "
    -- topic1: historical_figure key
    -- "?"
  elseif topic == df.talk_choice_type.TellAboutPerson then
    -- topic1: historical_figure key
    -- ?
  elseif topic == df.talk_choice_type.AskFeelings then
    -- "How are you feeling right now?"
  elseif topic == df.talk_choice_type.TellThoughts then
    ----1
    -- "I've" / "I have"
    -- " been "
    -- "contemplating" / "considering" / "praying"
    -- "the subject of" / "the concept of" / "the idea of" / "the theme of"
    -- sphere_type / TODO: ? deity
    -- "It's a great day to fall in love all over again."
    -- / "People do get so carried away sometimes, but not I."
    -- / "Sometimes I just don't like somebody."
    -- / "How can someone be so consumed by hate?"
    -- / "I get so jealous sometimes."
    -- / "I don't understand how somebody can become so obsessed by what somebody else has."
    -- / "Be happy!"
    -- / "Is there something to be happy about?"
    -- / "It really gets me down sometimes."
    -- / "How can people be so glum?"
    -- / "I have trouble controlling my temper."
    -- / "People can be so angry, and I just don't understand it."
    -- / "W... worried?  Do I look worried?"
    -- / "There's nothing to be upset about."
    -- / "I'm feeling randy today!"
    -- / "I just don't understand these flames of passion people go on about."
    -- / "I don't handle pressure well."
    -- / "I'm at my best under pressure."
    -- / "Yes, I want more.  Is that so bad?"
    -- / "Why are they so fixated on these baubles?"
    -- / "So I overindulge sometimes."
    -- / "Sometimes I think I need a drink, but I can control myself."
    -- / "There's nothing like a good brawl."
    -- / "Why must they be so violent?"
    -- / "Get me going and I won't stop for anything."
    -- / "Maybe I give up too early sometimes."
    -- / "I don't always do things in the most efficient way."
    -- / "We must be careful not to waste."
    -- / "I don't mind stirring things up."
    -- / "It's so great when everybody just gets along."
    -- / "You're so perceptive!"
    -- / "You don't care, so don't ask."
    -- / "I try to live and behave properly."
    -- / "What's this about proper living?"
    -- / "I was never one to follow advice."
    -- / "I'm not much of a decision maker."
    -- / "Have no fear."
    -- / "Bravery is not a strength of mine."
    -- / "We will be successful."
    -- / "I don't think I'm cut out for this."
    -- / "I look splendid today."
    -- / "Some people are so wrapped up in themselves."
    -- / "My goals are important to me."
    -- / "I don't feel like I need to chase anything."
    -- / "One should always return a favor."
    -- / "It's not a gift if you expect something in return."
    -- / "I like to dress well."
    -- / "I wouldn't feel comfortable getting all dressed up."
    -- / "Did you hear the one about the " TODO
    -- / "That isn't funny."
    -- / "Don't get on my bad side."
    -- / "You shouldn't waste your life on revenge."
    -- / "I am a very, very important person."
    -- / "Oh, I'm nothing special."
    -- / "There's no room for mercy in this world."
    -- / "Show some mercy now and again."
    -- / "I'm concentrating on something."
    -- / "Huh?  What was that?"
    -- / "I'm feeling optimistic about the future."
    -- / "It won't turn out well."
    -- / "I'm curious.  Tell me everything!"
    -- / "I don't really want to know."
    -- / "I wonder what they think."
    -- / "Who cares what they think?"
    -- / "I could tell you all about it!"
    -- / "I don't feel like telling you about it."
    -- / "If you have a task, do it properly."
    -- / "It's not perfect, but it's good enough.  Why fret about it?"
    -- / "I'm not going to change my mind."
    -- / "Try to keep an open mind."
    -- / "Everybody has their own way of life."
    -- / "I don't understand why they have to be that way."
    -- / "Friendship is forever."
    -- / "I don't really get attached to people."
    -- / "I go with the flow sometimes."
    -- / "Don't bother trying to play on my emotions."
    -- / "I'm happy to help."
    -- / "Why should I help?"
    -- / "Do your duty."
    -- / "I don't like being obligated to anybody."
    -- / "Oh, I don't usually think much."
    -- / "One must always carefully consider the correct course of action."
    -- / "Everything just so in its proper place!"
    -- / "It's my mess."
    -- / "People are basically trustworthy."
    -- / "My trust is earned, and not by many."
    -- / "It's such a joy to be with people."
    -- / "I prefer to be by myself."
    -- / "People should listen to what I have to say."
    -- / "I try not to interrupt."
    -- / "There's so much to be done!"
    -- / "What's the rush?"
    -- / "I need some more excitement in my life."
    -- / "I'd just as soon not have anything too exciting happen today."
    -- / "Do you have dreams?  Tell me a story!"
    -- / "Try to focus on the practical side of the matter."
    -- / "A great piece of art is one that moves me."
    -- / "I guess I just don't appreciate art."
    -- / "I could really use a drink."
    -- / "I am not governed by urges."
    -- / "I encountered a fascinating conundrum recently."
    -- / "I cannot stand the world any longer..."
    -- / "Everything is all piling up at once!"
    -- / "I'm feel like I'm about to snap."
    -- / "I just don't care anymore..."
    -- / "I feel so tired of everything."
    -- / "I can't take much more of this!"
    -- / "I feel angry all the time."
    -- / "I'm feeling really worn down."
    -- / "It's all starting to get me down."
    -- / "I've been feeling anxious."
    -- / "I get fed up sometimes."
    -- / "I've been under some pressure."
    -- / "I'm " / "I'm doing " / "I've been " / "I feel " / "Everything's "
    -- "fine" / "well" / "alright" / "good" / "just fine"
    -- "."
  elseif topic == df.talk_choice_type.AskServices then
  elseif topic == df.talk_choice_type.TellServices then
    -- "We have many drinks to choose from."
    -- / "The poet!  It's such an honor to have you here.  We have river spirits, potato wine and prickle berry wine.  All drinks cost 1 for a mug.  We rent out rooms for 17 a night."
    -- / "This is not that kind of establishment."
  elseif topic == df.talk_choice_type.OrderDrink then
    ----1
    -- "I'd like the " drink "."
  elseif topic == df.talk_choice_type.RentRoom then
    -- "I'd like a room."
  elseif topic == df.talk_choice_type.ExtendRoomRental then
    -- "I'd like my room for another night."
  elseif topic == df.talk_choice_type.ConfirmServiceOrder then
    -- "I'll be back with your drink in a moment."
    -- / "Your room is up the stairs, the first door on your right."
    -- / "You'll have the room for another day. I'm glad you're enjoying your stay."
  elseif topic == df.talk_choice_type.AskJoinEntertain then
    -- "Let's entertain the world together!"
  elseif topic == df.talk_choice_type.RespondJoinEntertain then
   -- TODO
   -- "Can you manage a troupe so large?"
   -- 5 "I'm sorry.  My duty is here."
  elseif topic == df.talk_choice_type.AskJoinTroupe then
  -- elseif topic == 183 then
  elseif topic == df.talk_choice_type.RefuseTroupeApplication then
  elseif topic == df.talk_choice_type.InviteJoinTroupe then
  elseif topic == df.talk_choice_type.AcceptTroupeInvitation  then
  elseif topic == df.talk_choice_type.RefuseTroupeInvitation then
  elseif topic == df.talk_choice_type.KickOutOfTroupe then
    -- "I'm kicking you out of "
    -- topic1: historical_entity key
    -- "."
  elseif topic == df.talk_choice_type.CreateTroupe then
  elseif topic == df.talk_choice_type.LeaveTroupe then
  -- elseif topic == 191 then
  elseif topic == df.talk_choice_type.TellBePatientForService then
    -- "Please be patient. I'll have your order ready in a moment."
    constituent = ps.utterance{
      ps.sentence{
        ps.infl{
          polite=true,
          mood=k'IMPERATIVE',
          subject=ps.thee(context),
          k'patient',
        },
      },
      ps.sentence{
        ps.infl{
          tense=k'FUTURE',
          t'cause to be'{
            agent=ps.me(context),
            theme=ps.infl{
              subject=ps.np{rel=ps.thee(context), k'order,N'},
              ps.adj{
                t'within time span'{t=ps.np{det=k'a', k'moment'}},
                k'ready',
              },
            },
          },
        },
      },
    }
  elseif topic == df.talk_choice_type.TellNoServices then
    -- "We don't offer any specific services here."
  elseif topic == df.talk_choice_type.AskWaitUntilThere then
    -- "Yes, I can serve you when we're both there."
  elseif topic == df.talk_choice_type.DenyWorkingHere then
    -- "I don't work here."
  elseif topic == df.talk_choice_type.ExpressEmotionMenu then
    -- N/A
  elseif topic == df.talk_choice_type.StateValueMenu then
    -- N/A
  elseif topic == df.talk_choice_type.StateValue then
    ----1
    if topic1 == df.value_type.LAW then
      -- "One should always respect the law."
      -- "Society flourishes when law breakers are punished."
      -- "Nothing gives them the right to establish these laws."
      -- "No law can do justice to the complexity of life."
      -- "Some laws are just, while others were made to be broken."
      -- "Rules are there to be bent, but they shouldn't be flouted thoughtlessly."
      -- "I consider laws to be more of a suggestion than anything."
    elseif topic1 == df.value_type.LOYALTY then
      -- "You must never forget true loyalty.  Repay it in full."
      -- "How can society function without loyalty?  We must be able to have faith in each other."
      -- "One must always be loyal to their cause and the ones they serve."
      -- "Don't serve anyone blindly.  You'll only get into trouble."
      -- "The whole idea of loyalty is pointless.  Acting purely out of loyalty implies acting against one's own best interest."
      -- "Never lose yourself in loyalty.  You know what is best for yourself."
      -- "Loyalty has value, but you should always keep the broader picture in mind."
      -- "You should only maintain loyalty so long as something more important is not at stake."
      -- "Consider your loyalties carefully, adhere to them while they last, and abandon them when you must."
    elseif topic1 == df.value_type.FAMILY then
      -- "How great it is to be surrounded by family!"
      -- "You can always rely on your family when everything else falls away."
      -- "Family is the true bond that keeps society thriving."
      -- "I was always irritated by family."
      -- "We cannot choose our families, but we can choose to avoid them."
      -- "I hold the relationships I've forged myself over family ties I had no part in creating."
      -- "Family is complicated and those ties be both a boon and a curse.  Sometimes both at once!"
      -- "You can't always rely on your family, but it's good to know somebody is there."
    elseif topic1 == df.value_type.FRIENDSHIP then
      -- "There's nothing like a good friend."
      -- "Surround yourself with friends you can trust and you will be unstoppable."
      -- "When all other bonds wither, friendship will remain."
      -- "Be careful of your so-called friends."
      -- "Friends are future enemies.  I don't see the difference.  People do as they must."
      -- "Building friendships is a waste.  There is no bond that can withstand distance or a change of circumstance."
      -- "Friends are nice, but you should keep your priorities straight."
    elseif topic1 == df.value_type.POWER then
      -- "Strive for power."
      -- "Power over others is the only true measure of worth."
      -- "You can be powerful or powerless.  The choice is yours, until somebody makes it for you."
      -- "There's nothing admirable about bullying others."
      -- "It is abhorrent to seek power over other people."
      -- "The struggle for power must be balanced by other considerations."
    elseif topic1 == df.value_type.TRUTH then
      -- "You should always tell the truth."
      -- "There is nothing so important that it is worth telling a lie."
      -- "Everything is so much easier when you just tell the truth."
      -- "There is no value in telling the truth thoughtlessly.  Consider the circumstances and say what is best."
      -- "Is there ever a time when honesty by itself overrides other considerations?  Say what is right, not what is true."
      -- "Don't think about the truth, whatever that is.  Just say what needs to be said."
      -- "There are times when it is alright not to tell the whole truth."
      -- "It is best not to complicate your life with lies, sure, but the truth also has its problems."
      -- "Sometimes the blunt truth just does more damage.  Think about how the situation will unfold before you speak."
    elseif topic1 == df.value_type.CUNNING then
      -- "I do admire a clever trap."
      -- "There's no value in all of this scheming I see these days."
      -- "Be shrewd, but do not lose yourself in guile."
    elseif topic1 == df.value_type.ELOQUENCE then
      -- "I do admire a clever turn of phrase."
      -- "I can appreciate the right turn of phrase."
      -- "Who are these mealy-mouthed cowards trying to impress?"
      -- "They are so full of all those big words."
      -- "There is a time for artful speech, and a time for blunt speech as well."
    elseif topic1 == df.value_type.FAIRNESS then
      -- "Always deal fairly."
      -- "Don't be afraid to do anything to get ahead in this world."
      -- "Life isn't fair, and sometimes you have to do what you have to do, but working toward a balance isn't a bad thing."
    elseif topic1 == df.value_type.DECORUM then
      -- "Please maintain your dignity."
      -- "What do you care how I speak or how I live?"
      -- "I can see a place for maintaining decorum, but it's exhausting to live that way."
    elseif topic1 == df.value_type.TRADITION then
      -- "Some things should never change."
      -- "It's admirable when the traditions are upheld."
      -- "We need to find a better way than those of before."
      -- "We need to move beyond traditions."
      -- "Some traditions are worth keeping, but we should consider their overall value."
    elseif topic1 == df.value_type.ARTWORK then
      -- "Art is life."
      -- "The creative impulse is so valuable."
      -- "What's so special about art?"
      -- "Art?  More like wasted opportunity."
      -- "Art is complicated.  I know what I like, but some I can do without."
    elseif topic1 == df.value_type.COOPERATION then
      -- "We should all work together."
      -- "It's better to work alone when possible, I think.  Cooperation breeds weakness."
      -- "You should think carefully before embarking on a joint enterprise, though there is some value in working together."
    elseif topic1 == df.value_type.INDEPENDENCE then
      -- "I treasure my freedom."
      -- "Nobody is free, and it is pointless to act as if you are."
      -- "Personal freedom must be tempered by other considerations."
    elseif topic1 == df.value_type.STOICISM then
      -- "One should not complain or betray any feeling."
      -- "Do not hide yourself behind an unfeeling mask."
      -- "There are times when it is best to keep your feelings to yourself, but I wouldn't want to force it."
    elseif topic1 == df.value_type.INTROSPECTION then
      -- "It is important to discover yourself."
      -- "Why would I waste time thinking about myself?"
      -- "Some time spent in reflection is admirable, but you must not forget to live your life."
    elseif topic1 == df.value_type.SELF_CONTROL then
      -- "I think self-control is key.  Master yourself."
      -- "Why deny yourself your heart's desire?"
      -- "People should be able to control themselves, but it's fine to follow impulses that aren't too harmful."
    elseif topic1 == df.value_type.TRANQUILITY then
      -- "The mind thinks best when the world is at rest."
      -- "Give me the bustle and noise over all that quiet!"
      -- "I like a balance of tranquility and commotion myself."
    elseif topic1 == df.value_type.HARMONY then
      -- "We should all be as one.  Why all the struggling?"
      -- "We grow through debate and struggle, even chaos and discord."
      -- "Some discord is a healthy part of society, but we must also try to live together."
    elseif topic1 == df.value_type.MERRIMENT then
      -- "Be merry!"
      -- "It's great when we all get a chance to be merry together."
      -- "Bah!  I hope you aren't celebrating something."
      -- "Merriment is worthless."
      -- "I can take or leave merrymaking myself, but I don't begrudge people their enjoyment."
    elseif topic1 == df.value_type.CRAFTSMANSHIP then
      -- "An artisan, their materials and the tools to shape them!"
      -- "Masterwork?  Why should I care?"
      -- "A tool should get the job done, but one shouldn't obsess over the details."
    elseif topic1 == df.value_type.MARTIAL_PROWESS then
      -- "A skilled warrior is a beautiful sight to behold."
      -- "Why this obsession with weapons and battle?  I don't understand some people."
      -- "The world isn't always safe.  I can see the value in martial training, the beauty even, but it shouldn't be exalted."
    elseif topic1 == df.value_type.SKILL then
      -- "We should all be so lucky as to truly master a skill."
      -- "The amount of practice that goes into mastering a skill is so impressive."
      -- "Everyone should broaden their horizons.  Any work beyond learning the basics is just a waste."
      -- "All of that practice is misspent effort."
      -- "I think people should hone their skills, but it's possible to take it too far and lose sight of the breadth of life."
      -- "There's more to life than becoming great at just one thing, but being good at several isn't bad!"
    elseif topic1 == df.value_type.HARD_WORK then
      -- "In life, you should work hard.  Then work harder."
      -- "Hard work is the true sign of character."
      -- "The best way to get what you want out of life is to work for it."
      -- "It's foolish to work hard for anything."
      -- "You shouldn't whittle your life away on working."
      -- "Hard work is bested by luck, connections and wealth every time."
      -- "An earnest effort at any required tasks.  That's all that's needed."
      -- "I only work so hard, but sometimes you have to do what you have to do."
      -- "Hard work is great.  Finding a way to work half as hard is even better."
    elseif topic1 == df.value_type.SACRIFICE then
      -- "We must be ready to sacrifice when the time comes."
      -- "Why harm yourself for anybody else's benefit?"
      -- "Some self-sacrifice is worthy, but do not forget yourself in devotion to the well-being of others."
    elseif topic1 == df.value_type.COMPETITION then
      -- "It's a competitive world, and you'd be a fool to think otherwise."
      -- "All of this striving against one another is so foolish."
      -- "There is value in a good rivalry, but such danger as well."
    elseif topic1 == df.value_type.PERSEVERENCE then
      -- "Keep going and never quit."
      -- "Anybody that sticks to something a moment longer than they have to is an idiot."
      -- "It's good to keep pushing forward, but sometimes you just have to know when it's time to stop."
    elseif topic1 == df.value_type.LEISURE_TIME then
      -- "Wouldn't it be grand to just take my life off and do nothing for the rest of my days?"
      -- "It's best to slow down and just relax."
      -- "There's work to be done!"
      -- "Time spent in leisure is such a waste."
      -- "There's some value in leisure, but one also has to engage with other aspects of life."
    elseif topic1 == df.value_type.COMMERCE then
      -- "Trade is the life-blood of a thriving society."
      -- "All of this buying and selling isn't honest work."
      -- "There's something to be said for trade as a necessity, but there are better things in life to do with one's time."
    elseif topic1 == df.value_type.ROMANCE then
      -- "There's nothing like a great romance!"
      -- "These people carrying on about romance should be more practical."
      -- "You shouldn't get too carried away with romance, but it's fine in moderation."
    elseif topic1 == df.value_type.NATURE then
      -- "It's wonderful to be out exploring the wilds!"
      -- "I could do without all of those creatures and that tangled greenery."
      -- "Nature can be enjoyed and used for myriad purposes, but there must always be respect and even fear of its power."
    elseif topic1 == df.value_type.PEACE then
      -- "Let there be peace throughout the world."
      -- "How I long for the beautiful spectacle of war!"
      -- "War is sometimes necessary, but peace must be valued as well, when we can have it."
    elseif topic1 == df.value_type.KNOWLEDGE then
      -- "The quest for knowledge never ends."
      -- "All of that so-called knowledge doesn't mean a thing."
      -- "Knowledge can be useful, but it can also be pointless or even dangerous."
    end
  elseif topic == df.talk_choice_type.SayNoOrderYet then
    -- "You haven't ordered anything. Would you like something?"
  elseif topic == df.talk_choice_type.ProvideDirectionsBuilding then
    -- topic1, topic2: building
    -- " is "
    -- direction
    -- "."
  elseif topic == df.talk_choice_type.Argue then
    ----1
    -- "No."
    -- "I disagree."
    -- "I cannot agree."
    -- "That's wrong."
    -- "That's not right."
    -- "I beg to differ."
    -- "Pause to consider."
    -- "You are thinking about this all wrong."
    -- "Stop and reflect."
    -- "I don't agree."
    -- "Just think about it."
  elseif topic == df.talk_choice_type.Flatter then
    ----1
    -- "Though I cannot agree fully on a slight technicality,"
    -- / "Despite some minor reservations..."
    -- / "Even if I don't change my mind,"
    -- / "Ignoring that I don't quite concur..."
    -- / "Although my own insignificant beliefs lie elsewhere,"
    -- "you are so clever I must concede!"
    -- / "I admire how brilliant you are!"
    -- / "I must say that is a truly insightful observation!"
    -- / "I confess your stunning argument overwhelms me!"
    -- / "I am overmastered by your presence!"
    -- / "we can both agree you are by far the most persuasive!"
    -- / "no one can deny your genius!"
    -- / "you needn't indulge my trivial thoughts!"
    -- / "I am so nearly swayed by your greatness alone that we can simply assign you the victory!"
  elseif topic == df.talk_choice_type.DismissArgument then
    ----1
    -- "No!"
    -- "Ha!"
    -- "Eh?"
    -- "Huh?"
    -- "Ack!"
    -- "Uh..."
    -- "How unreasonable!"
    -- "Were you trying to make an argument?"
    -- "Give me a break."
    -- "Are you being serious?"
    -- "What?"
    -- "Wait, what?"
    -- "What did you just say?"
    -- "Forgive me, but"
    -- "Am I supposed to engage with that?"
    -- "You must be joking."
    -- "I've heard it all now!"
    -- "Oh, no,"
    -- "That's absurd!"
    -- "that is the stupidest statement I have ever heard."
    -- "don't waste my time with this drivel."
    -- "really, I've been over all this nonsense before."
    -- "I couldn't follow your rambling."
    -- "I'm having trouble taking you seriously."
    -- "nobody could possibly believe that."
    -- "it would amaze me if somebody actually thought that."
    -- "there's just no way you can believe something so stupid."
    -- "the things some people think just boggle the mind."
    -- "you should keep your weird thoughts to yourself."
    -- "that isn't at all convincing."
    -- "I'm appalled."
    -- "Shameful."
    -- "You're wrong."
    -- "Unbelievable."
    -- "Really."
    -- "It's wrong."
  elseif topic == df.talk_choice_type.RespondPassively then
    ----1
    -- "I don't want to argue."
    -- / "I don't know what to say."
    -- / "I guess I'm not sure."
    -- / "I just don't know."
  elseif topic == df.talk_choice_type.Acquiesce then
    ----1
    -- "Maybe you're right."
    -- "Yes, I can see it clearly now."
    -- "I have been so foolish.  Yes, I agree."
    -- "You know, I think you're right."
  elseif topic == df.talk_choice_type.DerideFlattery then
    ----1
    -- "You insult me with your flattery, but let us move on."
  elseif topic == df.talk_choice_type.ExpressOutrageAtDismissal then
    ----1
    -- "You insult me with your derision, but let us move on."
  elseif topic == df.talk_choice_type.PressArgument then
    ----1
    -- "I must insist."
    -- "You must be convinced."
    -- "I require a substantive reply."
    -- "I sense you're wavering."
    -- "No, I mean it."
    -- TODO: others? see string dump
  elseif topic == df.talk_choice_type.DropArgument then
    ----1
    -- "If you insist so strongly, we can move on."
    -- / "Well, there must be something else to discuss."
    -- / "Fine.  Let's drop the argument."
    -- "How gracious!"
    -- / "Of course."
    -- / "You are right."
    -- "There must be something else to discuss."
    -- / "Let's drop the argument."
    -- / "Yes, let's move on."
  elseif topic == df.talk_choice_type.AskWork then
  elseif topic == df.talk_choice_type.AskWorkGroup then
  elseif topic == df.talk_choice_type.GrantWork then
  elseif topic == df.talk_choice_type.RefuseWork then
  elseif topic == df.talk_choice_type.GrantWorkGroup then
  elseif topic == df.talk_choice_type.RefuseWorkGroup then
  elseif topic == df.talk_choice_type.GiveSquadOrder then
    -- "You must drive "
    -- topic3: historical_entity / "an unknown civilization"
    -- " from their home at "
    -- topic4: world_site / "an unknown site"
    -- / "You must kill the "
    -- topic2: race " " name
    -- "This "
    -- "great beast" / "horrible beast" / "evil being" / "beast from the wilds"
    -- " threatens our people with its very presence."
    -- "This vile fiend has killed " number " in " his/her " lust for murder!"
    -- "Seek your foe in "  -- This might go before "This vile fiend..."
    -- "the town of " name / "the hamlet of " name
    -- "Our hopes travel with you." / "Enjoy the hunt!"
    -- / "You must drive the ruffians of "
    -- topic3: historical_entity
    -- " from "
    -- topic4:
    --   "our "
    --   "hillocks"  -- based on world_site's type and flags
    --   / "fortress"
    --   / "cave"
    --   / "hillocks"
    --   / "forest retreat"
    --   / "town" / "hamlet"
    --   / "important location"
    --   / "lair"
    --   / "fortress"
    --   / "camp"
    --   / "monument"
    --   " of " world_site
    --   / "an unknown site"
    -- ".  They have been harassing the people for too long."
  end
  if not constituent then
    -- TODO: This should never happen, once the above are all filled in.
    -- "Uh...  what was that?"
    -- / "Uh...  nevermind."
    -- / "I don't remember what I was going to say..."
    -- / "I've forgotten what I was going to say..."
    -- / "I am confused."
    constituent = {text='... [' .. tostring(topic) .. ',' .. tostring(topic1) .. ',' .. tostring(topic2) .. ',' .. tostring(topic3) .. ',' .. tostring(topic4) .. '] (' .. english .. ')', features={}, morphemes={}}
  end
  return constituent, context
end

--[[
Converts a sequence of utterables to a string.

The full transcription is the concatenation of the transcriptions of the
utterables joined by `WORD_SEPARATOR`. Each string transcription is
itself. Each mword transcription is the concatenation of the
transcriptions of its morphemes joined by `MORPHEME_SEPARATOR`. Each
morpheme transcription is the concatenation of the transcription of its
phonemes. Phonemes are transcribed using the phonology's symbols.

Args:
  utterables: A sequence of utterables.
  phonology: A phonology.

Returns:
  The string transcription of `utterables` using `phonology`'s symbols.
]]
local function transcribe(utterables, phonology)
  local t1 = {}
  for _, utterable in ipairs(utterables) do
    if type(utterable) == 'string' then
      t1[#t1 + 1] = utterable
    else
      local t2 = {}
      for _, morpheme in ipairs(utterable) do
        local lemma = get_lemma(phonology, morpheme.pword)
        if lemma ~= '' then
          t2[#t2 + 1] = lemma
        end
      end
      local word = table.concat(t2, MORPHEME_SEPARATOR)
      if word ~= '' then
        t1[#t1 + 1] = word
      end
    end
  end
  return table.concat(t1, WORD_SEPARATOR)
end

--[[
Randomly generates a word for a lect.

Args:
  lect! A lect.
  word_id: The ID of the new word.

Returns:
  A constituent representing a random word.
  The sequence of morphemes used by the constituent.
  The lemma of the word as a string.
]]
local function random_word(lect, word_id)
  -- TODO: OCP
  -- TODO: Protect against infinite loops due to sonority dead ends.
  local phonology = lect.phonology
  local parameters = get_parameters(lect)
  -- TODO: random sonority parameters
  local min_peak_sonority = parameters.max_sonority
  local min_sonority_delta = math.max(1, math.floor((parameters.max_sonority - parameters.min_sonority) / 2))
  -- TODO: more realistic syllable count distribution
  local syllables_left = math.random(2)
  -- TODO: make sure this is low enough so it never triggers a new syllable on the first phoneme (here and below)
  local peak_sonority = -100
  local prev_sonority = -100
  local pword = {}
  local limit = 20  -- TODO: make this limit unnecessary
  while syllables_left ~= 0 and limit ~= 0 do
    limit = limit - 1
--    print('\nleft: ' .. syllables_left)
    local phoneme_and_sonority =
      parameters.inventory[math.random(#parameters.inventory)]
    local phoneme = phoneme_and_sonority[1]
    local sonority = phoneme_and_sonority[2]
--    print('phoneme: ' .. get_lemma(phonology, {phoneme}) .. ' (' .. sonority .. ')')
    local use_phoneme = true
    local sonority_delta = sonority - prev_sonority
--    print('peak sonority: ' .. peak_sonority)
--    print('delta: ' .. sonority_delta)
    if ((sonority < peak_sonority and sonority_delta > 0) or
        (sonority > peak_sonority and sonority_delta < 0) or
        math.abs(sonority_delta) < min_sonority_delta) then
      if peak_sonority < 0 then
        use_phoneme = false
--        print('  skip!')
      else
        syllables_left = syllables_left - 1
--        print('  new syllable!')
        peak_sonority = -100
      end
    end
    if use_phoneme and syllables_left ~= 0 then
      if sonority >= min_peak_sonority then
        peak_sonority = sonority
      end
      prev_sonority = sonority
      pword[#pword + 1] = phoneme
    end
  end
  local morpheme = m{#lect.morphemes + 1, pword=pword}
  lect.morphemes[#lect.morphemes + 1] = morpheme
  local morphemes = {morpheme}
  local constituent = x{m=morphemes}
  lect.constituents[word_id] = constituent
  return constituent, morphemes, get_lemma(phonology, pword)
end

--[[
Creates a comparator function for SFIs.

The comparator function sorts SFIs by increasing depth; then movement
SFIs before agreement SFIs; then lexicographically increasing by
feature name.

Args:
  parameters: A language parameter table.

Returns:
  A function suitable for sorting SFIs with `utils.sort_vector`.
]]
local function compare_sfis(parameters)
  return function(a, b)
    if a.depth < b.depth then
      return -1
    elseif a.depth > b.depth then
      return 1
    elseif (parameters.strategies[a.feature] and
            not parameters.strategies[b.feature]) then
      return -1
    elseif (not parameters.strategies[a.feature] and
            parameters.strategies[b.feature]) then
      return 1
    elseif a.feature < b.feature then
      return -1
    elseif a.feature > b.feature then
      return 1
    end
    return 0
  end
end

if TEST then
  local cmpfun = compare_sfis({strategies={a={}}})
  local sfi_0_a = {depth=0, head={x=1}, feature='a'}
  local sfi_0_b = {depth=0, head={x=1}, feature='b'}
  local sfi_0_c = {depth=0, head={x=1}, feature='c'}
  local sfi_1_a = {depth=1, head={x=1}, feature='a'}
  assert_eq(
    utils.sort_vector({sfi_1_a, sfi_0_b, sfi_0_a, sfi_0_c}, nil, cmpfun),
    {sfi_0_a, sfi_0_b, sfi_0_c, sfi_1_a})
end

--[[
Gets the best pair of SFIs for the purpose of agreement.

A pair of SFIs is eligible for agreement if they have the same feature
and exactly one of their heads has a value for that feature.

A pair of SFIs is better than another if the minimum of its two depths
is lower; otherwise if the maximum of its two depths is lower; otherwise
if its merging strategy is not merely agreement but the other's is.

One SFI from each sequence is chosen to maximize the quality of the
pair. They are removed from their sequences, along with any other pairs
between the same two heads that would be eligible for agreement.

Args:
  sfis_1! A sequence of SFIs sorted in decreasing order of quality as
    defined above.
  sfis_2! A sequence of SFIs sorted the same way.

Returns:
  The best SFI from `sfis_1`.
  The best SFI from `sfis_2`.
]]
local function get_best_sfis(sfis_1, sfis_2)
  local best_1, best_2
  local i = 1
  local j = 1
  local incrementing_i = false
  while i <= #sfis_1 and j <= #sfis_2 do
    local sfi_1 = sfis_1[i]
    local sfi_2 = sfis_2[j]
    local f = sfi_1.feature
    if (f == sfi_2.feature and
        not sfi_1.head.moved_to and not sfi_2.head.moved_to and
        not sfi_1.head.features[f] ~= not sfi_2.head.features[f]) then
      if incrementing_i ~= nil then
        best_1, best_2 = sfis_1[i], sfis_2[j]
        incrementing_i = nil
      elseif sfi_1.head == best_1.head and sfi_2.head == best_2.head then
        table.remove(sfis_1, i)
        table.remove(sfis_2, j)
      else
        break
      end
    elseif incrementing_i == nil then
      break
    end
    if incrementing_i then
      if i == #sfis_1 then
        incrementing_i = false
        i = j + 1
        j = i
      else
        i = i + 1
      end
    elseif incrementing_i == false then
      if j == #sfis_2 then
        incrementing_i = true
        j = i
        i = j + 1
      else
        j = j + 1
      end
    end
  end
  return best_1, best_2
end

if TEST then
  local f_unvalued = {feature='f', head={features={}}}
  local f_1 = {feature='f', head={features={f=1}}}
  local f_2 = {feature='f', head={features={f=2}}}
  local g_unvalued = {feature='g', head={features={}}}
  assert_eq(get_best_sfis({}, {}), nil)
  assert_eq(get_best_sfis({f_unvalued}, {}), nil)
  assert_eq(get_best_sfis({f_unvalued}, {f_unvalued}), nil)
  assert_eq(get_best_sfis({f_unvalued}, {g_unvalued}), nil)
  assert_eq(table.pack(get_best_sfis({f_unvalued}, {f_1})),
            {n=2, f_unvalued, f_1})
  assert_eq(get_best_sfis({f_1}, {f_1}), nil)
  assert_eq(get_best_sfis({f_1}, {g_unvalued}), nil)
  assert_eq(get_best_sfis({f_1}, {f_2}), nil)
  assert_eq(table.pack(get_best_sfis({f_unvalued}, {f_1, f_2})),
            {n=2, f_unvalued, f_1})
  assert_eq(table.pack(get_best_sfis({f_unvalued}, {f_2, f_1})),
            {n=2, f_unvalued, f_2})
  assert_eq(get_best_sfis({}, {f_unvalued}), nil)
  assert_eq(get_best_sfis({g_unvalued}, {f_unvalued}), nil)
  assert_eq(table.pack(get_best_sfis({f_1}, {f_unvalued})),
            {n=2, f_1, f_unvalued})
  assert_eq(get_best_sfis({g_unvalued}, {f_1}), nil)
  assert_eq(get_best_sfis({f_2}, {f_1}), nil)
  assert_eq(table.pack(get_best_sfis({f_1, f_2}, {f_unvalued})),
            {n=2, f_1, f_unvalued})
  assert_eq(table.pack(get_best_sfis({f_2, f_1}, {f_unvalued})),
            {n=2, f_2, f_unvalued})
  local sfis_1 = {f_1, f_1, f_1, f_1, f_1, f_1, f_1}
  local sfis_2 = {f_1, f_1, f_unvalued, f_unvalued, g_unvalued}
  assert_eq(table.pack(get_best_sfis(sfis_1, sfis_2)), {n=2, f_1, f_unvalued})
  assert_eq(sfis_1, {f_1, f_1, f_1, f_1, f_1})
  assert_eq(sfis_2, {f_1, f_1, g_unvalued})
end

--[[
Makes two SFIs agree (have the same value for their feature).

The SFIs must share the same feature. Exactly one must have a head which
has a value for that feature.

Args:
  sfi_1! An SFI.
  sfi_2! An SFI.
]]
local function agree(sfi_1, sfi_2)
  local goal, probe = sfi_1, sfi_2
  if sfi_1.head.features[sfi_1.feature] then
    goal, probe = probe, goal
  end
  local f = goal.feature
  local v = probe.head.features[probe.feature]
  local function set_feature(constituent)
    constituent.features[f] = v
    if constituent.n1 then
      set_feature(constituent.n1)
      if constituent.n2 then
        set_feature(constituent.n2)
      end
    end
  end
  set_feature(goal.head)
end

if TEST then
  local sfi_1 = {depth=1, feature='f', head={features={f=1}}}
  local sfi_2 = {depth=1, feature='f', head={features={f=false}}}
  agree(sfi_1, sfi_2)
  assert_eq(sfi_1.head, {features={f=1}})
  assert_eq(sfi_2.head, {features={f=1}})

  sfi_1 = {depth=1, feature='f', head={features={f=1}}}
  sfi_2 = {depth=1, feature='f', head={features={f=false}}}
  agree(sfi_2, sfi_1)
  assert_eq(sfi_1.head, {features={f=1}})
  assert_eq(sfi_2.head, {features={f=1}})

  -- TODO: Test with a non-head (`head` is now a misnomer).
end

--[[
Copies a morpheme deeply.

Args:
  morpheme: A morpheme.

Returns:
  A deep copy of the morpheme.
]]
local function copy_morpheme(morpheme)
  return {id=morpheme.id, text=morpheme.text, pword=copyall(morpheme.pword),
          dummy=morpheme.dummy and copy_morpheme(morpheme.dummy),
          affix=morpheme.affix, after=morpheme.after, initial=morpheme.initial,
          features=copyall(morpheme.features), fusion=copyall(morpheme.fusion)}
end

if TEST then
  local dummy = {id='z', pword={}, features={n=9}, fusion={}}
  local morpheme = {
    id='X', text='x', pword={}, affix='true', after=1, initial=-1,
    features={f=1, g=2}, fusion={y=dummy}, dummy=dummy,
  }
  local new_morpheme = copy_morpheme(morpheme)
  assert_eq(new_morpheme, morpheme)
  morpheme.features.f = 3
  assert_eq(new_morpheme.features.f, 1)
end

--[[
Copies a constituent deeply.

If `args` is provided, constituents dominated by `constituent` which
have `arg` keys are replaced with copies of the corresponding
constituents from `args`. If `args` is nil or there is no corresponding
constituent, it is just deleted; this allows for optional arguments.

Args:
  constituent: A constituent.
  args: An optional mapping of strings to constituents.

Returns:
  A deep copy of the constituent.
]]
local function copy_constituent(constituent, args)
  if constituent.arg then
    return args and copy_constituent(args[constituent.arg])
  end
  local morphemes = {}
  if constituent.morphemes then
    for i, morpheme in ipairs(constituent.morphemes) do
      morphemes[i] = copy_morpheme(morpheme)
    end
  end
  return {
    n1=constituent.n1 and copy_constituent(constituent.n1, args),
    n2=constituent.n2 and copy_constituent(constituent.n2, args),
    features=copyall(constituent.features),
    morphemes=morphemes,
    is_phrase=constituent.is_phrase,
    depth=constituent.depth,
    ref=constituent.ref,
    args=constituent.args,
    maximal=constituent.maximal,
    moved_to=constituent.moved_to,
    text=constituent.text,
    context_key=constituent.context_key,
    context_callback=constituent.context_callback,
  }
end

if TEST then
  local c1 = {
    n1={features={f=1, g=2}, morphemes={m'x', m'y'}},
    features={f=1, g=2}, morphemes={}, is_phrase=true,
  }
  assert_eq(copy_constituent(c1), c1)
  c1.n2 = {arg='a', morphemes={}}
  assert_eq(copy_constituent(c1).n2, nil)
  local c2 = {ref='r', features={}, morphemes={},
              args={t={ref='t', features={}, morphemes={}}}}
  assert_eq(copy_constituent(c1, {a=c2}).n2, c2)
end

--[[
Determines whether a morpheme should locally dislocate around another.

If dislocation would check an unvalued feature in `dislocated`, or if it
has no unvalued features, local dislocation should happen.

Args:
  dislocated: The feature map of the morpheme that would be locally
    dislocated.
  static: The feature map of the morpheme relative to which `dislocated`
    would be locally dislocated.

Returns:
  Whether the morpheme of which `dislocated` is the feature map should be
    locally dislocated.
]]
local function should_dislocate(dislocated, static)
  local found_unvalued_feature = false
  for f, v in pairs(dislocated) do
    if not v and static[f] then
      return true
    else
      found_unvalued_feature = true
    end
  end
  return not found_unvalued_feature
end

if TEST then
  assert_eq(should_dislocate({}, {}), true)
  assert_eq(should_dislocate({f=true}, {}), false)
  assert_eq(should_dislocate({f=false}, {}), false)
  assert_eq(should_dislocate({f=false}, {f=true}), true)
  assert_eq(should_dislocate({f=false}, {g=true}), false)
  assert_eq(should_dislocate({f=false, g=false}, {g=true}), true)
  assert_eq(should_dislocate({}, {f=false}), true)
end

--[[
Concatenate sequences with local dislocation.

The two sequences are concatenated. Some elements of one sequence may be
moved to the other; this is local dislocation. If the last morpheme (of
the last word) of `s1` is an affix, elements are dislocated from `s1`;
otherwise, they are dislocated from `s2`. Elements are dislocated from
the inner end of the chosen sequence (i.e. the last element of `s1` or
the first of `s2`) until there are no elements left, an element is not
an affix, or local dislocation fails.

Local dislocation must be motivated. It can fail if it would not
decrease the number of unvalued features. This is so that the later
phase of dummy insertion has something to work with. During dummy
insertion, there is no later phase to pick up the slack, so
`force_dislocation` is set to true, which forces local dislocation to
occur without regard for features.

A dislocating morpheme moves to the position after or before the initial
or final element in the other sequence, controlled by its `after` and
`initial` values. If the sequences are of words, the morpheme moves to
that position in the inner-end word of the other sequence.

Strings can never be dislocated.

Args:
  s1: A sequence of morphemes or utterables.
  s2: A sequence of morphemes or utterables (whichever `s1` has).
  force_dislocation: Whether local dislocation must happen.

Returns:
  The concatenation of the two sequences of morphemes or utterables with
    local dislocation of the morphemes at the boundary between them.
]]
local function dislocate(s1, s2, force_dislocation)
  if #s1 == 0 then
    return s2
  elseif #s2 == 0 then
    return s1
  end
  local rv = {}
  for i, e in pairs(s1) do
    rv[i] = e[1] and copyall(e) or e
  end
  for _, e in ipairs(s2) do
    rv[#rv + 1] = e[1] and copyall(e) or e
  end
  local s1_onto_s2 = (s1[#s1][1] and s1[#s1][#s1[#s1]] or s1[#s1]).affix
  local i = #s1 + (s1_onto_s2 and 0 or 1)
  local addend = s1_onto_s2 and -1 or 1
  while rv[i] and type(rv[i]) ~= 'string' do
    local dislocator = rv[i]
    if #dislocator ~= 0 then
      dislocator = dislocator[1]
    end
    if dislocator.affix then
      local e = table.remove(rv, i)
      local j = (e[1] and i or
                 (s1_onto_s2 and (dislocator.initial and i or #rv) or
                  (dislocator.initial and 1 or i - 1)))
      local static = rv[j]
      if #static ~= 0 then
        static = static[1]
      end
      if (force_dislocation or
          should_dislocate(dislocator.features, static.features)) then
        if #rv[j] == 0 then
          table.insert(rv, j + (dislocator.after and 1 or 0), e)
        else
          table.insert(rv[j], (dislocator.initial and 1 or #rv[j]) +
                       (dislocator.after and 1 or 0), e[1])
        end
        i = i + addend
      else
        table.insert(rv, i, e)
        break
      end
    else
      break
    end
  end
  return rv
end

if TEST then
  local xs = {{id=2, features={}}, {id=3, features={}}, {id=4, features={}}}
  assert_eq(dislocate({}, {}, false), {})
  assert_eq(dislocate({{id=1, features={}}}, {}, false), {{id=1, features={}}})
  assert_eq(dislocate({}, {{id=1, features={}}}, false), {{id=1, features={}}})
  assert_eq(dislocate({{id=1, features={}}}, {{id=2, features={}}}, false),
            {{id=1, features={}}, {id=2, features={}}})
  assert_eq(dislocate({{id=1, features={}}}, xs, false),
            {{id=1, features={}}, {id=2, features={}}, {id=3, features={}},
             {id=4, features={}}})
  assert_eq(dislocate({{id=1, features={}, affix=true}}, xs, false),
            {{id=2, features={}}, {id=3, features={}},
             {id=1, features={}, affix=true}, {id=4, features={}}})
  assert_eq(dislocate({{id=1, features={}, affix=true, initial=true}}, xs,
                      false),
            {{id=1, features={}, affix=true, initial=true},
             {id=2, features={}}, {id=3, features={}}, {id=4, features={}}})
  assert_eq(dislocate({{id=1, features={}, affix=true, after=true}}, xs, false),
            {{id=2, features={}}, {id=3, features={}}, {id=4, features={}},
             {id=1, features={}, affix=true, after=true}})
  assert_eq(dislocate({{id=1, features={}, affix=true, initial=true,
                        after=true}}, xs, false),
            {{id=2, features={}},
             {id=1, features={}, affix=true, initial=true, after=true},
             {id=3, features={}}, {id=4, features={}}})
  assert_eq(dislocate({{id=0, features={}}, {id=1, features={}, affix=true}},
                      {{id=2, features={}}, {id=3, features={}}}, false),
            {{id=0, features={}}, {id=2, features={}},
             {id=1, features={}, affix=true}, {id=3, features={}}})
  assert_eq(dislocate({{id=0, features={}, affix=true}, {id=1, features={}}},
                      {{id=2, features={}}, {id=3, features={}}}, false),
            {{id=0, features={}, affix=true}, {id=1, features={}},
             {id=2, features={}}, {id=3, features={}}})
  assert_eq(dislocate({{id=0, features={}, affix=true},
                       {id=1, features={}, affix=true}},
                      {{id=2, features={}}, {id=3, features={}}}, false),
            {{id=2, features={}}, {id=1, features={}, affix=true},
             {id=0, features={}, affix=true}, {id=3, features={}}})
  assert_eq(dislocate(xs, {{id=1, features={}, affix=true}}, false),
            {{id=2, features={}}, {id=3, features={}},
             {id=1, features={}, affix=true}, {id=4, features={}}})
  assert_eq(dislocate(xs, {{id=1, features={}, affix=true, initial=true}},
                      false),
            {{id=1, features={}, affix=true, initial=true},
             {id=2, features={}}, {id=3, features={}}, {id=4, features={}}})
  assert_eq(dislocate(xs, {{id=1, features={}, affix=true, after=true}},
                      false),
            {{id=2, features={}}, {id=3, features={}}, {id=4, features={}},
             {id=1, features={}, affix=true, after=true}})
  assert_eq(
    dislocate(xs, {{id=1, features={}, affix=true, initial=true, after=true}},
              false),
    {{id=2, features={}},
     {id=1, features={}, affix=true, initial=true, after=true},
     {id=3, features={}}, {id=4, features={}}})
  assert_eq(dislocate({{id=2, features={}}, {id=3, features={}}},
                      {{id=0, features={}}, {id=1, features={}, affix=true}},
                      false),
            {{id=2, features={}}, {id=3, features={}}, {id=0, features={}},
             {id=1, features={}, affix=true}})
  assert_eq(dislocate({{id=2, features={}}, {id=3, features={}}},
                      {{id=0, features={}, affix=true}, {id=1, features={}}},
                      false),
            {{id=2, features={}}, {id=0, features={}, affix=true},
             {id=3, features={}}, {id=1, features={}}})
  assert_eq(dislocate({{id=2, features={}}, {id=3, features={}}},
                      {{id=0, features={}, affix=true},
                       {id=1, features={}, affix=true}}, false),
            {{id=2, features={}}, {id=0, features={}, affix=true},
             {id=1, features={}, affix=true}, {id=3, features={}}})
  assert_eq(dislocate({{id=1, features={f=false}, affix=true}}, xs, false),
            {{id=1, features={f=false}, affix=true}, {id=2, features={}},
             {id=3, features={}}, {id=4, features={}}})
  assert_eq(dislocate({{id=1, features={f=false}, affix=true}}, xs, true),
            {{id=2, features={}}, {id=3, features={}},
             {id=1, features={f=false}, affix=true}, {id=4, features={}}})
  assert_eq(dislocate({{id=1, features={f=1}, affix=true}}, xs, false),
            {{id=1, features={f=1}, affix=true}, {id=2, features={}},
             {id=3, features={}}, {id=4, features={}}})
  assert_eq(dislocate({{id=1, features={f=1}, affix=true}}, xs, true),
            {{id=2, features={}}, {id=3, features={}},
             {id=1, features={f=1}, affix=true}, {id=4, features={}}})
  assert_eq(dislocate({{id=1, features={f=false}, affix=true}},
                      {{id=2, features={f=1}}, {id=3, features={}},
                       {id=4, features={}}}, false),
            {{id=1, features={f=false}, affix=true}, {id=2, features={f=1}},
             {id=3, features={}}, {id=4, features={}}})

  assert_eq(dislocate({{{id=1, features={}}}}, {xs}, false),
            {{{id=1, features={}}}, xs})
  assert_eq(dislocate({{{id=1, features={}, affix=true}}}, {xs}, false),
            {{{id=2, features={}}, {id=3, features={}},
              {id=1, features={}, affix=true}, {id=4, features={}}}})
  assert_eq(dislocate({{{id=1, features={}, affix=true, initial=true}}}, {xs},
                      false),
            {{{id=1, features={}, affix=true, initial=true},
              {id=2, features={}}, {id=3, features={}}, {id=4, features={}}}})
  assert_eq(dislocate({{{id=1, features={}, affix=true, after=true}}}, {xs},
                      false),
            {{{id=2, features={}}, {id=3, features={}}, {id=4, features={}},
              {id=1, features={}, affix=true, after=true}}})
  assert_eq(dislocate({{{id=1, features={}, affix=true, initial=true,
                         after=true}}}, {xs}, false),
            {{{id=2, features={}},
              {id=1, features={}, affix=true, initial=true, after=true},
              {id=3, features={}}, {id=4, features={}}}})
  assert_eq(dislocate({{{id=1, features={}, affix=true},
                        {id=0, features={}}}}, {xs}, false),
            {{{id=1, features={}, affix=true}, {id=0, features={}}},
             {{id=2, features={}}, {id=3, features={}}, {id=4, features={}}}})
end

--[[
Merges constituents.

The target becomes a copy of the source, maintaining its old data when
not conflicting with the source's. The new constituent's morphemes are a
concatenation of both input constituents'. The source is given a
`moved_to` value of the target.

Args:
  target! A constituent.
  source! A constituent.
]]
local function merge_constituents(target, source)
  target.n1 = source.n1 and copy_constituent(source.n1)
  target.n2 = source.n2 and copy_constituent(source.n2)
  target.is_phrase = source.is_phrase
  target.morphemes = dislocate(target.morphemes, source.morphemes)
  utils.fillTable(target.features, source.features)
  source.moved_to = target
end

if TEST then
  local n1 = {n1={features={f=1, g=2}, morphemes={}}, features={f=1, g=2},
              morphemes={}, is_phrase=true}
  local target = {morphemes={{id=1, affix=true, features={}}},
                  features={f=4, i=5}}
  local source = {n1=n1, n2=copy_constituent(n1), is_phrase=true,
                  morphemes={{id=2, features={}}, {id=3, features={}},
                             {id=4, features={}}},
                  features={f=1, g=2, h=3}}
  merge_constituents(target, source)
  assert_eq(target,
            {n1=n1, n2=n1, is_phrase=true, features={f=1, g=2, h=3, i=5},
             morphemes={{id=2, features={}}, {id=3, features={}},
                        {id=1, features={}, affix=true}, {id=4, features={}}}})
  assert_eq(source,
            {n1=n1, n2=copy_constituent(n1), is_phrase=true, moved_to=target,
             morphemes={{id=2, features={}}, {id=3, features={}},
                        {id=4, features={}}},
             features={f=1, g=2, h=3}})
end

--[[
Makes two constituents agree in re a feature and maybe merge them.

If the input SFIs are not nil, their constituents are made to agree.
If their feature warrants it, and there is no structural impediment to
doing so, one constituent is merged into the other, by raising or
lowering.

Args:
  parameters: A language parameter table.
  sfi_1! An SFI or nil.
  sfi_2! An SFI, or nil if `sfi_1` is nil.
]]
local function agree_and_maybe_merge(parameters, sfi_1, sfi_2)
  if sfi_1 then
    local strategy = parameters.strategies[sfi_1.feature]
    local merge_target, merge_source = sfi_1.head, sfi_2.head
    if strategy and strategy.lower == (merge_target.depth < merge_source.depth)
    then
      merge_target, merge_source = merge_source, merge_target
    end
    if strategy and strategy.lower then
      strategy = nil
    elseif strategy and strategy.pied_piping then
      merge_source = merge_source.maximal or merge_source
    end
    if strategy and (merge_target.n1 or
                     not (merge_source.n1 or next(merge_source.morphemes)) or
                     merge_source.n1 and next(merge_target.morphemes)) then
      strategy = nil
    end
    agree(sfi_1, sfi_2)
    if strategy then
      merge_constituents(merge_target, merge_source)
    end
  end
end

if TEST then
  local parameters = {strategies={r={}, l={lower=true}, rp={pied_piping=true},
                                  lp={lower=true, pied_piping=true}}}
  agree_and_maybe_merge(parameters, nil, nil)
  local sfi_1 = {feature='a', depth=1,
                 head={depth=1, features={a=1}, morphemes={{id=1}}}}
  local sfi_2 = {feature='a', depth=1,
                 head={depth=1, features={a=false}, morphemes={{id=2}}}}
  agree_and_maybe_merge(parameters, sfi_1, sfi_2)
  assert_eq(sfi_1, {feature='a', depth=1,
                    head={depth=1, features={a=1}, morphemes={{id=1}}}})
  assert_eq(sfi_2, {feature='a', depth=1,
                    head={depth=1, features={a=1}, morphemes={{id=2}}}})
  sfi_1 = {feature='r', depth=1,
           head={depth=1, features={r=1}, morphemes={{id=1}}}}
  sfi_2 = {feature='r', depth=2,
           head={depth=2, features={r=false}, morphemes={{id=2}}}}
  agree_and_maybe_merge(parameters, sfi_1, sfi_2)
  assert_eq(sfi_1, {feature='r', depth=1, head={depth=1, features={r=1},
                                                morphemes={{id=1}, {id=2}}}})
  assert_eq(sfi_2, {feature='r', depth=2,
                    head={depth=2, moved_to=sfi_1.head, features={r=1},
                          morphemes={{id=2}}}})
  sfi_1 = {feature='l', depth=1,
           head={depth=1, features={l=1}, morphemes={{id=1}}}}
  sfi_2 = {feature='l', depth=2,
           head={depth=2, features={l=false}, morphemes={{id=2}}}}
  agree_and_maybe_merge(parameters, sfi_1, sfi_2)
  assert_eq(sfi_1, {feature='l', depth=1,
                    head={depth=1, features={l=1}, morphemes={{id=1}}}})
  assert_eq(sfi_2, {feature='l', depth=2,
                    head={depth=2, features={l=1}, morphemes={{id=2}}}})
  sfi_1 = {feature='l', depth=1,
           head={depth=1, features={l=1}, morphemes={{id=1}}}}
  sfi_2 = {feature='l', depth=2,
           head={depth=2, features={l=false}, morphemes={{id=2}}, maximal={}}}
  agree_and_maybe_merge(parameters, sfi_1, sfi_2)
  assert_eq(sfi_1, {feature='l', depth=1,
                    head={depth=1, features={l=1}, morphemes={{id=1}}}})
  assert_eq(sfi_2, {feature='l', depth=2,
                    head={depth=2, features={l=1}, morphemes={{id=2}},
                          maximal={}}})
  sfi_1 = {feature='rp', depth=1,
           head={depth=1, features={rp=1}, morphemes={}}}
  sfi_2 = {feature='rp', depth=2,
           head={depth=2, features={rp=false}, morphemes={{id=2}},
                 maximal={depth=1, features={}, morphemes={{id=3}}}}}
  agree_and_maybe_merge(parameters, sfi_1, sfi_2)
  assert_eq(sfi_1, {feature='rp', depth=1, head={depth=1, features={rp=1},
                                                 morphemes={{id=3}}}})
  assert_eq(sfi_2, {feature='rp', depth=2,
                    head={depth=2, features={rp=1}, morphemes={{id=2}},
                          maximal={depth=1, moved_to=sfi_1.head, features={},
                                   morphemes={{id=3}}}}})
end

--[[
Determines whether a constituent should lower to another.

Lowering should happen if and only if the constituents share a feature
value for a feature which causes lowering in this lect.

Args:
  f1: The feature map of one constituent.
  f2: The feature map of the other constituent.
  parameters: A language parameter table.

Returns:
  Whether the constituents of which `f1` and `f2` are the feature maps
    should participate in lowering with each other.
]]
local function should_lower(f1, f2, parameters)
  for f, v in pairs(f1) do
    if v == f2[f] then
      local strategy = parameters.strategies[f]
      if strategy and strategy.lower then
        return true
      end
    end
  end
  return false
end

--[=[
Lowers subconstituents as appropriate.

Given the structure [AP a [BP b [CP c]]] where all the heads share a
feature value for a lowering feature, a moves to b, and then b moves to
c. This is not realistic, but such a structure is unlikely, so this is
acceptable.

Args:
  constituent! A constituent.
  parameters: A language parameter table.

Returns:
  `constituent`.
]=]
local function do_lowering(constituent, parameters)
  local mother
  local nh
  local nc
  local function do_lowering(constituent)
    if constituent.moved_to and not parameters.overt_trace then
    elseif not constituent.n1 then
      if mother then-- and mother[nc] == constituent.maximal then
        if should_lower(constituent.features, mother[nh].features, parameters)
        then
          merge_constituents(constituent, mother[nh])
        end
        mother = nil
      end
    elseif (constituent.n1 and constituent.n2 and
            ((not constituent.n1.n1) or (not constituent.n2.n1)) and
            (constituent.n1.is_phrase or constituent.n2.is_phrase)) then
      local lnh, lnc = 'n1', 'n2'
      if constituent[lnh].is_phrase then
        lnh, lnc = lnc, lnh
      end
      if mother then
        do_lowering(constituent[lnh])
      end
      mother = constituent
      nh, nc = lnh, lnc
      do_lowering(constituent[lnc])
    else
      if constituent.n1 then
        do_lowering(constituent.n1)
      end
      if constituent.n2 then
        do_lowering(constituent.n2)
      end
    end
    return constituent
  end
  return do_lowering(constituent)
end

if TEST then
  local a = x{f={f=1}}
  local b = x{f={f=1}}
  local c = x{f={f=1}}
  local l = do_lowering(xp{a, xp{b, xp{c}}}, {strategies={f={lower=true}}})
  assert_eq(l, xp{
                 x{f={f=1}, moved_to=l.n2.n1},
                 xp{
                   x{f={f=1}, moved_to=l.n2.n2.n1},
                   xp{
                     x{f={f=1}}}}})
end

--[[
Looks up a constituent by key in the lexicon of a lect.

If the constituent is not in the lexicon, it recursively looks it up in
the lect's parent, if any.

Args:
  lect: A lect.
  ref: A constituent key.

Returns:
  The constituent corresponding to the given key in the given lect, or
    nil if there is none.
]]
local function resolve_lexeme(lect, ref)
  if lect then
    return lect.constituents[ref] or resolve_lexeme(lect.parent, ref)
  end
end

--[[
Does syntax, not including lowering or anything after.

Syntax involves expanding references to items in the lexicon, checking
syntactic features, and merging constituents by raising.

Args:
  constituent! A constituent.
  lect: A lect.
  parameters: A language parameter table.

Returns:
  `constituent`.
]]
local function do_syntax(constituent, lect, parameters)
  local do_syntax
  local function extend_sfis(constituent, n, depth, sfis, maximal)
    local sfis_n = {}
    constituent[n] = do_syntax(constituent[n], depth + 1, sfis_n, maximal)
    for _, sfi in ipairs(sfis_n) do
      sfis[#sfis + 1] = sfi
    end
    return sfis_n
  end
  do_syntax = function(constituent, depth, sfis, maximal)
    constituent.depth = depth
    if constituent.is_phrase then
      maximal = constituent
    end
    if constituent.n1 then
      local sfis_1 = extend_sfis(constituent, 'n1', depth, sfis, maximal)
      if constituent.n2 then
        local sfis_2 = extend_sfis(constituent, 'n2', depth, sfis, maximal)
        utils.sort_vector(sfis, nil, compare_sfis(parameters))
        agree_and_maybe_merge(parameters, get_best_sfis(sfis_1, sfis_2))
      end
      -- TODO: don't duplicate code! (from later in this same function)
      for feature, value in pairs(constituent.features) do
        sfis[#sfis + 1] = {depth=depth, head=constituent, feature=feature}
      end
    else
      local replacement = resolve_lexeme(lect, constituent.ref)
      if replacement then
        replacement = copy_constituent(replacement, constituent.args)
        if constituent.features then
          utils.fillTable(replacement.features, constituent.features)
        end
        return do_syntax(replacement, depth, sfis, maximal)
      elseif constituent.ref then
        dfhack.color(COLOR_YELLOW)
        print('No constituent with ID ' .. constituent.ref)
        dfhack.color()
      elseif not constituent.text then
        constituent.maximal = maximal
        for _, morpheme in ipairs(constituent.morphemes) do
          -- TODO: Which should take precedence, constituent's or morpheme's?
          utils.fillTable(constituent.features, morpheme.features)
        end
        for feature, value in pairs(constituent.features) do
          sfis[#sfis + 1] = {depth=depth, head=constituent, feature=feature}
        end
      end
    end
    return constituent
  end
  return do_syntax(constituent, 0, {})
end

--[[
Linearizes a constituent.

A linearization is the sequence of the mwords of the heads dominated by
a constituent in breadth-first order. If a constituent has two children,
the second is linearized first if the `swap` parameter is set, and the
two linearizations are dislocated around each other.

Args:
  constituent: A constituent.
  parameters: A language parameter table.

Returns:
  The linearization of the constituent as a sequence of utterables. If
    `constituent` is nil, the sequence is empty.
]]
local function linearize(constituent, parameters)
  if (not constituent or
      (constituent.moved_to and not parameters.overt_trace)) then
    return {}
  end
  constituent = copy_constituent(constituent)
  for i, morpheme in ipairs(constituent.morphemes) do
    utils.fillTable(morpheme.features, constituent.features)
  end
  if constituent.text then
    return {constituent.text}
  elseif not constituent.n1 then
    return {constituent.morphemes}
  end
  local n1, n2 = 'n1', 'n2'
  if parameters.swap then
    n1, n2 = n2, n1
  end
  return dislocate(linearize(constituent[n1], parameters),
                   linearize(constituent[n2], parameters))
end

if TEST then
  local n1 = x{f={f=1, g=2}, m={m(1), m(2)}}
  local constituent = x{n1,
                        x{x{m={m(3)}},
                          x{f={g=2}, m={m(2)}, moved_to=n1}}}
  assert_eq(linearize(constituent, {}),
            {{m{1, 1, features={f=1, g=2}}, m{2, 2, features={f=1, g=2}}},
             {m{3, 3}}})
  assert_eq(linearize(constituent, {overt_trace=true}),
            {{m{1, 1, features={f=1, g=2}}, m{2, 2, features={f=1, g=2}}},
             {m{3, 3}}, {m{2, 2, features={g=2}}}})
  assert_eq(linearize(constituent, {swap=true}),
            {{m{3, 3}},
             {m{1, 1, features={f=1, g=2}}, m{2, 2, features={f=1, g=2}}}})
  assert_eq(linearize(constituent, {overt_trace=true, swap=true}),
            {{m{2, 2, features={g=2}}}, {m{3, 3}},
             {m{1, 1, features={f=1, g=2}}, m{2, 2, features={f=1, g=2}}}})
  assert_eq(linearize(x{x{m={m{'que', affix=true, initial=true, after=true}}},
                        x{m={m{'populus'}}}}, {}),
            {{m{'populus'},
              m{'que', affix=true, initial=true, after=true}}})
end

--[[
Fuses two morphemes in a sequence.

It tries to fuse `morphemes[i]` and `morphemes[i + 1]`, where both of
those indices are valid. If it fuses, both morphemes are replaced with
the new fused morpheme in the same place in the sequence.

Args:
  morphemes! A sequence of morphemes.
  i: The index in `morphemes` of the first morpheme to fuse.

Returns:
  Whether the morphemes were fused.
]]
local function fuse(morphemes, i)
  local m1 = morphemes[i]
  local m2 = morphemes[i + 1]
  local fused = m1.fusion[m2.id]
  if fused then
    morphemes[i] = fused
    table.remove(morphemes, i + 1)
  end
  return fused
end

if TEST then
  local m3 = {id=3, fusion={}}
  local m4 = {id=4, fusion={}}
  local morphemes =
    {{id=1, fusion={}},
     {id=2, fusion={[3]={id=5, fusion={[4]={id=6, fusion={}}}}}}, m3, m4}
  assert_eq(not fuse(morphemes, 1), true)
  assert_eq(morphemes,
            {{id=1, fusion={}},
             {id=2, fusion={[3]={id=5, fusion={[4]={id=6, fusion={}}}}}}, m3,
             m4})
  assert_eq(not fuse(morphemes, 2), false)
  assert_eq(morphemes,
            {{id=1, fusion={}}, {id=5, fusion={[4]={id=6, fusion={}}}}, m4})
end

--[[
Rearranges the morphemes of an mword with fusion.

The output sequence is the final phonological form of the mword, except
for dummy support.

Args:
  mword! An mword.

Returns:
  `mword`.
]]
local function do_fusion(mword)
  local i = 1
  while i < #mword do
    if fuse(mword, i) then
      if mword[i].affix then
        table.remove(mword, i)
        if morpheme[i].after then
          table.insert(mword, morpheme)
        else
          table.insert(mword, 1, morpheme)
          i = 1
        end
      end
    else
      i = i + 1
    end
  end
  return mword
end

if TEST then
  local will = {id='will', fusion={}}
  local past = {id='PAST', fusion={}}
  local went = {id='went', fusion={}}
  local go = {id='go', fusion={PAST=went}}
  local mword = {will, go}
  do_fusion(mword)
  assert_eq(mword, {will, go})
  mword = {go, past}
  do_fusion(mword)
  assert_eq(mword, {went})
end

--[[
Provides an mword with dummy support if necessary and possible.

Args:
  mword: An mword.

Returns:
  If `mword` has a free morpheme, `mword`; if not, `mword` with dummy
    support for one of the morphemes; if no morpheme has a dummy,
    `mword`.
]]
local function insert_dummy(mword)
  local dummy
  for _, morpheme in ipairs(mword) do
    if morpheme.affix then
      dummy = dummy or morpheme.dummy
    else
      return mword
    end
  end
  if dummy then
    -- TODO: This is pointless. What was the intent?
    for f, v in pairs(dummy.features) do
      dummy.features[f] = v
    end
  end
  return dummy and dislocate(mword, {dummy}, true) or mword
end

if TEST then
  local do_ = {id='do', features={}}
  local past = {id='PAST', features={}, affix=true, after=true, dummy=do_}
  assert_eq(insert_dummy({{id='go'}, past}), {{id='go'}, past})
  assert_eq(insert_dummy({past}), {do_, past})
end

--[[
Converts a constituent to a sequence of mwords.

Args:
  constituent! A constituent.
  lect: A lect.
  parameters: A language parameter table.

Returns:
  A sequence of utterables.
]]
local function make_utterance(constituent, lect, parameters)
  local utterables = {}
  for _, utterable in ipairs(linearize(do_lowering(
    do_syntax(constituent, lect, parameters), parameters), parameters))
  do
    if type(utterable) == 'table' then
      local new_mword = utterable
      repeat
        utterable = do_fusion(new_mword)
        new_mword = insert_dummy(utterable)
      until new_mword == utterable
    end
    utterables[#utterables + 1] = utterable
  end
  return utterables
end

--[[
Gets the string representation of a morpheme.

Args:
  morpheme: A morpheme.

Returns:
  The string representation of `morpheme`.
]]
local function spell_morpheme(morpheme)
  if morpheme.text then
    return morpheme.text
  else
    -- TODO
    local s = '[' .. tostring(morpheme.id or '?')
    for f, v in pairs(morpheme.features) do
      s = s .. ',' .. tostring(f)
      if v == false then
        s = s .. '*'
      elseif v ~= true then
        s = s .. '=' .. tostring(v)
      end
    end
    return s .. ']'
  end
end

--[[
Gets the string representation of a sequence of mwords.

Every mword has a space after it, except those without morphemes.

Args:
  utterance: A sequence of mwords.

Returns:
  The string representation of `utterance`.
]]
local function spell_utterance(utterance)
  local s = ''
  for _, mword in ipairs(utterance) do
    for i, morpheme in ipairs(mword) do
      if i ~= 1 then
        s = s .. '-'
      end
      s = s .. spell_morpheme(morpheme)
    end
    if next(mword) then
      s = s .. ' '
    end
  end
  return s
end

if TEST and TODO then
  assert_eq(
    spell_utterance(make_utterance(
      {features={}, morphemes={{text='a', pword={}, fusion={}, features={}},
                               {text='b', pword={}, fusion={}, features={}}}},
      {constituents={}}, {strategies={}})),
    'a-b ')
  assert_eq(
    spell_utterance(make_utterance(
      x{x{m={m{[2]='a'}}},
        x{m={m{[2]='b'}}}},
      {constituents={}}, {strategies={}})),
    'a b ')
  assert_eq(
    spell_utterance(make_utterance(
       x{x{m={m{[2]='a'}}},
         x{m={m{[2]='b'}}}},
      {constituents={}}, {strategies={}, swap=true})),
    'b a ')
  assert_eq(
    spell_utterance(make_utterance(
      x{r'X', x{m={m{[2]='b'}}}},
      {constituents={X=r'Y', Y=x{m={m{[2]='z'}}}}},
      {strategies={}})),
    'z b ')
  local n1 = x{f={f=1, g=2}, m={m{[2]='1'}, m{[2]='2'}}}
  local constituent =
    x{n1,
      x{x{m={m{[2]='3'}}},
        x{f={g=2}, m={m{[2]='4'}}, moved_to=n1}}}
  assert_eq(spell_utterance(make_utterance(constituent, {constituents={}},
                                           {strategies={}})),
            '1-2 3 ')
  assert_eq(spell_utterance(make_utterance(constituent, {constituents={}},
                                           {strategies={}, overt_trace=true})),
            '1-2 3 4 ')
  local q_sent =
    x{
      x{f={Case='Nom'}},
      x{
        r'foo',
        xp{
          f={Case=false},
          x{r'bar', r'baz'}
        }
      }
    }
  local q_lect = {constituents={
      foo=x{m={m{'foo'}}},
      bar=x{m={m{'bar'}}},
      baz=x{m={m{'baz'}}}
    },
  }
  local q_params = {strategies={}}
  assert_eq(spell_utterance(make_utterance(q_sent, q_lect, q_params)),
            '[foo] [bar,Case=Nom] [baz,Case=Nom] ')
  local en_past = {features={}}
  local en_not = {
    features={}, morphemes={{
      id='not', text='not', pword={}, fusion={}, features={}
    }}
  }
  local en_walk =
    {features={}, morphemes={m{'walk', 'walk', features={v=true}}}}
  local en_do =
    {morphemes={{id='do', text='do', pword={}, features={v=true},
                 fusion={PAST={id='do.PAST', text='did', pword={}, fusion={},
                               features={v=true}}}}},
     features={}}
  en_past.morphemes = {{
    id='PAST', text='ed', pword={}, fusion={}, features={v=false, q=false},
    affix=true, after=true, dummy=en_do.morphemes[1],
  }}
  local en_you = {morphemes={m'you'}, features={}}
  local en_what = {features={}, morphemes={{id='what', text='what', pword={},
                                            features={wh=true}, fusion={}}}}
  local en_thing = {features={}, morphemes={m'thing'}}
  local en_lect =
    {constituents={PAST=en_past, ['not']=en_not, walk=en_walk, you=en_you,
                   what=en_what, thing=en_thing, ['do']=en_do}}
  local en_parameters =
    {strategies={v={lower=true}, wh={pied_piping=true}, q={}, d={}}}
  local early_en_parameters = {strategies={v={}}}
  assert_eq(spell_utterance(make_utterance(xp{r'PAST', xp{x{r'walk'}}},
                                           en_lect, en_parameters)),
            'walk-ed ')
  local en_did_not_walk = xp{r'PAST', xp{r'not', xp{r'walk'}}}
  assert_eq(spell_utterance(make_utterance(en_did_not_walk, en_lect,
                                           en_parameters)),
            'did not walk ')
  assert_eq(spell_utterance(make_utterance(en_did_not_walk, en_lect,
                                           early_en_parameters)),
            'walk-ed not ')
  local en_what_thing_did_you_do =
    xp{x{f={wh=false}},
       x{x{f={q=true}},
         x{r'PAST',
           x{r'you',
             x{r'do',
               xp{r'what',
                  r'thing'}}}}}}
  assert_eq(spell_utterance(make_utterance(en_what_thing_did_you_do,
                                           en_lect, en_parameters)),
            'what thing did you do ')
  local en_you_did_thing =
    xp{
      x{},
      x{
        x{},
        xp{
          x{f={d=false}},
          x{
            r'PAST',
            xp{
              xp{r{d=true}'you'},
              x{
                r'do',
                xp{
                   x{},
                   r'thing'}}}}}}}
  assert_eq(spell_utterance(make_utterance(en_you_did_thing, en_lect,
                                           en_parameters)),
            'you did thing ')
  local fr_lect = {constituents={
      beau=x{f={gender=false}, m={m{'beau'}}},
      vieux=x{f={gender=false}, m={m{'vieux'}}},
      femme=x{f={gender='FEM'}, m={m{'femme'}}},
    },
  }
  local fr_parameters = {strategies={gender=nil}}
  -- TODO: add example here with "la" to test that agreement works downward too
  local fr_belle_vieille_femme = ps.xp{
    false,
    r'beau',
    r'vieux',
    r'femme',
  }
  assert_eq(spell_utterance(make_utterance(fr_belle_vieille_femme, fr_lect,
                                           fr_parameters)),
            '[beau,gender=FEM] [vieux,gender=FEM] [femme,gender=FEM] ')
end

--[[
Translates an utterance into a lect.

Args:
  lect: The lect to translate into, or nil to skip translation.
  should_abort: Whether to abort the conversation.
  topic: A `talk_choice_type`.
  topic1: An integer whose exact interpretation depends on `topic`.
  topic2: Ditto.
  topic3: Ditto.
  topic4: Ditto.
  english: The English text of the utterance.
  speakers: The speaker of the report as a unit.
  hearers: The hearers of the report as a sequence of units.

Returns:
  The text of the translated utterance.
]]
local function translate(lect, should_abort, topic, topic1, topic2, topic3,
                         topic4, english, speaker, hearers)
  print('translate ' .. tostring(lect) .. ' ' .. tostring(should_abort) .. ' [' .. tostring(topic) .. ',' .. tostring(topic1) .. ',' .. tostring(topic2) .. ',' .. tostring(topic3) .. ',' .. tostring(topic4) .. '] '.. english)
  if not lect then
    return english
  end
  local constituent = contextualize(get_constituent(
    should_abort, topic, topic1, topic2, topic3, topic4, english, speaker,
    hearers))
  local utterables = make_utterance(constituent, lect, get_parameters(lect))
  return transcribe(utterables, lect.phonology)
end

--[[
Gets a civilization's native lect.

Args:
  civ: A historical entity, or nil.

Returns:
  A lect, or nil if there is none or `civ` is nil.
]]
local function get_civ_native_lect(civ)
  print('civ native lect: civ.id=' .. (civ and civ.id or 'nil'))
  if civ then
    print('      ' .. #lects)
    local _, lect = utils.linear_index(lects, civ, 'community')
    if HACK_FOR_QUICK_TEST and not lect then
      return lects[1]
    end
    return lect
  end
end

--[[
This sequence of constituent keys must be a superset of all the
constituent keys mentioned in `get_constituent` or in context callbacks
mentioned therein.
]]
local DEFAULT_CONSTITUENT_KEYS = {
  '!',
  '-ly',
  '...',
  '0,D',
  '0,N',
  '?!',
  '?',
  '??',
  'FUTURE',
  'HORTATIVE',
  'IMPERATIVE',
  'INFINITIVE',
  'PASSIVE',
  'PAST',
  'PAST_PARTICIPLE',
  'PERFECT',
  'POS',
  'PRESENT',
  'PRESENT_PARTICIPLE',
  'PROGRESSIVE',
  'PRONOUN',
  'SENTENCE SEPARATOR',
  'SENTENCE_SEPARATOR',
  'a',
  'able',
  'about',
  'accept',
  'accompany',
  'actually',
  'admirable',
  'adoration',
  'affectionate',
  'agitating',
  'agony',
  'agree',
  'ah (fear)',
  'ah (shock)',
  'alienated',
  'all around',
  'all',
  'amazing',
  'amusing',
  'and if so then',
  'and',
  'angry',
  'anguish',
  'anguished',
  'annoyed',
  'annoying',
  'anxious',
  'any',
  'area',
  'argument',
  'aroused',
  'arranged',
  'as',
  'astonishing',
  'at',
  'attack',
  'awake',
  'awe-struck',
  'baby',
  'battle',
  'be',
  'behold',
  'being',
  'believe',
  'best',
  'bitter',
  'blight',
  'bliss',
  'blissful',
  'blizzard',
  'blood',
  'body',
  'boring',
  'break,V',
  'brief',
  'bring',
  'but',
  'by',
  'call',
  'can',
  'can,X',
  'care',
  'cause to be',
  'child of the night',
  'child',
  'clothing',
  'come apart',
  'come',
  'complete',
  'concur',
  'confinement',
  'conflict',
  'confused',
  'contempt',
  'content',
  'core',
  'could',
  'dead',
  'death',
  'deceased',
  'defeated',
  'dejected',
  'delightful',
  'describe',
  'despair',
  'disappointment',
  'disaster',
  'disgusting',
  'dislike',
  'displeased',
  'disposal',
  'disposed',
  'divine',
  'do',
  'doubt',
  'drink,V',
  'drop',
  'easy',
  'eek',
  'embarrassing',
  'end,V',
  'enjoyable',
  'euphoric',
  'ever',
  'everything',
  'exhilarating',
  'fall for',
  'family',
  'fear',
  'fear,V',
  'feed',
  'feel condition',
  'feel emotion',
  'fight',
  'fighting',
  'fleeting',
  'for the best',
  'for',
  'fragile',
  'free',
  'frustrating',
  'get away from',
  'get into situation',
  'ghost',
  'glum',
  'good',
  'good,MN',
  'goodbye',
  'grave,J',
  'greetings',
  'gruesome',
  'guilty',
  'haha',
  'hall',
  'happen',
  'hate',
  'have (experience)',
  'have',
  'hello',
  'help',
  'helpless',
  'here',
  'hey',
  'honor',
  'horror',
  'how',
  'improve',
  'in tatters',
  'in way',
  'in',
  'incredible',
  'indeed',
  'inevitable',
  'injure',
  'injury',
  'intense',
  'interesting',
  'intruder',
  'irritating',
  'isolated',
  'it',
  'join',
  'joyous',
  'just',
  'keep,N',
  'know',
  'left-hand',
  'legend',
  'less',
  'library',
  'life (in general)',
  'life',
  'living',
  'long',
  'look like',
  'lose',
  'love,N',
  'made by entity',
  'made of material',
  'master,V',
  'masterpiece',
  'means',
  'midst',
  'mighty',
  'moment',
  'mortal,N',
  'much',
  'must',
  'naive',
  'name,V',
  'nauseate',
  'near',
  'need',
  'no',
  'no,DET',
  'none',
  'not',
  'nuance',
  'occasion',
  'of',
  'off',
  'oh',
  'okay',
  'old',
  'on',
  'one way or another',
  'or',
  'order (noun)',
  'order,N',
  'other',
  'otherwise',
  'out in',
  'over my dead body',
  'overwhelm',
  'overwhelming',
  'own',
  'pain',
  'palpable',
  'parent',
  'part',
  'passive',
  'patient',
  'patrol',
  'pay',
  'pet',
  'pleasurable',
  'pointless',
  'prey',
  'problem',
  'quick',
  'rage,V',
  'rain,N',
  'rain,V',
  'rawr',
  'ready',
  'really',
  'rejected',
  'release',
  'restless',
  'reunite',
  'right',
  'right-hand',
  'rot,V',
  'sad but not unexpected',
  'sad',
  'safety',
  'salutations',
  'same',
  'satisfying',
  'save',
  'scarcely',
  'separate',
  'session',
  'shall',
  'should',
  'skulk',
  'slay',
  'snow storm',
  'snow,V',
  'so',
  'somebody',
  'something',
  'somewhat',
  'sorry',
  'sound like',
  'sparring',
  'spouse',
  'stand by',
  'stand',
  'stop',
  'strike',
  'such',
  'sun',
  'suspicious',
  'sweet',
  'tear',
  'tell about',
  'temple',
  'terrible',
  'terribly',
  'terrific',
  'terrifying',
  'that',
  'that,C',
  'the',
  'there',
  'thing',
  'this',
  'throw',
  'tide',
  'time (delimited)',
  'to',
  'together with',
  'too much',
  'trade',
  'trade,V',
  'troublemaker',
  'true',
  'turn,V',
  'uh (shock)',
  'uneasy',
  'unexpected',
  'up to',
  'value',
  'very',
  'wa',
  'warrior',
  'way',
  'we (in general)',
  'weapon',
  'wear',
  'what',
  'where',
  'which',
  'who',
  'why',
  'with',
  'withdraw',
  'within time span',
  'world',
  'worthlessness',
  'would',
  'wound',
  'wound,V',
  'wow',
  'wrack',
  'wronged',
  'yield',
}

if TEST then
  local own_path
  for path, script in pairs(dfhack.internal.scripts) do
    if script.env == _ENV then
      own_path = path
      break
    end
  end
  if own_path then
    local file = io.open(own_path)
    local code = file:read('*all')
    file:close()
    local keys = {}
    for key in code:gmatch("%f[%w\\][kt_][%s(]*('[^'\n]*')") do
      keys[key] = true
    end
    for key in code:gmatch("%f[%w\\][kt_][%s(]*%b{}[%s(]*('[^'\n]*')") do
      keys[key] = true
    end
    local missing_keys = ''
    for key in pairs(keys) do
      key = load('return ' .. key)()
      if key and not utils.linear_index(DEFAULT_CONSTITUENT_KEYS, key) then
        missing_keys = missing_keys .. '\n' .. key
      end
    end
    if missing_keys ~= '' then
      qerror('Missing constituent keys:' .. missing_keys)
    end
  else
    qerror('Cannot find the path to this script')
  end
end

--[[
Creates a word, setting its flags and adding it to each translation.

The entry added to each translation is the empty string. The point is to
maintain the invariant that every translation has one entry per word.
Other functions can be called after this one if the entry should not be
empty.

Args:
  _1: Ignored.
  _2: Ignored.
  word_id: The ID of the new word.
  noun_sing: The singular noun form of the word in English, or nil, '',
    'n/a', or 'none' if this word cannot be used as a singular noun.
  noun_plur: The plural noun form of the word in English, or 'STP' if
    the plural form is `noun_sing .. 's'`, or nil, '', or 'NP' if this
    word cannot be used as a plural noun.
  adj: The adjective form of the word in English, or nil, '', 'n/a', or
    'none' if this word cannot be used as an adjective.
  of_noun_sing: Whether the singular noun works in English as the object
    of the preposition "of" without a determiner.
]]
local function create_word(_1, _2,
                           word_id, noun_sing, noun_plur, adj, of_noun_sing)
  local words = df.global.world.raws.language.words
  words:insert('#', {new=true, word=word_id})
  local word = words[#words - 1]
  local str = word.str
  local has_noun_sing = false
  local has_noun_plur = false
  local noun_str
  if noun_sing and noun_sing ~= '' and noun_sing ~= 'n/a' and
    noun_sing ~= 'none'
  then
    has_noun_sing = true
  end
  if noun_plur and noun_plur ~= '' and noun_plur ~= 'NP' then
    has_noun_plur = true
  end
  if has_noun_sing or has_noun_plur then
    noun_str = '[NOUN'
  end
  if has_noun_sing then
    noun_str = noun_str .. ':' .. noun_sing
    word.forms.Noun = noun_sing
    word.flags.front_compound_noun_sing = true
    word.flags.rear_compound_noun_sing = true
    word.flags.the_noun_sing = true
    word.flags.the_compound_noun_sing = true
    str:insert('#', {new=true, value='[FRONT_COMPOUND_NOUN_SING]'})
    str:insert('#', {new=true, value='[REAR_COMPOUND_NOUN_SING]'})
    str:insert('#', {new=true, value='[THE_NOUN_SING]'})
    str:insert('#', {new=true, value='[THE_COMPOUND_NOUN_SING]'})
    if of_noun_sing then
      word.flags.of_noun_sing = true
      str:insert('#', {new=true, value='[OF_NOUN_SING]'})
    end
  end
  if has_noun_plur then
    if noun_plur == 'STP' then
      noun_plur = noun_sing .. 's'
    end
    noun_str = noun_str .. ':' .. noun_plur
    word.forms.NounPlural = noun_plur
    word.flags.front_compound_noun_plur = true
    word.flags.rear_compound_noun_plur = true
    word.flags.the_noun_plur = true
    word.flags.the_compound_noun_plur = true
    word.flags.of_noun_plur = true
    str:insert('#', {new=true, value='[FRONT_COMPOUND_NOUN_PLUR]'})
    str:insert('#', {new=true, value='[REAR_COMPOUND_NOUN_PLUR]'})
    str:insert('#', {new=true, value='[THE_NOUN_PLUR]'})
    str:insert('#', {new=true, value='[THE_COMPOUND_NOUN_PLUR]'})
    str:insert('#', {new=true, value='[OF_NOUN_PLUR]'})
  end
  if noun_str then
    str:insert('#', {new=true, value=noun_str .. ']'})
  end
  if adj and adj ~= '' and adj ~= 'n/a' and adj ~= 'none' then
    word.forms.Adjective = adj
    word.flags.front_compound_adj = true
    word.flags.rear_compound_adj = true
    word.flags.the_compound_adj = true
    str:insert('#', {new=true, value='[ADJ:' .. adj .. ']'})
    str:insert('#', {new=true, value='[FRONT_COMPOUND_ADJ]'})
    str:insert('#', {new=true, value='[REAR_COMPOUND_ADJ]'})
    str:insert('#', {new=true, value='[THE_COMPOUND_ADJ]'})
    str:insert('#', {new=true, value='[ADJ_DIST:4]'})
  end
  for _,  translation in ipairs(df.global.world.raws.language.translations) do
    translation.words:insert('#', {new=true})
  end
end

--[[
Creates a new word for a lect, if appropriate for its speech community.

Args:
  lect! A lect.
  resource_id: An ID of the referent of the word.
  resource_functions: A sequence of functions, each of which takes a
    speech community and returns a list of values. If any of the
    returned values of one of these functions given `lect.community` is
    `resource_id`, the word is appropriate for `lect.community` and a
    new word is added to the lect.
  word_id: The ID of the new word.
]]
local function add_word_to_lect(lect, resource_id, resource_functions, word_id)
  for _, f in ipairs(resource_functions) do
    if utils.linear_index(f(lect.community), resource_id) then
      local _, _, lemma = random_word(lect, word_id)
      print('civ ' .. lect.community.id, resource_id, word_id, lemma)
      lect.lemmas.words[utils.linear_index(
        df.global.world.raws.language.words, word_id, 'word')].value =
        escape(lemma)
      return
    end
  end
end

--[[
Gets the state of a material at standard ambient temperature.

Args:
  material: A material.

Returns:
  A `df.matter_state`.
]]
local function get_state_at_usual_temperature(material)
  local melting_point = material.heat.melting_point
  local boiling_point = material.heat.boiling_point
  if melting_point == NO_TEMPERATURE or boiling_point == NO_TEMPERATURE then
    if not material.state_name.Solid:find('%f[^\0 ]frozen ') then
      return df.matter_state.Solid
    elseif not material.state_name.Gas:find('%f[^\0 ]boiling ') then
      return df.matter_state.Gas
    end
    return df.matter_state.Liquid
  end
  local temperature = material.heat.mat_fixed_temp
  if temperature == NO_TEMPERATURE then
    temperature = STANDARD_AMBIENT_TEMPERATURE
  end
  if temperature >= boiling_point then
    return df.matter_state.Gas
  elseif temperature >= melting_point then
    return df.matter_state.Liquid
  end
  return df.matter_state.Solid
end

--[[
Calls a function for everything that a lect might have a word for.

Args:
  f: A function which takes:
    resource_id: See `add_word_to_lect`.
    resource_functions: Ditto.
    word_id: The ID of the word.
    noun_sing: See `create_word`.
    noun_plur: Ditto.
    adj: Ditto.
    of_noun_sing: Ditto.
    Any of these arguments can be ignored.
]]
local function expand_lexicons(f)
  local raws = df.global.world.raws
  local universal = {function(civ) return {0} end}
  for _, topic in pairs(DEFAULT_CONSTITUENT_KEYS) do
    f(0, universal, WORD_ID_CHAR .. topic)
  end
  --[[
  for _, topic in ipairs(df.talk_choice_type) do
    if topic then
      f(0, universal, WORD_ID_CHAR .. topic)
    end
  end
  ]]
  for _, item_type in ipairs(df.item_type) do
    -- This overgenerates but is necessary for items without subtypes.
    -- TODO: Use is_rawable, if reliable, to decide which ones need this.
    local classname = df.item_type.attrs[item_type].classname
    if classname then
      f(0, universal, 'ITEM_TYPE' .. WORD_ID_CHAR .. classname)
    end
  end
  for _, slab_type in ipairs(df.slab_engraving_type) do
    f(0, universal, 'item_slabst' .. WORD_ID_CHAR .. slab_type)
  end
  for _, building_type in ipairs(df.building_type) do
    f(0, universal, 'building_type' .. WORD_ID_CHAR .. building_type)
  end
  for _, job_skill in ipairs(df.job_skill) do
    f(0, universal, 'job_skill' .. WORD_ID_CHAR .. job_skill)
  end
  for _, unit_relationship_type in ipairs(df.unit_relationship_type) do
    f(0, universal,
      'unit_relationship_type' .. WORD_ID_CHAR .. unit_relationship_type)
  end
  for i, builtin in ipairs(df.builtin_mats) do
    -- TODO: coke vs charcoal
    local material = raws.mat_table.builtin[i]
    local state = get_state_at_usual_temperature(material)
    f(0,
      universal,
      'builtin' .. WORD_ID_CHAR .. builtin,
      material.state_name[state],
      nil,
      material.state_adj[state],
      true)
  end
  for i, inorganic in ipairs(raws.inorganics) do
    local state = get_state_at_usual_temperature(inorganic.material)
    f(i,
      {
        function(civ) return civ.resources.metals end,
        function(civ) return civ.resources.stones end,
        function(civ) return civ.resources.gems end,
      },
      'inorganic' .. WORD_ID_CHAR .. inorganic.id .. WORD_ID_CHAR,
      inorganic.material.state_name[state],
      nil,
      inorganic.material.state_adj[state],
      true)
  end
  local plant_resource_functions = {
    function(civ) return civ.resources.tree_fruit_plants end,
    function(civ) return civ.resources.shrub_fruit_plants end,
    function(civ) return civ.resources.discovered_plants end,
  }
  for _, plant in ipairs(raws.plants.all) do
    f(plant.anon_1,
      plant_resource_functions,
      'plant' .. WORD_ID_CHAR .. plant.id,
      plant.name,
      plant.name_plural,
      plant.adj)
    for _, material in ipairs(plant.material) do
      local state = get_state_at_usual_temperature(material)
      local prefix = material.prefix
      if prefix ~= '' then
        prefix = prefix .. ' '
      end
      f(plant.anon_1,
        plant_resource_functions,
        -- TODO: What if plant.id contains WORD_ID_CHAR? Ditto creatures m.m.
        'plant' .. WORD_ID_CHAR .. plant.id .. WORD_ID_CHAR .. material.id,
        prefix .. material.state_name[state],
        nil,
        prefix .. material.state_adj[state],
        true)
    end
  end
  --[[
  for _, tissue in ipairs(raws.tissue_templates) do
    f(0,
      universal,
      'TISSUE_TEMPLATE' .. WORD_ID_CHAR .. tissue.id,
      tissue.tissue_name_singular,
      tissue.tissue_name_plural,
      nil,
      tissue.tissue_name_plural ~= 'NP')
  end
  ]]
  local creature_resource_functions = {
    function(civ) return {civ.race} end,
    function(civ) return civ.resources.fish_races end,
    function(civ) return civ.resources.fish_races end,
    function(civ) return civ.resources.egg_races end,
    function(civ) return civ.resources.animals.pet_races end,
    function(civ) return civ.resources.animals.wagon_races end,
    function(civ) return civ.resources.animals.pack_animal_races end,
    function(civ) return civ.resources.animals.wagon_puller_races end,
    function(civ) return civ.resources.animals.mount_races end,
    function(civ) return civ.resources.animals.minion_races end,
    function(civ) return civ.resources.animals.exotic_pet_races end,
    function(civ) return civ.resources.discovered_creatures end,
  }
  for i, creature in ipairs(raws.creatures.all) do
    f(i,
      creature_resource_functions,
      'creature' .. WORD_ID_CHAR .. creature.creature_id,
      creature.name[0],
      creature.name[1],
      creature.name[2])
    --[[
    TODO: Commented out temporarily because it is so slow.
    for _, material in ipairs(creature.material) do
      local state = get_state_at_usual_temperature(material)
      local prefix = material.prefix
      if prefix ~= '' then
        prefix = prefix .. ' '
      end
      f(i,
        creature_resource_functions,
        'creature' .. WORD_ID_CHAR .. creature.creature_id .. WORD_ID_CHAR ..
        material.id,
        prefix .. material.state_name[state],
        nil,
        prefix .. material.state_adj[state],
        true)
    end
    ]]
  end
  --[[
  for _, food in ipairs(raws.itemdefs.food) do
    f(?, ?, 'item_foodst' .. WORD_ID_CHAR .. food.id, food.name, '', '')
  end
  ]]
  for _, instrument in ipairs(raws.itemdefs.instruments) do
    f(instrument.subtype,
      {function(civ) return civ.resources.instrument_type end},
      'item_instrumentst' .. WORD_ID_CHAR .. instrument.id,
      instrument.name,
      instrument.name_plural)
  end
  for _, toy in ipairs(raws.itemdefs.toys) do
    f(toy.subtype,
      {function(civ) return civ.resources.toy_type end},
      'item_toyst' .. WORD_ID_CHAR .. toy.id,
      toy.name,
      toy.name_plural)
  end
  for _, armor in ipairs(raws.itemdefs.armor) do
    f(armor.subtype,
      {function(civ) return civ.resources.armor_type end},
      'item_armorst' .. WORD_ID_CHAR .. armor.id,
      armor.name,
      armor.name_plural)
  end
  for _, shoe in ipairs(raws.itemdefs.shoes) do
    f(shoe.subtype,
      {function(civ) return civ.resources.shoes_type end},
      'item_shoesst' .. WORD_ID_CHAR .. shoe.id,
      shoe.name,
      shoe.name_plural)
  end
  for _, shield in ipairs(raws.itemdefs.shields) do
    f(shield.subtype,
      {function(civ) return civ.resources.shield_type end},
      'item_shieldst' .. WORD_ID_CHAR .. shield.id,
      shield.name,
      shield.name_plural)
  end
  for _, helm in ipairs(raws.itemdefs.helms) do
    f(helm.subtype,
      {function(civ) return civ.resources.helm_type end},
      'item_helmst' .. WORD_ID_CHAR .. helm.id,
      helm.name,
      helm.name_plural)
  end
  for _, glove in ipairs(raws.itemdefs.gloves) do
    f(glove.subtype,
      {function(civ) return civ.resources.gloves_type end},
      'item_glovesst' .. WORD_ID_CHAR .. glove.id,
      glove.name,
      glove.name_plural)
  end
  for _, pants in ipairs(raws.itemdefs.pants) do
    f(pants.subtype,
      {function(civ) return civ.resources.helm_type end},
      'item_pantsst' .. WORD_ID_CHAR .. pants.id,
      pants.name,
      pants.name_plural)
  end
  for _, siege_ammo in ipairs(raws.itemdefs.siege_ammo) do
    f(siege_ammo.subtype,
      {function(civ) return civ.resources.siegeammo_type end},
      'item_siegeammost' .. WORD_ID_CHAR .. siege_ammo.id,
      siege_ammo.name,
      siege_ammo.name_plural)
  end
  for _, weapon in ipairs(raws.itemdefs.weapons) do
    f(weapon.subtype,
      {function(civ) return civ.resources.digger_type end,
       function(civ) return civ.resources.weapon_type end,
       function(civ) return civ.resources.training_weapon_type end},
      'item_weaponst' .. WORD_ID_CHAR .. weapon.id,
      weapon.name,
      weapon.name_plural)
  end
  for _, ammo in ipairs(raws.itemdefs.ammo) do
    f(ammo.subtype,
      {function(civ) return civ.resources.ammo_type end},
      'item_ammost' .. WORD_ID_CHAR .. ammo.id,
      ammo.name,
      ammo.name_plural)
  end
  for _, trapcomp in ipairs(raws.itemdefs.trapcomps) do
    f(trapcomp.subtype,
      {function(civ) return civ.resources.trapcomp_type end},
      'item_trapcompst' .. WORD_ID_CHAR .. trapcomp.id,
       trapcomp.name,
       trapcomp.name_plural)
  end
  for _, tool in ipairs(raws.itemdefs.tools) do
    f(tool.subtype,
      {function(civ) return civ.resources.toy_type end},
      'item_toolst' .. WORD_ID_CHAR .. tool.id,
      tool.name,
      tool.name_plural)
  end
  for i, shape in ipairs(raws.language.shapes) do
    local is_gem = #utils.list_bitfield_flags(shape.gems_use) ~= 0
    local gem_prefix = is_gem and
      (shape.gems_use.adj or shape.gems_use.adj_noun) and
      #shape.adj > 0 and shape.adj[0].value .. ' ' or ''
    f(i,
      {
        function(civ) return is_gem and {} or {i} end,
        function(civ) return civ.entity_raw.gem_shapes end,
        function(civ) return civ.entity_raw.stone_shapes end,
      },
      'SHAPE' .. WORD_ID_CHAR .. shape.id,
      gem_prefix .. shape.name,
      gem_prefix .. shape.name_plural)
  end
  if not HACK_FOR_QUICK_TEST and lects[1] then
    for _, entity in ipairs(df.global.world.entities.all) do
      f(0, universal, 'ENTITY' .. WORD_ID_CHAR .. entity.id)
    end
  end
  --[[
  for _, building in ipairs(raws.buildings.all) do
    f(?, ?, 'BUILDING' .. WORD_ID_CHAR .. building.id, building.name)
  end
  for _, builtin in ipairs(raws.mat_table.builtin) do
    if builtin then
      f(?, ?, 'BUILTIN' .. WORD_ID_CHAR .. builtin.id,
        builtin.state_name.Solid, nil, builtin.state_adj.Solid)
    end
  end
  for _, syndrome in ipairs(raws.syndromes.all) do
    f(?, ?, 'SYNDROME' .. WORD_ID_CHAR .. syndrome.id, syndrome.syn_name)
  end
  ]]
end

--[[
Validates a boundary.

If the given boundary is not a legal boundary, or if the given boundary
is the given scope, it raises an error.

Args:
  boundary: A string, which might be a boundary.
  scope: A boundary, or nil if the scope has not been set.
]]
local function validate_boundary(boundary, scope)
  if not (boundary == 'UTTERANCE' or boundary == 'WORD' or
          boundary == 'MORPHEME' or boundary == 'SYLLABLE' or
          boundary == 'ONSET' or boundary == 'NUCLEUS' or
          boundary == 'CODA') then
    qerror('Unknown boundary: ' .. boundary)
  end
  if boundary == scope then
    qerror('Repeated boundary: ' .. boundary)
  end
end

--[[
Inserts a skip pattern element into a pattern.

Args:
  pattern! A non-empty pattern to append a skip pattern element to.
  domain: The feature index to not skip.
  scope: A boundary to not skip.
  boundary: A boundary to not skip.
]]
local function insert_skip(pattern, domain, scope, boundary)
  local prev_boundary = nil
  if pattern[#pattern].type == 'boundary' then
    prev_boundary = pattern[#pattern].boundary
  end
  table.insert(pattern, {type='skip', feature=domain,
                         boundaries={scope, prev_boundary, boundary}})
end

if TEST then
  local pattern = {{type='phoneme'}}
  insert_skip(pattern, 2)
  assert_eq(pattern,
            {{type='phoneme'}, {type='skip', feature=2, boundaries={}}})
  insert_skip(pattern, 3, 'WORD')
  assert_eq(pattern[#pattern], {type='skip', feature=3, boundaries={'WORD'}})
  insert_skip(pattern, 1, 'WORD', 'MORPHEME')
  assert_eq(pattern[#pattern],
            {type='skip', feature=1, boundaries={'WORD', nil, 'MORPHEME'}})
  table.insert(pattern, {type='boundary', boundary='MORPHEME'})
  insert_skip(pattern, 0, 'WORD', 'SYLLABLE')
  assert_eq(pattern[#pattern], {type='skip', feature=0,
                                boundaries={'WORD', 'MORPHEME', 'SYLLABLE'}})
end

--[[
Parses a string as a dimension value bit.

'-' is 0. '+' is 1. Anything else is an error.

Args:
  subtag: A string to parse.
  tag: The tag, for the error message.

Returns:
  0 or 1.
]]
local function get_valid_value(subtag, tag)
  if subtag == '-' then
    return  0
  elseif subtag == '+' then
    return 1
  end
  qerror('Value for must be + or -: ' .. tag)
end

--[[
Loads all phonology raw files into `phonologies`.

The raw files must match 'phonology_*.txt'.
]]
local function load_phonologies()
  local dir = dfhack.getSavePath()
  if not dir then
    return
  end
  dir = dir .. '/raw/objects'
  for _, filename in pairs(dfhack.filesystem.listdir(dir)) do
    local path = dir .. '/' .. filename
    if (dfhack.filesystem.isfile(path) and
        filename:match('^phonology_.*%.txt')) then
      io.input(path)
      -- TODO: Is it bad that it can qerror without closing the file?
      -- TODO: Check the first line for the file name.
      -- TODO: '\n'-terminated tokens trim trailing whitespace.
      local current_phonology = nil
      local current_parent = 0
      local current_dimension
      local nodes_in_dimension_tree = {}
      for tag in io.read('*all'):gmatch('%[([^]\n]*)%]?') do
        local subtags = {}
        for subtag in string.gmatch(tag .. ':', '([^]:]*):') do
          table.insert(subtags, subtag)
        end
        if #subtags >= 1 then
          if subtags[1] == 'OBJECT' then
            if #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            if subtags[2] ~= 'PHONOLOGY' then
              qerror('Wrong object type: ' .. subtags[2])
            end
            phonologies = {}
          elseif not phonologies then
            qerror('Missing OBJECT tag: ' .. filename)
          elseif subtags[1] == 'PHONOLOGY' then
            if #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif utils.linear_index(phonologies, subtags[2], 'name') then
              qerror('Duplicate phonology: ' .. subtags[2])
            elseif current_dimension then
              qerror('Unfinished dimension tree before ' .. subtags[2])
            end
            table.insert(phonologies,
                         {name=subtags[2], nodes={}, scalings={}, symbols={},
                          dispersions={}, affixes={}, articulators={},
                          constraints={{type='Max'}, {type='Dep'}}})
            current_phonology = phonologies[#phonologies]
          elseif subtags[1] == 'NODE' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags < 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif current_phonology.dimension then
              qerror('Node after the dimension tree: ' .. tag)
            end
            local sonority = 0
            local feature_class = current_parent == 0 and FEATURE_CLASS_NEUTRAL
              or current_phonology.nodes[current_parent].feature_class
            local feature = true
            local prob = DEFAULT_NODE_PROBABILITY_GIVEN_PARENT *
              (current_parent == 0 and 1 or
               current_phonology.nodes[current_parent].prob)
            local add_symbol = nil
            local remove_symbol = nil
            local i = 3
            while i <= #subtags do
              if subtags[i] == 'SONORITY' then
                if i == #subtags then
                  qerror('No sonority specified for node ' .. subtags[2])
                end
                i = i + 1
                sonority = tonumber(subtags[i])
                if not sonority or sonority < 0 then
                  qerror('Sonority must be a nonnegative number: ' ..
                         subtags[i])
                end
              elseif subtags[i] == 'VOWEL' then
                feature_class = FEATURE_CLASS_VOWEL
              elseif subtags[i] == 'CONSONANT' then
                feature_class = FEATURE_CLASS_CONSONANT
              elseif subtags[i] == 'CLASS' then
                if (current_parent ~= 0 and
                    current_phonology.nodes[current_parent].feature) then
                  qerror(subtags[2] .. ' cannot be a class node because ' ..
                         current_phonology.nodes[current_parent].name ..
                         ', its parent, is a feature node')
                end
                feature = false
              elseif subtags[i] == 'PROB' then
                if i == #subtags then
                  qerror('No probability specified for node ' .. subtags[2])
                end
                i = i + 1
                prob = tonumber(subtags[i])
                if not prob or prob < 0 or 1 < prob then
                  qerror('Probability must be between 0 and 1: ' .. subtags[i])
                end
              elseif subtags[i] == 'ADD' then
                if i == #subtags then
                  qerror('No symbol specified for node ' .. subtags[2])
                end
                i = i + 1
                add_symbol = unescape(subtags[i])
              elseif subtags[i] == 'REMOVE' then
                if i == #subtags then
                  qerror('No symbol specified for node ' .. subtags[2])
                end
                i = i + 1
                remove_symbol = unescape(subtags[i])
              else
                qerror('Unknown subtag ' .. subtags[i])
              end
              i = i + 1
            end
            table.insert(current_phonology.nodes,
                         {name=subtags[2], parent=current_parent,
                          add=add_symbol, remove=remove_symbol,
                          sonority=sonority, feature_class=feature_class,
                          feature=feature, prob=prob, articulators={}})
            if (current_parent ~= 0 and
                current_phonology.nodes[current_parent].feature) then
              table.insert(current_phonology.scalings, {
                  mask=bitfield_set(
                    bitfield_set({}, #current_phonology.nodes - 1, 1),
                    current_parent - 1, 1),
                  values=bitfield_set({}, #current_phonology.nodes - 1, 1),
                  scalar=0, strength=math.huge,
                })
            end
            current_parent = #current_phonology.nodes
            table.insert(current_phonology.constraints,
                         {type='Ident', feature=current_parent})
          elseif subtags[1] == 'ARTICULATOR' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            end
            local bp = nil
            local bp_category = nil
            local bp_flag = nil
            local creature = nil
            local creature_class = nil
            local creature_flag = nil
            local caste = nil
            local caste_flag = nil
            local i = 2
            while i <= #subtags do
              if i == #subtags then
                qerror('No value specified for ' .. subtags[i] .. ': ' .. tag)
              end
              if subtags[i] == 'BP' then
                if bp or bp_category or bp_flag then
                  qerror('Extra BP or BP_CATEGORY or BP_FLAG: ' .. tag)
                end
                i = i + 1
                bp = subtags[i]
              elseif subtags[i] == 'BP_CATEGORY' then
                if bp or bp_category or bp_flag then
                  qerror('Extra BP or BP_CATEGORY or BP_FLAG: ' .. tag)
                end
                i = i + 1
                bp_category = subtags[i]
              elseif subtags[i] == 'BP_FLAG' then
                if bp or bp_category or bp_flag then
                  qerror('Extra BP or BP_CATEGORY or BP_FLAG: ' .. tag)
                end
                i = i + 1
                bp_flag = subtags[i]
                if copyall(df.global.world.raws.creatures.all[0].caste[0]
                           .body_info.body_parts[0].flags)[bp_flag] == nil then
                  qerror('No such body part flag: ' .. bp_flag)
                end
              elseif subtags[i] == 'CREATURE' then
                if creature or creature_category or creature_flag then
                  qerror(
                    'Extra CREATURE or CREATURE_CATEGORY or CREATURE_FLAG: ' ..
                    tag)
                end
                i = i + 1
                creature = subtags[i]
              elseif subtags[i] == 'CREATURE_CLASS' then
                if creature or creature_category or creature_flag then
                  qerror(
                    'Extra CREATURE or CREATURE_CATEGORY or CREATURE_FLAG: ' ..
                    tag)
                end
                i = i + 1
                creature_category = subtags[i]
              elseif subtags[i] == 'CREATURE_FLAG' then
                if creature or creature_category or creature_flag then
                  qerror(
                    'Extra CREATURE or CREATURE_CATEGORY or CREATURE_FLAG: ' ..
                    tag)
                end
                i = i + 1
                creature_flag = subtags[i]
                if (copyall(df.global.world.raws.creatures.all[0].flags)
                    [creature_flag] == nil) then
                  qerror('No such creature flag: ' .. creature_flag)
                end
              elseif subtags[i] == 'CASTE' then
                if caste then
                  qerror('Extra CASTE or CASTE_FLAG: ' .. tag)
                end
                i = i + 1
                caste = subtags[i]
              elseif subtags[i] == 'CASTE_FLAG' then
                if caste then
                  qerror('Extra CASTE or CASTE_FLAG: ' .. tag)
                end
                i = i + 1
                caste_flag = subtags[i]
                if copyall(df.global.world.raws.creatures.all[0].caste[0]
                           .flags)[caste_flag] == nil then
                  qerror('No such caste flag: ' .. caste_flag)
                end
              else
                qerror('Unknown subtag ' .. subtags[i])
              end
              i = i + 1
            end
            local caste_index = nil
            if creature then
              local index, creature_raw = utils.linear_index(
                df.global.world.raws.creatures.all, creature, 'creature_id')
              if not index then
                qerror('No such creature: ' .. creature)
              end
              if caste then
                local caste_index, caste_raw =
                  utils.linear_index(creature_raw.caste, caste, 'caste_id')
                if not index then
                  qerror('No such caste for ' .. creature .. ': ' .. caste)
                end
                caste_index = caste
              end
            elseif caste then
              qerror('CASTE requires CREATURE: ' .. tag)
            end
            table.insert(
              (current_parent == 0 and current_phonology or
               current_phonology.nodes[current_parent]).articulators,
              {bp=bp, bp_category=bp_category, creature=creature_raw,
               creature_class=creature_class, caste_index=caste_index})
          elseif subtags[1] == 'END' then
            if not current_phonology or current_parent == 0 then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local children = {}
            local i = #current_phonology.nodes
            while i > 0 do
              if current_phonology.nodes[i].parent == current_parent then
                table.insert(children, current_phonology.nodes[i])
                i = i - 1
              else
                i = current_phonology.nodes[i].parent
              end
            end
            current_parent = current_phonology.nodes[current_parent].parent
          elseif subtags[1] == 'DIMENSION' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags > 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif not current_dimension and #nodes_in_dimension_tree ~= 0 then
              qerror('Multiple root dimensions')
            elseif subtags[2] and subtags[2] ~= 'PERIPHERAL' then
              qerror('Invalid subtoken: ' .. subtags[2])
            end
            current_dimension =
              {parent=current_dimension, scalings={}, peripheral=subtags[2]}
          elseif subtags[1] == 'DIMENSION_NODE' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif current_dimension.d2 then
              qerror('A dimension can only have two subdimensions: ' .. tag)
            end
            local n, node =
              utils.linear_index(current_phonology.nodes, subtags[2], 'name')
            if not n then
              qerror('No such node: ' .. subtags[2])
            end
            nodes_in_dimension_tree[n] = true
            current_dimension[current_dimension.d1 and 'd2' or 'd1'] =
              {id={n}, nodes={n}, mask=bitfield_set({}, n - 1, 1),
               cache=node.feature and
               {{score=1 - node.prob}, {score=node.prob, n}} or {{score=1, n}}}
          elseif subtags[1] == 'END_DIMENSION' then
            if not current_phonology or not current_dimension then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif not current_dimension.d2 then
              qerror('Each dimension must have two subdimensions.')
            end
            local d = current_dimension
            d.id = {d.d1.id[1], d.d2.id[#d.d2.id]}
            d.cache = {}
            d.mask = bitfield_or(d.d1.mask, d.d2.mask)
            d.nodes = concatenate(d.d1.nodes, d.d2.nodes)
            d.values_1 = {}
            d.values_2 = {}
            d.dispersions = {}
            current_dimension, current_dimension.parent = d.parent
            if current_dimension then
              current_dimension[current_dimension.d1 and 'd2' or 'd1'] = d
            elseif #nodes_in_dimension_tree == #current_phonology.nodes then
              current_phonology.dimension = d
              nodes_in_dimension_tree = {}
            else
              qerror('Not all nodes are in the dimension tree.')
            end
          elseif subtags[1] == 'SCALE' or subtags[1] == 'DIMENSION_SCALE' then
            local in_dimension = subtags[1] == 'DIMENSION_SCALE'
            if (not current_phonology or
                (in_dimension and not current_dimension)) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags < 6 or #subtags % 2 ~= 0 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local scalar = tonumber(subtags[2])
            if not scalar or scalar < 0 then
              qerror('Scalar must be a non-negative number: ' .. subtags[2])
            end
            local strength = (scalar < 1 and 1 / scalar or scalar) - 1
            local mask = {}
            local values = {}
            local i = 3
            while i < #subtags do
              local value = get_valid_value(subtags[i], tag)
              local node = utils.linear_index(
                current_phonology.nodes, subtags[i + 1], 'name')
              if not node then
                qerror('No such node: ' .. subtags[i + 1])
              elseif not current_phonology.nodes[node].feature then
                qerror('Node must not be a class node: ' .. subtags[i + 1])
              elseif bitfield_get(mask, node - 1) == 1 then
                qerror('Same node twice in one scaling: ' .. tag)
              end
              bitfield_set(mask, node - 1, 1)
              bitfield_set(values, node - 1, value)
              i = i + 2
            end
            table.insert((in_dimension and current_dimension or
                          current_phonology).scalings,
                         {mask=mask, values=values, scalar=scalar, tag=tag,
                          strength=strength})
          elseif subtags[1] == 'DISPERSE' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags < 5 or #subtags % 3 ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local scalar = tonumber(subtags[2])
            if not scalar or scalar < 0 then
              qerror('Scalar must be a non-negative number: ' .. subtags[2])
            end
            local mask = {}
            local values_1 = {}
            local values_2 = {}
            local i = 3
            while i < #subtags do
              local value_1 = get_valid_value(subtags[i], tag)
              local value_2 = get_valid_value(subtags[i + 1], tag)
              local node = utils.linear_index(
                current_phonology.nodes, subtags[i + 2], 'name')
              if not node then
                qerror('No such node: ' .. subtags[i + 2])
              elseif not current_phonology.nodes[node].feature then
                qerror('Node must not be a class node: ' .. subtags[i + 2])
              elseif bitfield_get(mask, node - 1) == 1 then
                qerror('Same node twice in one dispersion: ' .. tag)
              end
              bitfield_set(mask, node - 1, 1)
              bitfield_set(values_1, node - 1, value_1)
              bitfield_set(values_2, node - 1, value_2)
              i = i + 3
            end
            if bitfield_equals(values_1, values_2) then
              qerror('Cannot disperse something from itself: ' .. tag)
            end
            current_phonology.dispersions[#current_phonology.dispersions + 1] =
              {mask=mask, values_1=values_1, values_2=values_2, scalar=scalar}
          elseif subtags[1] == 'SYMBOL' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            end
            local nodes = {}
            local i = 3
            while i <= #subtags do
              local n, node = utils.linear_index(current_phonology.nodes,
                                                 subtags[i], 'name')
              if not n then
                qerror('No such node: ' .. subtags[i])
              end
              if node.parent ~= 0 then
                table.insert(subtags,
                             current_phonology.nodes[node.parent].name)
              end
              nodes[n] = true
              i = i + 1
            end
            table.insert(current_phonology.symbols,
                         {symbol=unescape(subtags[2]), features=nodes})
          elseif subtags[1] == 'CONSTRAINT' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            end
            local constraint = {type='*', {}}
            local domain = 0
            local scope = nil
            local vars = {['']=0}
            local i = 2
            while i <= #subtags do
              if subtags[i] == 'BOUNDARY' then
                if i == #subtags then
                  qerror('Incomplete boundary: ' .. tag)
                end
                local boundary = subtags[i + 1]
                validate_boundary(boundary, scope)
                insert_skip(constraint, domain, scope, boundary)
                table.insert(constraint, {type='boundary', boundary=boundary})
                i = i + 1
              elseif subtags[i] == 'DOMAIN' then
                if #constraint ~= 1 then
                  qerror('Domain must precede phonemes and boundaries: ' ..
                         tag)
                end
                if i == #subtags then
                  qerror('No node specified for domain: ' .. tag)
                end
                local n, node = utils.linear_index(current_phonology.nodes,
                                                   subtags[i + 1], 'name')
                if not n then
                  qerror('No such node: ' .. subtags[i + 1])
                end
                domain = n
                i = i + 1
              elseif subtags[i] == 'SCOPE' then
                if #constraint ~= 1 then
                  qerror('Scope must precede phonemes and boundaries: ' .. tag)
                end
                if i == #subtags then
                  qerror('No scope for constraint: ' .. tag)
                end
                scope = subtags[i + 1]
                validate_boundary(scope)
                i = i + 1
              elseif subtags[i] == 'THEN' then
                insert_skip(constraint, domain, scope)
                table.insert(constraint, {type='phoneme'})
              else
                if i + 2 > #subtags then
                  qerror('Incomplete constraint: ' .. tag)
                end
                local val = true
                if subtags[i + 1] == '-' then
                  val = false
                elseif subtags[i + 1] ~= '+' then
                  qerror('The token after node ' .. subtags[i] ..
                         ' must be + or -: ' .. tag)
                end
                local n, node = utils.linear_index(current_phonology.nodes,
                                                   subtags[i], 'name')
                if not n then
                  qerror('No such node: ' .. subtags[i])
                end
                if not (dominates(domain, n, current_phonology.nodes) or
                        dominates(n, domain, current_phonology.nodes)) then
                  qerror('Constraint has domain ' .. nodes[domain].name ..
                         ' but one of its phonemes specifies ' ..
                         nodes[n].name)
                end
                if constraint[#constraint].type ~= 'phoneme' then
                  insert_skip(constraint, domain, scope)
                  table.insert(constraint, {type='phoneme'})
                end
                local _, var = utils.insert_or_update(vars, subtags[i + 2])
                constraint[#constraint][n] = {val=val, var=var}
                i = i + 2
              end
              i = i + 1
            end
            table.insert(current_phonology.constraints, constraint)
          else
            qerror('Unknown tag: ' .. tag)
          end
        end
      end
      io.input():close()
    end
  end
end

--[[
Sets a historical figure's fluency in `fluency_data`.

Args:
  hf_id: The ID of a historical figure.
  civ_id: The ID of a civilization corresponding to a lect.
  fluency: A number.
]]
local function set_fluency(hf_id, civ_id, fluency)
  if not fluency_data[hf_id] then
    fluency_data[hf_id] = {}
  end
  fluency_data[hf_id][civ_id] = {fluency=fluency}
end

--[[
Gets a historical figure's fluency from `fluency_data`.

Args:
  hf_id: The ID of a historical figure.
  civ_id: The ID of a civilization corresponding to a lect.

Returns:
  The historical figure's fluency in the civilization's lect.
]]
local function get_fluency(hf_id, civ_id)
  if not fluency_data[hf_id] then
    fluency_data[hf_id] = {}
  end
  if not fluency_data[hf_id][civ_id] then
    fluency_data[hf_id][civ_id] = {fluency=MINIMUM_FLUENCY}
  end
  return fluency_data[hf_id][civ_id]
end

--[[
Loads fluency data from a file into `fluency_data`.

The file must be `fluency_data.txt` in the raws directory. Each line of
the file has three numbers separated by spaces. The numbers are the ID
of a historical figure, the ID of a civilization, and the fluency level
of the historical figure in the civilization's lect.
]]
local function load_fluency_data()
  fluency_data = {}
  local file = io.open(dfhack.getSavePath() .. '/raw/objects/fluency_data.txt')
  if file then
    for line in file:lines() do
      local fields = utils.split_string(line, ' ')
      if #fields ~= 3 then
        qerror('Wrong number of fields: ' .. line)
      end
      local _, hf_id = utils.check_number(fields[1])
      local _, civ_id = utils.check_number(fields[2])
      local _, fluency = utils.check_number(fields[3])
      if hf_id and civ_id and fluency then
        set_fluency(hf_id, civ_id, fluency)
      else
        qerror('Invalid fluency data: ' .. line)
      end
    end
    file:close()
  end
end

--[[
Writes fluency data from `fluency_data` to a file.

The documentation for `load_fluency_data` describes the file and its
format.
]]
local function write_fluency_data()
  local file = io.open(dfhack.getSavePath() .. '/raw/objects/fluency_data.txt',
                       'w')
  if file then
    for hf_id, hf_data in pairs(fluency_data) do
      for civ_id, fluency_record in pairs(hf_data) do
        file:write(hf_id .. ' ' .. civ_id .. ' ' .. fluency_record.fluency ..
                   '\n')
      end
    end
    file:close()
  end
end

--[[
Writes a constituent to a file.

Args:
  file: An open file handle.
  constituent: A constituent to write.
  depth: The depth of the constituent, where a top-level constituent's
    depth is 1 and any other's is one more than its parent's.
  id: The constituent's ID if it is a top-level constituent or an
    argument, or nil.
]]
local function write_constituent(file, constituent, depth, id)
  local indent = ('\t'):rep(depth)
  file:write(indent, '[CONSTITUENT')
  if id then
    file:write(':', id)
  end
  file:write(']\n')
  if constituent.n1 then
    write_constituent(file, constituent.n1, depth + 1)
    if constituent.n2 then
      write_constituent(file, constituent.n2, depth + 1)
    end
  end
  for k, v in pairs(constituent.features or {}) do
    file:write(indent, '\t[C_FEATURE:', tostring(k), ':', tostring(v), ']\n')
  end
  for _, morpheme in ipairs(constituent.morphemes or {}) do
    file:write(indent, '\t[C_MORPHEME:', morpheme.id, ']\n')
  end
  if constituent.is_phrase then
    file:write(indent, '\t[PHRASE]\n')
  end
  if constituent.ref then
    file:write(indent, '\t[REF:', constituent.ref, ']\n')
    for role, argument in pairs(constituent.args or {}) do
      write_constituent(file, argument, depth + 1, role)
    end
  elseif constituent.arg then
    file:write(indent, '\t[ARG:', constituent.arg, ']\n')
  elseif constituent.text then
    file:write(indent, '\t[TEXT:', escape(constituent.text), ']\n')
  elseif constituent.context_key then
    file:write(indent, '\t[CONTEXT:', escape(constituent.context_key), ':',
               escape(constituent.context_callback), ']\n')
  end
  file:write(indent, '[END_CONSTITUENT]\n')
end

--[[
Writes all lects from `lects` to files.
]]
local function write_lect_files()
  local dir = dfhack.getSavePath() .. '/raw/objects'
  for i, lect in ipairs(lects) do
    local filename = 'lect_' .. string.format('%04d', i)
    local file = io.open(dir .. '/' .. filename .. '.txt', 'w')
    file:write(filename, '\n\n[OBJECT:LECT]\n\n[LECT]\n')
    if lect.parent then
      file:write('\t[PARENT:', utils.linear_index(lects, lect.parent), ']\n')
    end
    file:write('\t[SEED:', lect.seed, ']\n')
    file:write('\t[LEMMAS:', lect.lemmas.name, ']\n')
    file:write('\t[COMMUNITY:', lect.community.id, ']\n')
    file:write('\t[PHONOLOGY:', lect.phonology.name, ']\n')
    for id, morpheme in pairs(lect.morphemes) do
      file:write('\t[MORPHEME:', id, ']\n')
      file:write('\t\t[PWORD:',
        escape(serialize_pword(lect.phonology.nodes, morpheme.pword)), ']\n')
      for k, v in pairs(morpheme.features) do
        file:write('\t\t[M_FEATURE:', k, ':', v, ']\n')
      end
      if morpheme.affix then
        file:write('\t\t[AFFIX]')
      end
      if morpheme.after then
        file:write('\t\t[AFTER]')
      end
      if morpheme.affix then
        file:write('\t\t[INITIAL]')
      end
      for k, v in pairs(morpheme.fusion) do
        file:write('\t\t[FUSE:', k, ':', v.id, ']\n')
      end
      if morpheme.dummy then
        file:write('\t\t[DUMMY:', morpheme.dummy.id, ']\n')
      end
    end
    for id, constituent in pairs(lect.constituents) do
      write_constituent(file, constituent, 1, id)
    end
    file:close()
  end
end

--[[
Loads all lect raw files into `lects`.

The raw files must match 'lect_*.txt'.
]]
local function load_lects()
  lects = lects or {}
  local dir = dfhack.getSavePath()
  if not dir then
    return
  end
  dir = dir .. '/raw/objects'
  for _, filename in pairs(dfhack.filesystem.listdir(dir)) do
    local path = dir .. '/' .. filename
    if (dfhack.filesystem.isfile(path) and filename:match('^lect_.*%.txt')) then
      io.input(path)
      local object_seen = false
      local current_lect
      local current_morpheme
      local morphemes_to_backpatch = {}
      local constituent_stack
      for tag in io.read('*all'):gmatch('%[([^]\n]*)%]?') do
        local subtags = {}
        for subtag in string.gmatch(tag .. ':', '([^]:]*):') do
          table.insert(subtags, subtag)
        end
        if #subtags >= 1 then
          if subtags[1] == 'OBJECT' then
            if #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif subtags[2] ~= 'LECT' then
              qerror('Wrong object type: ' .. subtags[2])
            end
            object_seen = true
          elseif not object_seen then
            qerror('Missing OBJECT tag: ' .. filename)
          elseif subtags[1] == 'LECT' then
            if #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            current_lect = {morphemes={}, constituents={}}
            lects[#lects + 1] = current_lect
            current_morpheme = nil
            constituent_stack = {}
          elseif subtags[1] == 'PARENT' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local parent_index = tonumber(subtags[2])
            if (not parent_index or
                parent_index < 1 or
                parent_index >= #lects or
                parent_index ~= math.floor(parent_index)) then
              qerror('The parent must be a valid lect index: ' .. subtags[2])
            end
            current_lect.parent = lects[parent_index]
          elseif subtags[1] == 'SEED' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            current_lect.seed = tonumber(subtags[2])
            if not current_lect.seed then
              qerror('The seed must be a number: ' .. subtags[2])
            end
          elseif subtags[1] == 'LEMMAS' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local _, translation = utils.linear_index(df.global.world.raws.language.translations, subtags[2], 'name')
            if not translation then
              qerror('Lemmas not found: ' .. subtags[2])
            end
            current_lect.lemmas = translation
          elseif subtags[1] == 'COMMUNITY' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local community = df.historical_entity.find(tonumber(subtags[2]))
            if not community then
              qerror('Entity not found: ' .. subtags[2])
            end
            current_lect.community = community
          elseif subtags[1] == 'PHONOLOGY' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif not phonologies then
              qerror('Phonologies must be loaded before lects.')
            end
            local _, phonology =
              utils.linear_index(phonologies, subtags[2], 'name')
            if not phonology then
              qerror('Phonology ' .. subtags[2] .. ' not found.')
            end
            current_lect.phonology = phonology
          elseif subtags[1] == 'MORPHEME' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif current_lect.morphemes[subtags[2]] then
              qerror('Duplicate morpheme: ' .. subtags[2])
            end
            local id = tonumber(subtags[2])
            current_morpheme = {id=id, features={}, fusion={}}
            current_lect.morphemes[id] = current_morpheme
          elseif subtags[1] == 'PWORD' then
            if not current_morpheme then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            elseif not current_lect.phonology then
              qerror('The phonology must be set before the morphemes.')
            end
            current_morpheme.pword = deserialize_pword(
              current_lect.phonology.nodes, unescape(subtags[2]))
          elseif subtags[1] == 'M_FEATURE' then
            if not current_morpheme then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 3 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            current_morpheme.features[subtags[2]] = subtags[3]
          elseif subtags[1] == 'AFFIX' then
            if not current_morpheme then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            current_morpheme.affix = true
          elseif subtags[1] == 'AFTER' then
            if not current_morpheme then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            current_morpheme.after = true
          elseif subtags[1] == 'INITIAL' then
            if not current_morpheme then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            current_morpheme.initial = true
          elseif subtags[1] == 'FUSE' then
            if not current_morpheme then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 3 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            morphemes_to_backpatch[#morphemes_to_backpatch + 1] =
              {t=current_morpheme.fusion, k=subtags[2], v=subtags[3],
               m=current_lect.morphemes}
          elseif subtags[1] == 'DUMMY' then
            if not current_morpheme then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            morphemes_to_backpatch[#morphemes_to_backpatch + 1] =
              {t=current_morpheme, k='dummy', v=subtags[2],
               m=current_lect.morphemes}
          elseif subtags[1] == 'CONSTITUENT' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif next(constituent_stack) and #subtags ~= 1 or #subtags ~= 2
            then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local current_constituent = constituent_stack[#constituent_stack]
            local new_constituent = {features={}, morphemes={}}
            local id = subtags[2]
            if current_constituent then
              if id then
                if current_constituent.ref then
                  current_constituent.args = current_constituent.args or {}
                  current_constituent.args[#current_constituent.args + 1] =
                    new_constituent
                else
                  qerror('Argument without a predicate: ' .. id)
                end
              elseif current_constituent.n1 then
                if current_constituent.n2 then
                  current_constituent.n2 = new_constituent
                else
                  qerror('Extra constituent: ' .. tag)
                end
              else
                current_constituent.n1 = new_constituent
              end
            end
            constituent_stack[#constituent_stack + 1] = new_constituent
            if id then
              current_lect.constituents[id] = new_constituent
            end
          elseif subtags[1] == 'C_FEATURE' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            constituent_stack[#constituent_stack].features[subtags[2]] =
              subtags[3]
          elseif subtags[1] == 'C_MORPHEME' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local morphemes = constituent_stack[#constituent_stack].morphemes
            morphemes[#morphemes + 1] = 0
            morphemes_to_backpatch[#morphemes_to_backpatch + 1] =
              {t=morphemes, k=#morphemes, v=subtags[2],
               m=current_lect.morphemes}
          elseif subtags[1] == 'PHRASE' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            constituent_stack[#constituent_stack].is_phrase = true
          elseif subtags[1] == 'REF' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            constituent_stack[#constituent_stack].ref = subtags[2]
          elseif subtags[1] == 'ARG' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            constituent_stack[#constituent_stack].arg = subtags[2]
          elseif subtags[1] == 'TEXT' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            constituent_stack[#constituent_stack].text = subtags[2]
          elseif subtags[1] == 'CONTEXT' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            constituent_stack[#constituent_stack].context_key = subtags[2]
            constituent_stack[#constituent_stack].context_callback = subtags[3]
          elseif subtags[1] == 'END_CONSTITUENT' then
            constituent_stack[#constituent_stack] = nil
          else
            qerror('Unknown tag: ' .. tag)
          end
        end
      end
      for _, mtb in ipairs(morphemes_to_backpatch) do
        local _, morpheme = utils.linear_index(mtb.m, tonumber(mtb.v), 'id')
        if not morpheme then
          qerror('No such morpheme: ' .. mtb.v)
        end
        mtb.t[mtb.k] = morpheme
      end
      io.input():close()
    end
  end
end

--[[
Determines whether a file is a language file.

Args:
  path: The path of a file.

Returns:
  Whether the file is a language file.
]]
local function has_language_object(path)
  -- TODO: check that the first line has the filename
  io.input(path)
  -- TODO: check for legal variants of this regex and false positives
  local rv = false
  if io.read('*all'):find('%[OBJECT:LANGUAGE%]') then
    rv = true
  end
  io.input():close()
  return rv
end

--[[
Writes raw tags to a file.

Args:
  file: The file to write to.
  tags: A sequence of tags.
]]
local function write_raw_tags(file, tags)
  -- TODO: This is not guaranteed to write the tags in order.
  for _, str in pairs(tags) do
    file:write('\t', str.value, '\n')
  end
end

--[[
Writes a translation file.

Args:
  dir: The name of the directory to write the file to.
  index: A number to use in the file name so the files all have unique
    names and a well-defined order.
  translation: A translation.
]]
local function write_translation_file(dir, index, translation)
  local filename = 'language_' .. string.format('%04d', index) .. '_' ..
    translation.name
  local file = io.open(dir .. '/' .. filename .. '.txt', 'w')
  file:write(filename, '\n\n[OBJECT:LANGUAGE]\n\n[TRANSLATION:',
             translation.name, ']\n')
  write_raw_tags(file, translation.str)
  for i = #translation.str, #df.global.world.raws.language.words - 1 do
    local value = ''
    if i < #translation.words then
      value = translation.words[i].value
    end
    file:write('\t[T_WORD:', df.global.world.raws.language.words[i].word, ':',
               value, ']\n')
  end
  file:close()
end

--[[
Writes a symbols file.

Args:
  dir: The name of the directory to write the file to.
]]
local function write_symbols_file(dir)
  local file = io.open(dir .. '/language_SYM.txt', 'w')
  file:write('language_SYM\n\n[OBJECT:LANGUAGE]\n')
  for _, symbol in pairs(df.global.world.raws.language.symbols) do
    file:write('\n[SYMBOL:', symbol.name, ']\n')
    write_raw_tags(file, symbol.str)
  end
  file:close()
end

--[[
Writes a words file.

Args:
  dir: The name of the directory to write the file to.
]]
local function write_words_file(dir)
  local file = io.open(dir .. '/language_words.txt', 'w')
  file:write('language_words\n\n[OBJECT:LANGUAGE]\n')
  for _, word in pairs(df.global.world.raws.language.words) do
    file:write('\n[WORD:', word.word, ']\n')
    write_raw_tags(file, word.str)
  end
  file:close()
end

--[[
Overwrites the default language files in the raws directory.

The new files use the same format but contain additional data.
]]
local function overwrite_language_files()
  local dir = dfhack.getSavePath() .. '/raw/objects'
  for _, filename in pairs(dfhack.filesystem.listdir(dir)) do
    local path = dir .. '/' .. filename
    if dfhack.filesystem.isfile(path) then
      if has_language_object(path) then
        os.remove(path)
      end
    end
  end
  for i, translation in pairs(df.global.world.raws.language.translations) do
    if translation.flags == 0 then  -- not generated
      write_translation_file(dir, i, translation)
    end
  end
  write_symbols_file(dir)
  write_words_file(dir)
end

--[[
Loans words from one civilization's lect to another's.

Args:
  dst_civ_id: The ID of the historical entity whose lect is the
    destination.
  src_civ_id: The ID of the historical entity whose lect is the source.
  loans: A sequence of loans.
]]
local function loan_words(dst_civ_id, src_civ_id, loans)
  -- TODO: Don't loan between lects with different phonologies.
  local dst_civ = df.historical_entity.find(dst_civ_id)
  local src_civ = df.historical_entity.find(src_civ_id)
  local dst_lect = get_civ_native_lect(dst_civ)
  local src_lect = get_civ_native_lect(src_civ)
  for i = 1, #loans do
    for _, id in pairs(loans[i].get(src_civ)) do
      local word_id = loans[i].prefix .. loans[i].type.find(id)[loans[i].id]
      local word_index =
        utils.linear_index(df.global.world.raws.language.words, word_id, 'word')
      if not dst_lect.constituents[word_id] then
        local lemma = src_lect.lemmas.words[word_index].value
        print('Civ ' .. dst_civ_id .. ' gets "' .. lemma .. '" (' .. word_id .. ') from civ ' .. src_civ_id)
        dst_lect.lemmas.words[word_index].value = lemma
        local mwords =
          make_utterance(copy_constituent(src_lect.constituents[word_id]))
        local pwords = {}
        for _, mword in ipairs(mwords) do
          pwords[#pwords + 1] = mword.pword
          -- TODO: literal text
        end
        local morpheme =
          m{id=tostring(#dst_lect.morphemes), pword=table.concat(pwords)}
        dst_lect.morphemes[#dst_lect.morphemes + 1] = morpheme
        dst_lect.constituents[word_id] = x{m={m{pword=table.concat(pwords)}}}
      end
    end
  end
end

local GENERAL = {
  {prefix='item_glovesst' .. WORD_ID_CHAR, type=df.itemdef_glovesst, id='id',
   get=function(civ) return civ.resources.gloves_type end},
  {prefix='item_shoesst' .. WORD_ID_CHAR, type=df.itemdef_shoesst, id='id',
   get=function(civ) return civ.resources.shoes_type end},
  {prefix='item_pantsst' .. WORD_ID_CHAR, type=df.itemdef_pantsst, id='id',
   get=function(civ) return civ.resources.pants_type end},
  {prefix='item_toyst' .. WORD_ID_CHAR, type=df.itemdef_toyst, id='id',
   get=function(civ) return civ.resources.toy_type end},
  {prefix='item_instrumentst' .. WORD_ID_CHAR, type=df.itemdef_instrumentst, id='id',
   get=function(civ) return civ.resources.instrument_type end},
  {prefix='item_toolst' .. WORD_ID_CHAR, type=df.itemdef_toolst, id='id',
   get=function(civ) return civ.resources.tool_type end},
  {prefix='plant' .. WORD_ID_CHAR, type=df.plant_raw, id='id',
   get=function(civ) return civ.resources.tree_fruit_plants end},
  {prefix='plant' .. WORD_ID_CHAR, type=df.plant_raw, id='id',
   get=function(civ) return civ.resources.shrub_fruit_plants end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.pet_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.mount_races end}
}

local TRADE = {
  {prefix='item_weaponst' .. WORD_ID_CHAR, type=df.itemdef_weaponst, id='id',
   get=function(civ) return civ.resources.digger_type end},
  {prefix='item_weaponst' .. WORD_ID_CHAR, type=df.itemdef_weaponst, id='id',
   get=function(civ) return civ.resources.training_weapon_type end},
  {prefix='item_glovesst' .. WORD_ID_CHAR, type=df.itemdef_glovesst, id='id',
   get=function(civ) return civ.resources.gloves_type end},
  {prefix='item_shoesst' .. WORD_ID_CHAR, type=df.itemdef_shoesst, id='id',
   get=function(civ) return civ.resources.shoes_type end},
  {prefix='item_pantsst' .. WORD_ID_CHAR, type=df.itemdef_pantsst, id='id',
   get=function(civ) return civ.resources.pants_type end},
  {prefix='item_toyst' .. WORD_ID_CHAR, type=df.itemdef_toyst, id='id',
   get=function(civ) return civ.resources.toy_type end},
  {prefix='item_instrumentst' .. WORD_ID_CHAR, type=df.itemdef_instrumentst,
   id='id', get=function(civ) return civ.resources.instrument_type end},
  {prefix='item_toolst' .. WORD_ID_CHAR, type=df.itemdef_toolst, id='id',
   get=function(civ) return civ.resources.tool_type end},
  {prefix='inorganic' .. WORD_ID_CHAR, type=df.inorganic_raw, id='id',
   get=function(civ) return civ.resources.metals end},
  {prefix='inorganic' .. WORD_ID_CHAR, type=df.inorganic_raw, id='id',
   get=function(civ) return civ.resources.stones end},
  {prefix='inorganic' .. WORD_ID_CHAR, type=df.inorganic_raw, id='id',
   get=function(civ) return civ.resources.gems end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.fish_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.egg_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.pet_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.wagon_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.pack_animal_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.wagon_puller_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.mount_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.exotic_pet_races end}
}

local WAR = {
  {prefix='item_weaponst' .. WORD_ID_CHAR, type=df.itemdef_weaponst, id='id',
   get=function(civ) return civ.resources.weapon_type end},
  {prefix='item_armorst' .. WORD_ID_CHAR, type=df.itemdef_armorst, id='id',
   get=function(civ) return civ.resources.armor_type end},
  {prefix='item_ammost' .. WORD_ID_CHAR, type=df.itemdef_ammost, id='id',
   get=function(civ) return civ.resources.ammo_type end},
  {prefix='item_helmst' .. WORD_ID_CHAR, type=df.itemdef_helmst, id='id',
   get=function(civ) return civ.resources.helm_type end},
  {prefix='item_shieldst' .. WORD_ID_CHAR, type=df.itemdef_shieldst, id='id',
   get=function(civ) return civ.resources.shield_type end},
  {prefix='item_siegeammost' .. WORD_ID_CHAR, type=df.itemdef_siegeammost,
   id='id', get=function(civ) return civ.resources.siegeammo_type end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return {civ.race} end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.mount_races end},
  {prefix='creature' .. WORD_ID_CHAR, type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.minion_races end}
}

--[[
Copies a translation.

Args:
  dst! The destination translation.
  src: The source translation.
]]
local function copy_translation(dst, src)
  for _, word in pairs(src.words) do
    dst.words:insert('#', {new=true, value=word.value})
  end
end

--[[
Creates a lect for a civilization.

Args:
  civ: A historical entity.
]]
local function create_lect(civ)
  if HACK_FOR_QUICK_TEST and lects[1] then
    return
  end
  local translations = df.global.world.raws.language.translations
  translations:insert('#', {new=true, name=civ.id .. 'S'})
  -- TODO: Don't simply copy from the first translation.
  copy_translation(translations[#translations - 1], translations[0])
  -- TODO: Choose a phonology based on physical ability to produce the phones.
  lect = {
    seed=dfhack.random.new():random(),
    lemmas=translations[#translations - 1],
    community=civ,
    phonology=phonologies[1],
    morphemes={},
    constituents={},
  }
  lects[#lects + 1] = lect
  expand_lexicons(dfhack.curry(add_word_to_lect, lect))
end

--[[
Determines whether a historical figure is not a unit.

Args:
  hf: A historical figure.

Returns:
  Whether a historical figure is not a unit.
]]
local function is_unprocessed_hf(hf)
  local id = hf.id
  if id < 0 then
    return false
  end
  -- TODO: Is there any way to create a new HF that makes this fail?
  for i = 0, #df.global.world.units.all - 1 do
    if df.global.world.units.all[i].hist_figure_id == id then
      return false
    end
  end
  return true
end

--[[
Gets a historical figure's native lect.

A historical figure's native lect is the native lect of their
civilization. Naturally, outsiders have no native lect.

Args:
  hf: A historical figure.

Returns:
  A lect, or nil if there is none.
]]
local function get_hf_native_lect(hf)
  print('hf native lect: hf.id=' .. hf.id)
  return get_civ_native_lect(df.historical_entity.find(hf.civ_id))
end

--[[
Gets all of a historical figure's lects.

Args:
  hf: A historical figure.

Returns:
  A sequence of lects the historical figure knows.
]]
local function get_hf_lects(hf)
  print('hf lects: hf.id=' .. hf.id)
  if not fluency_data[hf.id] then
    local lect = get_hf_native_lect(hf)
    if lect then
      set_fluency(hf.id, lect.community.id, MAXIMUM_FLUENCY)
    else
      fluency_data[hf.id] = {}
    end
  end
  local hf_lects = {}
  for civ_id, fluency_record in pairs(fluency_data[hf.id]) do
    if fluency_record.fluency == MAXIMUM_FLUENCY then
      for _, lect in pairs(lects) do
        if lect.community.id == civ_id then
          table.insert(hf_lects, lect)
          break
        end
      end
    end
  end
  return hf_lects
end

--[[
Gets all of a unit's lects.

If the unit is historical, it uses `get_hf_lects`. If not, it assumes
the unit knows only the native lect of their civilization.

Args:
  unit: A unit.

Returns:
  A sequence of lects the unit knows.
]]
local function get_unit_lects(unit)
  print('unit lects: unit.id=' .. unit.id)
  local _, hf = utils.linear_index(df.global.world.history.figures,
                                   unit.hist_figure_id, 'id')
  if hf then
    return get_hf_lects(hf)
  end
  print('unit has no hf')
  return {get_civ_native_lect(df.historical_entity.find(unit.civ_id))}
end

--[[
Gets the lect a report was spoken in.

Args:
  report: A report representing part of a conversation.

Returns:
  The lect of the report.
]]
local function get_report_lect(report)
  print('report lect: report.id=' .. report.id)
  local speaker = df.unit.find(report.unk_v40_3)
  -- TODO: Take hearers' lect knowledge into account.
  if speaker then
    local unit_lects = get_unit_lects(speaker)
    -- TODO: Don't always choose the first one.
    return unit_lects[1]
  end
end

local function initialize()
  load_phonologies()
  if not phonologies then
    qerror('At least one phonology must be defined.')
  end
  load_lects()
  if not fluency_data then
    load_fluency_data()
  end
  local entry2 = dfhack.persistent.get('babel/config2')
  -- TODO: why this truncation?
  if entry2 then
    local translations = df.global.world.raws.language.translations
    translations:insert(entry2.ints[1], translations[#translations - 1])
    translations:erase(#translations - 1)
  end
  local entry1 = dfhack.persistent.get('babel/config1')
  if not entry1 then
    entry1 = dfhack.persistent.save{key='babel/config1',
                                    ints={0, 0, 0, 0, 0, 0, 0}}
    -- TODO: Is there always exactly one generated translation, the last?
    entry2 = dfhack.persistent.save{
      key='babel/config2',
      ints={#df.global.world.raws.language.translations - 1}}
    expand_lexicons(create_word)
  end
  df.global.world.status.announcements:resize(0)
  df.global.world.status.reports:resize(0)
  -- TODO: popups
  next_report_index = 0
  region_x = -1
  region_y = -1
  region_z = -1
  unit_count = -1
  df.global.world.status.next_report_id = 0
end

local function handle_new_items(i, item_type)
  local entry1 = dfhack.persistent.get('babel/config1')
  local new_items = total_handlers.get[item_type]()
  if #new_items > entry1.ints[i] then
    print('\n' .. item_type .. ': ' .. #new_items .. '>' .. entry1.ints[i])
    for i = entry1.ints[i], #new_items - 1 do
      total_handlers.process_new[item_type](new_items[i], i)
    end
    entry1.ints[i] = #new_items
    entry1:save()
  end
end

function total_handlers.get.entities()
  return df.global.world.entities.all
end

function total_handlers.process_new.entities(entity, i)
  if entity.type == df.historical_entity_type.Civilization then
    create_lect(entity)
  end
  entity.name.nickname = 'Ent' .. i
end

function total_handlers.get.events()
  return df.global.world.history.events
end

--[[
Simulates the linguistic effects of a historical event.

This can modify anything related to translations or lects.

Args:
  event: A historical event.
]]
function total_handlers.process_new.events(event, i)
  if true then return end
  local loans = {}
  local civ1, civ2
  if (df.history_event_war_attacked_sitest:is_instance(event) or
      df.history_event_war_destroyed_sitest:is_instance(event) or
      df.history_event_war_field_battlest:is_instance(event)) then
    loan_words(event.attacker_civ, event.defender_civ, WAR)
    loan_words(event.defender_civ, event.attacker_civ, WAR)
  --[=[ TODO: Do these ever happen?
  elseif df.history_event_first_contactst:is_instance(event) then
    loan_words(event.contactor, event.contacted, GENERAL)
    loan_words(event.contacted, event.contactor, GENERAL)
  elseif df.history_event_topicagreement_madest:is_instance(event) then
    -- TODO: should depend on the topic
    loan_words(event.source, event.destination, TRADE)
    loan_words(event.destination, event.source, TRADE)
  elseif df.history_event_merchantst:is_instance(event) then
    -- TODO: should depend on flags2
    loan_words(event.source, event.destination, GENERAL)
    loan_words(event.source, event.destination, TRADE)
    loan_words(event.destination, event.source, TRADE)
  elseif df.history_event_entity_incorporatedst:is_instance(event) then
    -- TODO: migrant_entity no longer speaks their lect
  elseif df.history_event_masterpiece_createdst:is_instance(event) then
    --[[TODO: maker_entity coins word for item/building type
    civ1 = event.maker_entity
    topics.new = CIV1
    table.insert(referrents, )
    ]]
  ]=]
  elseif df.history_event_war_plundered_sitest:is_instance(event) then
    loan_words(event.attacker_civ, event.defender_civ, TRADE)
  elseif df.history_event_war_site_taken_overst:is_instance(event) then
    --[[TODO: What happens to the original inhabitants?
    civ1 = event.attacker_civ
    civ2 = event.defender_civ
    topics.government = CIV2
    topics.general = CIV1
    ]]
  elseif df.history_event_hist_figure_abductedst:is_instance(event) then
    --[[TODO: Does this include goblin child-snatching?
    civ1 = df.historical_figure.find(event.target).civ_id
    civ2 = df.historical_figure.find(event.snatcher).civ_id
    ]]
  elseif df.history_event_item_stolenst:is_instance(event) then
    --[[TODO: thief (histfig?)'s entity takes item/item_subtype words from entity
    civ1 = df.historical_figure.find(event.histfig).civ_id
    civ2 = entity
    topics.specific = CIV1
    table.insert(referrents, )
    ]]
  end
end

function total_handlers.get.historical_figures()
  return df.global.world.history.figures
end

--[[
Nicknames a historical figure.

Args:
  historical_figure! A historical figure.
]]
function total_handlers.process_new.historical_figures(historical_figure)
  if is_unprocessed_hf(historical_figure) then
    historical_figure.name.nickname = 'Hf' .. historical_figure.id
  end
end

function total_handlers.get.sites()
  return df.global.world.world_data.sites
end

function total_handlers.process_new.sites(site, i)
  site.name.nickname = 'S' .. i
end

function total_handlers.get.artifacts()
  return df.global.world.artifacts.all
end

function total_handlers.process_new.artifacts(artifact, i)
  artifact.name.nickname = 'A' .. i
end

function total_handlers.get.regions()
  return df.global.world.world_data.regions
end

function total_handlers.process_new.regions(region, i)
  region.name.nickname = 'Reg' .. i
end

local function get_new_turn_counts(reports)
  local new_turn_counts = {}
  for i = next_report_index, #reports - 1 do
    print('r' .. i .. ': ' .. reports[i].text)
    local conversation_id = reports[i].unk_v40_1
    if conversation_id ~= -1 and not reports[i].flags.continuation then
      new_turn_counts[conversation_id] =
        (new_turn_counts[conversation_id] or 0) + 1
    end
  end
  return new_turn_counts
end

local function update_fluency(acquirer, report_lect)
  local fluency_record =
    get_fluency(acquirer.hist_figure_id, report_lect.community.id)
  fluency_record.fluency = math.min(
    MAXIMUM_FLUENCY, fluency_record.fluency + math.ceil(
      acquirer.status.current_soul.mental_attrs.LINGUISTIC_ABILITY.value /
      UTTERANCES_PER_XP))
  print('strength <-- ' .. fluency_record.fluency)
  if fluency_record.fluency == MAXIMUM_FLUENCY and not HACK_FOR_QUICK_TEST then
    dfhack.gui.showAnnouncement(
      'You have learned the language of ' ..
      dfhack.TranslateName(report_lect.community.name) .. '.',
      COLOR_GREEN)
  end
end

--[[
Gets the participants in a conversation.

Args:
  report: A report.
  conversation: The conversation the report comes from.

Returns:
  The speaker of the report as a unit.
  The hearers of the report as a sequence of units.
]]
local function get_participants(report, conversation)
  local speaker_id = report.unk_v40_3
  local participants = conversation.participants
  local speaker = df.unit.find(speaker_id)
  -- TODO: hearer doesn't always exist.
  -- TODO: Solution: cache all <activity_event_conversationst>s' participants.
  -- TODO: Get all the hearers.
  local hearer = #participants > 1 and df.unit.find(
    participants[speaker_id == participants[0].unit_id and 1 or 0].unit_id)
  return speaker, {hearer}
end

--[[
Gets a conversation's participants and whether to abort it.

Args:
  report: A report.
  conversation: The conversation the report comes from.
  adventurer: The adventurer as a unit.

Returns:
  The initial part of the text of the report saying who says the report
    to whom.
  The speaker of the report as a unit.
  The hearers of the report as a sequence of units.
  Whether to force the conversation to end because the participants are
    not speaking the same language.
]]
local function get_participant_preamble(report, conversation, adventurer)
  -- TODO: Invalid for goodbyes: the data has been deleted by then.
  local speaker, hearers = get_participants(report, conversation)
  local should_abort = false
  local adventurer_is_hearer = utils.linear_index(hearers, adventurer)
  if adventurer_is_hearer or speaker == adventurer then
    -- TODO: df.global.ui_advmode.conversation.choices instead?
    conversation.menu = df.conversation_menu.RespondGoodbye
    if adventurer_is_hearer then
      -- TODO: unless this is the first turn of the conversation
      should_abort = true
    end
  end
  -- TODO: What if the adventurer knows the participants' names?
  local preamble = speaker == adventurer and 'You' or
    df.profession.attrs[speaker.profession].caption
  if speaker ~= adventurer and not adventurer_is_hearer then
    preamble = preamble .. ' (to ' ..
      (hearers[1] and df.profession.attrs[hearers[1].profession].caption or '?')
      .. ')'
    -- TODO: titles, if available, instead of professions
    -- TODO: descriptors like "squeaky-voiced"
  end
  return preamble .. ': ', speaker, hearers, should_abort
end

--[[
Breaks a string into lines.

Args:
  max_length: The maximum length of a line as a positive integer.
  text: A string.

Returns:
  The line-broken text as a sequence of strings.
]]
local function line_break(max_length, text)
  local lines = {''}
  local previous_space = ''
  for word, space in text:gmatch('([^ ]+)( *)') do
    local line_plus_space = lines[#lines] .. previous_space
    local line_plus_word = line_plus_space .. word
    if #line_plus_word <= max_length then
      lines[#lines] = line_plus_word
    elseif #word > max_length and #line_plus_space < max_length then
      local remainder_length = max_length - #line_plus_space
      lines[#lines] = line_plus_space .. word:sub(1, remainder_length)
      word = word:sub(remainder_length + 1)
      repeat
        lines[#lines + 1] = word:sub(1, max_length)
        word = word:sub(max_length + 1)
      until word == ''
    else
      lines[#lines + 1] = word
    end
    previous_space = space
  end
  return lines
end

if TEST then
  assert_eq(line_break(80, ''), {''})
  assert_eq(line_break(5, ' a  b  c '), {'a  b', 'c'})
  assert_eq(line_break(11, 'Lorem ipsum dolor sit amet.'),
    {'Lorem ipsum', 'dolor sit', 'amet.'})
  assert_eq(line_break(4, '123412341234'), {'1234', '1234', '1234'})
  assert_eq(line_break(4, '1234123412345'), {'1234', '1234', '1234', '5'})
  assert_eq(line_break(4, '0 123412341234'), {'0 12', '3412', '3412', '34'})
  assert_eq(line_break(4, '0 1234'), {'0', '1234'})
end

local function replace_turn(conversation_id, new_turn_counts, english, id_delta,
                            report, report_index, announcement_index,
                            adventurer, report_lect)
  local conversation = df.activity_entry.find(conversation_id).events[0]
  local turn = conversation.turns
  -- TODO: Investigate crash:
  -- attempt to perform arithmetic on field '?' (a nil value)
  turn = turn[#turn - new_turn_counts[conversation_id]]
  new_turn_counts[conversation_id] = new_turn_counts[conversation_id] - 1
  local continuation = false
  local preamble, speaker, hearers, should_abort =
    get_participant_preamble(report, conversation, adventurer)
  for _, line in ipairs(line_break(REPORT_LINE_LENGTH, preamble .. translate(
    report_lect, should_abort, turn.type, turn.anon_2, turn.anon_3, turn.anon_4,
    turn.unk_v4014_1, english, speaker, hearers)))
  do
    id_delta = id_delta + 1
    local new_report = {
      new=true,
      type=report.type,
      text=line,
      color=report.color,
      bright=report.bright,
      duration=report.duration,
      flags={new=true, continuation=continuation},
      repeat_count=report.repeat_count,
      id=report.id + id_delta,
      year=report.year,
      time=report.time,
      unk_v40_1=conversation_id,
      unk_v40_2=report.unk_v40_2,
      unk_v40_3=report.unk_v40_3,
    }
    continuation = true
    print('insert: index=' .. report_index .. ' length=' .. #df.global.world.status.reports)
    df.global.world.status.reports:insert(report_index, new_report)
    print('        "' .. line .. '"')
    print('        new length='..#df.global.world.status.reports)
    report_index = report_index + 1
    if announcement_index then
      df.global.world.status.announcements:insert(
        announcement_index, new_report)
      announcement_index = announcement_index + 1
    end
  end
  return id_delta, report_index, announcement_index
end

local function handle_new_units()
  local map = df.global.world.map
  local units = df.global.world.units.all
  if (region_x == map.region_x and
      region_y == map.region_y and
      region_z == map.region_z and
      unit_count == #units) then
    return
  end
  print(#units .. ' @ ' .. region_x .. ',' .. region_y .. ',' .. region_z)
  region_x = map.region_x
  region_y = map.region_y
  region_z = map.region_z
  unit_count = #units
  for i, unit in ipairs(units) do
    if unit.hist_figure_id == -1 then
      unit.name.nickname = 'U' .. i
    end
  end
end

local function handle_new_reports()
  local reports = df.global.world.status.reports
  if #reports <= next_report_index then
    return
  end
  print('\nreports: ' .. #reports .. '>' .. next_report_index)
  local new_turn_counts = get_new_turn_counts(reports)
  local announcements = df.global.world.status.announcements
  local id_delta = 0
  local i = next_report_index
  local english = ''
  while i < #reports do
--    print(i .. ' < ' .. #reports .. ' d=' .. id_delta)
    local report = reports[i]
    local announcement_index =
      reverse_linear_index(announcements, report.id, 'id')
    local conversation_id = report.unk_v40_1
    if conversation_id == -1 then
      print('  not a conversation: ' .. report.text)
      report.id = report.id + id_delta
      i = i + 1
      if announcement_index then
        announcement_index = announcement_index + 1
      end
    else
      local report_lect = get_report_lect(report)
      -- TODO: What if `report_lect == nil`?
      local adventurer = df.global.world.units.active[0]
      local adventurer_lects = get_unit_lects(adventurer)
      if not HACK_FOR_QUICK_TEST and utils.linear_index(adventurer_lects, report_lect) then
        print('  adventurer understands: ' .. report.text)
        report.id = report.id + id_delta
        i = i + 1
        if announcement_index then
          announcement_index = announcement_index + 1
        end
      else
        english = english .. (english == '' and '' or ' ') .. report.text
        reports:erase(i)
        if announcement_index then
          announcements:erase(announcement_index)
        end
        id_delta = id_delta - 1
        if i == #reports or not reports[i].flags.continuation then
          id_delta, i, announcement_index = replace_turn(conversation_id, new_turn_counts, english, id_delta, report, i, announcement_index, adventurer, report_lect)
          english = ''
          if report_lect then
            update_fluency(adventurer, report_lect)
          end
        end
      end
    end
  end
  next_report_index = i
  df.global.world.status.next_report_id = i
end

local function run()
  for i, item_type in ipairs(total_handlers.types) do
    handle_new_items(i, item_type)
  end
  handle_new_units()
  handle_new_reports()
  local viewscreen = dfhack.gui.getCurViewscreen()
  if dfhack.gui.getFocusString(viewscreen) == 'option' then
    -- Only write files right before retiring or abandoning.
    if (viewscreen.in_retire_adv == 1 or
        viewscreen.in_retire_dwf_abandon_adv == 1 or
        viewscreen.in_abandon_dwf == 1 or
        viewscreen.options[viewscreen.sel_idx] ==
          df.viewscreen_optionst.T_options.AbortRetire or
        viewscreen.options[viewscreen.sel_idx] ==
          df.viewscreen_optionst.T_options.Abandon) then
      if dirty then
        write_fluency_data()
        write_lect_files()
        overwrite_language_files()
        dirty = false
      end
    end
  else
    dirty = true
  end
end

local function finalize()
  phonologies = nil
  lects = nil
  fluency_data = nil
end

local function main()
  if dfhack.isMapLoaded() then
    if not phonologies then
      initialize()
    end
    run()
  elseif phonologies then
    finalize()
  end
  if enabled then
    timer = dfhack.timeout(1, 'frames', main)
  end
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
  args = {dfhack_flags.enable_state and 'start' or 'stop'}
end
if #args >= 1 then
  if args[1] == 'start' then
    enabled = true
    dfhack.with_suspend(main)
  elseif args[1] == 'stop' then
    enabled = false
    dfhack.timeout_active(timer)
  elseif args[1] == 'functions' then
    local own_path
    for path, script in pairs(dfhack.internal.scripts) do
      if script.env == _ENV then
        own_path = path
        break
      end
    end
    if own_path then
      local file = io.open(own_path)
      local name
      local graph = {}
      for line in file:lines() do
        line = line:gsub('%-%-.*', '')
        if line == 'end' then
          name = nil
        end
        local match = line:match('^local function ([%w_]+)%(')
        if match then
          name = match
        else
          match = line:match('^([%w_]+)[.%w_]* = function%(')
          if match then
            name = match
          else
            for match in line:gmatch('([.%w_]+)%(') do
              if match and name then
                match = match:match('[%w_]+')
                if not graph[name] then
                  graph[name] = {}
                end
                if match and name ~= match then
                  graph[name][match] = true
                end
              end
            end
          end
        end
      end
      file:close()
      for f, calls in pairs(graph) do
        for call in pairs(calls) do
          if not graph[call] then
            calls[call] = nil
          end
        end
        if not next(calls) then
          graph[f] = nil
        end
      end
      for f, calls in pairs(graph) do
        print(f)
        for call in pairs(calls) do
          print('  ' .. call)
        end
      end
    else
      qerror('Cannot find the path to this script')
    end
  elseif args[1] == 'test' then
    finalize()
    initialize()
    --[[
    phonologies = nil
    load_phonologies()
    local morpheme = m{2, features={n=1}}
    local lect = {seed=0x8d168, community={race=466}, phonology=phonologies[1],
                  morphemes={}, constituents={}}
    for _, ps in ipairs(get_parameters(lect).inventory) do
      --print(ps[2], get_lemma(phonologies[1], {ps[1]}))
    end
    for i = 1, 30 do
      local constituent, morphemes, lemma = random_word(lect, tostring(i))
      print(lemma)
    end
    ]]
  else
    usage()
  end
else
  usage()
end
