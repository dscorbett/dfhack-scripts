local utils = require 'utils'

-- TODO: clear announcements on reloading world
-- TODO: Why does GEN_DIVINE have no words now?

local MINIMUM_FLUENCY = -32768
local MAXIMUM_FLUENCY = 32767
local UTTERANCES_PER_XP = 16
local phonologies = nil

if enabled == nil then
  enabled = false
end

function usage()
  print [[
Usage:
  TODO
]]
end

function translate(language, topic, topic1, topic2, topic3)
  print('translate ' .. tostring(topic) .. '/' .. topic1)
  local word
  if topic == true then
    word = 'FORCE_GOODBYE'
  elseif topic == 0 then  -- Greet
    word = 'GREETINGS'
  --[[
  elseif topic == 1 then  -- Nevermind
  elseif topic == 2 then  -- Trade
  elseif topic == 3 then  -- AskJoin
  elseif topic == 4 then  -- AskSurroundings
  ]]
  elseif topic == 5 then  -- SayGoodbye
    word = 'GOODBYE'
  --[[
  elseif topic == 6 then  -- AskStructure
  elseif topic == 7 then  -- AskFamily
  elseif topic == 8 then  -- AskProfession
  elseif topic == 9 then  -- AskPermissionSleep
  elseif topic == 10 then  -- AccuseNightCreature
  elseif topic == 11 then  -- AskTroubles
  elseif topic == 12 then  -- BringUpEvent
  elseif topic == 13 then  -- SpreadRumor
  elseif topic == 14 then  -- ReplyGreeting
  elseif topic == 15 then  -- RefuseConversation
  elseif topic == 16 then  -- ReplyImpersonate
  elseif topic == 17 then  -- BringUpIncident
  elseif topic == 18 then  -- TellNothingChanged
  elseif topic == 19 then  -- Goodbye2
  elseif topic == 20 then  -- ReturnTopic
  elseif topic == 21 then  -- ChangeSubject
  elseif topic == 22 then  -- AskTargetAction
  elseif topic == 23 then  -- RequestSuggestAction
  elseif topic == 24 then  -- AskJoinInsurrection
  elseif topic == 25 then  -- AskJoinRescue
  ]]
  elseif topic == 26 then  -- StateOpinion
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
  --[[
  elseif topic == 29 then  -- AllowPermissionSleep
  elseif topic == 30 then  -- DenyPermissionSleep
  elseif topic == 32 then  -- AskJoinAdventure
  elseif topic == 33 then  -- AskGuideLocation
  elseif topic == 34 then  -- RespondJoin
  elseif topic == 35 then  -- RespondJoin2
  elseif topic == 36 then  -- OfferCondolences
  elseif topic == 37 then  -- StateNotAcquainted
  elseif topic == 38 then  -- SuggestTravel
  elseif topic == 39 then  -- SuggestTalk
  elseif topic == 40 then  -- SuggestSelfRescue
  elseif topic == 41 then  -- AskWhatHappened
  elseif topic == 42 then  -- AskBeRescued
  elseif topic == 43 then  -- SayNotRemember
  elseif topic == 45 then  -- SayNoFamily
  elseif topic == 46 then  -- StateUnitLocation
  elseif topic == 47 then  -- ReferToElder
  elseif topic == 48 then  -- AskComeCloser
  elseif topic == 49 then  -- DoBusiness
  elseif topic == 50 then  -- AskComeStoreLater
  elseif topic == 51 then  -- AskComeMarketLater
  elseif topic == 52 then  -- TellTryShopkeeper
  elseif topic == 53 then  -- DescribeSurroundings
  elseif topic == 54 then  -- AskWaitUntilHome
  elseif topic == 55 then  -- DescribeFamily
  elseif topic == 56 then  -- StateAge
  elseif topic == 57 then  -- DescribeProfession
  elseif topic == 58 then  -- AnnounceNightCreature
  elseif topic == 59 then  -- StateIncredulity
  elseif topic == 60 then  -- BypassGreeting
  elseif topic == 61 then  -- AskCeaseHostilities
  elseif topic == 62 then  -- DemandYield
  elseif topic == 63 then  -- HawkWares
  elseif topic == 64 then  -- YieldTerror
  elseif topic == 65 then  -- Yield
  elseif topic == 66 then  -- ExpressOverwhelmingEmotion
  elseif topic == 67 then  -- ExpressGreatEmotion
  elseif topic == 68 then  -- ExpressionEmotion
  elseif topic == 69 then  -- ExpressMinorEmotion
  elseif topic == 70 then  -- ExpressLackEmotion
  elseif topic == 71 then  -- OutburstFleeConflict
  elseif topic == 72 then  -- StateFleeConflict
  elseif topic == 73 then  -- MentionJourney
  elseif topic == 74 then  -- SummarizeTroubles
  elseif topic == 75 then  -- AskAboutIncident
  elseif topic == 76 then  -- AskDirectionsPerson
  elseif topic == 77 then  -- AskDirectionsPlace
  elseif topic == 78 then  -- AskWhereabouts
  elseif topic == 79 then  -- RequestGuide
  elseif topic == 80 then  -- RequestGuide2
  elseif topic == 81 then  -- ProvideDirections
  elseif topic == 82 then  -- ProvideWhereabouts
  elseif topic == 83 then  -- TellTargetSelf
  elseif topic == 84 then  -- TellTargetDead
  elseif topic == 85 then  -- RecommentGuide
  elseif topic == 86 then  -- ProfessIgnorance
  elseif topic == 87 then  -- TellAboutPlace
  elseif topic == 88 then  -- AskFavorMenu
  elseif topic == 89 then  -- AskWait
  elseif topic == 90 then  -- AskFollow
  elseif topic == 91 then  -- ApologizeBusy
  elseif topic == 92 then  -- ComplyOrder
  elseif topic == 93 then  -- AgreeFollow
  elseif topic == 94 then  -- ExchangeItems
  elseif topic == 95 then  -- AskComeCloser2
  elseif topic == 96 then  -- InitiateBarter
  elseif topic == 97 then  -- AgreeCeaseHostile
  elseif topic == 98 then  -- RefuseCeaseHostile
  elseif topic == 99 then  -- RefuseCeaseHostile2
  ]]
  else
    -- TODO: more topics
    word = 'BLAH_BLAH_BLAH'
  end
  local languages = df.global.world.raws.language
  local word_index, _ = utils.linear_index(languages.words, 'REPORT;' .. word,
                                           'word')
  if not word_index then
    return topic .. '/' .. topic1 .. '/' .. topic2 .. '/' .. topic3
  end
  -- TODO: Capitalize the result.
  return languages.translations[language.name.language].words[word_index].value
    .. '.'
