-- Adds languages.

local utils = require('utils')

--[[
TODO:
* Documentation: which sequences may be empty (i.e. not really Lua sequences)
* Put words in GEN_DIVINE.
* Update any new names in GEN_DIVINE to point to the moved GEN_DIVINE.
* Protect against infinite loops due to sonority dead ends in random_word.
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
* Ears required for oral languages and eyes for sign languages
* Language acquisition: babbling, jargon, holophrastic stage, telegraphic stage
* Effects of missing the critical period
* Creolization by kidnapped children
* Pidgins for merchants
* Orthography and spelling pronunciations
]]

local TEST = true

local DEFAULT_NODE_PROBABILITY_GIVEN_PARENT = 0.9375
local DEFAULT_IMPLICATION_PROBABILITY = 1
local MINIMUM_FLUENCY = -32768
local MAXIMUM_FLUENCY = 32767
local UTTERANCES_PER_XP = 16

local FEATURE_CLASS_NEUTRAL = 0
local FEATURE_CLASS_VOWEL = 1
local FEATURE_CLASS_CONSONANT = 2

local phonologies = nil
local parameter_sets = {}
local fluency_data = nil
local next_report_index = 0

if enabled == nil then
  enabled = false
end

--[[
Data definitions:

Language:
A persistent entry with the keys:
  value: The name of the language, for debugging.
  ints: A sequence of 4 integers:
    [1]: The number of this language among all languages.
    [2]: The ID of the associated civilization.
    [3]: The index of the language's phonology in `phonologies`.
    [4]: A random number generator seed for generating the language.

Phonology:
  constraints: A sequence of constraints.
  scalings: A sequence of scalings.
  nodes: A sequence of nodes.
  symbols: A sequence of symbols.

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
    token.
  bp_category: A body part category string. The unit must have a body
    part with this category.
  creature_index: An index into `df.global.world.raws.creatures.all`.
    The unit must be an instance of the creature at this index.
  creature_class: A creature class string. The unit must be an instance
    of a creature of this creature class.
  caste_index: An index into
    `df.global.world.raws.creatures.all[creature_index].caste`. The
    unit's caste must be at this index. If `creature_index` is nil,
    this field must be too.

Node:
  name: A string, used only for parsing the phonology raw file.
  parent: The index of the node's parent node in the associated
    phonology, or 0 if the parent is the root node.
  add: A string to append to the symbol of a phoneme that does not
    have this node to denote a phoneme that does have it but is
    otherwise identical.
  remove: The opposite of `add`.
  sonorous: Whether this node adds sonority to a phoneme that has it.
  feature_class: TODO: This should be used or removed.
  feature: Whether this node is a feature node, as opposed to a class
    node.
  prob: The probability that a phoneme has this node. It is 1 for class
    nodes.
  articulators: A sequence of articulators. At least one must be present
    in a unit for that unit to produce a phoneme with this node.

Language parameter table:
  inventory: A sequence of phonemes used by this language.
  min_sonority: The minimum sonority of all phonemes in `inventory`.
  max_sonority: The maximum sonority of all phonemes in `inventory`.

Environment:
A table whose keys are indices of features and whose values are feature
environments for those features.

Feature environment:
A sequence of two sequences, each of whose keys are variable indexes and
whose values are assignments. The two subsequences correspond to two
patterns in the scope of which the feature environment is being used.

Assignment:
A table representing a value bound to an variable name in an
environment.
  val: A boolean for whether this variable has the same value as the
    value of the variable that this variable is defined in terms of.
  var: The index of the variable that this variable is defined in
    terms of.

Word:
A sequence of phonemes.
-- TODO: for now, anyway

Phoneme:
A table whose keys are feature indices and whose values are booleans.

Dimension value:
A sequence of node indices sorted in increasing order.
  score: A score of how good this dimension value is. It only has
    meaning in comparison to other scores. A higher score means the
    dimension value is more likely to be chosen.
-- TODO: `score` is currently only used to filter out values with scores
-- of 0. It could also be used to decide which subdimension to pick a
-- new value from.

Indexed dimension value:
A pair of a dimension value and an index.
  i: The index of `candidate` in some unspecified sequence. This is only
    useful if a function specifies what the index means.
  candidate: A dimension value.

Scaling:
A scaling factor to apply to the score of dimension value when two of
its nodes have specific values.
  val_1: Whether `node_1` must be present for the scaling to apply.
  node_1: A node index.
  val_2: Whether `node_2` must be present for the scaling to apply.
  node_2: A node index.
  scalar: How much to scale the score of a phoneme by for which this
    scaling applies. It is non-negative.
  strength: How strong the scaling factor is as a function of scalar.
    A scalar of 0 gets the maximum strength, then the strength decreases
    monotonically for scalars from 0 to 1, with a minimum strength at 1,
    then increases monotonically for scalars greater than 1.
  prob: The probability that this scaling applies in a language. It is
    in the range [0, 1].

Dimension:
A producer of dimension values. A dimension may have two subdimensions
from whose cross product its values are drawn.
  id: An ID for debugging.
  cache: A sequence of dimension values.
  nodes: A sequence of the node indices covered by this dimension.
  d1: A dimension.
  d2: A dimension.
  values_1: A sequence of values chosen from `d1`.
  values_2: A sequence of values chosen from `d2`.
  scalings: A sequence of scalings which apply to the nodes of this
    dimension but not to either of its subdimensions'. That is, each
    scaling's `node_1` and `node_2` are present in `d1.nodes` and
    `d2.nodes`, respectively or vice versa.

Link:
A relationship between two dimensions, and how close the relationship
is. The details of the relationship are not specified here.
  d1: A dimension.
  d2: A dimension.
  scalings: A sequence of scalings which apply between the two
    dimensions. See `scalings` in dimension.
  strength: How strong the link is. See `strength` in scaling.

Boundary:
A string representing a boundary.
-- TODO: Enumerate them.

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
function usage()
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

function escape(str)
  return str:gsub('[\x00\n\r\x1a%%:%]]', function(c)
      return '%' .. string.format('%02X', string.byte(c))
    end)
end

if TEST then
  assert_eq(escape('<]:\r\n|%\x1a\x00>'), '<%5D%3A%0D%0A|%25%1A%00>')
end

function unescape(str)
  return str:gsub('%%[%da-fA-F][%da-fA-F]', function(c)
      return string.char(tonumber(c:sub(2), 16))
    end)
end

if TEST then
  assert_eq(unescape('(%5D%3A%0a|%25%1A)'), '(]:\n|%\x1a)')
end

--[[
Merge two sequences without duplicates sorted in increasing order.

Elements present in both input sequences are collapsed into one.

Args:
  s1: A sequence.
  s2: A sequence.

Returns:
  A merged sorted sequence.  
]]
function merge_sorted_sequences(s1, s2)
  local rv = {}
  for _, e in ipairs(s1) do
    table.insert(rv, e)
  end
  for _, e in ipairs(s2) do
    utils.insert_sorted(rv, e, nil, utils.compare)
  end
  return rv
end

if TEST then
  assert_eq(merge_sorted_sequences({1, 2, 5}, {-1, 3, 4, 5, 100}),
            {-1, 1, 2, 3, 4, 5, 100})
end

--[[
Translates an utterance into a language.

Args:
  language: The language to translate into
  topic: An integer corresponding to DFHack's `talk_choice_type` enum.
  topic1,
  topic2,
  topic3: Integers whose exact interpretation depends on `topic`.

Returns:
  The translated utterance.
]]
function translate(language, topic, topic1, topic2, topic3)
  print('translate ' .. tostring(topic) .. '/' .. topic1)
  local word
  if topic == true then
    word = 'FORCE_GOODBYE'
  elseif topic == df.talk_choice_type.Greet then
    word = 'GREETINGS'
  --[[
  elseif topic == df.talk_choice_type.Nevermind then
  elseif topic == df.talk_choice_type.Trade then
  elseif topic == df.talk_choice_type.AskJoin then
  elseif topic == df.talk_choice_type.AskSurroundings then
  ]]
  elseif topic == df.talk_choice_type.SayGoodbye then
    word = 'GOODBYE'
  --[[
  elseif topic == df.talk_choice_type.AskStructure then
  elseif topic == df.talk_choice_type.AskFamily then
  elseif topic == df.talk_choice_type.AskProfession then
  elseif topic == df.talk_choice_type.AskPermissionSleep then
  elseif topic == df.talk_choice_type.AccuseNightCreature then
  elseif topic == df.talk_choice_type.AskTroubles then
  elseif topic == df.talk_choice_type.BringUpEvent then
  elseif topic == df.talk_choice_type.SpreadRumor then
  elseif topic == df.talk_choice_type.ReplyGreeting then
  elseif topic == df.talk_choice_type.RefuseConversation then
  elseif topic == df.talk_choice_type.ReplyImpersonate then
  elseif topic == df.talk_choice_type.BringUpIncident then
  elseif topic == df.talk_choice_type.TellNothingChanged then
  elseif topic == df.talk_choice_type.Goodbye2 then
  elseif topic == df.talk_choice_type.ReturnTopic then
  elseif topic == df.talk_choice_type.ChangeSubject then
  elseif topic == df.talk_choice_type.AskTargetAction then
  elseif topic == df.talk_choice_type.RequestSuggestAction then
  elseif topic == df.talk_choice_type.AskJoinInsurrection then
  elseif topic == df.talk_choice_type.AskJoinRescue then
  ]]
  elseif topic == df.talk_choice_type.StateOpinion then
    if topic1 == 0 then
      word = 'VIOLENT'
    elseif topic1 == 2 then
      word = 'INEVITABLE'
    elseif topic1 == 4 then
      word = 'TERRIFYING'
    elseif topic1 == 8 then
      word = 'DONT_CARE'
    else
      -- TODO: more opinions
      word = 'OPINION'
    end
  -- elseif topic == 28 then
  -- elseif topic == 29 then
  --[[
  elseif topic == df.talk_choice_type.AllowPermissionSleep then
  elseif topic == df.talk_choice_type.DenyPermissionSleep then
  -- elseif topic == 32 then
  elseif topic == df.talk_choice_type.AskJoinAdventure then
  elseif topic == df.talk_choice_type.AskGuideLocation then
  elseif topic == df.talk_choice_type.RespondJoin then
  elseif topic == df.talk_choice_type.RespondJoin2 then
  elseif topic == df.talk_choice_type.OfferCondolences then
  elseif topic == df.talk_choice_type.StateNotAcquainted then
  elseif topic == df.talk_choice_type.SuggestTravel then
  elseif topic == df.talk_choice_type.SuggestTalk then
  elseif topic == df.talk_choice_type.RequestSelfRescue then
  elseif topic == df.talk_choice_type.AskWhatHappened then
  elseif topic == df.talk_choice_type.AskBeRescued then
  elseif topic == df.talk_choice_type.SayNotRemember then
  -- elseif topic == 45 then
  elseif topic == df.talk_choice_type.SayNoFamily then
  elseif topic == df.talk_choice_type.StateUnitLocation then
  elseif topic == df.talk_choice_type.ReferToElder then
  elseif topic == df.talk_choice_type.AskComeCloser then
  elseif topic == df.talk_choice_type.DoBusiness then
  elseif topic == df.talk_choice_type.AskComeStoreLater then
  elseif topic == df.talk_choice_type.AskComeMarketLater then
  elseif topic == df.talk_choice_type.TellTryShopkeeper then
  elseif topic == df.talk_choice_type.DescribeSurroundings then
  elseif topic == df.talk_choice_type.AskWaitUntilHome then
  elseif topic == df.talk_choice_type.DescribeFamily then
  elseif topic == df.talk_choice_type.StateAge then
  elseif topic == df.talk_choice_type.DescribeProfession then
  elseif topic == df.talk_choice_type.AnnounceNightCreature then
  elseif topic == df.talk_choice_type.StateIncredulity then
  elseif topic == df.talk_choice_type.BypassGreeting then
  elseif topic == df.talk_choice_type.AskCeaseHostilities then
  elseif topic == df.talk_choice_type.DemandYield then
  elseif topic == df.talk_choice_type.HawkWares then
  elseif topic == df.talk_choice_type.YieldTerror then
  elseif topic == df.talk_choice_type.Yield then
  elseif topic == df.talk_choice_type.ExpressOverwhelmingEmotion then
  elseif topic == df.talk_choice_type.ExpressGreatEmotion then
  elseif topic == df.talk_choice_type.ExpressEmotion then
  elseif topic == df.talk_choice_type.ExpressMinorEmotion then
  elseif topic == df.talk_choice_type.ExpressLackEmotion then
  elseif topic == df.talk_choice_type.OutburstFleeConflict then
  elseif topic == df.talk_choice_type.StateFleeConflict then
  elseif topic == df.talk_choice_type.MentionJourney then
  elseif topic == df.talk_choice_type.SummarizeTroubles then
  elseif topic == df.talk_choice_type.AskAboutIncident then
  elseif topic == df.talk_choice_type.AskDirectionsPerson then
  elseif topic == df.talk_choice_type.AskDirectionsPlace then
  elseif topic == df.talk_choice_type.AskWhereabouts then
  elseif topic == df.talk_choice_type.RequestGuide then
  elseif topic == df.talk_choice_type.RequestGuide2 then
  elseif topic == df.talk_choice_type.ProvideDirections then
  elseif topic == df.talk_choice_type.ProvideWhereabouts then
  elseif topic == df.talk_choice_type.TellTargetSelf then
  elseif topic == df.talk_choice_type.TellTargetDead then
  elseif topic == df.talk_choice_type.RecommendGuide then
  elseif topic == df.talk_choice_type.ProfessIgnorance then
  elseif topic == df.talk_choice_type.TellAboutPlace then
  elseif topic == df.talk_choice_type.AskFavorMenu then
  elseif topic == df.talk_choice_type.AskWait then
  elseif topic == df.talk_choice_type.AskFollow then
  elseif topic == df.talk_choice_type.ApologizeBusy then
  elseif topic == df.talk_choice_type.ComplyOrder then
  elseif topic == df.talk_choice_type.AgreeFollow then
  elseif topic == df.talk_choice_type.ExchangeItems then
  elseif topic == df.talk_choice_type.AskComeCloser2 then
  elseif topic == df.talk_choice_type.InitiateBarter then
  elseif topic == df.talk_choice_type.AgreeCeaseHostile then
  elseif topic == df.talk_choice_type.RefuseCeaseHostile then
  elseif topic == df.talk_choice_type.RefuseCeaseHostile2 then
  elseif topic == df.talk_choice_type.RefuseYield then
  elseif topic == df.talk_choice_type.RefuseYield2 then
  elseif topic == df.talk_choice_type.Brag then
  elseif topic == df.talk_choice_type.DescribeRelation then
  -- elseif topic == 105 then
  elseif topic == df.talk_choice_type.AnnounceLairHunt then
  elseif topic == df.talk_choice_type.RequestDuty then
  elseif topic == df.talk_choice_type.AskJoinService then
  elseif topic == df.talk_choice_type.AcceptService then
  elseif topic == df.talk_choice_type.TellRemainVigilant then
  elseif topic == df.talk_choice_type.GiveServiceOrder then
  elseif topic == df.talk_choice_type.WelcomeSelfHome then
  -- elseif topic == 113 then
  elseif topic == df.talk_choice_type.AskTravelReason then
  elseif topic == df.talk_choice_type.TellTravelReason then
  elseif topic == df.talk_choice_type.AskLocalRuler then
  elseif topic == df.talk_choice_type.ComplainAgreement then
  elseif topic == df.talk_choice_type.CancelAgreement then
  elseif topic == df.talk_choice_type.SummarizeConflict then
  elseif topic == df.talk_choice_type.SummarizeViews then
  elseif topic == df.talk_choice_type.AskClaimStrength then
  elseif topic == df.talk_choice_type.AskArmyPosition then
  elseif topic == df.talk_choice_type.AskOtherClaims then
  elseif topic == df.talk_choice_type.AskDeserters then
  elseif topic == df.talk_choice_type.AskSiteNeighbors then
  elseif topic == df.talk_choice_type.DescribeSiteNeighbors then
  elseif topic == df.talk_choice_type.RaiseAlarm then
  elseif topic == df.talk_choice_type.DemandDropWeapon then
  elseif topic == df.talk_choice_type.AgreeComplyDemand then
  elseif topic == df.talk_choice_type.RefuseComplyDemand then
  elseif topic == df.talk_choice_type.AskLocationObject then
  elseif topic == df.talk_choice_type.DemandTribute then
  elseif topic == df.talk_choice_type.AgreeGiveTribute then
  elseif topic == df.talk_choice_type.RefuseGiveTribute then
  elseif topic == df.talk_choice_type.OfferGiveTribute then
  elseif topic == df.talk_choice_type.AgreeAcceptTribute then
  elseif topic == df.talk_choice_type.RefuseAcceptTribute then
  elseif topic == df.talk_choice_type.CancelTribute then
  elseif topic == df.talk_choice_type.OfferPeace then
  elseif topic == df.talk_choice_type.AgreePeace then
  elseif topic == df.talk_choice_type.RefusePeace then
  elseif topic == df.talk_choice_type.AskTradeDepotLater then
  elseif topic == df.talk_choice_type.ExpressAstonishment then
  elseif topic == df.talk_choice_type.CommentWeather then
  elseif topic == df.talk_choice_type.CommentNature then
  elseif topic == df.talk_choice_type.SummarizeTerritory then
  elseif topic == df.talk_choice_type.SummarizePatrols then
  elseif topic == df.talk_choice_type.SummarizeOpposition then
  elseif topic == df.talk_choice_type.DescribeRefugees then
  elseif topic == df.talk_choice_type.AccuseTroublemaker then
  elseif topic == df.talk_choice_type.AskAdopt then
  elseif topic == df.talk_choice_type.AgreeAdopt then
  elseif topic == df.talk_choice_type.RefuseAdopt then
  elseif topic == df.talk_choice_type.RevokeService then
  elseif topic == df.talk_choice_type.InviteService then
  elseif topic == df.talk_choice_type.AcceptInviteService then
  elseif topic == df.talk_choice_type.RefuseShareInformation then
  elseif topic == df.talk_choice_type.RefuseInviteService then
  elseif topic == df.talk_choice_type.RefuseRequestService then
  elseif topic == df.talk_choice_type.OfferService then
  elseif topic == df.talk_choice_type.AcceptPositionService then
  elseif topic == df.talk_choice_type.RefusePositionService then
  elseif topic == df.talk_choice_type.InvokeNameBanish then
  elseif topic == df.talk_choice_type.InvokeNameService then
  elseif topic == df.talk_choice_type.GrovelMaster then
  elseif topic == df.talk_choice_type.DemandItem then
  elseif topic == df.talk_choice_type.GiveServiceReport then
  elseif topic == df.talk_choice_type.OfferEncouragement then
  elseif topic == df.talk_choice_type.PraiseTaskCompleter then
  ]]
  else
    -- TODO: This should never happen, once the above are uncommented.
    word = 'BLAH_BLAH_BLAH'
  end
  local languages = df.global.world.raws.language
  local word_index, _ = utils.linear_index(languages.words, 'REPORT;' .. word,
                                           'word')
  if not word_index then
    return topic .. '/' .. topic1 .. '/' .. topic2 .. '/' .. topic3
  end
  -- TODO: Capitalize the result.
  local phonology = phonologies[language.ints[3]]
  return get_lemma(phonology, optimize(
    parameter_sets[language.ints[2]], deserialize(
      math.ceil(#phonology.nodes / 8), unescape(
        languages.translations[language.ints[1]].words[word_index].value))))
end

function closest_phoneme(phoneme, inventory)
  -- TODO
  return phoneme
end

--[[
function best_candidate(constraint_index, constraints, original, candidate,
                        violation_counts)
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

function optimize(parameters, input, is_loan)
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
function update_binding(feature_env, lvalue_i, lvalue_var, new)
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
function equalize(a1, a2, feature_env)
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

function get_feature_set_overlap(overlap, phoneme_2, env)
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

function get_overlap(element_1, element_2, env)
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

function apply_unfix(alignment, unfix)
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

function substitute(alignment, env)
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

function get_alignments(index_1, constraint_1, index_2, constraint_2, alignment,
                        env, unfix, results)
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
function get_feeding_constraint(constraint_1, constraint_2, unfix)
  local feeding_constraints = {}
  get_alignments(1, constraint_1, 1, constraint_2, {delta=0}, {}, unfix,
                 feeding_constraints)
  return feeding_constraints
end

-- Get the markedness constraints describing the contexts in which
-- applying `fix` because of `constraints[original_constraint_index]`
-- feeds a violation of `fed_constraint`.
function get_feeding_constraints(fix, fed_constraint, constraints,
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

function features_worth_changing(pattern)
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

function next_fix(record, constraint_index, constraints)
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

function constraint_to_rules(constraint_index, constraints)
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

function constraints_to_rules(constraints)
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
Deserializes a word.

Args:
  bytes_per_phoneme: The number of bytes per serialized phoneme.
  str: A serialized word.

Returns:
  A word.
]]
function deserialize(bytes_per_phoneme, str)
  local word = {}
  local phoneme = {}
  for i = 1, #str do
    local code = str:byte(i)
    for b = 8, 1, -1 do
      table.insert(phoneme, (code % (2 ^ b)) >= (2 ^ (b - 1)))
    end
    if i % bytes_per_phoneme == 0 then
      table.insert(word, phoneme)
      phoneme = {}
    end
  end
  return word
end

if TEST then
  assert_eq(deserialize(1, ''), {})
  assert_eq(deserialize(1, '\x00'),
            {{false, false, false, false, false, false, false, false}})
  assert_eq(deserialize(1, '\x80'),
            {{true, false, false, false, false, false, false, false}})
  assert_eq(deserialize(1, '\x40'),
            {{false, true, false, false, false, false, false, false}})
  assert_eq(deserialize(1, '\x20'),
            {{false, false, true, false, false, false, false, false}})
  assert_eq(deserialize(1, '\x10'),
            {{false, false, false, true, false, false, false, false}})
  assert_eq(deserialize(1, '\x08'),
            {{false, false, false, false, true, false, false, false}})
  assert_eq(deserialize(1, '\x04'),
            {{false, false, false, false, false, true, false, false}})
  assert_eq(deserialize(1, '\x02'),
            {{false, false, false, false, false, false, true, false}})
  assert_eq(deserialize(1, '\x01'),
            {{false, false, false, false, false, false, false, true}})
  assert_eq(deserialize(2, '\x00\x80'),
            {{false, false, false, false, false, false, false, false, true,
              false, false, false, false, false, false, false}})
  assert_eq(deserialize(3, '\x00\x10\x00'),
            {{false, false, false, false, false, false, false, false, false,
              false, false, true, false, false, false, false, false, false,
              false, false, false, false, false, false}})
  assert_eq(deserialize(1, '\x7c'),
            {{false, true, true, true, true, true, false, false}})
  assert_eq(deserialize(1, '\x80\x80'),
            {{true, false, false, false, false, false, false, false},
             {true, false, false, false, false, false, false, false}})
end

--[[
Serializes a word.

Args:
  features_per_phoneme: The number of features per phoneme.
  word: A word.

Returns:
  An opaque string serialization of the word, which can be deserialized
    with `deserialize`.
]]
function serialize(features_per_phoneme, word)
  local str = ''
  for _, phoneme in pairs(word) do
    local byte = 0
    for i = 1, features_per_phoneme do
      if phoneme[i] then
        byte = byte + 2 ^ ((8 - i) % 8)
      end
      if i == features_per_phoneme or i % 8 == 0 then
        str = str .. string.format('%c', byte)
        byte = 0
      end
    end
  end
  return str
end

if TEST then
  assert_eq(serialize(8, {}), '')
  assert_eq(serialize(8, {{}}), '\x00')
  assert_eq(serialize(8, {{[1]=true}}), '\x80')
  assert_eq(serialize(8, {{[2]=true}}), '\x40')
  assert_eq(serialize(8, {{[3]=true}}), '\x20')
  assert_eq(serialize(8, {{[4]=true}}), '\x10')
  assert_eq(serialize(8, {{[5]=true}}), '\x08')
  assert_eq(serialize(8, {{[6]=true}}), '\x04')
  assert_eq(serialize(8, {{[7]=true}}), '\x02')
  assert_eq(serialize(8, {{[8]=true}}), '\x01')
  assert_eq(serialize(9, {{[9]=true}}), '\x00\x80')
  assert_eq(serialize(24, {{[12]=true}}), '\x00\x10\x00')
  assert_eq(serialize(8, {{false, true, true, true, true, true}}), '\x7c')
  assert_eq(serialize(8, {{true}, {true}}), '\x80\x80')
end

--[[
Gets the lemma of a word.

This is only useful in names. A Dwarf Fortress name has a list of
indices into a translation. To print the name, it concatenates the
strings at those indices. Therefore, there must be a human-readable form
of each word. This is why there are two translations for each new
language: one for first names (where the strings are immutable) and one
for reports (where anything is possible).

Args:
  phonology: A phonology.
  word: A word.

Returns:
  The lemma.
]]
function get_lemma(phonology, word)
  local str = ''
  for _, phoneme in pairs(word) do
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
      for i, node in pairs(phonology.nodes) do
        if phoneme[i] ~= (symbol_features[i] or false) then
          if node.add and phoneme[i] then
            symbol = symbol .. node.add
            score = score + 1
          elseif node.remove and not phoneme[i] then
            symbol = symbol .. node.remove
            score = score + 1
          end
        end
      end
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

if TEST then
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
Constructs a random phoneme.

Args:
  nodes: A sequence of nodes.
  rng: A random number generator to use to choose nodes.

Returns:
  A new random phoneme.
  The sonority of that phoneme.
]]
function random_phoneme(nodes, rng)
  local phoneme = {}
  local sonority = 0
  for _, node in pairs(nodes) do
    if (node.parent == 0 or phoneme[node.parent]) and rng:random(2) == 1 then
      table.insert(phoneme, true)
      if node.sonorous then
        sonority = sonority + 1
      end
    else
      table.insert(phoneme, false)
    end
  end
  return phoneme, sonority
end

--[[
Shuffles a sequence randomly.

Args:
  t: A sequence.
  rng: A random number generator.

Returns:
  A copy of `t`, randomly shuffled.
]]
function shuffle(t, rng)
  t = copyall(t)
  local j
  for i = #t, 2, -1 do
    j = rng:random(i) + 1
    t[i], t[j] = t[j], t[i]
  end
  return t
end

--[[
Randomly selects a subset of a sequence of scalings.

Args:
  rng: A random number generator.
  scalings: A sequence of scalings.

Returns:
  A subset of `scalings`.
]]
function random_scalings(rng, scalings)
  local rv = {}
  for _, scaling in ipairs(scalings) do
    if rng:drandom() < scaling.prob then
      table.insert(rv, scaling)
    end
  end
  return rv
end

--[[
Merges links that are between the same two dimensions.

If two links have the same dimensions, their `scalings` sequences are
merged. After merging, the whole sequence is sorted in increasing order
by link strength.

Args:
  links! A sequence of links.
]]
function merge_links(links)
  utils.sort_vector(links, nil, function(a, b)
      if a.d1.id > a.d2.id then
        a.d1, a.d2 = a.d2, a.d1
      end
      if b.d1.id > b.d2.id then
        b.d1, b.d2 = b.d2, b.d1
      end
      if a.d1.id < b.d1.id then
        return -1
      elseif a.d1.id > b.d1.id then
        return 1
      elseif a.d2.id < b.d2.id then
        return -1
      elseif a.d2.id > b.d2.id then
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
  utils.sort_vector(links, 'strength', utils.compare)
end

if TEST then
  local dim_1 = {id=1}
  local dim_2 = {id=2}
  local dim_3 = {id=3}
  local links = {{d1=dim_1, d2=dim_2, scalings={}, strength=1},
                 {d1=dim_1, d2=dim_3, scalings={}, strength=1},
                 {d1=dim_2, d2=dim_1, scalings={}, strength=2}}
  merge_links(links)
  assert_eq(links, {{d1=dim_1, d2=dim_3, scalings={}, strength=1},
                    {d1=dim_1, d2=dim_2, scalings={}, strength=3}})
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
function merge_dimensions(dimensions, links)
  if next(links) then
    local link = table.remove(links)
    local id = math.min(link.d1.id, link.d2.id)
    local dimension = {id=id, cache={}, nodes={}, d1=link.d1, d2=link.d2,
                       values_1={}, values_2={}, scalings=link.scalings}
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
    table.insert(dimensions, dimension)
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
    table.insert(dimensions, 1, {cache={}, nodes={}, d1=d1, d2=d2, values_1={},
                                 values_2={}, scalings={}})
  end
end

if TEST then
  local dim_1 = {id=1}
  local dim_2 = {id=2}
  local dim_3 = {id=3}
  local dim_5 = {id=5}
  local dimensions = {dim_3, dim_2, dim_5}
  local links = {{d1=dim_1, d2=dim_2, scalings={12}, strength=1},
                 {d1=dim_2, d2=dim_3, scalings={23}, strength=1}}
  merge_dimensions(dimensions, links)
  local dim_23 = {id=2, cache={}, nodes={}, d1=dim_2, d2=dim_3, values_1={},
                  values_2={}, scalings={23}}
  assert_eq({dim_5, dim_23}, dimensions)
  assert_eq({{d1=dim_1, d2=dim_23, scalings={12}, strength=1}}, links)
  merge_dimensions(dimensions, {})
  assert_eq({{cache={}, nodes={}, d1=dim_23, d2=dim_5, values_1={},
              values_2={}, scalings={}}}, dimensions)
end

--[[
Determines whether a creature has at least one of a set of articulators.

Args:
  creature_index: The index of a creature in
    `df.global.world.raws.creatures.all`.
  articulators: A possibly empty sequence of articulators.

Returns:
  Whether at least one articulator from `articulators` would be present
  in an unwounded `df.global.world.raws.creatures.all[creature_index]`,
  of no matter what caste; or true, if `articulators` is empty.
]]
function can_articulate(creature_index, articulators)
  if not next(articulators) then
    return true
  end
  local creature = df.global.world.raws.creatures.all[creature_index]
  for _, articulator in ipairs(articulators) do
    local castes_okay = true
    for caste_index, caste in ipairs(creature.caste) do
      if ((articulator.creature_index and
           creature_index ~= articulator.creature_index) or
          (articulator.caste_index and
           caste_index ~= articulator.caste_index) or
          (articulator.creature_class and not utils.linear_index(
           caste.creature_class, articulator.creature_class, 'value'))) then
        castes_okay = false
        break
      end
      local bp_applies = not articulator.bp
      local bp_category_applies = not articulator.bp_category
      if not (bp_applies and bp_category_applies) then
        for _, bp in ipairs(caste.body_info.body_parts) do
          if bp.token == articulator.bp then
            bp_applies = true
            break
          elseif bp.category == articulator.bp_category then
            bp_category_applies = true
            break
          end
        end
      end
      if not (bp_applies and bp_category_applies) then
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
  local df_orig = df
  df = {global={world={raws={creatures={all={
    {caste={{body_info={body_parts={{token='BP1', category='BC1'},
                                    {token='BP2', category='BC2'}}},
             creature_class={{value='CC1'}}}}}}}}}}}
  assert_eq(can_articulate(1, {}), true)
  assert_eq(can_articulate(1, {{}}), true)
  assert_eq(can_articulate(1, {{bp='x'}}), false)
  assert_eq(can_articulate(1, {{bp_category='x'}}), false)
  assert_eq(can_articulate(1, {{creature_index=2}}), false)
  assert_eq(can_articulate(1, {{creature_class='x'}}), false)
  assert_eq(can_articulate(1, {{caste_index=2}}), false)
  assert_eq(can_articulate(1, {{bp='BP1'}}), true)
  assert_eq(can_articulate(1, {{bp_category='BC1'}}), true)
  assert_eq(can_articulate(1, {{creature_index=1}}), true)
  assert_eq(can_articulate(1, {{creature_class='CC1'}}), true)
  assert_eq(can_articulate(1, {{caste_index=1}}), true)
  assert_eq(can_articulate(1, {{bp='x'}, {}}), true)
  assert_eq(can_articulate(1, {{bp='BP1', bp_category='x'}}), false)
  df = df_orig
end

--[[
Randomly generates a dimension for a phonology given a target creature.

Args:
  rng: A random number generator.
  phonology: A phonology.
  creature_index: The index of a creature in
    `df.global.world.raws.creatures.all`.

Returns:
  A dimension which is the root of a binary tree of dimensions. The
  children of a node in the tree are in `d1` and `d2`.
]]
function get_dimension(rng, phonology, creature_index)
  local nodes = phonology.nodes
  local dimensions = {}
  local node_to_dimension = {}
  local inarticulable_node_index = nil
  for i, node in ipairs(nodes) do
    if not (inarticulable_node_index and
            dominates(inarticulable_node_index, i, nodes)) then
      if can_articulate(creature_index, node.articulators) then
        local dimension =
          {id=i, domain={i}, nodes={}, cache=node.feature and
           {{score=1 - node.prob}, {score=node.prob, i}} or {{score=1, i}}}
        table.insert(dimensions, dimension)
        node_to_dimension[i] = dimension
      else
        inarticulable_node_index = i
      end
    end
  end
  local scalings = random_scalings(rng, phonology.scalings)
  local links = {}
  for _, scaling in ipairs(scalings) do
    local d1 = node_to_dimension[scaling.node_1]
    local d2 = node_to_dimension[scaling.node_2]
    if d1 and d2 then
      table.insert(links, {d1=d1, d2=d2, scalings={scaling},
                           strength=scaling.strength})
    end
  end
  utils.sort_vector(links, 'strength', utils.compare)
  while #dimensions > 1 do
    merge_dimensions(dimensions, links)
  end
  return dimensions[1]
end

--[[
Gets the product of applicable scalings' scalars.

Args:
  value: A dimension value.
  scalings: A sequence of scalings.

Returns:
  The product of the scalars of all the scalings in `scalings` which are
  satisfied by this value.
]]
function get_scalings_scalar(value, scalings)
  local rv = 1
  for _, scaling in ipairs(scalings) do
    local _, found_1 =
      utils.binsearch(value, scaling.node_1, nil, utils.compare)
    local _, found_2 =
      utils.binsearch(value, scaling.node_2, nil, utils.compare)
    if found_1 == scaling.val_1 and found_2 == scaling.val_2 then
      rv = rv * scaling.scalar
    end
  end
  return rv
end

if TEST then
  local scalings = {{val_1=true, node_1=1, val_2=false, node_2=2, scalar=2,
                     strength=4, prob=1},
                    {val_1=true, node_1=1, val_2=true, node_2=3, scalar=3,
                     strength=5, prob=1},
                    {val_1=true, node_1=1, val_2=true, node_2=4, scalar=5,
                     strength=7, prob=1}}
  assert_eq(get_scalings_scalar({}, scalings), 1)
  assert_eq(get_scalings_scalar({1, 3}, scalings), 6)
  assert_eq(get_scalings_scalar({1, 3, 4}, scalings), 30)
end

--[[
Counts the nodes in a dimension value not in a list of node indices.

Args:
  value: A dimension value.
  nodes: A sequence of node indices sorted in increasing order.

Returns:
  How many nodes in `value` are not in `nodes`.
]]
function get_nodes_difference(value, nodes)
  local difference = 0
  for _, node in ipairs(value) do
    if not utils.binsearch(nodes, node, nil, utils.compare) then
      difference = difference + 1
    end
  end
  return difference
end

if TEST then
  assert_eq(get_nodes_difference({1, 3}, {1, 2, 3}), 0)
  assert_eq(get_nodes_difference({1, 3}, {1, 2}), 1)
  assert_eq(get_nodes_difference({1, 3}, {2}), 2)
end

--[[
Gets the candidates with the fewest new nodes.

Args:
  candidates: A sequence of dimension values.
  nodes: A sequence of nodes indices sorted in increasing order.

Returns:
  A sequence of indexed dimension values, where the indices are into
  `candidates`.
]]
function get_gradually_different_values(candidates, nodes)
  local min_difference = math.huge
  local rv = {}
  for i, candidate in ipairs(candidates) do
    local difference = math.max(1, get_nodes_difference(candidate, nodes))
    if difference <= min_difference then
      if difference ~= min_difference then
        min_difference = difference
        rv = {}
      end
      table.insert(rv, {index=i, candidate=candidate})
    end
  end
  return rv
end

if TEST then
  assert_eq(get_gradually_different_values({{}, {1}, {3, 4}, {2, 3}}, {2}),
            {{index=1, candidate={}}, {index=2, candidate={1}},
             {index=4, candidate={2, 3}}})
  assert_eq(get_gradually_different_values({{1, 2}, {1, 2, 3}}, {}),
            {{index=1, candidate={1, 2}}})
end

--[[
Removes a random dimension value from a sequence.

The dimension value to be removed is chosen from all those with the
fewest nodes not appearing in `nodes`. Among those, the probability of
choosing a given one for removal is proportional to its score out of
the total score of the whole subset.

Args:
  rng: A random number generator.
  candidates! A sequence of dimension values.
  nodes: A sequence of node indices sorted in increasing order.

Returns:
  The removed dimension value.
]]
function remove_random_value(rng, candidates, nodes)
  local indexed_values = get_gradually_different_values(candidates, nodes)
  local total_score = 0
  for _, indexed_value in ipairs(indexed_values) do
    total_score = total_score + indexed_value.candidate.score
  end
  local target = rng:drandom() * total_score
  local sum = 0
  for _, indexed_value in ipairs(indexed_values) do
    sum = sum + indexed_value.candidate.score
    if sum > target then
      return table.remove(candidates, indexed_value.index)
    end
  end
end

if TEST then
  local rng = {drandom=function(self) return 0 end}
  assert_eq(remove_random_value(
    rng, {{score=1, 1, 2, 3}, {score=2, 1, 2}, {score=0, 1, 3}}, {1}),
    {score=2, 1, 2})
end

--[[
Randomly gets the next dimension value from a dimension.

Args:
  rng: A random number generator.
  dimension: A dimension.

Returns:
  The next dimension value of `dimension`. It is random, but it prefers
  getting dimension values similar to those it got before, i.e. using
  a previously used value from one of the subdimensions. It also takes
  scalings into account.
]]
function get_next_dimension_value(rng, dimension)
  while true do
    while not next(dimension.cache) do
      dimension.value_1 = dimension.value_1 or dimension.d1 and
        get_next_dimension_value(rng, dimension.d1)
      dimension.value_2 = dimension.value_2 or dimension.d2 and
        get_next_dimension_value(rng, dimension.d2)
      if not dimension.value_1 then
        dimension.d1 = nil
      end
      if not dimension.value_2 then
        dimension.d2 = nil
      end
      if not (dimension.d1 or dimension.d2) then
        return nil
      end
      local a, b
      if dimension.value_1 then
        if dimension.value_2 then
          if next(dimension.values_1) and next(dimension.values_2) then
            if rng:drandom() < 0.5 then --* (dimension.value_1.score + dimension.value_2.score) < dimension.value_1.score then
              a, b = '1', '2'
            else
              a, b = '2', '1'
            end
          elseif next(dimension.values_1) then
            a, b = '2', '1'
          else
            a, b = '1', '2'
          end
        else
          a, b = '1', '2'
        end
      else
        a, b = '2', '1'
      end
      local value_a = dimension['value_' .. a]
      dimension['value_' .. a] = nil
      table.insert(dimension['values_' .. a], value_a)
      for _, value_b in ipairs(dimension['values_' .. b]) do
        local new_value = merge_sorted_sequences(value_a, value_b)
        new_value.score = value_a.score * value_b.score *
          get_scalings_scalar(new_value, dimension.scalings)
        if new_value.score > 0 then
          table.insert(dimension.cache, new_value)
        end
      end
    end
    repeat
      local value = remove_random_value(rng, dimension.cache, dimension.nodes)
      for _, node_index in ipairs(value) do
        utils.insert_sorted(dimension.nodes, node_index, nil, utils.compare)
      end
      return value
    until not next(dimension.cache)
  end
end

if TEST then
  local rng = {drandom=function(self) return 0 end}
  local dim_1 = {id=1, cache={{score=0.2}, {score=0.8, 1}}, nodes={},
                 values_1={}, values_2={}, scalings={}}
  local dim_2 = {id=2, cache={{score=0.3}, {score=0.7, 2}}, nodes={},
                 values_1={}, values_2={}, scalings={}}
  local dim_3 = {id=3, cache={}, nodes={}, d1=dim_1, d2=dim_2, values_1={},
                 values_2={}, scalings={{val_1=true, node_1=1, val_2=true,
                                             node_2=2, scalar=0.1}}}
  assert_eq(get_next_dimension_value(rng, dim_3), {score=0.06})
  assert_eq(get_next_dimension_value(rng, dim_3), {score=0.24, 1})
  assert_eq(get_next_dimension_value(rng, dim_3), {score=0.2 * 0.7, 2})
  assert_eq(get_next_dimension_value(rng, dim_3), {score=0.8 * 0.7 * 0.1, 1, 2})
  assert_eq(get_next_dimension_value(rng, dim_3), nil)
  assert_eq(get_next_dimension_value(rng, dim_3), nil)
end

--[[
Randomly generates a phonemic inventory.

Args:
  rng: A random number generator.
  phonology: A phonology.
  creature_index: The index of a creature in
    `df.global.world.raws.creatures.all`.

Returns:
  A sequence of dimension values which have some similarities to each
  other and form a cohesive and plausible phonemic inventory, and which
  are pronounceable by the creature at the given index.
]]
function random_inventory(rng, phonology, creature_index)
  local dimension = get_dimension(rng, phonology, creature_index)
  local target_size = 10 + rng:random(21)  -- TODO: better distribution
  local inventory = {}
  repeat
    local phoneme = get_next_dimension_value(rng, dimension)
    if phoneme then
      table.insert(inventory, phoneme)
    else
      break
    end
  until #inventory == target_size
  return inventory
end

--[[
Randomly generates a language parameter table.

Args:
  phonology: The phonology of the language to generate.
  seed: The seed of the random number generator to use.

Returns:
  A language parameter table.
]]
function random_parameters(phonology, seed)
  local rng = dfhack.random.new(seed)
  -- TODO: normal distribution of inventory sizes
  local size = 10 + rng:random(21)
  local parameters = {max_sonority=0, min_sonority=math.huge, inventory={},
                      constraints=shuffle(phonology.constraints, rng)}
  for i = 1, size do
    local phoneme, sonority = random_phoneme(phonology.nodes, rng)
    -- TODO: Don't allow duplicate phonemes.
    parameters.inventory[i] = {phoneme, sonority}
    parameters.min_sonority = math.min(sonority, parameters.min_sonority)
    parameters.max_sonority = math.max(sonority, parameters.max_sonority)
  end
  return parameters
end

--[[
Randomly generates a word for a language.

Args:
  language: A language.
  parameters: A language parameter table.

Returns:
  A word.
]]
function random_word(language, parameters)
  local phonology = phonologies[language.ints[3]]
  -- TODO: random sonority parameters
  local min_peak_sonority = parameters.max_sonority
  local min_sonority_delta = math.max(1, math.floor((parameters.max_sonority - parameters.min_sonority) / 2))
  -- TODO: more realistic syllable count distribution
  local syllables_left = math.random(2)
  -- TODO: make sure this is low enough so it never triggers a new syllable on the first phoneme (here and below)
  local peak_sonority = -100
  local prev_sonority = -100
  local word = {}
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
      table.insert(word, phoneme)
    end
  end
  return serialize(#phonology.nodes, word), get_lemma(phonology, word)
end

-- TODO: doc
function update_word(resource_id, word, noun_sing, noun_plur, adj,
                     resource_functions)
  if noun_sing ~= '' and noun_sing ~= 'n/a' then
    word.forms.Noun = noun_sing
    word.flags.front_compound_noun_sing = true
    word.flags.rear_compound_noun_sing = true
    word.flags.the_noun_sing = true
    word.flags.the_compound_noun_sing = true
    word.flags.of_noun_sing = true
  end
  if noun_plur ~= '' and noun_plur ~= 'NP' then
    word.forms.NounPlural = noun_plur
    word.flags.front_compound_noun_plur = true
    word.flags.rear_compound_noun_plur = true
    word.flags.the_noun_plur = true
    word.flags.the_compound_noun_plur = true
    word.flags.of_noun_plur = true
  end
  if adj ~= '' and adj ~= 'n/a' then
    word.forms.Adjective = adj
    word.flags.front_compound_adj = true
    word.flags.rear_compound_adj = true
    word.flags.the_compound_adj = true
  end
  for _, entity in pairs(df.global.world.entities.all) do
    if entity.type == df.historical_entity_type.Civilization then
      local language = civ_native_language(entity)
      local parameters = parameter_sets[entity.id]
      if not parameters then
        parameters = random_parameters(phonologies[language.ints[3]],
                                       language.ints[4])
        parameter_sets[entity.id] = parameters
      end
      local u_translation, s_translation = language_translations(language)
      local u_form = ''
      local s_form = ''
      for _, f in pairs(resource_functions) do
        if f == true or in_list(resource_id, f(entity), 0) then
          u_form, s_form = random_word(language, parameters)
          print('Civ ' .. entity.id .. '\t' .. word.word .. '\t' .. escape(u_form) .. '\t' .. escape(s_form))
          break
        end
      end
      u_translation.words:insert('#', {new=true, value=escape(u_form)})
      s_translation.words:insert('#', {new=true, value=escape(s_form)})
    end
  end
end

-- TODO: doc
function expand_lexicons()
  local raws = df.global.world.raws
  local words = raws.language.words
  -- Words used in conversations
  for _, word in pairs{'FORCE_GOODBYE', 'GREETINGS', 'GOODBYE', 'VIOLENT',
                       'INEVITABLE', 'TERRIFYING', 'DONT_CARE', 'OPINION'} do
    words:insert('#', {new=true, word='REPORT;' .. word})
    update_word(nil, words[#words - 1], '', '', '', {true})
  end
  -- Inorganic materials
  local inorganics = raws.inorganics
  for i = 0, #inorganics - 1 do
    local noun_sing = inorganics[i].material.state_name.Solid
    local adj = inorganics[i].material.state_adj.Solid
    words:insert('#', {new=true, word='INORGANIC;' .. inorganics[i].id})
    update_word(i, words[#words - 1], noun_sing, '', adj,
                {function(civ) return civ.resources.metals end,
                 function(civ) return civ.resources.stones end,
                 function(civ) return civ.resources.gems end})
  end
  -- Plants
  local plants = raws.plants.all
  for i = 0, #plants - 1 do
    local noun_sing = plants[i].name
    local noun_plur = plants[i].name_plural
    local adj = plants[i].adj
    words:insert('#', {new=true, word='PLANT;' .. plants[i].id})
    update_word(plants[i].anon_1, words[#words - 1], noun_sing, noun_plur, adj,
                {function(civ) return civ.resources.tree_fruit_plants end,
                 function(civ) return civ.resources.shrub_fruit_plants end})
  end
  --[[
  -- Tissues
  local tissues = raws.tissue_templates
  for i = 0, #tissues - 1 do
    local noun_sing = tissues[i].tissue_name_singular
    local noun_plur = tissues[i].tissue_name_plural
    words:insert('#', {new=true, word='TISSUE_TEMPLATE;' .. tissues[i].id})
    update_word(words[#words - 1], noun_sing, noun_plur, '')
  end
  ]]
  -- Creatures
  local creatures = raws.creatures.all
  for i = 0, #creatures - 1 do
    local noun_sing = creatures[i].name[0]
    local noun_plur = creatures[i].name[1]
    local adj = creatures[i].name[2]
    words:insert('#', {new=true, word='CREATURE;' .. creatures[i].creature_id})
    update_word(i, words[#words - 1], noun_sing, noun_plur, adj,
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
                 function(civ) return civ.resources.animals.exotic_pet_races end
                })
  end
  -- Weapons
  local weapons = raws.itemdefs.weapons
  for i = 0, #weapons - 1 do
    local noun_sing = weapons[i].name
    local noun_plur = weapons[i].name_plural
    words:insert('#', {new=true, word='ITEM_WEAPON;' .. weapons[i].id})
    update_word(weapons[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.digger_type end,
                 function(civ) return civ.resources.weapon_type end,
                 function(civ) return civ.resources.training_weapon_type end
                })
  end
  -- Trap components
  local trapcomps = raws.itemdefs.trapcomps
  for i = 0, #trapcomps - 1 do
    local noun_sing = trapcomps[i].name
    local noun_plur = trapcomps[i].name_plural
    words:insert('#', {new=true, word='ITEM_TRAPCOMP;' .. trapcomps[i].id})
    update_word(trapcomps[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.trapcomp_type end})
  end
  -- Toys
  local toys = raws.itemdefs.toys
  for i = 0, #toys - 1 do
    local noun_sing = toys[i].name
    local noun_plur = toys[i].name_plural
    words:insert('#', {new=true, word='ITEM_TOY;' .. toys[i].id})
    update_word(toys[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.toy_type end})
  end
  -- Tools
  local tools = raws.itemdefs.tools
  for i = 0, #tools - 1 do
    local noun_sing = tools[i].name
    local noun_plur = tools[i].name_plural
    words:insert('#', {new=true, word='ITEM_TOOL;' .. tools[i].id})
    update_word(tools[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.toy_type end})
  end
  -- Instruments
  local instruments = raws.itemdefs.instruments
  for i = 0, #instruments - 1 do
    local noun_sing = instruments[i].name
    local noun_plur = instruments[i].name_plural
    words:insert('#', {new=true, word='ITEM_INSTRUMENT;' .. instruments[i].id})
    update_word(instruments[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.instrument_type end})
  end
  -- Armor
  local armor = raws.itemdefs.armor
  for i = 0, #armor - 1 do
    local noun_sing = armor[i].name
    local noun_plur = armor[i].name_plural
    words:insert('#', {new=true, word='ITEM_ARMOR;' .. armor[i].id})
    update_word(armor[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.armor_type end})
  end
  -- Ammo
  local ammo = raws.itemdefs.ammo
  for i = 0, #ammo - 1 do
    local noun_sing = ammo[i].name
    local noun_plur = ammo[i].name_plural
    words:insert('#', {new=true, word='ITEM_AMMO;' .. ammo[i].id})
    update_word(ammo[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.ammo_type end})
  end
  -- Siege ammo
  local siege_ammo = raws.itemdefs.siege_ammo
  for i = 0, #siege_ammo - 1 do
    local noun_sing = siege_ammo[i].name
    local noun_plur = siege_ammo[i].name_plural
    words:insert('#', {new=true, word='ITEM_SIEGEAMMO;' .. siege_ammo[i].id})
    update_word(siege_ammo[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.siegeammo_type end})
  end
  -- Gloves
  local gloves = raws.itemdefs.gloves
  for i = 0, #gloves - 1 do
    local noun_sing = gloves[i].name
    local noun_plur = gloves[i].name_plural
    words:insert('#', {new=true, word='ITEM_GLOVES;' .. gloves[i].id})
    update_word(gloves[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.gloves_type end})
  end
  -- Shoes
  local shoes = raws.itemdefs.shoes
  for i = 0, #shoes - 1 do
    local noun_sing = shoes[i].name
    local noun_plur = shoes[i].name_plural
    words:insert('#', {new=true, word='ITEM_SHOES;' .. shoes[i].id})
    update_word(shoes[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.shoes_type end})
  end
  -- Shields
  local shields = raws.itemdefs.shields
  for i = 0, #shields - 1 do
    local noun_sing = shields[i].name
    local noun_plur = shields[i].name_plural
    words:insert('#', {new=true, word='ITEM_SHIELD;' .. shields[i].id})
    update_word(shields[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.shield_type end})
  end
  -- Helms
  local helms = raws.itemdefs.helms
  for i = 0, #helms - 1 do
    local noun_sing = helms[i].name
    local noun_plur = helms[i].name_plural
    words:insert('#', {new=true, word='ITEM_HELM;' .. helms[i].id})
    update_word(helms[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.helm_type end})
  end
  -- Pants
  local pants = raws.itemdefs.pants
  for i = 0, #pants - 1 do
    local noun_sing = pants[i].name
    local noun_plur = pants[i].name_plural
    words:insert('#', {new=true, word='ITEM_PANTS;' .. pants[i].id})
    update_word(pants[i].subtype, words[#words - 1], noun_sing, noun_plur, '',
                {function(civ) return civ.resources.helm_type end})
  end
  --[[
  -- Food
  local food = raws.itemdefs.food
  for i = 0, #food - 1 do
    local noun_sing = food[i].name
    words:insert('#', {new=true, word='ITEM_FOOD;' .. food[i].id})
    update_word(words[#words - 1], noun_sing, '', '')
  end
  -- Buildings
  local buildings = raws.buildings.all
  for i = 0, #buildings - 1 do
    local noun_sing = buildings[i].name
    words:insert('#', {new=true, word='BUILDING;' .. buildings[i].id})
    update_word(words[#words - 1], noun_sing, '', '')
  end
  -- Built-in materials
  local builtins = raws.mat_table.builtin
  for i = 0, #builtins - 1 do
    if builtins[i] then
      local noun_sing = builtins[i].state_name.Solid
      local adj = builtins[i].state_adj.Solid
      words:insert('#', {new=true, word='BUILTIN;' .. builtins[i].id})
      update_word(words[#words - 1], noun_sing, '', '')
    end
  end
  -- Syndromes
  local syndromes = raws.syndromes.all
  for i = 0, #syndromes - 1 do
    local noun_sing = syndromes[i].syn_name
    words:insert('#', {new=true, word='SYNDROME;' .. syndromes[i].id})
    update_word(words[#words - 1], noun_sing, '', '')
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
function validate_boundary(boundary, scope)
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
Determines whether one node dominates another.

Every node dominates itself.

Args:
  index_1: The index of a node in `nodes`.
  index_2: The index of a node in `nodes`.
  nodes: A sequence of nodes.

Returns:
  Whether `nodes[index_1]` dominates `nodes[index_2]`.
]]
function dominates(index_1, index_2, nodes)
  if index_1 == index_2 then
    return true
  elseif index_2 < index_1 then
    return false
  end
  return dominates(index_1, nodes[index_2].parent, nodes)
end

if TEST then
  local nodes = {{name='1', parent=0, sonorous=false},
                 {name='2', parent=0, sonorous=false},
                 {name='3', parent=2, sonorous=false}}
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

--[[
Inserts a skip pattern element into a pattern.

Args:
  pattern! A non-empty pattern to append a skip pattern element to.
  domain: The feature index to not skip.
  scope: A boundary to not skip.
  boundary: A boundary to not skip.
]]
function insert_skip(pattern, domain, scope, boundary)
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
Loads all phonology raw files into `phonologies`.

The raw files must match 'phonology_*.txt'.
]]
function load_phonologies()
  local dir = dfhack.getSavePath() .. '/raw/objects'
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
            end
            if utils.linear_index(phonologies, subtags[2], 'name') then
              qerror('Duplicate phonology: ' .. subtags[2])
            end
            table.insert(phonologies,
                         {name=subtags[2], nodes={}, scalings={},
                          symbols={}, affixes={},
                          constraints={{type='Max'}, {type='Dep'}}})
            current_phonology = phonologies[#phonologies]
          elseif subtags[1] == 'NODE' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            end
            if #subtags < 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local sonorous = false
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
              if subtags[i] == 'SONOROUS' then
                sonorous = true
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
                  qerror('Probability must be between 0 and 1: ' .. prob)
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
                          sonorous=sonorous, feature_class=feature_class,
                          feature=feature, prob=prob, articulators={}})
            if current_parent ~= 0 then
              table.insert(current_phonology.scalings,
                           {val_1=true, node_1=#current_phonology.nodes,
                            val_2=false, node_2=current_parent, scalar=0,
                            strength=1, prob=1})
            end
            current_parent = #current_phonology.nodes
            table.insert(current_phonology.constraints,
                         {type='Ident', feature=current_parent})
          elseif subtags[1] == 'ARTICULATOR' then
            if not current_phonology or current_parent == 0 then
              qerror('Orphaned tag: ' .. tag)
            end
            local bp = nil
            local bp_category = nil
            local creature = nil
            local creature_class = nil
            local caste = nil
            local creature_index = nil
            local caste_index = nil
            local i = 2
            while i <= #subtags do
              if i == #subtags then
                qerror('No value specified for ' .. subtags[i] .. ': ' .. tag)
              end
              if subtags[i] == 'BP' then
                if bp or bp_category then
                  qerror('BP or BP_CATEGORY already specified: ' .. tag)
                end
                i = i + 1
                bp = subtags[i]
              elseif subtags[i] == 'BP_CATEGORY' then
                if bp or bp_category then
                  qerror('BP or BP_CATEGORY already specified: ' .. tag)
                end
                i = i + 1
                bp_category = subtags[i]
              elseif subtags[i] == 'CREATURE' then
                if creature or creature_category then
                  qerror('CREATURE or CREATURE_CATEGORY already specified: ' ..
                         tag)
                end
                i = i + 1
                creature = subtags[i]
              elseif subtags[i] == 'CREATURE_CLASS' then
                if creature or creature_category then
                  qerror('CREATURE or CREATURE_CLASS already specified: '.. tag)
                end
                i = i + 1
                creature_category = subtags[i]
              elseif subtags[i] == 'CASTE' then
                if caste then
                  qerror('CASTE already specified: ' .. tag)
                end
                i = i + 1
                caste = subtags[i]
              else
                qerror('Unknown subtag ' .. subtags[i])
              end
              i = i + 1
            end
            if creature then
              local index, creature_raw = utils.linear_index(
                df.global.world.raws.creatures.all, creature, 'creature_id')
              if not index then
                qerror('No such creature: ' .. creature)
              end
              creature_index = index
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
              current_phonology.nodes[current_parent].articulators,
              {bp=bp, bp_category=bp_category, creature_index=creature_index,
               creature_class=creature_class, caste_index=caste_index})
          elseif subtags[1] == 'END' then
            if not current_phonology or current_parent == 0 then
              qerror('Orphaned tag: ' .. tag)
            end
            if #subtags ~= 1 then
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
          elseif subtags[1] == 'SCALE' then
            if not current_phonology then
              qerror('Orphaned tag: ' .. tag)
            end
            if #subtags ~= 6 and #subtags ~= 7 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local val_1 = true
            if subtags[2] == '-' then
              val_1 = false
            elseif subtags[2] ~= '+' then
              qerror('First value must be + or -: ' .. tag)
            end
            local val_2 = true
            if subtags[4] == '-' then
              val_2 = false
            elseif subtags[4] ~= '+' then
              qerror('Second value must be + or -: ' .. tag)
            end
            local node_1 = utils.linear_index(current_phonology.nodes,
                                              subtags[3], 'name')
            if not node_1 then
              qerror('No such node: ' .. subtags[3])
            elseif not current_phonology.nodes[node_1].feature then
              qerror('Node must not be a class node: ' .. subtags[3])
            end
            local node_2 = utils.linear_index(current_phonology.nodes,
                                              subtags[5], 'name')
            if not node_2 then
              qerror('No such node: ' .. subtags[5])
            elseif not current_phonology.nodes[node_2].feature then
              qerror('Node must not be a class node: ' .. subtags[5])
            elseif node_1 == node_2 then
              qerror('Same node twice in one scaling: ' .. subtags[3])
            end
            local scalar = tonumber(subtags[6])
            if not scalar or scalar < 0 then
              qerror('Scalar must be a non-negative number: ' .. subtags[6])
            end
            local strength = 1 - (scalar < 1 and 1 / scalar or scalar)
            local prob =
              tonumber(subtags[7]) or DEFAULT_IMPLICATION_PROBABILITY
            table.insert(current_phonology.scalings,
                         {val_1=val_1, node_1=node_1, val_2=val_2,
                          node_2=node_2, scalar=scalar, strength=strength,
                          prob=prob})
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
  civ_id: The ID of a civilization corresponding to a language.
  fluency: A number.
]]
function set_fluency(hf_id, civ_id, fluency)
  if not fluency_data[hf_id] then
    fluency_data[hf_id] = {}
  end
  fluency_data[hf_id][civ_id] = {fluency=fluency}
end

--[[
Gets a historical figure's fluency from `fluency_data`.

Args:
  hf_id: The ID of a historical figure.
  civ_id: The ID of a civilization corresponding to a language.

Returns:
  The historical figure's fluency in the civilization's language.
]]
function get_fluency(hf_id, civ_id)
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
of the historical figure in the civilization's language.
]]
function load_fluency_data()
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
function write_fluency_data()
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
Determines whether a file is a language file.

Args:
  path: The path of a file.

Returns:
  Whether the file is a language file.
]]
function has_language_object(path)
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
function write_raw_tags(file, tags)
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
function write_translation_file(dir, index, translation)
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
function write_symbols_file(dir)
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
function write_words_file(dir)
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
function overwrite_language_files()
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
    if translation.flags == 0 then
      write_translation_file(dir, i, translation)
    end
  end
  write_symbols_file(dir)
  write_words_file(dir)
end

--[[
Gets the two translations associated with a language.

Args:
  language: A language.

Returns:
  The lexicon translation.
  The lemma translation.
]]
function language_translations(language)
  local translation_id = language.ints[1]
  return df.language_translation.find(translation_id),
    df.language_translation.find(translation_id + 1)
end

--[[
Gets the two translations associated with a civilization.

Args:
  civ: A historical entity.

Returns:
  The lexicon translation.
  The lemma translation.
]]
function civ_translations(civ)
  return language_translations(civ_native_language(civ))
end

--[[
Loans words from one civilization's language to another's.

Args:
  dst_civ_id: The ID of the historical entity whose language is the
    destination.
  src_civ_id: The ID of the historical entity whose language is the
    source.
  loans: A sequence of loans.
]]
function loan_words(dst_civ_id, src_civ_id, loans)
  -- TODO: Don't loan between languages with different feature geometries.
  local dst_civ = df.historical_entity.find(dst_civ_id)
  local src_civ = df.historical_entity.find(src_civ_id)
  local dst_u_lang, dst_s_lang = civ_translations(dst_civ)
  local src_u_lang, src_s_lang = civ_translations(src_civ)
  for i = 1, #loans do
    for _, id in pairs(loans[i].get(src_civ)) do
      local word_index = utils.linear_index(df.global.world.raws.language.words,
        loans[i].prefix .. loans[i].type.find(id)[loans[i].id], 'word')
      if dst_u_lang.words[word_index].value == '' then
        local u_loanword = src_u_lang.words[word_index].value
        local s_loanword = src_s_lang.words[word_index].value
        print('Civ ' .. dst_civ.id .. ' gets "' .. s_loanword .. '" (' .. loans[i].prefix .. loans[i].type.find(id)[loans[i].id] .. ') from civ ' .. src_civ.id)
        dst_u_lang.words[word_index].value = u_loanword
        dst_s_lang.words[word_index].value = s_loanword
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
function copy_translation(dst, src)
  for _, word in pairs(src.words) do
    dst.words:insert('#', {new=true, value=word.value})
  end
end

--[[
Creates a language for a civilization.

The new language goes in `df.global.world.raws.language.translations`.
If `civ` is nil, nothing happens.

Args:
  civ: A historical entity, or nil.
]]
function create_language(civ)
  if not civ then
    return
  end
  local figures = df.global.world.history.figures
  local translations = df.global.world.raws.language.translations
  -- Create a persistent entry to represent the language.
  -- TODO: Choose a phonology based on physical ability to produce the phones.
  local language = dfhack.persistent.save(
    {key='babel/language', value='LG' .. civ.id,
     ints={#translations, civ.id, math.random(#phonologies),
           dfhack.random.new():random()}},
    true)
  -- Create two copies (underlying and surface forms) of the language.
  -- TODO: Don't simply copy from the first translation.
  translations:insert('#', {new=true, name=civ.id .. 'U'})
  copy_translation(translations[#translations - 1], translations[0])
  translations:insert('#', {new=true, name=civ.id .. 'S'})
  copy_translation(translations[#translations - 1], translations[0])
end

--[[
Simulate the linguistic effects of a historical event.

This can modify anything related to translations or languages.

Args:
  event: A historical event.
]]
function process_event(event)
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
    -- TODO: migrant_entity no longer speaks their language
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

--[[
Determines whether a historical figure is not a unit.

Args:
  hf: A historical figure.

Returns:
  Whether a historical figure is not a unit.
]]
function is_unprocessed_hf(hf)
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
Nicknames a historical figure.

Args:
  hf! A historical figure.
]]
-- TODO: Make more interesting.
function process_hf(hf)
  if is_unprocessed_hf(hf) then
    hf.name.nickname = 'Hf' .. hf.id
  end
end

--[[
Gets a historical figure's native language.

A historical figure's native language is the native language of their
civilization. Naturally, outsiders have no native language.

Args:
  hf: A historical figure.

Returns:
  A language, or nil if there is none.
]]
function hf_native_language(hf)
  print('hf native language: hf.id=' .. hf.id)
  return civ_native_language(df.historical_entity.find(hf.civ_id))
end

--[[
Gets a civilization's native language.

Args:
  civ: A historical entity.

Returns:
  A language, or nil if there is none.
]]
function civ_native_language(civ)
  if civ then
    local all_languages = dfhack.persistent.get_all('babel/language')
    for _, language in pairs(all_languages) do
      if language.ints[2] == civ.id then
        return language
      end
    end
  end
end

--[[
Gets all of a unit's languages.

If the unit is historical, it uses `hf_languages`. If not, it assumes
the unit knows only the native language of their civilization.

Args:
  unit: A unit.

Returns:
  A sequence of languages the unit knows.
]]
function unit_languages(unit)
  print('unit languages: unit.id=' .. unit.id)
  local _, hf = utils.linear_index(df.global.world.history.figures,
                                   unit.hist_figure_id, 'id')
  if hf then
    return hf_languages(hf)
  end
  print('unit has no hf')
  return {civ_native_language(df.historical_entity.find(unit.civ_id))}
end

--[[
Gets all of a historical figure's languages.

Args:
  hf: A historical figure.

Returns:
  A sequence of languages the historical figure knows.
]]
function hf_languages(hf)
  print('hf languages: hf.id=' .. hf.id)
  if not fluency_data[hf.id] then
    local language = hf_native_language(hf)
    if language then
      set_fluency(hf.id, language.ints[2], MAXIMUM_FLUENCY)
    else
      fluency_data[hf.id] = {}
    end
  end
  local languages = {}
  local all_languages = dfhack.persistent.get_all('babel/language')
  for civ_id, fluency_record in pairs(fluency_data[hf.id]) do
    if fluency_record.fluency == MAXIMUM_FLUENCY then
      for _, language in pairs(all_languages) do
        if language.ints[2] == civ_id then
          table.insert(languages, language)
          break
        end
      end
    end
  end
  return languages
end

--[[
Gets the language a report should have been spoken in.

Args:
  report: A report representating part of a conversation.

Returns:
  The language of the report.
]]
function report_language(report)
  print('report language: report.id=' .. report.id)
  local unit = df.unit.find(report.unk_v40_3)
  -- TODO: Take listener's language knowledge into account.
  if unit then
    local languages = unit_languages(unit)
    if #languages ~= 0 then
      -- TODO: Don't always choose the first one.
      return languages[1]
    end
  end
end

--[[
Determines whether an element is in a list.

Args:
  element: An element.
  list: A table with integer keys from `start` to `#list`.
  start: The first index.

Returns:
  Whether the element is the list.
]]
function in_list(element, list, start)
  for i = start, #list do
    if element == list[i] then
      return true
    end
  end
  return false
end

if TEST then
  assert_eq(in_list(1, {1, 2}, 1), true)
  assert_eq(in_list(0, {[0]=0, 1, 2}, 1), false)
  assert_eq(in_list(0, {[0]=0, 1, 2}, 0), true)
  assert_eq(in_list(2, {1, 2}, 1), true)
  assert_eq(in_list(2, {[0]=0, 1, 2}, 0), true)
end

--[[
Runs the simulation.
]]
function babel()
  if not dfhack.isWorldLoaded() then
    print('not loaded')
    write_fluency_data()
    return
  end
  dfhack.with_suspend(function()
    local entry1 = dfhack.persistent.get('babel/config1')
    local first_time = false
    if not entry1 then
      first_time = true
      entry1 = dfhack.persistent.save{key='babel/config1',
                                     ints={0, 0, 0, 0, 0, 0, 0}}
      -- TODO: Is there always exactly one generated translation, the last?
      entry2 = dfhack.persistent.save{
        key='babel/config2',
        ints={#df.global.world.raws.language.translations - 1}}
    end
    -- TODO: Track structures.
    local entities_done = entry1.ints[3]
    if #df.global.world.entities.all > entities_done then
      print('\nent: ' .. #df.global.world.entities.all .. '>' .. entities_done)
      for i = entities_done, #df.global.world.entities.all - 1 do
        if (df.global.world.entities.all[i].type ==
            df.historical_entity_type.Civilization) then
          create_language(df.global.world.entities.all[i])
        end
        df.global.world.entities.all[i].name.nickname = 'Ent' .. i
      end
      dfhack.persistent.save{key='babel/config1',
                             ints={[3]=#df.global.world.entities.all}}
      if first_time then
        expand_lexicons()
        overwrite_language_files()
      end
    end
    local events_done = entry1.ints[7]
    if #df.global.world.history.events > events_done then
      print('\nevent: ' .. #df.global.world.history.events .. '>' .. events_done)
      for i = events_done, #df.global.world.history.events - 1 do
        process_event(df.global.world.history.events[i])
      end
      dfhack.persistent.save{key='babel/config1',
                             ints={[7]=#df.global.world.history.events}}
    end
    local hist_figures_done = entry1.ints[1]
    if #df.global.world.history.figures > hist_figures_done then
      print('\nhf: ' .. #df.global.world.history.figures .. '>' .. hist_figures_done)
      for i = hist_figures_done, #df.global.world.history.figures - 1 do
        process_hf(df.global.world.history.figures[i])
      end
      dfhack.persistent.save{key='babel/config1',
                             ints={[1]=#df.global.world.history.figures}}
    end
    -- TODO: units_done shouldn't be persistent
    local units_done = entry1.ints[2]
    if #df.global.world.units.all > units_done then
      print('\nunit: ' .. #df.global.world.units.all .. '>' .. units_done)
      for i = units_done, #df.global.world.units.all - 1 do
--        print('#' .. i .. '\t' .. df.global.world.units.all[i].name.first_name .. '\t' .. df.global.world.units.all[i].hist_figure_id)
        if df.global.world.units.all[i].hist_figure_id == -1 then
          df.global.world.units.all[i].name.nickname = 'U' .. i
        end
      end
      dfhack.persistent.save{key='babel/config1',
                             ints={[2]=#df.global.world.units.all}}
    end
    local sites_done = entry1.ints[4]
    if #df.global.world.world_data.sites > sites_done then
      print('\nsite ' .. #df.global.world.world_data.sites .. '>' .. sites_done)
      for i = sites_done, #df.global.world.world_data.sites - 1 do
        df.global.world.world_data.sites[i].name.nickname = 'S' .. i
      end
      dfhack.persistent.save{key='babel/config1',
                             ints={[4]=#df.global.world.world_data.sites}}
    end
    local artifacts_done = entry1.ints[5]
    if #df.global.world.artifacts.all > artifacts_done then
      print('\nartifact ' .. #df.global.world.artifacts.all .. '>' .. artifacts_done)
      for i = artifacts_done, #df.global.world.artifacts.all - 1 do
        df.global.world.artifacts.all[i].name.nickname = 'A' .. i
      end
      dfhack.persistent.save{key='babel/config1',
                             ints={[5]=#df.global.world.artifacts.all}}
    end
    local regions_done = entry1.ints[6]
    if #df.global.world.world_data.regions > regions_done then
      print('\nregion ' .. #df.global.world.world_data.regions .. '>' .. regions_done)
      for i = regions_done, #df.global.world.world_data.regions - 1 do
        df.global.world.world_data.regions[i].name.nickname = 'Reg' .. i
      end
      dfhack.persistent.save{key='babel/config1',
                             ints={[6]=#df.global.world.world_data.regions}}
    end
    local reports = df.global.world.status.reports
    if #reports > next_report_index then
      print('\nreport: ' .. #reports .. ' > ' .. next_report_index)
      local counts = {}
      for i = next_report_index, #reports - 1 do
        local activity_id = reports[i].unk_v40_1
        if activity_id ~= -1 and not reports[i].flags.continuation then
          if counts[activity_id] then
            counts[activity_id] = counts[activity_id] + 1
          else
            counts[activity_id] = 1
          end
        end
      end
      local announcements = df.global.world.status.announcements
      local id_delta = 0
      local i = next_report_index
      while i < #reports do
        local report = reports[i]
        local announcement_index = utils.linear_index(announcements,
                                                      report.id, 'id')
        if (report.unk_v40_1 == -1 or
            df.global.gamemode ~= df.game_mode.ADVENTURE) then
          -- TODO: Combat logs in Fortress mode can have conversations.
          print('  not a conversation: ' .. report.text)
          report.id = report.id + id_delta
          i = i + 1
        else
          local report_language = report_language(report)
          print('  [' .. report.unk_v40_1 .. ']: ' .. report.text)
          local adventurer = df.global.world.units.active[0]
          local adv_hf = df.historical_figure.find(adventurer.hist_figure_id)
          local adv_languages = unit_languages(adventurer)
          for i = 1, #adv_languages do
            print('adv knows: ' .. adv_languages[i].value)
          end
          if report_language then
            print('speaker is speaking: ' .. report_language.value)
          else
            print('speaker speaks no language')
          end
          if (report_language and not in_list(report_language, adv_languages, 1)) or (report.flags.continuation and just_learned) then
            if report.flags.continuation then
              print('  ...: ' .. report.text)
              reports:erase(i)
              if announcement_index then
                announcements:erase(announcement_index)
              end
              id_delta = id_delta - 1
            else
              just_learned = false
              local fluency_record = get_fluency(adv_hf.id,
                                                 report_language.ints[2])
              local unit = df.unit.find(report.unk_v40_3)
              fluency_record.fluency = math.min(
                MAXIMUM_FLUENCY, fluency_record.fluency +
                math.ceil(adventurer.status.current_soul.mental_attrs.LINGUISTIC_ABILITY.value / UTTERANCES_PER_XP))
              print('strength <-- ' .. fluency_record.fluency)
              if fluency_record.fluency == MAXIMUM_FLUENCY then
                dfhack.gui.showAnnouncement('You have learned ' ..
                  dfhack.TranslateName(report_language.value) .. '.',
                  COLOR_GREEN)
                just_learned = true
              end
              local conversation_id = report.unk_v40_1
              local n = counts[conversation_id]
              counts[conversation_id] = counts[conversation_id] - 1
              local conversation = df.activity_entry.find(conversation_id)
              local force_goodbye = false
              local participants = conversation.events[0].anon_1
              local speaker_index, hearer_index = 0, 1
              if #participants > 0 then
                if participants[0].anon_1 ~= unit.id then
                  speaker_index, hearer_index = 1, 0
                end
                if (participants[0].anon_1 == adventurer.id or
                    (#participants > 1 and
                     participants[1].anon_1 == adventurer.id)) then
                  conversation.events[0].anon_2 = 7
                  if participants[0].anon_1 == adventurer.id then
                    force_goodbye = true
                  end
                end
              end
              reports:erase(i)
              if announcement_index then
                announcements:erase(announcement_index)
              end
              local details = conversation.events[0].anon_9
              details = details[#details - n]
              local text = ''
              -- TODO: participants is invalid for goodbyes, because that data has been deleted by then.
              -- TODO: What if the adventurer knows the participants' names?
              if #participants > speaker_index then
                local speaker = df.unit.find(participants[speaker_index].anon_1)
                text = df.profession.attrs[speaker.profession].caption
              end
              if #participants > 1 and participants[hearer_index].anon_1 ~= adventurer.id then
                local hearer = df.unit.find(participants[hearer_index].anon_1)
                text = text .. ' (to ' .. df.profession.attrs[hearer.profession].caption .. ')'
              end
              text = text .. ': ' ..
                translate(report_language, force_goodbye or details.anon_3,
                          details.anon_11, details.anon_12, details.anon_13)
              local continuation = false
              while not continuation or text ~= '' do
                print('text:' .. text)
                -- TODO: Break on whitespace preferably.
                local size = math.min(string.len(text), 73)
                new_report = {new=true,
                              type=report.type,
                              text=string.sub(text, 1, 73),
                              color=report.color,
                              bright=report.bright,
                              duration=report.duration,
                              flags={new=true,
                                     continuation=continuation},
                              repeat_count=report.repeat_count,
                              id=report.id + id_delta,
                              year=report.year,
                              time=report.time,
                              unk_v40_1=report.unk_v40_1,
                              unk_v40_2=report.unk_v40_2,
                              unk_v40_3=report.unk_v40_3}
                text = string.sub(text, 74)
                continuation = true
                reports:insert(i, new_report)
                i = i + 1
                if announcement_index then
                  announcements:insert(announcement_index, new_report)
                  announcement_index = announcement_index + 1
                end
              end
            end
          else
            just_learned = false
            i = i + 1
          end
        end -- conversation
      end
      next_report_index = i
      df.global.world.status.next_report_id = i
    end
    if enabled then
      timer = dfhack.timeout(1, 'frames', babel)
    end
  end)
end

args = {...}
if #args >= 1 then
  if args[1] == 'start' then
    enabled = true
    if not phonologies then
      load_phonologies()
      if not phonologies then
        qerror('At least one phonology must be defined')
      end
    end
    if not fluency_data then
      load_fluency_data()
    end
    df.global.world.status.announcements:resize(0)
    local entry2 = dfhack.persistent.get('babel/config2')
    if entry2 then
      local translations = df.global.world.raws.language.translations
      translations:insert(entry2.ints[1], translations[#translations - 1])
      translations:erase(#translations - 1)
    end
    babel()
  elseif args[1] == 'stop' then
    enabled = false
    if timer then
      dfhack.timeout_active(timer, nil)
    end
  elseif args[1] == 'test' then
    phonologies = nil
    load_phonologies()
    local rng = dfhack.random.new(121122)  -- 40221: too much ROUND
    local function print_dimension(nodes, dimension, indent)
      if not dimension then
        return
      end
      print(indent .. (dimension.id and dimension.id .. ': ' .. nodes[dimension.id].name or '---'))
      indent = indent .. '.'
      print_dimension(nodes, dimension.d1, indent)
      print_dimension(nodes, dimension.d2, indent)
    end
    local dim = get_dimension(rng, phonologies[1], 466)
    print_dimension(phonologies[1].nodes, dim, '')
    local inv = random_inventory(rng, phonologies[1], 466)
    print('-----------------------')
    for _, val in ipairs(inv) do
      local ph = {}
      for i, ni in pairs(val) do
        if type(i) == 'number' then
          ph[ni] = true
        end
      end
      print(get_lemma(phonologies[1], {ph}), val.score)
      for ni in pairs(ph) do
        if phonologies[1].nodes[ni].feature then
          print('\t'..phonologies[1].nodes[ni].name)
        end
      end
    end
  else
    usage()
  end
else
  usage()
end
