local utils = require 'utils'

-- TODO: clear announcements on reloading world

local MINIMUM_FLUENCY = -32768
local MAXIMUM_FLUENCY = 32767

if enabled == nil then
  enabled = false
end

function usage()
  print [[
Usage:
  TODO
]]
end

function make_languages()
  local language_count = 0
  for i = 0, #df.global.world.entities.all - 1 do
    local civ = df.global.world.entities.all[i + language_count]
    if civ.type == 0  then -- Civilization
      print('Creating language for civ ' .. civ.id)
      df.global.world.entities.all:insert(0,
                                          {new=true,
                                           type=1,  -- SiteGovernment
                                           id=df.global.entity_next_id,
                                           name={new=true, nickname='Lg' .. i},
                                           entity_links={new=true,
                                                         type=0,  -- PARENT
                                                         target=civ.id,
                                                         strength=100}})
      civ.entity_links:insert('#', {new=true,
                                    type=1,  -- CHILD
                                    target=df.global.entity_next_id,
                                    strength=100})
      df.global.entity_next_id = df.global.entity_next_id + 1
      language_count = language_count + 1
    end
  end
  return dfhack.persistent.save({key='babel', ints={0, 0, language_count, 0}})
end

-- TODO: reset when world is unloaded
if next_report_index == nil then
  next_report_index = 0
end

function unprocessed_historical_figure(index)
  id = df.global.world.history.figures[index].id
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

function get_hf_l1(hf)
  local _, civ = utils.linear_index(df.global.world.entities.all, hf.civ_id,
                                    'id')
  return get_civ_l1(civ)
end

function get_civ_l1(civ)
  if civ then
    for i = 0, #civ.entity_links - 1 do
      if civ.entity_links[i].type == 1 then  -- CHILD
        local _, language = utils.linear_index(df.global.world.entities.all,
                                               civ.entity_links[i].target, 'id')
        if language and language.name.nickname ~= '' then
          return language
        end
      end
    end
  end
end

function get_unit_languages(unit)
  local languages = {}
  local _, hf = utils.linear_index(df.global.world.history.figures,
                                   unit.id, 'unit_id')
  if not hf then
    print('unit has no hf')
    local _, civ = utils.linear_index(df.global.world.entities.all, unit.civ_id,
                                      'id')
    return {get_civ_l1(civ)}
  end
  for i = 0, #hf.entity_links - 1 do
    if hf.entity_links[i].link_strength == MAXIMUM_FLUENCY then
      local _, language = utils.linear_index(df.global.world.entities.all,
                                             hf.entity_links[i].entity_id, 'id')
      if language and language.name.nickname ~= '' then
        table.insert(languages, language)
      end
    end
  end
  return languages
end

function get_report_language(report)
  local _, unit = utils.linear_index(df.global.world.units.all,
                                     report.unk_v40_3, 'id')
  -- TODO: Take listener's language knowledge into account.
  if unit then
    local languages = get_unit_languages(unit)
    if #languages ~= 0 then
      return languages[1]  -- TODO: Don't always choose the first one.
    end
  end
end

function in_list(element, list)
  for i = 1, #list do
    if element == list[i] then
      return true
    end
  end
  return false
end

