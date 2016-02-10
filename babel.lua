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

local REPORT_LINE_LENGTH = 73
local DEFAULT_NODE_PROBABILITY_GIVEN_PARENT = 0.5
local MINIMUM_FLUENCY = -32768
local MAXIMUM_FLUENCY = 32767
local UTTERANCES_PER_XP = 16
local MINIMUM_DIMENSION_CACHE_SIZE = 32
local WORD_SEPARATOR = ' '
local MORPHEME_SEPARATOR = nil
local WORD_ID_CHAR = '/'

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

if enabled == nil then
  enabled = false
end
local dirty = true

--[[
Data definitions:

Lect:
A language or dialect.
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
All the IDs, features, and feature values of all morphemes and
constituents in a lect must contain no characters invalid in raw tags.
Morpheme IDs must be positive integers such that `morphemes` is a
sequence, and the others must be strings.

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
  strategies: A map from features to movement strategies or nil.
  overt_trace: Whether the language keeps traces in the phonological
    form.
  swap: Whether the language is head-final.

Movement strategy:
What sort of movement to do when checking a certain feature.
  lower: Whether to lower rather than raise.
  pied_piping: Whether to pied-pipe the constituents dominated by the
    maximal projection of the moving constituent along with it.

Context:
A table containing whatever is necessary to complete a syntax tree based
on the speaker, hearer, and any other non-constant information which may
differ between utterances of basically the same sentence. See
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
  maximal: The maximal projection of this constituent, or nil if none.
  moved_to: The constituent to which this constituent was moved, or nil
    if none.
  text: A string to use verbatim in the output. If this is non-nil, then
    `features` and `morphemes` must both be empty.
  context_key: A key to look up in a context. At most one of `n1`,
    `word`, `text`, and `context_key` can be non-nil.
  context_callback: A function returning a constituent to replace
    this one given `context[context_key]` where `context` is a context.
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
Merge two sequences without duplicates sorted in increasing order.

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
  local inventory =
    get_dimension_values(rng, get_dimension(rng, phonology, creature))
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
  cached_parameters = lect.parameters
  return lect.parameters
end

--[[
TODO
]]
local function contextualize(constituent, context)
  local context_key = constituent.context_key
  if context_key then
    return constituent.context_callback(context[context_key])
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

local function ps_xp(ps)
  local c = x{
    ps.head or x{},
    ps.complement or x{},
  }
  for i = #ps, 1, -1 do
    c = x{ps[i], c}
  end
  return xp{ps.specifier or x{}, c}
end

local function ps_clause(ps)
  return xp{  -- CP
    x{f={wh=false}},
    x{
      x{f={q=true}},
      ps[1],
    },
  }
end

local function ps_infl(ps)
  -- TODO: more inflections: aspect, voice, mood, AgrO, AgrIO...
  -- TODO: Make some levels optional; e.g. no vP => no AgrOP.
  -- TODO: Add features for Case etc. so movement will happen.
  local small_vp = ps_xp{  -- vP
    specifier=ps.agent,
    complement=ps_xp{  -- VP
      specifier=ps.theme,
      complement=ps.predicate,
    },
  }
  local negp = ps.neg and ps_xp{
    head=ps.neg,
    complement=small_vp,
  } or small_vp
  return ps_xp{  -- AgrSP
    complement=ps_xp{  -- TP
      head=ps.tense,
      complement=negp,
    },
  }
end

local function cc_pronoun(c)
  local person = 1
  if not utils.linear_index(c[3], c[1]) then
    person = 2
    for _, e in ipairs(c[3]) do
      if not utils.linear_index(c[2], e) then
        person = 3
        break
      end
    end
    person = person
  end
  -- TODO: gender, clusivity, distance, formality, social status, bystanderness
  return ps_xp{  --DP
    head=k{person=person, number=#c[3]}'PRONOUN'
  }
end

--[[
Gets a constituent for an utterance.

Args:
  force_goodbye: Whether to force a goodbye.
  topic: A `talk_choice_type`.
  topic1: An integer whose exact interpretation depends on `topic`.
  topic2: Ditto.
  topic3: Ditto.
  topic4: Ditto.
  english: The English text of the utterance.

Returns:
  The constituent corresponding to the utterance.
  The context in which the utterance was produced.
]]
local function get_constituent(force_goodbye, topic, topic1, topic2, topic3,
                               topic4, english, speaker, hearer)
  -- TODO: Double spaces may be collapsed when concatenating reports.
  -- TODO: [LISP]ing multiplies <s>es.
  -- TODO: The first non-whitespace character of a sentence is capitalized.
  -- TODO: So don't rely on the exact contents of `english`.
  local constituent
  local context = {
    speaker={speaker, {hearer}, {speaker}},
    it={speaker, {hearer}, {true}},
  }
  if force_goodbye then
    ----
  elseif topic == df.talk_choice_type.Greet then
    ----
    -- "Hey" / "Hello" / "Greetings" / "Salutations"
    -- etc.
  elseif topic == df.talk_choice_type.Nevermind then
    -- N/A
  elseif topic == df.talk_choice_type.Trade then
    -- "Let's trade."
  elseif topic == df.talk_choice_type.AskJoin then
    -- N/A
  elseif topic == df.talk_choice_type.AskSurroundings then
    -- "Tell me about this area."
  elseif topic == df.talk_choice_type.SayGoodbye then
    ----
    -- "Goodbye."
  elseif topic == df.talk_choice_type.AskStructure then
    -- only when in a structure?
  elseif topic == df.talk_choice_type.AskFamily then
    -- "Tell me about your family."
  elseif topic == df.talk_choice_type.AskProfession then
    -- "You look like a mighty warrior indeed."
  elseif topic == df.talk_choice_type.AskPermissionSleep then
    -- crash!
  elseif topic == df.talk_choice_type.AccuseNightCreature then
    -- "Whosoever would blight the world, preying on the helpless, fear me!  I call you a child of the night and will slay you where you stand."
  elseif topic == df.talk_choice_type.AskTroubles then
    -- "How have things been?" / "How's life here?"
  elseif topic == df.talk_choice_type.BringUpEvent then
    -- ?
  elseif topic == df.talk_choice_type.SpreadRumor then
    -- ?
  elseif topic == df.talk_choice_type.ReplyGreeting then
    ----
    -- "Hello"
    -- ".  It is good to see you."
    -- ?
  elseif topic == df.talk_choice_type.RefuseConversation then
    -- "You are my neighbor."
    -- ?
  elseif topic == df.talk_choice_type.ReplyImpersonate then
    -- "Behold mortal.  I am "
    -- "a divine being"
    -- ".  I know why you have come."
  elseif topic == df.talk_choice_type.BringUpIncident then
    ----
    -- ?
  elseif topic == df.talk_choice_type.TellNothingChanged then
    -- "It has been the same as ever."
  elseif topic == df.talk_choice_type.Goodbye2 then
    ----
    -- "Goodbye."
  elseif topic == df.talk_choice_type.ReturnTopic then
    -- N/A
  elseif topic == df.talk_choice_type.ChangeSubject then
    -- N/A
  elseif topic == df.talk_choice_type.AskTargetAction then
    -- "What will you do about it?"
  elseif topic == df.talk_choice_type.RequestSuggestAction then
    -- "What should I do about it?"
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
  elseif topic == df.talk_choice_type.StateOpinion then
    ----
    if topic1 == 0 then
      -- "This must be stopped by any means at our disposal."
      -- / "They must be stopped by any means at our disposal."
    elseif topic1 == 1 then
      -- "It's not my problem."
    elseif topic1 == 2 then
      -- "It was inevitable."
    elseif topic1 == 3 then
      -- "This is the life for me."
    elseif topic1 == 4 then
      -- "It is terrifying."
      constituent =
        ps_clause{
          ps_infl{
            tense=k'PRESENT',
            agent={context_key='it', context_callback=cc_pronoun},
            predicate=k'terrifying',
          },
        }
    elseif topic1 == 5 then
      -- "I don't know anything about that."
      constituent =
        ps_clause{
          ps_infl{
            tense=k'PRESENT',
            neg=k'not',
            agent={context_key='speaker', context_callback=cc_pronoun},
            predicate=k'know',
            theme=ps_xp{
              head=k'any',
              complement=ps_xp{
                head=k'thing',
                complement=ps_xp{
                  head=k'about',
                  -- TODO: that
                  complement={context_key='it', context_callback=cc_pronoun},
                },
              },
            },
          },
        }
    elseif topic1 == 6 then
      -- "We are in the right in all matters."
    elseif topic1 == 7 then
      -- "It's for the best."
    elseif topic1 == 8 then
      -- "I don't care one way or another."
    elseif topic1 == 9 then
      -- "I hate it." / "I hate them."
    elseif topic1 == 10 then
      -- "I am afraid of it." / "I am afraid of them."
    elseif topic1 == 12 then
      -- "That is sad but not unexpected."
    elseif topic1 == 12 then
      -- "That is terrible."
    elseif topic1 == 13 then
      -- "That's terrific!"
    else
      -- ?
    end
  elseif topic == 27 then  -- respond to invitation to insurrection
    -- topic1: invitation response
  elseif topic == 28 then
    -- "I'm with you on this."
  elseif topic == df.talk_choice_type.AllowPermissionSleep then
    -- "Uh... what was that?"
    -- ?
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
    ----
    -- "Please help me!"
  elseif topic == df.talk_choice_type.AskWhatHappened then
    -- "What happened?"
  elseif topic == df.talk_choice_type.AskBeRescued then
    -- "Come with me and I'll bring you to safety."
  elseif topic == df.talk_choice_type.SayNotRemember then
    -- "I don't remember clearly."
  elseif topic == 44 then
    -- "Thank you!"
  elseif topic == df.talk_choice_type.SayNoFamily then
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
    -- ?
  elseif topic == df.talk_choice_type.StateAge then
    -- "I'm "
    -- speaker's age in years
    -- "!"
  elseif topic == df.talk_choice_type.DescribeProfession then
    -- "I am "
    -- speaker's profession
    -- "."
  elseif topic == df.talk_choice_type.AnnounceNightCreature then
    -- "Fool!"
    -- Brag
  elseif topic == df.talk_choice_type.StateIncredulity then
    -- "What is this madness?  Calm yourself!"
  elseif topic == df.talk_choice_type.BypassGreeting then
    -- N/A
  elseif topic == df.talk_choice_type.AskCeaseHostilities then
    ----
    -- "Let us stop this pointless fighting!"
  elseif topic == df.talk_choice_type.DemandYield then
    ----
    -- "You must yield!"
  elseif topic == df.talk_choice_type.HawkWares then
    ----
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
    ----
    -- "Stop!  This isn't happening!"
  elseif topic == df.talk_choice_type.Yield then
    ----
    -- "I yield!  I yield!" / "We yield!  We yield!"
  elseif topic == df.talk_choice_type.ExpressOverwhelmingEmotion then
    ----
    -- topic1: emotion_type
    -- topic2: unit_thought_type
    -- topic3,4: various
  elseif topic == df.talk_choice_type.ExpressGreatEmotion then
    ----
    -- topic1: emotion_type
    -- topic2: unit_thought_type
    -- topic3,4: various
  elseif topic == df.talk_choice_type.ExpressEmotion then
    ----
    -- topic1: emotion_type
    -- topic2: unit_thought_type
    -- topic3,4: various
  elseif topic == df.talk_choice_type.ExpressMinorEmotion then
    ----
    -- topic1: emotion_type
    -- topic2: unit_thought_type
    -- topic3,4: various
  elseif topic == df.talk_choice_type.ExpressLackEmotion then
    ----
    -- topic1: emotion_type
    -- topic2: unit_thought_type
    -- topic3,4: various
  elseif topic == df.talk_choice_type.OutburstFleeConflict then
    ----
    -- "Help!  Save me!"
  elseif topic == df.talk_choice_type.StateFleeConflict then
    ----
    -- "I must withdraw!"
  elseif topic == df.talk_choice_type.MentionJourney then
    -- "I've forgotten what I was going to say..."
    -- ?
  elseif topic == df.talk_choice_type.SummarizeTroubles then
    ----
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
    -- crash!
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
    -- ? / "We will fight no more."
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
    -- ?
  elseif topic == df.talk_choice_type.DescribeRelation then
    -- ?
  elseif topic == 104 then
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
    -- hearthperson
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
    -- "Why are you traveling?"
  elseif topic == df.talk_choice_type.TellTravelReason then
    -- "I'm returning to my home in"
    -- "I'm going to"
    -- " to take up my position"
    -- " as"
    -- " to move into my new home with"
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
    -- ?
  elseif topic == df.talk_choice_type.CancelAgreement then
    -- "We can no longer travel together."
  elseif topic == df.talk_choice_type.SummarizeConflict then
    ----
    -- ?
  elseif topic == df.talk_choice_type.SummarizeViews then
    ----
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
    -- " trades directly with no fewer than"
    -- " other major settlements."
    -- "  The largest of these is"
    -- " engages in trade with"
    -- "There are"
    -- " villages which utilize the market here."
    -- "The villages"
    -- "The village"
    -- " is the only other settlement to utilize the market here."
    -- " utilize the market here."
    -- "This place is insulated from the rest of the world, at least in terms of trade."
    -- "The people of"
    -- " go to"
    -- " to trade."
    -- " other villages which utilize the market there."
    -- " is the only other settlement to utilize the market there."
    -- " also utilize the market there."
    -- ? "There's nothing organized here."
  elseif topic == df.talk_choice_type.RaiseAlarm then
    -- "Intruder!  Intruder!"
  elseif topic == df.talk_choice_type.DemandDropWeapon then
    ----
    -- "Drop the "
    -- topic1: item key
    -- "!"
  elseif topic == df.talk_choice_type.AgreeComplyDemand then
    ----
    -- "Okay!  I'll do it."
  elseif topic == df.talk_choice_type.RefuseComplyDemand then
    ----
    -- "Over my dead body!"
  elseif topic == df.talk_choice_type.AskLocationObject then
    -- "Where is the "
    -- topic1: item key
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
    ----
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
    ----
    -- "Look at the sky!  Are we in the Underworld?"
    -- "What an odd glow!"
    -- "At least it doesn't rain down here."
    -- "Is it raining?"
    -- "I have confidence in your abilities."
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
  elseif topic == df.talk_choice_type.AskAdopt then
    -- ?
  elseif topic == df.talk_choice_type.AgreeAdopt then
    -- ?
  elseif topic == df.talk_choice_type.RefuseAdopt then
    -- "I'm sorry, but I'm unable to help."
  elseif topic == df.talk_choice_type.RevokeService then
    -- "I am confused."
    -- ?
  elseif topic == df.talk_choice_type.InviteService then
    -- ?
  elseif topic == df.talk_choice_type.AcceptInviteService then
    -- ?
  elseif topic == df.talk_choice_type.RefuseShareInformation then
    -- "I'd rather not say."
  elseif topic == df.talk_choice_type.RefuseInviteService then
    -- "I cannot accept this honor.  I am sorry."
  elseif topic == df.talk_choice_type.RefuseRequestService then
    -- "You are not worthy of such an honor yet."
  elseif topic == df.talk_choice_type.OfferService then
    -- "Would you agree to become "
    -- "someone"
    -- " of "
    -- topic1: historical_entity key
    -- ", taking over my duties and responsibilities?"
  elseif topic == df.talk_choice_type.AcceptPositionService then
    -- "I accept this honor."
  elseif topic == df.talk_choice_type.RefusePositionService then
    -- "I am sorry, but I am otherwise disposed."
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
  elseif topic == 169 then  -- Ask about somebody (new menu)
    -- N/A
  elseif topic == 170 then
    -- "What can you tell me about "
    -- topic1: historical_figure key
    -- "?"
  elseif topic == 171 then  -- respond to question about someone
    -- topic1: historical_figure key
    -- ?
  elseif topic == 172 then
    -- "How are you feeling right now?"
  elseif topic == 173 then  -- Say something about your emotions or thoughts
    -- ?
  end
  if not constituent then
    -- TODO: This should never happen, once the above are all filled in.
    constituent = {text='... (' .. english .. ')', features={}, morphemes={}}
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
    features={f=1, g=2}, fusion={y=dummy}, dummy=dummy
  }
  local new_morpheme = copy_morpheme(morpheme)
  assert_eq(new_morpheme, morpheme)
  morpheme.features.f = 3
  assert_eq(new_morpheme.features.f, 1)
end

--[[
Copies a constituent deeply.

Args:
  constituent: A constituent.

Returns:
  A deep copy of the constituent.
]]
local function copy_constituent(constituent)
  local morphemes = {}
  if constituent.morphemes then
    for i, morpheme in ipairs(constituent.morphemes) do
      morphemes[i] = copy_morpheme(morpheme)
    end
  end
  return {
    n1=constituent.n1 and copy_constituent(constituent.n1),
    n2=constituent.n2 and copy_constituent(constituent.n2),
    features=copyall(constituent.features),
    morphemes=morphemes,
    is_phrase=constituent.is_phrase,
    depth=constituent.depth,
    ref=constituent.ref,
    maximal=constituent.maximal,
    moved_to=constituent.moved_to,
    text=constituent.text,
    context_key=constituent.context_key,
    context_callback=constituent.context_callback,
  }
end

if TEST then
  local constituent = {n1={features={f=1, g=2}, morphemes={m'x', m'y'}},
                       features={f=1, g=2}, morphemes={}, is_phrase=true}
  assert_eq(copy_constituent(constituent), constituent)
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
Make two constituents agree in re a feature and maybe merge them.

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
Does syntax, not including lowering or anything after.

Syntax involves expanding references to items in the lexicon, checking
syntactic features, and merging constituents by raising.

Args:
  constituent! A constituent.
  lexicon: A lexicon.
  parameters: A language parameter table.

Returns:
  `constituent`.
]]
local function do_syntax(constituent, lexicon, parameters)
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
      local replacement = lexicon[constituent.ref]
      if replacement then
        replacement = copy_constituent(replacement)
        if constituent.features then
          utils.fillTable(replacement.features, constituent.features)
        end
        return do_syntax(replacement, depth, sfis, maximal)
      elseif constituent.ref then
        dfhack.color(COLOR_YELLOW); printall(lexicon)
        qerror('No constituent with ID ' .. constituent.ref)
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
Fuse two morphemes in a sequence.

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
  lexicon: A lexicon.
  parameters: A language parameter table.