end

function random_word(civ)
  local index = civ.id
  local consonants = 'bcdfghjklmnpqrstvwxyz\x87\xa4\xe9\xeb'
  local vowels = 'aeiou\x81\x82\x83\x84\x85\x86\x88\x89\x8a\x8b\x8c\x8d\x91\x93\x94\x95\x96\x97\xa0\xa1\xa2\xa3'
  local rand1 = math.random(consonants:len())
  local rand2 = math.random(vowels:len())
  local rand3 = math.random(consonants:len())
  word = consonants:sub(rand1, rand1) .. vowels:sub(rand2, rand2) ..
    consonants:sub(rand3, rand3) ..
    vowels:sub(index % vowels:len(), index % vowels:len())
  return '/' .. word .. '/', '<' .. word .. '>'
end

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
    if entity.type == 0 then  -- Civilization
      local u_translation, s_translation = civ_translations(entity)
      local u_form = ''
      local s_form = ''
      for _, f in pairs(resource_functions) do
        if f == true or in_list(resource_id, f(entity), 0) then
          u_form, s_form = random_word(entity)
          print('Civ ' .. entity.id .. '\t' .. word.word .. '\t' .. u_form .. '\t' .. s_form)
          break
        end
      end
      u_translation.words:insert('#', {new=true, value=u_form})
      s_translation.words:insert('#', {new=true, value=s_form})
    end
  end
end

function expand_lexicons()
  print('expand lexicons')
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

function civ_translations(civ)
  for _, hf_id in pairs(civ.histfig_ids) do
    if hf_id < 0 then
      local translation_id = df.historical_figure.find(hf_id).name.language
      return df.language_translation.find(translation_id),
        df.language_translation.find(translation_id + 1)
    end
  end
end

