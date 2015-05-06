-- Adds languages.

local utils = require('utils')

--[[
TODO:
* Put words in GEN_DIVINE.
* Update any new names in GEN_DIVINE to point to the moved GEN_DIVINE.
* Protect against infinite loops due to sonority dead ends in random_word.
* Change the adventurer's forced goodbye response to "I don't understand you".
]]

local TEST = true

local DEFAULT_NODE_SCALAR = 0.9375
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
  implications: A sequence of implications.
  nodes: A sequence of nodes.
  symbols: A sequence of symbols.

Symbol:
  symbol: A string.
  features: The phoneme the symbol represents.

Constraint:
-- TODO

Node:
  name: A string, used only for parsing the phonology raw file.
  parent: The index of the node's parent node in the associated
    phonology, or 0 if the parent is the root node.
  add: A string to append to the symbol of a phoneme that does not
    have this node to denote a phoneme that does have it but is
    otherwise identical.
  remove: The opposite of `add`.
  sonorous: Whether this node adds sonority to a phoneme that has it.

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

Implication:
A table representing an implication between feature values that cannot
be represented directly in the feature hierarchy tree structure.
  ante: The index of the antecedent node.
  ante_val: Whether the antecedent node is specified as +.
  cons: The index of the consequent node.
  cons_val: Whether the consequent node is specified as +.
  prob: The probability that this implication will be randomly chosen.
    It should be in the range [0, 1].

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
Determines what values of a feature can be added to a phoneme.

Args:
  phoneme: A phoneme.
  node_index: The index of the node to specify a value for in `phoneme`.
  start_index: The index of the first implication to consider in
    `implications`.
  implications: A sequence of implications.

Returns:
  Whether the `node_index` node may be specified + in `phoneme`.
  Whether the `node_index` node may be specified - in `phoneme`.
]]
function is_phoneme_okay(phoneme, node_index, start_index, implications)
  local plus_okay = true
  local minus_okay = true
  for i = start_index, #implications do
    local imp = implications[i]
    if node_index == imp.ante then
      imp.ante, imp.cons = imp.cons, imp.ante
      imp.ante_val, imp.cons_val = not imp.cons_val, not imp.ante_val
    end
    if node_index == imp.cons then
      local antecedent_is_false = imp.ante_val ~= (phoneme[imp.ante] or false)
      plus_okay = plus_okay and (imp.cons_val or antecedent_is_false)
      minus_okay = minus_okay and (not imp.cons_val or antecedent_is_false)
    end
    if not (plus_okay or minus_okay) then
      break
    end
  end
  return plus_okay, minus_okay
end

if TEST then
  assert_eq({is_phoneme_okay({true}, 2, 1, {})}, {true, true})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1, {{ante=1, ante_val=true, cons=2, cons_val=true}})},
            {true, false})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1, {{ante=1, ante_val=true, cons=2, cons_val=false}})},
            {false, true})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1, {{ante=1, ante_val=false, cons=2, cons_val=true}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1,
              {{ante=1, ante_val=false, cons=2, cons_val=false}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1, {{ante=2, ante_val=true, cons=1, cons_val=true}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1, {{ante=2, ante_val=true, cons=1, cons_val=false}})},
            {false, true})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1, {{ante=2, ante_val=false, cons=1, cons_val=true}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {true}, 2, 1,
              {{ante=2, ante_val=false, cons=1, cons_val=false}})},
            {true, false})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1, {{ante=1, ante_val=true, cons=2, cons_val=true}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1,
              {{ante=1, ante_val=true, cons=2, cons_val=false}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1,
              {{ante=1, ante_val=false, cons=2, cons_val=true}})},
            {true, false})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1,
              {{ante=1, ante_val=false, cons=2, cons_val=false}})},
            {false, true})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1, {{ante=2, ante_val=true, cons=1, cons_val=true}})},
            {false, true})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1,
              {{ante=2, ante_val=true, cons=1, cons_val=false}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1,
              {{ante=2, ante_val=false, cons=1, cons_val=true}})},
            {true, false})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1,
              {{ante=2, ante_val=false, cons=1, cons_val=false}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {false}, 2, 2,
              {{ante=2, ante_val=false, cons=1, cons_val=true}})},
            {true, true})
  assert_eq({is_phoneme_okay(
              {false}, 2, 1,
              {{ante=2, ante_val=true, cons=1, cons_val=true},
               {ante=2, ante_val=false, cons=1, cons_val=true}})},
            {false, false})