Returns:
  A sequence of utterables.
]]
function make_utterance(constituent, lexicon, parameters)
  local utterables = {}
  for _, utterable in ipairs(linearize(do_lowering(
    do_syntax(constituent, lexicon, parameters), parameters), parameters))
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

if TEST then
  assert_eq(
    spell_utterance(make_utterance(
      {features={}, morphemes={{text='a', pword={}, fusion={}, features={}},
                               {text='b', pword={}, fusion={}, features={}}}},
      {}, {strategies={}})),
    'a-b ')
  assert_eq(
    spell_utterance(make_utterance(
      x{x{m={m{[2]='a'}}},
        x{m={m{[2]='b'}}}},
      {}, {strategies={}})),
    'a b ')
  assert_eq(
    spell_utterance(make_utterance(
       x{x{m={m{[2]='a'}}},
         x{m={m{[2]='b'}}}},
      {}, {strategies={}, swap=true})),
    'b a ')
  assert_eq(
    spell_utterance(make_utterance(
      x{r'X', x{m={m{[2]='b'}}}},
      {X=r'Y', Y=x{m={m{[2]='z'}}}},
      {strategies={}})),
    'z b ')
  local n1 = x{f={f=1, g=2}, m={m{[2]='1'}, m{[2]='2'}}}
  local constituent =
    x{n1,
      x{x{m={m{[2]='3'}}},
        x{f={g=2}, m={m{[2]='4'}}, moved_to=n1}}}
  assert_eq(spell_utterance(make_utterance(constituent, {}, {strategies={}})),
            '1-2 3 ')
  assert_eq(spell_utterance(make_utterance(constituent, {},
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
  local q_lex = {foo=x{m={m{'foo'}}}, bar=x{m={m{'bar'}}}, baz=x{m={m{'baz'}}}}
  local q_params = {strategies={}}
  assert_eq(spell_utterance(make_utterance(q_sent, q_lex, q_params)),
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
    affix=true, after=true, dummy=en_do.morphemes[1]
  }}
  local en_you = {morphemes={m'you'}, features={}}
  local en_what = {features={}, morphemes={{id='what', text='what', pword={},
                                            features={wh=true}, fusion={}}}}
  local en_thing = {features={}, morphemes={m'thing'}}
  local en_lexicon = {PAST=en_past, ['not']=en_not, walk=en_walk, you=en_you,
                      what=en_what, thing=en_thing, ['do']=en_do}
  local en_parameters =
    {strategies={v={lower=true}, wh={pied_piping=true}, q={}, d={}}}
  local early_en_parameters = {strategies={v={}}}
  assert_eq(spell_utterance(make_utterance(xp{r'PAST', xp{x{r'walk'}}},
                                           en_lexicon, en_parameters)),
            'walk-ed ')
  local en_did_not_walk = xp{r'PAST', xp{r'not', xp{r'walk'}}}
  assert_eq(spell_utterance(make_utterance(en_did_not_walk, en_lexicon,
                                           en_parameters)),
            'did not walk ')
  assert_eq(spell_utterance(make_utterance(en_did_not_walk, en_lexicon,
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
                                           en_lexicon, en_parameters)),
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
  assert_eq(spell_utterance(make_utterance(en_you_did_thing, en_lexicon,
                                           en_parameters)),
            'you did thing ')
  local fr_lexicon = {
    beau=x{f={gender=false}, m={m{'beau'}}},
    vieux=x{f={gender=false}, m={m{'vieux'}}},
    femme=x{f={gender='FEM'}, m={m{'femme'}}},
  }
  local fr_parameters = {strategies={gender=nil}}
  local fr_belle_vieille_femme = ps_xp{
    r'beau',
    r'vieux',
    head=r'femme',
  }
  assert_eq(spell_utterance(make_utterance(fr_belle_vieille_femme, fr_lexicon,
                                           fr_parameters)),
            '[beau,gender=FEM] [vieux,gender=FEM] [femme,gender=FEM] ')
end

--[[
Translates an utterance into a lect.

Args:
  lect: The lect to translate into, or nil to skip translation.
  force_goodbye: Whether to force a goodbye.
  topic: A `talk_choice_type`.
  topic1: An integer whose exact interpretation depends on `topic`.
  topic2: Ditto.
  topic3: Ditto.
  topic4: Ditto.
  english: The English text of the utterance.

Returns:
  The text of the translated utterance.
]]
local function translate(lect, force_goodbye, topic, topic1, topic2, topic3,
                         topic4, english, speaker, hearer)
  print('translate ' .. tostring(lect) .. ' ' .. tostring(topic) .. '/' .. topic1 .. ' ' .. english)
  if not lect then
    return english
  end
  local constituent = contextualize(get_constituent(
    force_goodbye, topic, topic1, topic2, topic3, topic4, english, speaker,
    hearer))
  local utterables =
    make_utterance(constituent, lect.constituents, get_parameters(lect))
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
    return lect
  end
end

--[[
This sequence of constituent keys must be a superset of all the
constituent keys mentioned in `get_constituent` or in context callbacks
mentioned therein.
]]
local DEFAULT_CONSTITUENT_KEYS = {
  'PRESENT',
  'PRONOUN',
  'about',
  'any',
  'it',
  'know',
  'not',
  'terrifying',
  'thing',
}

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
  noun_sing: The singular noun form of the word in English, or '' or
    'n/a' if this word cannot be used as a singular noun.
  noun_plur: The pural noun form of the word in English, or '' or 'NP'
    if this word cannot be used as a plural noun.
  adj: The adjective form of the word in English, or '' or 'n/a' if this
    word cannot be used as an adjective.
]]
local function create_word(_1, _2, word_id, noun_sing, noun_plur, adj)
  local words = df.global.world.raws.language.words
  words:insert('#', {new=true, word=word_id})
  local word = words[#words - 1]
  local str = word.str
  local has_noun_sing = false
  local has_noun_plur = false
  local noun_str
  if noun_sing ~= '' and noun_sing ~= 'n/a' then
    has_noun_sing = true
  end
  if noun_plur ~= '' and noun_plur ~= 'NP' then
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
    word.flags.of_noun_sing = true
    str:insert('#', {new=true, value='[FRONT_COMPOUND_NOUN_SING]'})
    str:insert('#', {new=true, value='[REAR_COMPOUND_NOUN_SING]'})
    str:insert('#', {new=true, value='[THE_NOUN_SING]'})
    str:insert('#', {new=true, value='[THE_COMPOUND_NOUN_SING]'})
    str:insert('#', {new=true, value='[OF_NOUN_SING]'})
  end
  if has_noun_plur then
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
  if adj ~= '' and adj ~= 'n/a' then
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
      print('civ ' .. lect.community.id, resource_id, lemma)
      lect.lemmas.words[utils.linear_index(
        df.global.world.raws.language.words, word_id, 'word')].value =
        escape(lemma)
      return
    end
  end
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
    Any of these arguments can be ignored.
]]
local function expand_lexicons(f)
  local raws = df.global.world.raws
  for _, topic in pairs(DEFAULT_CONSTITUENT_KEYS) do
    f(0, {function(civ) return {0} end}, WORD_ID_CHAR .. topic, '', '', '')
  end
  --[[
  for _, topic in ipairs(df.talk_choice_type) do
    if topic then
      f(0, {function(civ) return {0} end}, WORD_ID_CHAR .. topic, '', '', '')
    end
  end
  ]]
  for i, inorganic in ipairs(raws.inorganics) do
    f(i,
      {function(civ) return civ.resources.metals end,
       function(civ) return civ.resources.stones end,
       function(civ) return civ.resources.gems end},
      'INORGANIC' .. WORD_ID_CHAR .. inorganic.id,
      inorganic.material.state_name.Solid,
      '',
      inorganic.material.state_adj.Solid)
  end
  for _, plant in ipairs(raws.plants.all) do
    f(plant.anon_1,
      {function(civ) return civ.resources.tree_fruit_plants end,
       function(civ) return civ.resources.shrub_fruit_plants end},
      'PLANT' .. WORD_ID_CHAR .. plant.id,
      plant.name,
      plant.name_plural,
      plant.adj)
  end
  --[[
  for _, tissue in ipairs(raws.tissue_templates) do
    f(?, ?,
      'TISSUE_TEMPLATE' .. WORD_ID_CHAR .. tissue.id,
      tissue.tissue_name_singular,
      tissue.tissue_name_plural,
      '')
  end
  ]]
  for i, creature in ipairs(raws.creatures.all) do
    f(i,
      {function(civ) return {civ.race} end,
       function(civ) return civ.resources.fish_races end,
       function(civ) return civ.resources.fish_races end,
       function(civ) return civ.resources.egg_races end,
       function(civ) return civ.resources.animals.pet_races end,
       function(civ) return civ.resources.animals.wagon_races end,
       function(civ) return civ.resources.animals.pack_animal_races end,
       function(civ) return civ.resources.animals.wagon_puller_races end,
       function(civ) return civ.resources.animals.mount_races end,
       function(civ) return civ.resources.animals.minion_races end,
       function(civ) return civ.resources.animals.exotic_pet_races end},
      'CREATURE' .. WORD_ID_CHAR .. creature.creature_id,
      creature.name[0],
      creature.name[1],
      creature.name[2])
  end
  for _, weapon in ipairs(raws.itemdefs.weapons) do
    f(weapon.subtype,
      {function(civ) return civ.resources.digger_type end,
       function(civ) return civ.resources.weapon_type end,
       function(civ) return civ.resources.training_weapon_type end},
      'ITEM_WEAPON' .. WORD_ID_CHAR .. weapon.id,
      weapon.name,
      weapon.name_plural,
      '')
  end
  for _, trapcomp in ipairs(raws.itemdefs.trapcomps) do
    f(trapcomp.subtype,
      {function(civ) return civ.resources.trapcomp_type end},
      'ITEM_TRAPCOMP' .. WORD_ID_CHAR .. trapcomp.id,
       trapcomp.name,
       trapcomp.name_plural,
       '')
  end
  for _, toy in ipairs(raws.itemdefs.toys) do
    f(toy.subtype,
      {function(civ) return civ.resources.toy_type end},
      'ITEM_TOY' .. WORD_ID_CHAR .. toy.id,
      toy.name,
      toy.name_plural,
      '')
  end
  for _, tool in ipairs(raws.itemdefs.tools) do
    f(tool.subtype,
      {function(civ) return civ.resources.toy_type end},
      'ITEM_TOOL' .. WORD_ID_CHAR .. tool.id,
      tool.name,
      tool.name_plural,
      '')
  end
  for _, instrument in ipairs(raws.itemdefs.instruments) do
    f(instrument.subtype,
      {function(civ) return civ.resources.instrument_type end},
      'ITEM_INSTRUMENT' .. WORD_ID_CHAR .. instrument.id,
      instrument.name,
      instrument.name_plural,
      '')
  end
  for _, armor in ipairs(raws.itemdefs.armor) do
    f(armor.subtype,
      {function(civ) return civ.resources.armor_type end},
      'ITEM_ARMOR' .. WORD_ID_CHAR .. armor.id,
      armor.name,
      armor.name_plural,
      '')
  end
  for _, ammo in ipairs(raws.itemdefs.ammo) do
    f(ammo.subtype,
      {function(civ) return civ.resources.ammo_type end},
      'ITEM_AMMO' .. WORD_ID_CHAR .. ammo.id,
      ammo.name,
      ammo.name_plural,
      '')
  end
  for _, siege_ammo in ipairs(raws.itemdefs.siege_ammo) do
    f(siege_ammo.subtype,
      {function(civ) return civ.resources.siegeammo_type end},
      'ITEM_SIEGEAMMO' .. WORD_ID_CHAR .. siege_ammo.id,
      siege_ammo.name,
      siege_ammo.name_plural,
      '')
  end
  for _, glove in ipairs(raws.itemdefs.gloves) do
    f(glove.subtype,
      {function(civ) return civ.resources.gloves_type end},
      'ITEM_GLOVES' .. WORD_ID_CHAR .. glove.id,
      glove.name,
      glove.name_plural,
      '')
  end
  for _, shoe in ipairs(raws.itemdefs.shoes) do
    f(shoe.subtype,
      {function(civ) return civ.resources.shoes_type end},
      'ITEM_SHOES' .. WORD_ID_CHAR .. shoe.id,
      shoe.name,
      shoe.name_plural,
      '')
  end
  for _, shield in ipairs(raws.itemdefs.shields) do
    f(shield.subtype,
      {function(civ) return civ.resources.shield_type end},
      'ITEM_SHIELD' .. WORD_ID_CHAR .. shield.id,
      shield.name,
      shield.name_plural,
      '')
  end
  for _, helm in ipairs(raws.itemdefs.helms) do
    f(helm.subtype,
      {function(civ) return civ.resources.helm_type end},
      'ITEM_HELM' .. WORD_ID_CHAR .. helm.id,
      helm.name,
      helm.name_plural,
      '')
  end
  for _, pants in ipairs(raws.itemdefs.pants) do
    f(pants.subtype,
      {function(civ) return civ.resources.helm_type end},
      'ITEM_PANTS' .. WORD_ID_CHAR .. pants.id,
      pants.name,
      pants.name_plural,
      '')
  end
  --[[
  for _, food in ipairs(raws.itemdefs.food) do
    f(?, ?, 'ITEM_FOOD' .. WORD_ID_CHAR .. food.id, food.name, '', '')
  end
  for _, building in ipairs(raws.buildings.all) do
    f(?, ?, 'BUILDING' .. WORD_ID_CHAR .. building.id, building.name, '', '')
  end
  for _, builtin in ipairs(raws.mat_table.builtin) do
    if builtin then
      f(?, ?, 'BUILTIN' .. WORD_ID_CHAR .. builtin.id,
        builtin.state_name.Solid, '', builtin.state_adj.Solid)
    end
  end
  for _, syndrome in ipairs(raws.syndromes.all) do
    f(?, ?, 'SYNDROME' .. WORD_ID_CHAR .. syndrome.id, syndrome.syn_name,
      '', '')
  end
  ]]
  -- TODO: descriptors
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
                  scalar=0, strength=math.huge
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
  id: The constituent's ID, or nil if it is a top-level constituent.
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
  end
  if constituent.n2 then
    write_constituent(file, constituent.n2, depth + 1)
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
  end
  if constituent.text then
    file:write(indent, '\t[TEXT:', escape(constituent.text), ']\n')
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
          elseif subtags[1] == 'SEED' then
            if not current_lect then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            current_lect.seed = tonumber(subtags[2])
            if not current_lect.seed then
              qerror('The seed must be a number: ' .. current_lect.seed)
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
            elseif next(constituent_stack) and #subtags ~= 1
              or not next(constituent_stack) and #subtags ~= 2
            then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local current_constituent = constituent_stack[#constituent_stack]
            local new_constituent = {features={}, morphemes={}}
            if current_constituent then
              if current_constituent.n1 then
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
            if subtags[2] then
              current_lect.constituents[subtags[2]] = new_constituent
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
          elseif subtags[1] == 'TEXT' then
            if not next(constituent_stack) then
              qerror('Orphaned tag: ' .. tag)
            elseif #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            constituent_stack[#constituent_stack].text = subtags[2]
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
  {prefix='ITEM_GLOVES;', type=df.itemdef_glovesst, id='id',
   get=function(civ) return civ.resources.gloves_type end},
  {prefix='ITEM_SHOES;', type=df.itemdef_shoesst, id='id',
   get=function(civ) return civ.resources.shoes_type end},
  {prefix='ITEM_PANTS;', type=df.itemdef_pantsst, id='id',
   get=function(civ) return civ.resources.pants_type end},
  {prefix='ITEM_TOY;', type=df.itemdef_toyst, id='id',
   get=function(civ) return civ.resources.toy_type end},
  {prefix='ITEM_INSTRUMENT;', type=df.itemdef_instrumentst, id='id',
   get=function(civ) return civ.resources.instrument_type end},
  {prefix='ITEM_TOOL;', type=df.itemdef_toolst, id='id',
   get=function(civ) return civ.resources.tool_type end},
  {prefix='PLANT;', type=df.plant_raw, id='id',
   get=function(civ) return civ.resources.tree_fruit_plants end},
  {prefix='PLANT;', type=df.plant_raw, id='id',
   get=function(civ) return civ.resources.shrub_fruit_plants end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.pet_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.mount_races end}
}