function read_phonologies()
  local phonologies = nil
  local dir = 'data/save/' .. df.global.world.cur_savegame.save_dir .. '/raw/objects'
  for _, filename in pairs(dfhack.filesystem.listdir(dir)) do
    local path = dir .. '/' .. filename
    if (dfhack.filesystem.isfile(path) and
        filename:match('^phonology_.*%.txt')) then
      io.input(path)
      -- TODO: Is it bad that it can qerror without closing the file?
      -- TODO: Are CR/LF allowed within tokens?
      -- TODO: Check the first line for the file name.
      local current_phonology = nil
      local current_parent = 0
      for token in io.read('*all'):gmatch('%[.-%]') do
        local subtokens = {}
        for subtoken in token:gmatch('[^][:]+') do
          table.insert(subtokens, subtoken)
        end
        if #subtokens >= 1 then
          if subtokens[1] == 'OBJECT' then
            if #subtokens ~= 2 then
              qerror('Wrong number of subtokens: ' .. token)
            end
            if subtokens[2] ~= 'PHONOLOGY' then
              qerror('Wrong object type: ' .. subtokens[2])
            end
            phonologies = {}
          elseif not phonologies then
            qerror('Missing OBJECT token: ' .. filename)
          elseif subtokens[1] == 'PHONOLOGY' then
            if #subtokens ~= 2 then
              qerror('Wrong number of subtokens: ' .. token)
            end
            if utils.linear_index(phonologies, subtokens[2], 'name') then
              qerror('Duplicate phonology: ' .. subtokens[2])
            end
            table.insert(phonologies,
                         {name=subtokens[2], nodes={}, symbols={}, affixes={}})
            current_phonology = phonologies[#phonologies]
          elseif subtokens[1] == 'NODE' then
            if not current_phonology then
              qerror('Orphaned NODE token: ' .. token)
            end
            if #subtokens ~= 2 then
              qerror('Wrong number of subtokens: ' .. token)
            end
            table.insert(current_phonology.nodes,
                         {name=subtokens[2], parent=current_parent})
            current_parent = #current_phonology.nodes
          elseif subtokens[1] == 'END' then
            if not current_phonology then
              qerror('Orphaned NODE token: ' .. token)
            end
            if #subtokens ~= 1 then
              qerror('Wrong number of subtokens: ' .. token)
            end
            if current_parent == 0 then
              qerror('Misplaced END token')
            end
            current_parent = current_phonology.nodes[current_parent].parent
          elseif subtokens[1] == 'SYMBOL' then
            if not current_phonology then
              qerror('Orphaned NODE token: ' .. token)
            end
            if #subtokens < 3 then
              qerror('No features specified: ' .. token)
            end
            if current_phonology.symbols[subtokens[2]] then
              qerror('Duplicate symbol: ' .. subtokens[2])
            end
            local nodes = {}
            for i = 3, #subtokens do
              local n, node = utils.linear_index(current_phonology.nodes,
                                                 subtokens[i], 'name')
              if not n then
                qerror('No such node: ' .. subtokens[i])
              end
              if node.parent ~= 0 then
                table.insert(subtokens,
                             current_phonology.nodes[node.parent].name)
              end
              nodes[n] = true
            end
            current_phonology.symbols[subtokens[2]] = nodes
          elseif subtokens[1] == 'AFFIX' then
            if not current_phonology then
              qerror('Orphaned NODE token: ' .. token)
            end
            if #subtokens < 4 then
              qerror('No features specified: ' .. token)
            end
            -- TODO
            qerror('Affixes are not implemented yet')
          else
            qerror('Unknown token: ' .. token)
          end
        end
      end
      io.input():close()
    end
  end
  return phonologies
end

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

function write_raw_tokens(file, tokens)
  for _, str in pairs(tokens) do
    file:write('\t', str.value, '\n')
  end
end

function write_translation_file(dir, index, translation)
  local filename = 'language_' .. string.format('%04d', index) .. '_' ..
    translation.name
  local file = io.open(dir .. '/' .. filename .. '.txt', 'w')
  file:write(filename, '\n\n[OBJECT:LANGUAGE]\n\n[TRANSLATION:',
             translation.name, ']\n')
  write_raw_tokens(file, translation.str)
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

function write_symbol_file(dir)
  local file = io.open(dir .. '/language_SYM.txt', 'w')
  file:write('language_SYM\n\n[OBJECT:LANGUAGE]\n')
  for _, symbol in pairs(df.global.world.raws.language.symbols) do
    file:write('\n[SYMBOL:', symbol.name, ']\n')
    write_raw_tokens(file, symbol.str)
  end
  file:close()
end

function write_word_file(dir)
  local file = io.open(dir .. '/language_words.txt', 'w')
  file:write('language_words\n\n[OBJECT:LANGUAGE]\n')
  for _, word in pairs(df.global.world.raws.language.words) do
    file:write('\n[WORD:', word.word, ']\n')
    write_raw_tokens(file, word.str)
  end
  file:close()
end

function overwrite_language_files()
  local dir = 'data/save/' .. df.global.world.cur_savegame.save_dir .. '/raw/objects'
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
  write_symbol_file(dir)
  write_word_file(dir)
end

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

function representative_site(civ)
  -- TODO: use entity_site_link
  for _, site in pairs(df.global.world.world_data.sites) do
    if site.civ_id == civ.id then
      return site
    end
  end
  -- TODO: deal with nil
end

function copy_lexicon(dst, src)
  for _, word in pairs(src.words) do
    dst.words:insert('#', {new=true, value=word.value})
  end
end

function create_language(civ)
  print('create language: civ.id=' .. civ.id)
  if not civ then
    return
  end
  local figures = df.global.world.history.figures
  local translations = df.global.world.raws.language.translations
  -- Create a historical figure to represent the language.
  figures:insert(0, {new=true, id=figures[0].id - 1})
  figures[0].name.language = #translations
  figures[0].name.nickname = 'LG:' .. civ.id
  -- Register the language with the civ where it's spoken.
  civ.histfig_ids:insert('#', figures[0].id)
  -- Create two copies (underlying and surface forms) of the language.
  -- TODO: Don't simply copy from the first translation.
  translations:insert('#', {new=true, name=civ.id .. 'U'})
  copy_lexicon(translations[#translations - 1], translations[0])
  translations:insert('#', {new=true, name=civ.id .. 'S'})
  copy_lexicon(translations[#translations - 1], translations[0])
end

function register_hf_language(hf, language_id)
  print('register hf language: hf.id=' .. hf.id .. ' language_id=' .. language_id)
  hf.histfig_links:insert(
    '#', {new=true, target_hf=language_id, link_strength=MAXIMUM_FLUENCY})
end

function register_hf_language_by_entity(hf_id, entity)
  for _, language_id in pairs(entity.histfig_ids) do
    if language_id < 0 then
      local _, language = df.historical_figure.find(language_id)
      if language then
        register_hf_language(df.historical_figure.find(hf_id), language_id)
        return
      end
    end
  end
end

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

function init()
  return dfhack.persistent.save{key='babel', ints={0, 0, 0, 0, 0, 0, 0}}
end

-- TODO: reset when world is unloaded
if next_report_index == nil then
  next_report_index = 0
end

function is_unprocessed_hf(hf)
  local id = hf.id
  if id < 0 then
    return false
  end
  for i = 0, #df.global.world.units.all - 1 do
    if df.global.world.units.all[i].hist_figure_id == id then
      return false
    end
  end
  return true
end

function process_hf(hf)
  if is_unprocessed_hf(hf) then
    hf.name.nickname = 'Hf' .. hf.id
  end
end

function hf_native_language(hf)
  print('hf native language: hf.id=' .. hf.id)
  return civ_native_language(df.historical_entity.find(hf.civ_id))
end

function civ_native_language(civ)
  if civ then
    print('civ native language: civ.id=' .. civ.id)
    for _, histfig_id in pairs(civ.histfig_ids) do
      if histfig_id < 0 then
        return df.historical_figure.find(histfig_id)
      end
    end
  end
end

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

function hf_languages(hf)
  print('hf languages: hf.id=' .. hf.id)
  local languages = {}
  for i = 1, 2 do
    for _, link in pairs(hf.histfig_links) do
      if link._type == df.histfig_hf_link and link.target_hf < 0 and link.link_strength == MAXIMUM_FLUENCY then
        local language = df.historical_figure.find(link.target_hf)
        if language then
          table.insert(languages, language)
        end
      end
    end
    if #languages == 0 and i == 1 then
      local language = hf_native_language(hf)
      if language then
        register_hf_language(hf, language.id)
        --[[
          TODO: Register languages of linked civs and languages spoken by
          groups within home site, with varying degrees of fluency.
        ]]
      end
    else
      break
    end
  end
  return languages
end

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

function in_list(element, list, start)
  for i = 1, #list do
    if element == list[i + start - 1] then
      return true
    end
  end
  return false
end

function babel()
  if not dfhack.isWorldLoaded() then
    print('not loaded')
    next_report_index = nil
    return
  end
  dfhack.with_suspend(function()
    if not phonologies then
      phonologies = read_phonologies()
      if not phonologies then
        qerror('At least one phonology must be defined')
      end
    end
    local entry = dfhack.persistent.get('babel')
    local first_time = false
    if not entry then
      first_time = true
      entry = init()
    end
    -- TODO: Track structures.
    local entities_done = entry.ints[3]
    if #df.global.world.entities.all > entities_done then
      print('\nent: ' .. #df.global.world.entities.all .. '>' .. entities_done)
      for i = entities_done, #df.global.world.entities.all - 1 do
        if df.global.world.entities.all[i].type == 0 then  -- Civilization
          create_language(df.global.world.entities.all[i])
        end
        df.global.world.entities.all[i].name.nickname = 'Ent' .. i
      end
      dfhack.persistent.save{key='babel',
                             ints={[3]=#df.global.world.entities.all}}
      if first_time then
        expand_lexicons()
        overwrite_language_files()
      end
    end
    local events_done = entry.ints[7]
    if #df.global.world.history.events > events_done then
      print('\nevent: ' .. #df.global.world.history.events .. '>' .. events_done)
      for i = events_done, #df.global.world.history.events - 1 do
        process_event(df.global.world.history.events[i])
      end
      dfhack.persistent.save{key='babel',
                             ints={[7]=#df.global.world.history.events}}
    end
    local hist_figures_done = entry.ints[1]
    if #df.global.world.history.figures > hist_figures_done then
      print('\nhf: ' .. #df.global.world.history.figures .. '>' .. hist_figures_done)
      for i = hist_figures_done, #df.global.world.history.figures - 1 do
        process_hf(df.global.world.history.figures[i])
      end
      dfhack.persistent.save{key='babel',
                             ints={[1]=#df.global.world.history.figures}}
    end
    -- TODO: units_done shouldn't be persistent
    local units_done = entry.ints[2]
    if #df.global.world.units.all > units_done then
      print('\nunit: ' .. #df.global.world.units.all .. '>' .. units_done)
      for i = units_done, #df.global.world.units.all - 1 do
--        print('#' .. i .. '\t' .. df.global.world.units.all[i].name.first_name .. '\t' .. df.global.world.units.all[i].hist_figure_id)
        if df.global.world.units.all[i].hist_figure_id == -1 then
          df.global.world.units.all[i].name.nickname = 'U' .. i
        end
      end
      dfhack.persistent.save{key='babel',
                             ints={[2]=#df.global.world.units.all}}
    end
    local sites_done = entry.ints[4]
    if #df.global.world.world_data.sites > sites_done then
      print('\nsite ' .. #df.global.world.world_data.sites .. '>' .. sites_done)
      for i = sites_done, #df.global.world.world_data.sites - 1 do
        df.global.world.world_data.sites[i].name.nickname = 'S' .. i
      end
      dfhack.persistent.save{key='babel',
                             ints={[4]=#df.global.world.world_data.sites}}
    end
    local artifacts_done = entry.ints[5]
    if #df.global.world.artifacts.all > artifacts_done then
      print('\nartifact ' .. #df.global.world.artifacts.all .. '>' .. artifacts_done)
      for i = artifacts_done, #df.global.world.artifacts.all - 1 do
        df.global.world.artifacts.all[i].name.nickname = 'A' .. i
      end
      dfhack.persistent.save{key='babel',
                             ints={[5]=#df.global.world.artifacts.all}}
    end
    local regions_done = entry.ints[6]
    if #df.global.world.world_data.regions > regions_done then
      print('\nregion ' .. #df.global.world.world_data.regions .. '>' .. regions_done)
      for i = regions_done, #df.global.world.world_data.regions - 1 do
        df.global.world.world_data.regions[i].name.nickname = 'Reg' .. i
      end
      dfhack.persistent.save{key='babel',
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
        if report.unk_v40_1 == -1 or df.global.gamemode ~= 1 then  -- ADVENTURE
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
            print('adv knows: ' .. adv_languages[i].name.nickname)
          end
          if report_language then
            print('speaker is speaking: ' .. report_language.name.nickname)
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
              local _, link = utils.linear_index(
                adv_hf.histfig_links, report_language.id, 'target_hf')
              if not link then
                link = {new=true, target_hf=report_language.id,
                        link_strength=MINIMUM_FLUENCY}
                adv_hf.histfig_links:insert('#', link)
              end
              local unit = df.unit.find(report.unk_v40_3)
              link.link_strength = math.min(
                MAXIMUM_FLUENCY, link.link_strength +
                math.ceil(adventurer.status.current_soul.mental_attrs.LINGUISTIC_ABILITY.value / UTTERANCES_PER_XP))
              print('strength <-- ' .. link.link_strength)
              if link.link_strength == MAXIMUM_FLUENCY then
                dfhack.gui.showAnnouncement(
                  'You have learned ' ..
                  dfhack.TranslateName(report_language.name) .. '.', COLOR_GREEN)
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
    babel()
  elseif args[1] == 'stop' then
    enabled = false
    if timer then
      dfhack.timeout_active(timer, nil)
    end
  else
    usage()
  end
else
  usage()
end
