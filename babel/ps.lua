--@ module = true

local testing = reqscript('babel/testing')
local trees = reqscript('babel/trees')

local WORD_ID_CHAR = trees.WORD_ID_CHAR
local c = testing.coverage_test
local cc = trees.cc
local k = trees.k
local m = trees.m
local r = trees.r
local t = trees.t
local x = trees.x

--[[

Args:
  arg:
  specifier or false
  adjunct*
  head+complement or false
]]
function xp(arg)
  local c = arg[#arg] or x{}
  for i = #arg - 1, 2, -1 do
    c = x{arg[i], c}
  end
  return trees.xp{arg[1] or x{}, c}
end

--[[


Args:
  arg!
  deg=
  q=
  adjunct*
  adjective+arguments
]]
function adj(arg)
  table.insert(arg, 1, false)
  return adv(arg)
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
adv = function(arg)
  if arg[1] then
    local deg = arg.deg
    local q = arg.q
    arg.deg = nil
    arg.q = nil
    return xp{  -- DegP
      false,  -- TODO: measure, e.g. "two years"
      x{  -- Deg'
        deg or k'POS',  -- TODO: measure Deg
        xp{  -- QP
          false,
          -- TODO: "than"
          x{  -- Q'
            q,
            xp{  -- AdvP
              false,
              x{  --Adv'
                k'-ly',
                adj(arg),
              },
            },
          },
        },
      },
    }
  else
    return xp{  -- DegP
      false,  -- TODO: measure, e.g. "two years"
      x{  -- Deg'
        arg.deg or k'POS',  -- TODO: measure Deg
        xp{  -- QP
          false,
          -- TODO: "than"
          x{  -- Q'
            arg.q,
            xp(arg),  -- AP/AdvP
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
function conj(arg)
  return xp{arg[1], x{arg[2], arg[3]}}
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
function infl(arg)
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
    return infl(arg)
  end
  local rv
  table.insert(arg, 1, false)
  if arg.passive then
    local args = arg[#arg].args
    if args.theme then
      if args.agent then
        table.insert(arg, #arg - 1, t'by'{theme=args.agent})
        args.agent = nil
      end
      rv = xp{false, x{k'PASSIVE', xp(arg)}}
    else
      -- TODO: "I've been rained on." vs. "It has rained on me."
      -- What is "it" in those sentences? An expletive? A quasi-argument?
      -- Use active voice for such confusing cases for now.
    end
  else
    rv = xp(arg)
  end
  if arg.progressive then
    rv = xp{false, x{k'PROGRESSIVE', rv}}
  end
  if arg.perfect then
    rv = xp{false, x{k'PERFECT', rv}}
  end
  if arg.mood then
    rv = xp{false, x{arg.mood, rv}}
  end
  if arg.neg then
    rv = xp{false, x{k'not', rv}}
  end
  -- TODO: Should k'INFINITIVE' create a different structure from +tense Ts?
  rv = xp{false, x{arg.tense or k'PRESENT', rv}}
  return rv
end

--[[


Args:
  arg:
]]
function ing(arg)
  return xp{
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
function np(arg)
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
  return xp(arg)
end

--[[


Args:
  arg:
]]
function past_participle(arg)
  -- adverb?
  -- verb
  -- TODO: adverb
  return xp{
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
function wh(arg)
  return xp{  -- CP
    x{f={wh=false}},
    x{
      k'that,C',
      infl(arg),
    },
  }
end

wh_bound = wh

wh_ever = wh

--[[


Args:
  arg:
]]
function fragment(arg)
  -- any
  return arg[1]
end

--[[


Args:
  arg:
]]
function noise(arg)
  -- The point of this function is to mark noises. It isn't particularly
  -- useful on its own. Eventually there will be some way to ensure that
  -- "rawr" always sounds like a roar and "ah" like a gasp, for example.
  return arg
end

--[[


Args:
  arg:
]]
function sentence(arg)
  -- any
  -- punct=
  -- TODO:
  -- vocative=
  -- [2]
  -- formality
  return xp{false, x{k(arg.punct or 'SENTENCE SEPARATOR'), arg[1]}}
end

--[[


Args:
  arg!
]]
function simple(arg)
  return sentence{
    vocative=arg.vocative,
    infl(arg),
    punct=arg.punct,
  }
end

--[[


Args:
  arg:
  sentence+
]]
function utterance(arg)
  local c = arg[#arg]
  for i = #arg - 2, 1, -1 do
    c = xp{arg[i], x{k'SENTENCE SEPARATOR', c}}
  end
  return c
end

--[[

]]
function it()
  return k'it'
end

--[[

]]
function me(context)
  context.me = {context.speaker}
  return cc('pronoun', 'me')
end

--[[

]]
function that()
  return k'that'
end

--[[

]]
function thee(context)
  context.thee = {context.hearers[0]}
  return cc('pronoun', 'thee')
end

--[[

]]
function thee_inanimate(context)
  -- TODO: differentiate
  return thee(context)
end

--[[

]]
function them(context)
  context.them = {true, true}
  return cc('pronoun', 'them')
end

--[[

]]
function this()
  return k'this'
end

--[[

]]
function us_inclusive(context)
  context.us_inclusive = copyall(context.hearers)
  context.us_inclusive[#context.us_inclusive + 1] = context.speaker
  return cc('pronoun', 'us_inclusive')
end

--[[

]]
function us_exclusive(context)
  context.us_inclusive = copyall(context.hearers)
  context.us_inclusive[#context.us_inclusive + 1] = true
  return cc('pronoun', 'us_inclusive')
end

--[[

]]
function you(context)
  return cc('pronoun', 'hearers')
end

--[[


Args:
  arg!
  verb
]]
function lets(arg, context)
  if not arg.args then
    arg.args = {}
  end
  arg.args.agent = us_inclusive(context)
  return simple{
    mood=k'IMPERATIVE',
    arg[1],
  }
end

--[[


Args:
  arg:
]]
function there_is(arg)
  -- noun
  -- punct=
  return simple{
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
function artifact_name(arg)
  -- artifact_record ID
  return {text='\xae' ..
          dfhack.TranslateName(df.artifact_record.find(arg).name) .. '\xaf'}
end

--[[


Args:
  arg:
]]
function building_type_name(arg)
  -- building_type
  return r(
    'building_type' .. WORD_ID_CHAR .. c(df.building_type, arg, 'building_type'))
end

--[[


Args:
  arg:
]]
function hf_name(arg)
  -- historical_figure ID
  return {text='\xae' ..
          dfhack.TranslateName(df.historical_figure.find(arg).name) .. '\xaf'}
end

--[[


Args:
  arg:
]]
function item(arg)
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
      handedness = adj{k'right-hand'}
    elseif item.handedness[1] then
      handedness = adj{k'left-hand'}
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
  local phrase = {false}
  phrase[#phrase + 1] = coin_entity
  phrase[#phrase + 1] = coin_ruler
  phrase[#phrase + 1] = t'made of material'{theme=r(material)}
  phrase[#phrase + 1] = handedness
  phrase[#phrase + 1] = r(head_key)
  -- TODO: fallback: "object I can't remember"
  return xp(phrase)
end

--[[


Args:
  arg:
]]
function job_skill(arg)
  -- job_skill
  return r('job_skill' .. WORD_ID_CHAR .. c(df.job_skill, arg, 'job_skill'))
end

--[[


Args:
  arg:
]]
function my_relationship_type_name(arg, context)
  -- unit_relationship_type
  return np{
    t('unit_relationship_type' .. WORD_ID_CHAR ..
      c(df.unit_relationship_type, arg, 'unit_relationship_type'))
      {relative=thee(context)}
  }
end

--[[


Args:
  arg:
]]
function relationship_type_name(arg)
  -- unit_relationship_type
  return r('unit_relationship_type' .. WORD_ID_CHAR ..
           c(df.unit_relationship_type, arg, 'unit_relationship_type'))
end

--[[

]]
function world_name()
  return {text='\xae' ..
          dfhack.TranslateName(df.global.world.world_data.name) .. '\xaf'}
end