end

--[[
Randomly adds implications to a sequence of implications.

Args:
  rng: A random number generator.
  input_implications: A sequence of implications to draw implications
    from.
  output_implications! A sequence of implications to extend.
  inventory: A nonempty sequence of phonemes.
  new_node_index: The index of a node that must be present in an
    implication in `input_implications` to add it to
    `output_implications`.
]]
function add_random_implications(rng, input_implications, output_implications,
                                 inventory, new_node_index)
  for _, imp in pairs(input_implications) do
    if (((imp.ante == new_node_index and inventory[1][imp.cons] ~= nil) or
         (imp.cons == new_node_index and inventory[1][imp.ante] ~= nil)) and
        rng:drandom() <= imp.prob) then
      table.insert(output_implications, imp)
    end
  end
end

--[[
Add the children of a node to a sequence.

Args:
  output! The sequence of nodes to add the children's indexes to.
  node_index: The index of the node whose children to get.
  nodes: A sequence of nodes.
]]
function add_child_nodes(output, node_index, nodes)
  for i, node in pairs(nodes) do
    if node.parent == node_index then
      table.insert(output, i)
    end
  end
end

function get_implication_scalars(implications, old_index, new_index)
  local pp = nil
  local pm = nil
  local mp = nil
  local mm = nil
  for _, imp in pairs(implications) do
    if pp and pm and mp and mm then
      break
    end
    if imp.ante == old_index and imp.cons == new_index then
      if imp.ante_val then
        if imp.cons_val then
          pp = imp.prob
        else
          pm = imp.prob
        end
      else
        if imp.cons_val then
          mp = imp.prob
        else
          mm = imp.prob
        end
      end
    end
  end
  return pp or 1, pm or 1, mp or 1, mm or 1
end

-- TODO: docs
-- example combination: {score=0.123, 1, 4, 6}
-- combinations is a sequence of those, plus total=1.234
-- TODO: this only works for IMPLIES + +
function get_combinations(phonology, root_index)
  local nodes = phonology.nodes
  local combinations =
    {total=1, {score=1, feature_count=0, feature_class=FEATURE_CLASS_NEUTRAL}}
  for i = root_index, #nodes do
    if i ~= root_index and nodes[i].parent < root_index then
      break
    end
    for j = 1, #combinations do
      if nodes[i].feature then
        if i == root_index or in_list(nodes[i].parent, combinations[j], 1) then
          local combination = copyall(combinations[j])
          combinations.total = combinations.total - combination.score
          combination.score = combination.score * nodes[i].scalar
          combination.feature_count = combination.feature_count + 1
          combination.last_feature = i
          combination.feature_class =
            math.max(combination.feature_class, nodes[i].feature_class)
          for ante = root_index, i do
            local pp, pm, mp, mm =
              get_implication_scalars(phonology.implications, ante, i)
            if in_list(ante, combination, 1) then
              combination.score = combination.score * pp
              combinations[j].score = combinations[j].score * pm
            else
              combination.score = combination.score * mp
              combinations[j].score = combinations[j].score * mm
            end
          end
          table.insert(combination, i)
          table.insert(combinations, combination)
          combinations.total =
            combinations.total + combination.score + combinations[j].score
        end
      else
        table.insert(combinations[j], i)
      end
    end
  end
  for _, combination in ipairs(combinations) do
--[[
    for _, ni in ipairs(combination) do
      print(nodes[ni].name)
    end
]]
    local licensed = nil
    for i = #combination, 1, -1 do
      local node = nodes[combination[i]]
      if node.feature or combination[i] == licensed then
        licensed = node.parent
      else
--        print('',node.name)
        table.remove(combination, i)
      end
    end
--    print()
  end
--  print()
  return combinations
end

function random_dimensions(rng, phonology)
  local nodes = phonology.nodes
  local dimensions = {}
  for i = 1, #nodes do
    if nodes[i].parent == 0 then
      local combinations = get_combinations(phonology, i)
      local queue = {}
      table.insert(dimensions, {combinations=combinations, queue=queue,
        next=function()
          local queued_value = table.remove(queue)
          if queued_value then
            return queued_value
          end
          local target = rng:drandom() * combinations.total
          if target < 0 then
            return nil
          end
          local sum = 0
          local i = 0
          local combination
          while sum <= target do
            i = i + 1
            combination = combinations[i]
            if not combination then
              return nil
            end
            sum = sum + combination.score
          end
          combinations.total = combinations.total - combination.score
          combination.original_score = combination.score
          combination.score = 0
          if combination.feature_count >= 2 then
            for prereq_index, prereq in ipairs(combinations) do
              if (prereq.feature_count == 1 and prereq.score ~= 0 and
                  in_list(prereq.last_feature, combination, 1)) then
                table.insert(queue, prereq_index)
                combinations.total = combinations.total - prereq.score
                prereq.original_score = prereq.score
                prereq.score = 0
              end
            end
            shuffle(queue, rng)
            table.insert(queue, 1, i)
            return table.remove(queue)
          end
          return i
        end})
    end
  end
  return dimensions