local TRADE = {
  {prefix='ITEM_WEAPON;', type=df.itemdef_weaponst, id='id',
   get=function(civ) return civ.resources.digger_type end},
  {prefix='ITEM_WEAPON;', type=df.itemdef_weaponst, id='id',
   get=function(civ) return civ.resources.training_weapon_type end},
  {prefix='ITEM_GLOVES;', type=df.itemdef_glovesst, id='id',
   get=function(civ) return civ.resources.gloves_type end},
  {prefix='ITEM_SHOES;', type=df.itemdef_shoesst, id='id',
   get=function(civ) return civ.resources.shoes_type end},
  {prefix='ITEM_PANTS;', type=df.itemdef_pantsst, id='id',
   get=function(civ) return civ.resources.pants_type end},
  {prefix='ITEM_TOY;', type=df.itemdef_toyst, id='id',
   get=function(civ) return civ.resources.toy_type end},
  {prefix='ITEM_INSTRUMENT;', type=df.itemdef_instrumentst, id='id',
   get=function(civ) return civ.resources.instrument_type end},
  {prefix='ITEM_TOOL;', type=df.itemdef_toolst, id='id',
   get=function(civ) return civ.resources.tool_type end},
  {prefix='INORGANIC;', type=df.inorganic_raw, id='id',
   get=function(civ) return civ.resources.metals end},
  {prefix='INORGANIC;', type=df.inorganic_raw, id='id',
   get=function(civ) return civ.resources.stones end},
  {prefix='INORGANIC;', type=df.inorganic_raw, id='id',
   get=function(civ) return civ.resources.gems end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.fish_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.egg_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.pet_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.wagon_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.pack_animal_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.wagon_puller_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.mount_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.exotic_pet_races end}
}

