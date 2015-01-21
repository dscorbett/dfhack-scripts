local utils = require 'utils'

-- TODO: clear announcements on reloading world

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
        if unprocessed_historical_figure(i) then
          local figure = df.global.world.history.figures[i]
          figure.name.nickname = 'Hf' .. i
          local _, civ = utils.linear_index(df.global.world.entities.all,
                                            figure.civ_id, 'id')
          if civ then
            for i = 0, #civ.entity_links - 1 do
              if civ.entity_links[i].type == 1 then  -- CHILD
                local _, language = utils.linear_index(df.global.world.entities.all,
                                                       civ.entity_links[i].target,
                                                       'id')
                if language and language.name.nickname ~= '' then
                  figure.entity_links:insert('#', {new=true,
                                                   entity_id=language.id,
                                                   link_strength=100})
                  break
                end
              end
            end
          end
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
        if report.unk_v40_1 == -1 then
          print('  not a conversation: ' .. report.text)
          report.id = report.id + id_delta
          i = i + 1
        elseif report.flags.continuation then
          print('  ...: ' .. report.text)
          reports:erase(i)
          announcements:erase(announcement_index)
          id_delta = id_delta - 1
        else
          print('  [' .. report.unk_v40_1 .. ']: ' .. report.text)
          local conversation_id = report.unk_v40_1
          local n = counts[conversation_id]
          counts[conversation_id] = counts[conversation_id] - 1
          local conversation_index = utils.linear_index(
            df.global.world.activities.all, conversation_id,
            'id')
          local details = df.global.world.activities.all[conversation_index].events[0].anon_9
          reports:erase(i)
          announcements:erase(announcement_index)
          text = '[' .. details[#details - n].anon_3 .. ']: ' .. string.upper(report.text)
          local continuation = false -- TODO: use in flags
          while text ~= '' do
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
            reports:insert(i, new_report)
            announcements:insert(announcement_index, new_report)
            i = i + 1
            announcement_index = announcement_index + 1
          end
        end
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