end

function is_dphoneme_okay(phonology, dimensions, dphoneme, dimension_index,
                          dimension_value)
  --[[
  print('\nIs this okay?')
  for di, dvi in ipairs(dphoneme) do
    for _, ni in ipairs(dimensions[di].combinations[dvi]) do
      print(phonology.nodes[ni].name)
    end
  end
  print(' dimension_index: '..dimension_index)
  for _, ni in ipairs(dimension_value) do
    print(phonology.nodes[ni].name)
  end
  ]]
  for _, imp in pairs(phonology.implications) do
    if (phonology.nodes[imp.ante].dimension ~=
        phonology.nodes[imp.cons].dimension) then
      local in_ante = nil
      if in_list(imp.ante, dimension_value, 1) then
        in_ante = true
      elseif in_list(imp.cons, dimension_value, 1) then
        in_ante = false
      end
      if in_ante ~= nil then
        --[[
        if not imp[in_ante and 'ante' or 'cons'] then
          imp.ante, imp.cons = imp.cons, imp.ante
          imp.ante_val, imp.cons_val = not imp.cons_val, not imp.ante_val
          in_ante = not in_ante
        end
        ]]
        if not in_ante then
          imp.ante, imp.cons = imp.cons, imp.ante
          imp.ante_val, imp.cons_val = not imp.cons_val, not imp.ante_val
        end
--[[
        print(in_ante,
              phonology.nodes[imp.ante].name..'='..tostring(imp.ante_val),
              ' => ',
              phonology.nodes[imp.cons].name..'='..tostring(imp.cons_val))
]]
        if imp.ante_val then
          local dp = in_ante and 'cons' or 'ante'
          local dp_di = phonology.nodes[imp[dp]].dimension
          local dp_dvi = dphoneme[dp_di]
          if (dp_dvi ~= nil and imp[dp .. '_val'] ~=
              in_list(imp[dp], dimensions[dp_di].combinations[dp_dvi], 1)) then
--            print('   ---> false')
            return false
          end
        end
      end
    end
  end
--  print('   ---> true')
  return true
end

function get_size(sequence)
  local i = 1
  while sequence[i] do
    i = i + 1
  end
  return i - 1
end

function random_dphoneme_inventory(phonology, rng, dimensions, target_size)
  local inventory = {{feature_class=FEATURE_CLASS_NEUTRAL}}
  local dimensions_left = #dimensions
  local dimensions_used = {n=0}
  local current_size = 0
  while dimensions_left ~= 0 and (dimensions_used.n ~= #dimensions or
                                  current_size < target_size) do