local WAR = {
  {prefix='ITEM_WEAPON;', type=df.itemdef_weaponst, id='id',
   get=function(civ) return civ.resources.weapon_type end},
  {prefix='ITEM_ARMOR;', type=df.itemdef_armorst, id='id',
   get=function(civ) return civ.resources.armor_type end},
  {prefix='ITEM_AMMO;', type=df.itemdef_ammost, id='id',
   get=function(civ) return civ.resources.ammo_type end},
  {prefix='ITEM_HELM;', type=df.itemdef_helmst, id='id',
   get=function(civ) return civ.resources.helm_type end},
  {prefix='ITEM_SHIELD;', type=df.itemdef_shieldst, id='id',
   get=function(civ) return civ.resources.shield_type end},
  {prefix='ITEM_SIEGEAMMO;', type=df.itemdef_siegeammost, id='id',
   get=function(civ) return civ.resources.siegeammo_type end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return {civ.race} end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
   get=function(civ) return civ.resources.animals.mount_races end},
  {prefix='CREATURE;', type=df.creature_raw, id='creature_id',
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
  -- TODO: Take hearer's lect knowledge into account.
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
Simulate the linguistic effects of a historical event.

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

local function get_new_turn_counts(reports, conversation_id)
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
  if fluency_record.fluency == MAXIMUM_FLUENCY then
    dfhack.gui.showAnnouncement(
      'You have learned the language of ' ..
      dfhack.TranslateName(report_lect.community.name) .. '.',
      COLOR_GREEN)
  end
end

--[[
TODO
]]
local function get_participants(report, conversation)
  local speaker_id = report.unk_v40_3
  local participants = conversation.anon_1
  local speaker = df.unit.find(speaker_id)
  -- TODO: hearer doesn't always exist.
  -- TODO: Solution: cache all <activity_event_conversationst>s' participants.
  local hearer = #participants > 1 and df.unit.find(
    participants[speaker_id == participants[0].anon_1 and 1 or 0].anon_1)
  return speaker, hearer
end

--[[
TODO
]]
local function get_turn_preamble(report, conversation, adventurer)
  -- TODO: Invalid for goodbyes: the data has been deleted by then.
  local speaker, hearer = get_participants(report, conversation)
  local force_goodbye = false
  if speaker == adventurer or hearer == adventurer then
    -- TODO: Figure out why 7 makes "Say goodbye" the only available option.
    -- TODO: df.global.ui_advmode.conversation.choices instead?
    -- TODO: Cf. anon_15.
    conversation.anon_2 = 7
    if hearer == adventurer then
      force_goodbye = true
    end
  end
  -- TODO: What if the adventurer knows the participants' names?
  local text = speaker == adventurer and 'You' or
    df.profession.attrs[speaker.profession].caption
  if speaker ~= adventurer and hearer ~= adventurer then
    text = text .. ' (to ' ..
      (hearer and df.profession.attrs[hearer.profession].caption or '???')
      .. ')'
  end
  return text .. ': ', force_goodbye, speaker, hearer
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
  local turn = conversation.anon_9
  turn = turn[#turn - new_turn_counts[conversation_id]]
  new_turn_counts[conversation_id] = new_turn_counts[conversation_id] - 1
  local continuation = false
  local preamble, force_goodbye, speaker, hearer =
    get_turn_preamble(report, conversation, adventurer)
  for _, line in ipairs(line_break(REPORT_LINE_LENGTH, preamble .. translate(
    report_lect, force_goodbye, turn.anon_3, turn.anon_11, turn.anon_12,
    turn.anon_13, turn.unk_v4014_1, english, speaker, hearer)))
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
--    print(i .. ' / ' .. #reports .. ' +' .. id_delta)
    local report = reports[i]
    local announcement_index =
      utils.linear_index(announcements, report.id, 'id')
    local conversation_id = report.unk_v40_1
    if conversation_id == -1 then
      print('  not a conversation: ' .. report.text)
      report.id = report.id + id_delta
      i = i + 1
    else
      local report_lect = get_report_lect(report)
      -- TODO: What if `report_lect == nil`?
      local adventurer = df.global.world.units.active[0]
      local adventurer_lects = get_unit_lects(adventurer)
      if utils.linear_index(adventurer_lects, report_lect) then
        print('  adventurer understands: ' .. report.text)
        report.id = report.id + id_delta
        i = i + 1
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
        viewscreen.in_abandon_dwf == 1) then
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
    if timer then
      dfhack.timeout_active(timer)
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
