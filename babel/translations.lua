--@ module = true

local context_callbacks = reqscript('babel/context-callbacks')
local ps = reqscript('babel/ps')
local trees = reqscript('babel/trees')

local cc = trees.cc
local k = trees.k
local m = trees.m
local r = trees.r
local t = trees.t
local x = trees.x
local xp = trees.xp

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
function get_constituent(should_abort, topic, topic1, topic2, topic3, topic4,
                         english, speaker, hearers)
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