--[[
    print()
    print('dims left: '..dimensions_left)
    print('#inv:      '..#inventory)
    print('cursz:     '..current_size)
    for _,x in pairs(inventory) do
      print('-------------')
      for a, b in pairs(x) do
        if type(a) == 'number' then
          print('In dimension '..a..':')
          printall(dimensions[a].combinations[b])
        end
      end
    end
]]
    local dimension_index = (dimensions_used.n == #dimensions) and
      (rng:random(#dimensions) + 1) or (dimensions_used.n + 1)
    local dimension_value_index = dimensions[dimension_index].next()
    if dimension_value_index then
      local dimension_value =
        dimensions[dimension_index].combinations[dimension_value_index]
      --[[
      [N.B. "dphoneme" here is a sequence of dimension value indices, not
       feature indices]
      [e.g. {1,2,1} means dim1=val1, dim2=val2, dim3=val1]
      [and those numbers (1,2,1) are indices into each dimension]
      ]]
      local i = 1
      local final_index = #inventory
      while i <= final_index do
--        print('',dimension_index,dimension_value_index,i, final_index)
--        printall(dimensions[dimension_index].combinations[dimension_value_index])
        local dphoneme = inventory[i]
        if (dphoneme.feature_class == dimension_value.feature_class or
            dphoneme.feature_class == FEATURE_CLASS_NEUTRAL or
            dimension_value.feature_class == FEATURE_CLASS_NEUTRAL) then
          local change_okay = true
          for _, dp in pairs(inventory) do
            local same = true
            for di = 1, #dimensions do
              if (dp[di] ~= ((di ~= dimension_index) and dphoneme[di] or
                             dimension_value_index)) then
                same = false
                break
              end
            end
            if same then
              change_okay = false
              break
            end
          end
          change_okay = change_okay and is_dphoneme_okay(
              phonology, dimensions, dphoneme, dimension_index, dimension_value)
          if change_okay then
            table.insert(inventory, copyall(dphoneme))
            if not dimensions_used[dimension_index] then
              dimensions_used[dimension_index] = true
              dimensions_used.n = dimensions_used.n + 1
            end
            dphoneme[dimension_index] = dimension_value_index
            dphoneme.feature_class =
              math.max(dphoneme.feature_class, dimension_value.feature_class)
            if get_size(dphoneme) == #dimensions then
              current_size = current_size + 1
            end
          end
        end
        i = i + 1
      end
    else
      dimensions_left = dimensions_left - 1
      if not dimensions_used[dimension_index] then
        dimensions_used[dimension_index] = true
        dimensions_used.n = dimensions_used.n + 1
      end
    end
  end
  return inventory
end

function random_inventory(phonology, seed)
  local rng = dfhack.random.new(seed)
  local target_size = 10 + rng:random(21)  -- TODO: better distribution
  local dimensions = random_dimensions(rng, phonology)
  local dphoneme_inventory =
    random_dphoneme_inventory(phonology, rng, dimensions, target_size)
  local empty_phoneme = {score=0}
  for i = 1, #phonology.nodes do
    empty_phoneme[i] = false
  end
  local inventory = {}
  for i = 1, #dphoneme_inventory do
    local dphoneme = dphoneme_inventory[i]
    if get_size(dphoneme) == #dimensions then
      local uphoneme = {score=0}
      for dimension_index, dimension_value_index in ipairs(dphoneme) do
        local dimension_value =
          dimensions[dimension_index].combinations[dimension_value_index]
        uphoneme.score = uphoneme.score - dimension_value.original_score
        for _, node_index in ipairs(dimension_value) do
          uphoneme[node_index] = true
        end
      end
      utils.insert_sorted(inventory, uphoneme, 'score', utils.compare)
    end
  end
  for i = 1, target_size do
    inventory[i].score = nil
  end
  for _ = target_size + 1, #inventory do
    table.remove(inventory)
  end
  return inventory
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
      local current_dimension = 0
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
                         {name=subtags[2], nodes={}, implications={},
                          symbols={}, affixes={},
                          constraints={{type='Max'}, {type='Dep'}}})
            current_phonology = phonologies[#phonologies]
          elseif subtags[1] == 'NODE' then
            if not current_phonology then
              qerror('Orphaned NODE tag: ' .. tag)
            end
            if #subtags < 2 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local sonorous = false
            local feature_class = current_parent == 0 and FEATURE_CLASS_NEUTRAL
              or current_phonology.nodes[current_parent].feature_class
            local feature = true
            local scalar = DEFAULT_NODE_SCALAR
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
              elseif subtags[i] == 'SCALE' then
                if i == #subtags then
                  qerror('No scalar specified for node ' .. subtags[2])
                end
                i = i + 1
                scalar = tonumber(subtags[i])
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
            if current_parent == 0 then
              current_dimension = current_dimension + 1
            end
            table.insert(current_phonology.nodes,
                         {name=subtags[2], parent=current_parent,
                          add=add_symbol, remove=remove_symbol,
                          sonorous=sonorous, feature_class=feature_class,
                          dimension=current_dimension, feature=feature,
                          scalar=scalar, score=0})
            current_parent = #current_phonology.nodes
            table.insert(current_phonology.constraints,
                         {type='Ident', feature=#current_phonology.nodes})
          elseif subtags[1] == 'END' then
            if not current_phonology then
              qerror('Orphaned END tag: ' .. tag)
            end
            if #subtags ~= 1 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            if current_parent == 0 then
              qerror('Misplaced END tag')
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
            local score = 1 / (#children + 1)
            for _, child in pairs(children) do
              child.score = score
            end
            current_parent = current_phonology.nodes[current_parent].parent
          elseif subtags[1] == 'IMPLIES' then
            if not current_phonology then
              qerror('Orphaned IMPLIES tag: ' .. tag)
            end
            if #subtags ~= 5 and #subtags ~= 6 then
              qerror('Wrong number of subtags: ' .. tag)
            end
            local ante_val = true
            if subtags[2] == '-' then
              ante_val = false
            elseif subtags[2] ~= '+' then
              qerror('Antecedent value must be + or -: ' .. tag)
            end
            local cons_val = true
            if subtags[4] == '-' then
              cons_val = false
            elseif subtags[4] ~= '+' then
              qerror('Consequent value must be + or -: ' .. tag)
            end
            local ante = utils.linear_index(current_phonology.nodes,
                                            subtags[3], 'name')
            if not ante then
              qerror('No such node: ' .. subtags[3])
            elseif not current_phonology.nodes[ante].feature then
              qerror('Node must not be a class node: ' .. subtags[3])
            end
            local cons = utils.linear_index(current_phonology.nodes,
                                            subtags[5], 'name')
            if not cons then
              qerror('No such node: ' .. subtags[5])
            elseif not current_phonology.nodes[cons].feature then
              qerror('Node must not be a class node: ' .. subtags[5])
            end
            if ante == cons then
              qerror('Same node twice in one implication: ' .. subtags[3])
            elseif cons < ante then
              ante, cons = cons, ante
              ante_val, cons_val = not cons_val, not ante_val
            end
            local prob = tonumber(subtags[6]) or DEFAULT_IMPLICATION_PROBABILITY
            if prob < 0 then
              qerror('Probability must not be negative: ' .. subtags[6])
            end
            table.insert(
              current_phonology.implications,
              {ante_val=ante_val, ante=ante, cons_val=cons_val, cons=cons,
               prob=prob})
          elseif subtags[1] == 'SYMBOL' then
            if not current_phonology then
              qerror('Orphaned SYMBOL tag: ' .. tag)
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
              qerror('Orphaned CONSTRAINT tag: ' .. tag)
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
    local rng = dfhack.random.new(134)
    --[[
    local combinations = get_combinations(phonologies[1].nodes, utils.linear_index(phonologies[1].nodes, 'PLACE', 'name'), phonologies[1].implications)
    local q = 100
    for i, com in ipairs(combinations) do
      if com.score ~= 0 then
        if q <= 0 then break end
        q = q - 1
        print('\nscore: '..com.score)
        for _, x in ipairs(com) do
          print('\t'..phonologies[1].nodes[x].name)
        end
      end
    end
    print('total combos: '..#combinations)
    print('total score:  '..combinations.total)
    ]]
    local dims = random_dimensions(rng, phonologies[1])
    --[[
    print('total dims: '..#dims)
    local dim = dims[1]
    while true do
      local ci = dim.next()
      if ci == nil then break end
      local com = dim.combinations[ci]
      print('\n' .. com.feature_class)
      for _, x in ipairs(com) do
        print('\t'..phonologies[1].nodes[x].name)
      end
    end
    ]]
    --[[
    local ph = {}
    local s = {'BACK','FRONT','OUND','HIGH','VOICED','LOW TONE'}
    while next(s) do
      local i, node = utils.linear_index(phonologies[1].nodes, s[1], 'name')
      table.remove(s, 1)
      if i then
        ph[i] = true
        if node.parent ~= 0 and not ph[node.parent] then
          table.insert(s, phonologies[1].nodes[node.parent].name)
        end
      end
    end
    local inv = {ph}
    ]]
    local inv = random_inventory(phonologies[1], 5)
    for _, ph in pairs(inv) do
      print('\n'..get_lemma(phonologies[1], {ph}))
      for i = 1, #phonologies[1].nodes do
        if ph[i] and phonologies[1].nodes[i].feature then
          print('\t'..phonologies[1].nodes[i].name)
        end
      end
    end
    print(#inv)
    --[[
    local inv = random_dphoneme_inventory(phonologies[1], 113)
    for i, ph in pairs(inv) do
      print(i..' ['..ph.sonority..'] '..get_lemma(phonologies[1], {ph}))
      for n, v in ipairs(ph) do
        if phonologies[1].nodes[n].parent ~= 0 then
          print('\t'..phonologies[1].nodes[n].name, v)
        end
      end
    end
    ]]
  else
    usage()
  end
else
  usage()
end