function babel()
  if dfhack.isWorldLoaded() then
    dfhack.with_suspend(function()
    local entry = dfhack.persistent.get('babel')
    if not entry then
      entry = make_languages()
    end
    local hist_figure_next_id = entry.ints[1]
    if #df.global.world.history.figures > hist_figure_next_id then
      print('\nhf: ' .. #df.global.world.history.figures .. '>' .. hist_figure_next_id)
      for i = hist_figure_next_id, #df.global.world.history.figures - 1 do
        local hf = df.global.world.history.figures[i]
        if unprocessed_historical_figure(i) then
          hf.name.nickname = 'Hf' .. i
        end
        local language = get_hf_l1(hf)
        if language then
          print('L1[' .. dfhack.TranslateName(hf.name) .. '] = ' .. language.name.nickname)
          hf.entity_links:insert('#', {new=true,
                                       entity_id=language.id,
                                       link_strength=MAXIMUM_FLUENCY})
        end
      end
      dfhack.persistent.save({key='babel',
                        ints={[1]=#df.global.world.history.figures}})
    end
    local unit_next_id = entry.ints[2]
    if #df.global.world.units.all > unit_next_id then
      print('\nunit: ' .. #df.global.world.units.all .. '>' .. unit_next_id)
      for i = unit_next_id, #df.global.world.units.all - 1 do
        print('#' .. i .. '\t' .. df.global.world.units.all[i].name.first_name .. '\t' .. df.global.world.units.all[i].hist_figure_id)
        if df.global.world.units.all[i].hist_figure_id == -1 then
          df.global.world.units.all[i].name.nickname = 'U' .. i
        end
      end
      dfhack.persistent.save({key='babel',
                        ints={[2]=#df.global.world.units.all}})
    end
    local entity_next_id = entry.ints[3]
    if #df.global.world.entities.all > entity_next_id then
      print('\nent: ' .. #df.global.world.entities.all .. '>' .. entity_next_id)
      for i = entity_next_id, #df.global.world.entities.all - 1 do
        df.global.world.entities.all[i].name.nickname = 'Ent' .. i
      end
      dfhack.persistent.save({key='babel',
                        ints={[3]=#df.global.world.entities.all}})
    end
    local site_next_id = entry.ints[4]
    if #df.global.world.world_data.sites > site_next_id then
      print('\nsite ' .. #df.global.world.world_data.sites .. '>' .. site_next_id)
      for i = site_next_id, #df.global.world.world_data.sites - 1 do
        df.global.world.world_data.sites[i].name.nickname = 'S' .. i
      end
      dfhack.persistent.save({key='babel',
                        ints={[4]=#df.global.world.world_data.sites}})
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
        elseif report.flags.continuation then
          print('  ...: ' .. report.text)
          reports:erase(i)
          if announcement_index then
            announcements:erase(announcement_index)
          end
          id_delta = id_delta - 1
        else
          local report_language = get_report_language(report)
          print('  [' .. report.unk_v40_1 .. ']: ' .. report.text)
          local adventurer = df.global.world.units.active[0]
          local _, adv_hf = utils.linear_index(df.global.world.history.figures,
                                               adventurer.hist_figure_id, 'id')
          local adv_languages = get_unit_languages(adventurer)
          for i = 1, #adv_languages do
            print('adv knows: ' .. adv_languages[i].name.nickname)
          end
          if report_language then
            print('speaker is speaking: ' .. report_language.name.nickname)
          else
            print('speaker speaks no language')
          end
          if report_language and not in_list(report_language, adv_languages) then
            local _, link = utils.linear_index(adv_hf.entity_links,
                                               report_language.id, 'entity_id')
            if not link then
              link = {new=true, entity_id=report_language.id,
                      link_strength=MINIMUM_FLUENCY}
              adv_hf.entity_links:insert('#', link)
            end
            local _, unit = utils.linear_index(df.global.world.units.all,
                                               report.unk_v40_3, 'id')
            link.link_strength = math.min(
              MAXIMUM_FLUENCY, link.link_strength +
              unit.status.current_soul.mental_attrs.LINGUISTIC_ABILITY.value)
            print('strength <-- ' .. link.link_strength)
            local conversation_id = report.unk_v40_1
            local n = counts[conversation_id]
            counts[conversation_id] = counts[conversation_id] - 1
            local _, conversation = utils.linear_index(
              df.global.world.activities.all, conversation_id, 'id')
            local details = conversation.events[0].anon_9
            local force_goodbye = false
            local participants = conversation.events[0].anon_1
            if #participants > 0 and (participants[0].anon_1 == adventurer.id or (#participants > 1 and conversation.events[0].anon_1[1].anon_1 == adventurer.id)) then
              conversation.events[0].anon_2 = 7
              force_goodbye = true
            end
            reports:erase(i)
            if announcement_index then
              announcements:erase(announcement_index)
            end
            local text = '[' .. details[#details - n].anon_3 .. ']: ' .. string.upper(report.text)
            if force_goodbye then
              text = '[I DO NOT SPEAK YOUR LANGUAGE. GOODBYE.]'
            end
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
          else
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
  else
    print('not loaded')
    next_report_index = nil
  end
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
