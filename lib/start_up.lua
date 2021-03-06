start_up = {}

function start_up.init()
  
  softcut.buffer_clear()
  softcut.pan(1, 0.0)
  
  for i = 1, 4 do
    softcut.level(i,0.0)
    softcut.level_input_cut(1, i, 1.0)
    softcut.level_input_cut(2, i, 1.0)
    softcut.buffer(i, 1)
    audio.level_adc_cut(1)
    softcut.fade_time(i, 0.01)
    softcut.play(i, 1)
    softcut.rate(i, 1)
    softcut.loop_start(i, 1)
    softcut.loop_end(i, 9)
    softcut.loop_end(1,8.99)
    softcut.loop(i, 1)
    softcut.rec(1, 1)
    softcut.rec_level(1, 1)
    softcut.pre_level(1, 0.25)
    softcut.position(i, 1)
    softcut.phase_quant(i, 0.01)
    -- softcut.phase_quant(i, 1/15)
    -- softcut.rec_offset(i, -0.0003)
    softcut.enable(i, 1)
    softcut.rate_slew_time(4,0.2)
  end
  
  softcut.event_phase(phase)
  softcut.poll_start_phase()
  softcut.event_render(on_render)
  
  softcut.level(5,1)
  softcut.pan(5,-1)
  softcut.buffer(5,1)
  softcut.play(5, 1)
  softcut.rate(5, 1)
  softcut.loop_start(5, 41)
  softcut.loop_end(5, 41.5)
  softcut.loop(5, 1)
  softcut.rec(5, 1)
  softcut.rec_level(5, 1)
  softcut.pre_level(5, 0.5)
  softcut.recpre_slew_time(5,0.01)
  softcut.position(5, 41)
  -- softcut.rec_offset(5, -0.0003)
  softcut.enable(5, 1)
  
  softcut.level(6,1)
  softcut.pan(6,1)
  softcut.level_cut_cut(2,6,0.3)
  softcut.level_cut_cut(3,6,0.7)
  softcut.level_cut_cut(4,6,1)
  softcut.buffer(6,1)
  softcut.play(6, 1)
  softcut.rate(6, 1)
  softcut.loop_start(6, 71)
  softcut.loop_end(6, 71.5)
  softcut.loop(6, 1)
  softcut.rec(6, 1)
  softcut.rec_level(6, 1)
  softcut.pre_level(6, 0.5)
  softcut.recpre_slew_time(6,0.01)
  softcut.position(6, 71)
  -- softcut.rec_offset(6, -0.0003)
  softcut.enable(6, 1)
  
  --params:add_separator()
  
  params:add_group("loops + buffers", 27)

  params:add_separator("clips")
  
  for i = 1,3 do
    params:add_file("clip "..i.." sample", "clip "..i.." sample")
    params:set_action("clip "..i.." sample", function(file) load_sample(file,i) end)
  end

  for i = 1,3 do
    params:add{type = "trigger", id = "save_buffer"..i, name = "save live buffer "..i.." [K3]", action = function() save_sample(i) end}	
  end

  params:add_separator("live")

  for i = 1,3 do
    params:add_option("rec_loop_"..i, "live "..i.." rec behavior", {"loop","1-shot"}, 1)
    params:set_action("rec_loop_"..i,
      function(x)
        rec[i].loop = 2-x
        if rec[i].loop == 0 then rec.stopped = true end
        if rec.focus == i then
          softcut.loop(1,rec[rec.focus].loop)
          softcut.position(1,rec[rec.focus].start_point)
          softcut.rec_level(1,rec[rec.focus].state)
          if rec[rec.focus].state == 1 then
            if x == 2 then
              --rec_state_watcher:start()
              run_one_shot_rec_clock()
              softcut.pre_level(1,params:get("live_rec_feedback_"..rec.focus))
            elseif x == 1 then
              softcut.pre_level(1,params:get("live_rec_feedback_"..rec.focus))
            end
          end
        end
      end
    )
  end

  params:add_option("one_shot_clock_div","--> 1-shot sync",{"next beat","next bar","free"},1)
  params:add_control("one_shot_latency_offset","--> latency offset",controlspec.new(0,1,'lin',0.01,0,'s'))

  params:add_option("rec_loop_enc_resolution", "rec loop enc resolution", {"0.1","0.01","1/16","1/8","1/4","1/2","1 bar"}, 1)
  params:set_action("rec_loop_enc_resolution", function(x)
    local resolutions =
    { [1] = 10
    , [2] = 100
    , [3] = 1/(clock.get_beat_sec()/4)
    , [4] = 1/(clock.get_beat_sec()/2)
    , [5] = 1/(clock.get_beat_sec())
    , [6] = (1/(clock.get_beat_sec()))/2
    , [7] = (1/(clock.get_beat_sec()))/4
    }
    rec_loop_enc_resolution = resolutions[x]
    if x > 2 then
      -- rec[rec.focus].start_point = 1+(8*(rec.focus-1))
      -- local lbr = {1,2,4}
      -- rec[rec.focus].end_point = (1+(8*(rec.focus-1) + (1/rec_loop_enc_resolution))/lbr[params:get("live_buff_rate")])
      local lbr = {1,2,4}
      for i = 1,3 do
        rec[i].start_point = 1+(8*(i-1))
        rec[i].end_point = (1+(8*(i-1) + (1/rec_loop_enc_resolution))/lbr[params:get("live_buff_rate")])
      end
      softcut.loop_start(1,rec[rec.focus].start_point)
      softcut.loop_end(1,rec[rec.focus].end_point)
    end
  end)

  for i = 1,3 do
    params:add{id="live_rec_feedback_"..i, name="live "..i.." rec feedback", type="control", 
    controlspec=controlspec.new(0,1.0,'lin',0,0.25,""),
    action=function(x)
      if rec.focus == i and rec[rec.focus].state == 1 then
        softcut.pre_level(1,x)
      end
    end}
  end
  
  params:add_option("live_buff_rate", "live buffer max", {"8 sec", "16 sec", "32 sec"}, 1)
  params:set_action("live_buff_rate", function(x)
    local buff_rates = {1,0.5,0.25}
    softcut.rate(1,buff_rates[x])
    compare_rec_resolution(params:get("rec_loop_enc_resolution"))
    local rate_offset = {0,-12,-24}
    params:set("offset",rate_offset[x])
  end)
  
  for i = 1,3 do
    params:add_control("random_rec_clock_prob_"..i, "rand rec "..i.." probability", controlspec.new(0, 100, 'lin', 1, 0, "%"))
  end

  params:add_separator("global")

  params:add_control("offset", "global pitch offset", controlspec.new(-24, 24, 'lin', 1, 0, "st"))
  params:set_action("offset",
    function(value)
      for i=1,3 do
        for j = 1,16 do
          bank[i][j].offset = math.pow(0.5, -value / 12)
        end
        if bank[i][bank[i].id].pause == false then
          softcut.rate(i+1, bank[i][bank[i].id].rate*bank[i][bank[i].id].offset)
        end
      end
    end
  )
  
  loop_enc_resolution = {}
  local banks = {"(a)","(b)","(c)"}
  for i = 1,3 do
    params:add_option("loop_enc_resolution_"..i, "loops enc resolution "..banks[i], {"0.1","0.01","1/16","1/8","1/4","1/2","1 bar"}, 1)
    params:set_action("loop_enc_resolution_"..i, function(x)
      local resolutions =
      { [1] = 10
      , [2] = 100
      , [3] = 1/(clock.get_beat_sec()/4)
      , [4] = 1/(clock.get_beat_sec()/2)
      , [5] = 1/(clock.get_beat_sec())
      , [6] = (1/(clock.get_beat_sec()))/2
      , [7] = (1/(clock.get_beat_sec()))/4
      }
      loop_enc_resolution[i] = resolutions[x]
      for j = 1,16 do
        local pad = bank[i][j]
        if x > 2 then
          pad.end_point = pad.start_point + (((1/loop_enc_resolution[pad.bank_id])))
          if menu ~= 1 then screen_dirty = true end
        end
      end
      softcut.loop_start(i+1,bank[i][bank[i].id].start_point)
      softcut.loop_end(i+1,bank[i][bank[i].id].end_point)
      if all_loaded then
        mc.mft_redraw(bank[i][bank[i].id],"all")
      end
    end)
  end

  params:add_option("preview_clip_change", "preview clip changes?", {"yes","no"},1)
  params:set_action("preview_clip_change", function() if all_loaded then persistent_state_save() end end)
  
  --params:add_option("zilchmo_bind_rand","bind random zilchmo?", {"no","yes"}, 1)
  
  params:add_group("patterns + arps",23)
  params:add_separator("patterns")
  params:add_option("zilchmo_patterning", "grid pat style", { "classic", "rad sauce" })
  params:set_action("zilchmo_patterning", function() if all_loaded then persistent_state_save() end end)
  params:add_option("arc_patterning", "arc pat style", { "passive", "active" })
  params:set_action("arc_patterning", function() if all_loaded then persistent_state_save() end end)
  for i = 1,3 do
    params:add_option("sync_clock_to_pattern_"..i, "sync bpm to free pat "..i.."?", { "no", "yes" })
    params:set_action("sync_clock_to_pattern_"..i, function() if all_loaded then persistent_state_save() end end)
  end
  params:add_separator("pattern quantization")
  for i = 1,3 do
    params:add_option("pattern_"..i.."_quantization", "quantize pat "..i.."?", {"no", "yes"})
    params:set_action("pattern_"..i.."_quantization", function(x)
      grid_pat[i]:quant(x == 1 and 0 or 1)
      if midi_pat ~= nil then -- TODO FIXME
        midi_pat[i]:quant(x == 1 and 0 or 1)
      end
    end
    )
  end
  params:add_option("launch_quantization", "pat launch quant", {"next beat", "next bar"})
  params:add_separator("random patterns")
  for i = 1,3 do
    params:add_option("random_patterning_"..i,"rand pat "..i.." style", 
      { "rand"
      , "horizontal"
      , "h.snake"
      , "vertical"
      , "v.snake"
      , "top-in"
      , "bottom-in"
      , "zig-zag"
      , "wrap"
    })
    params:set_action("random_patterning_"..i, function(x)
      if x > 1 then
        grid_pat[i].playmode = 2
        if midi_pat ~= nil then -- TODO FIXME
          midi_pat[i].playmode = 2
        end
      end
    end)
  end

  for i = 1,3 do
    params:add_option("rand_pattern_"..i.."_note_length", "rand pat "..i.." note length", {"1/16", "1/8", "1/4", "1/2", "1", "rand"},6)
  end

  params:add_separator("arps (grid only)")
  for i = 1,3 do
    params:add_option("arp_"..i.."_hold_style", "arp "..i.." hold style", {"last pressed","additive"},1)
  end

  params:add_trigger("arp_panic","arp reset (K3)")
  params:set_action("arp_panic",
    function (x)
      if all_loaded == true then
        print("here")
        for i = 1,3 do
          clock.cancel(arp_clock[i])
          arp_clock[i] = nil
          arp_clock[i] = clock.run(arps.arpeggiate,i)
        end
      end
    end
  )
  
  params:add_group("mappable control",89)

  params:add{type='binary',name="save mappings",id='save_mappings',behavior='momentary', allow_pmap=false,
  action=function(x)
    if all_loaded and x == 1 then
      norns.pmap.write()
    end
  end
  }

params:add_separator("ALT key")

  params:add{type='binary',name="ALT key",id='alt_key',behavior='momentary',
  action=function(x)
    if all_loaded then
      grid.alt = x == 1 and true or false
      grid_dirty = true
    end
  end
  }
  -- params:hide("manual control")

  params:add_separator("arc encoders")
  for i = 1,3 do
    params:add_option("enc_"..i.."_param", "enc "..i.." param", {"loop window", "loop start", "loop end", "filter tilt", "level", "pan"})
    params:set_action("enc_"..i.."_param", function(x)
      arc_param[i] = x
    end)
  end

  params:add_separator("pattern trigs")

  for i = 1,3 do
    params:add{type='binary',name="midi pat "..i.." rec",id='midi_pat_'..i..' rec',behavior='trigger',
      action=function()
        if all_loaded then
          -- if x == 1 then
            -- print(i)
            if midi_pat[i].rec == 0 then
              if midi_pat[i].count == 0 and not grid.alt then
                midi_pattern_recording(i,"start")
              elseif midi_pat[i].count ~= 0 and not grid.alt then
                toggle_midi_pattern_overdub(i)
              elseif grid.alt then
                if midi_pat[i].count > 0 then
                  midi_pat[i]:rec_stop()
                  if midi_pat[i].clock ~= nil then
                    print("clearing clock: "..midi_pat[i].clock)
                    clock.cancel(midi_pat[i].clock)
                  end
                  midi_pat[i]:clear()
                end
              end
            elseif midi_pat[i].rec == 1 then
              if not grid.alt then
                midi_pattern_recording(i,"stop")
              end
            end
          -- end
        end
      end
    }
  end

  for i = 1,3 do
    params:add{type='binary',name="random pattern "..i,id='random_pat_'..i,behavior='trigger',
      action=function()
        if all_loaded then
          -- if x == 1 then
            if g.device ~= nil then
              random_grid_pat(i,3)
            else
              random_midi_pat(i)
            end
          -- end
        end
      end
    }
  end

  for i = 1,3 do
    params:add{type='binary',name="shuffle pattern "..i,id='shuffle_pat_'..i,behavior='trigger',
      action=function(x)
        if all_loaded then
          if x == 1 then
            if g.device ~= nil then
              random_grid_pat(id,2)
            else
              shuffle_midi_pat(id)
            end
          end
        end
      end
    }
  end

  params:add_separator("live recording trigs")

  for i = 1,3 do
    params:add{type='binary',name="rec live "..i,id='rec_live_'..i,behavior='trigger',
      action=function()
        if all_loaded then
          if not grid.alt then
            toggle_buffer(i)
          else
            buff_flush()
          end
        end
      end
    }
  end

  params:add_separator("zilchmos: global mods")

  local global_zilches =
  {
    {"0.5x rate","0.5x_rate"}
  , {"2x rate","2x_rate"}
  , {"reverse rate","reverse_rate"}
  , {"reverse pan","reverse_pan"}
  , {"random pan","random_pan"}
  , {"pause","pause"}
  , {"random start","random_start"}
  , {"random end","random_end"}
  , {"random window","random_window"}
  }

  for i = 1,#global_zilches do
    params:add{type='binary',name=global_zilches[i][1],id=global_zilches[i][2],behavior='momentary',
      action=function(x)
        if all_loaded then
          mc.midi_mod_table[global_zilches[i][1]] = x == 1 and true or false
        end
      end
    }
  end

  params:add_separator("zilchmos: local mods")

  local local_zilches =
  {
    {"a: 0.5x rate","a_0.5x_rate"}
  , {"b: 0.5x rate","b_0.5x_rate"}
  , {"c: 0.5x rate","c_0.5x_rate"}
  , {"a: 2x rate","a_2x_rate"}
  , {"b: 2x rate","b_2x_rate"}
  , {"c: 2x rate","c_2x_rate"}
  , {"a: reverse rate","a_reverse_rate"}
  , {"b: reverse rate","b_reverse_rate"}
  , {"c: reverse rate","c_reverse_rate"}
  , {"a: random pan","a_random_pan"}
  , {"b: random pan","b_random_pan"}
  , {"c: random pan","c_random_pan"}
  , {"a: pause","a_pause"}
  , {"b: pause","b_pause"}
  , {"c: pause","c_pause"}
  , {"a: random start","a_random_start"}
  , {"b: random start","b_random_start"}
  , {"c: random start","c_random_start"}
  , {"a: random end","a_random_end"}
  , {"b: random end","b_random_end"}
  , {"c: random end","c_random_end"}
  , {"a: random window","a_random_window"}
  , {"b: random window","b_random_window"}
  , {"c: random window","c_random_window"}
  }

  for i = 1,#local_zilches do
    params:add{type='binary',name=local_zilches[i][1],id=local_zilches[i][2],behavior='momentary',
      action=function(x)
        if all_loaded then
          mc.midi_mod_table[local_zilches[i][1]] = x == 1 and true or false
        end
      end
    }
  end
  
  for i = 1,3 do
    local banks = {"(a)","(b)","(c)"}
    params:add_separator(banks[i].." values")
    params:add_control("current pad "..i, "current pad "..banks[i], controlspec.new(1,16,'lin',1,1))
    params:set_action("current pad "..i, function(x)
      if bank[i].id ~= x then
        bank[i].id = x
        selected[i].x = (math.ceil(bank[i].id/4)+(5*(i-1)))
        selected[i].y = 8-((bank[i].id-1)%4)
        cheat(i,bank[i].id)
        screen_dirty = true
        grid_dirty = true
      end
    end)
    local rates = {-4,-2,-1,-0.5,-0.25,-0.125,0.125,0.25,0.5,1,2,4}
    params:add_option("rate "..i, "rate "..banks[i], {"-4x","-2x","-1x","-0.5x","-0.25x","-0.125x","0.125x","0.25x","0.5x","1x","2x","4x"}, 10)
    params:set_action("rate "..i, function(x)
      for p = (grid.alt and 1 or bank[i].id),(grid.alt and 16 or bank[i].id) do
        bank[i][p].rate = rates[x]
      end
      if bank[i][bank[i].id].pause == false then
        softcut.rate(i+1, bank[i][bank[i].id].rate*bank[i][bank[i].id].offset)
      end
    end)
    params:add_control("rate slew time "..i, "rate slew time "..banks[i], controlspec.new(0,3,'lin',0.01,0))
    params:set_action("rate slew time "..i, function(x) softcut.rate_slew_time(i+1,x) end)
    params:add_control("pan "..i, "pan "..banks[i], controlspec.new(-1,1,'lin',0.01,0))
    params:set_action("pan "..i, function(x)
      softcut.pan(i+1,x)
      for p = (grid.alt and 1 or bank[i].id),(grid.alt and 16 or bank[i].id) do
        bank[i][p].pan = x
      end
      screen_dirty = true
    end)
    params:add_control("pan slew "..i,"pan slew "..banks[i], controlspec.new(0.,200.,'lin',0.1,5.0))
    params:set_action("pan slew "..i, function(x) softcut.pan_slew_time(i+1,x) end)
    params:add_control("level "..i, "pad level "..banks[i], controlspec.new(0,127,'lin',1,64))
    params:set_action("level "..i, function(x)
      for p = (grid.alt and 1 or bank[i].id),(grid.alt and 16 or bank[i].id) do
        mc.adjust_pad_level(bank[i][p],x)
      end
      if all_loaded then mc.redraw(bank[i][bank[i].id]) end
      end)
    params:add_control("bank level "..i, "bank level "..banks[i], controlspec.new(0,127,'lin',1,64))
    params:set_action("bank level "..i, function(x)
      mc.adjust_bank_level(bank[i][bank[i].id],x)
      if all_loaded then mc.redraw(bank[i][bank[i].id]) end
      end)
    params:add_control("start point "..i, "start point "..banks[i], controlspec.new(0,127,'lin',1,0))
    params:set_action("start point "..i, function(x)
      mc.move_start(bank[i][bank[i].id],x)
      if all_loaded then mc.redraw(bank[i][bank[i].id]) end
      end)
    params:add_control("end point "..i, "end point "..banks[i], controlspec.new(0,127,'lin',1,8))
    params:set_action("end point "..i, function(x)
      mc.move_end(bank[i][bank[i].id],x)
      if all_loaded then mc.redraw(bank[i][bank[i].id]) end
      end)
    params:add{type='binary',name="toggle loop "..banks[i],id="loop_"..i,behavior='momentary',
      action=function(x)
        if x == 1 then
          grid_actions.toggle_pad_loop(i)
        end
      end
    }
  end
  
  params:add_group("delays",51)

  params:add_separator("manage delay audio")
  params:add{type = "trigger", id = "save_left_delay", name = "** save L delay", action = function() del.save_delay(1) end}
  params:add{type = "trigger", id = "save_right_delay", name = "save R delay **", action = function() del.save_delay(2) end}
  params:add{type = "trigger", id = "save_both_delays", name = "** save both delays **", action = function() for i = 1,2 do del.save_delay(i) end end}
  params:add_file("load_left_delay", "--> load L delay")
  params:set_action("load_left_delay", function(file) del.load_delay(file,1) end)
  params:add_file("load_right_delay", "load R delay <--")
  params:set_action("load_right_delay", function(file) del.load_delay(file,2) end)
  
  
  for i = 4,5 do
    local sides = {"L","R"}
    params:add_separator("delay output "..sides[i-3])
    params:add_control("delay "..sides[i-3]..": global level", "delay "..sides[i-3]..": global level", controlspec.new(0,1,'lin',0,0,""))
    params:set_action("delay "..sides[i-3]..": global level", function(x) softcut.level(i+1,x) screen_dirty = true encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","global level") end)
    params:add_option("delay "..sides[i-3]..": mode", "delay "..sides[i-3]..": mode", {"clocked", "free"},1)
    params:set_action("delay "..sides[i-3]..": mode", function(x)
      if x == 1 then
        delay[i-3].mode = "clocked"
        softcut.loop_end(i+1,delay[i-3].end_point)
      else
        delay[i-3].mode = "free"
        softcut.loop_end(i+1,delay[i-3].free_end_point)
      end
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","mode")
      screen_dirty = true
    end)
    params:add_option("delay "..sides[i-3]..": div/mult", "--> clocked div/mult: ",
    {"x16"   ,"x15 3/4"   ,"x15 2/3"   ,"x15 1/2"   ,"x15 1/3"   ,"x15 1/4"
    , "x15"   ,"x14 3/4"   ,"x14 2/3"   ,"x14 1/2"   ,"x14 1/3"   ,"x14 1/4"
    , "x14"   ,"x13 3/4"   ,"x13 2/3"   ,"x13 1/2"   ,"x13 1/3"   ,"x13 1/4"
    , "x13"   ,"x12 3/4"   ,"x12 2/3"   ,"x12 1/2"   ,"x12 1/3"   ,"x12 1/4"
    , "x12"   ,"x11 3/4"   ,"x11 2/3"   ,"x11 1/2"   ,"x11 1/3"   ,"x11 1/4"
    , "x11"   ,"x10 3/4"   ,"x10 2/3"   ,"x10 1/2"   ,"x10 1/3"   ,"x10 1/4"
    , "x10"   ,"x9 3/4"   ,"x9 2/3"   ,"x9 1/2"   ,"x9 1/3"   ,"x9 1/4"
    , "x9"    ,"x8 3/4"   ,"x8 2/3"   ,"x8 1/2"   ,"x8 1/3"   ,"x8 1/4"
    , "x8"    ,"x7 3/4"   ,"x7 2/3"   ,"x7 1/2"   ,"x7 1/3"   ,"x7 1/4"
    , "x7"    ,"x6 3/4"   ,"x6 2/3"   ,"x6 1/2"   ,"x6 1/3"   ,"x6 1/4"
    , "x6"    ,"x5 3/4"   ,"x5 2/3"   ,"x5 1/2"   ,"x5 1/3"   ,"x5 1/4"
    , "x5"    ,"x4 3/4"   ,"x4 2/3"   ,"x4 1/2"   ,"x4 1/3"   ,"x4 1/4"
    , "x4"    ,"x3 3/4"   ,"x3 2/3"   ,"x3 1/2"   ,"x3 1/3"   ,"x3 1/4"
    , "x3"    ,"x2 3/4"   ,"x2 2/3"   ,"x2 1/2"   ,"x2 1/3"   ,"x2 1/4"
    , "x2"    ,"x1 3/4"   ,"x1 2/3"   ,"x1 1/2"   ,"x1 1/3"   ,"x1 1/4"
    , "x1"    ,"/1 1/4"   ,"/1 1/3"   ,"/1 1/2"   ,"/1 2/3"   ,"/1 3/4"   ,"/2"   ,"/4"
    },91)
    params:set_action("delay "..sides[i-3]..": div/mult", function(x)
      delay[i-3].clocked_length = clocked_delays[x]
      delay[i-3].id = x
      local delay_rate_to_time = clock.get_beat_sec() * clocked_delays[x] * delay[i-3].modifier
      local delay_time = delay_rate_to_time + (41 + (30*(i-4)))
      delay[i-3].end_point = delay_time
      softcut.loop_end(i+1,delay[i-3].end_point)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","div/mult")
      screen_dirty = true
    end)
    params:add{
      type='control',
      id='delay '..sides[i-3]..': free length',
      name='--> free length: ',
      controlspec=controlspec.def{
        min=0.00,
        max=30.0,
        warp='lin',
        step=0.0001,
        default=1,
        quantum=0.0001,
        wrap=false,
      },
    }
    params:hide("delay "..sides[i-3]..": free length")
    params:set_action("delay "..sides[i-3]..": free length", function(x)
      if delay[i-3].mode == "free" then
        delay[i-3].free_end_point = delay[i-3].start_point + x
        softcut.loop_end(i+1,delay[i-3].free_end_point)
        encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","free length")
      end
    end)
    --params:add_control("delay "..sides[i-3]..": free length", "--> free length: ", controlspec.new(0.01,30,'lin',0.01,0.01,""))
    params:add{
      type='control',
      id="delay "..sides[i-3]..": fade time",
      name="delay "..sides[i-3]..": fade time",
      controlspec=controlspec.def{
        min=0.000,
        max=2.000,
        warp='lin',
        step=0.001,
        default=0.01,
        quantum=0.001,
        wrap=false,
      },
    }
    params:set_action("delay "..sides[i-3]..": fade time", function(x)
      softcut.fade_time(i+1,x)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","fade time")
    end)
    params:add{
      type='control',
      id="delay "..sides[i-3]..": rate",
      name="delay "..sides[i-3]..": rate",
      controlspec=controlspec.def{
        min=0.25,
        max=24.000,
        warp='lin',
        step=0.01,
        default=1,
        quantum=1/(23.75*100),
        wrap=false,
      },
    }
    params:set_action("delay "..sides[i-3]..": rate", function(x)
      delay[i-3].rate = x
      softcut.rate(i+1,x*(delay[i-3].reverse and -1 or 1))
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","rate")
    end)
    params:add_option("delay "..sides[i-3]..": rate bump", "delay "..sides[i-3]..": rate bump", {"fifth","detune"}, 1)
    params:add_control("delay "..sides[i-3]..": rate slew time", "delay "..sides[i-3]..": rate slew time", controlspec.new(0,3,'lin',0.01,0.01))
    params:set_action("delay "..sides[i-3]..": rate slew time", function(x) softcut.rate_slew_time(i+1,x) end)
    params:add_control("delay "..sides[i-3]..": feedback", "delay "..sides[i-3]..": feedback", controlspec.new(0,100,'lin',0,50,"%"))
    params:set_action("delay "..sides[i-3]..": feedback",
    function(x)
      softcut.pre_level(i+1,(x/100))
      screen_dirty = true
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","feedback")
    end)
    params:add{type = "trigger", id = "save_delay_"..sides[i-3], name = "***** save delay "..sides[i-3].." ***** [K3]", action = function() del.save_delay(i-3) end}	
  end

  params:add_separator("delay input")

  for i = 1,3 do
    local banks = {"a","b","c"}
    params:add_control("delay L: ("..banks[i]..") send", "delay L: ("..banks[i]..") send", controlspec.new(0,1,'lin',0.1,0,""))
    params:set_action("delay L: ("..banks[i]..") send", function(x)
      if bank[i][bank[i].id].enveloped == false then
        softcut.level_cut_cut(i+1,5,(x*bank[i][bank[i].id].level)*bank[i].global_level)
      end
      for j = 1,16 do
        bank[i][j].left_delay_level = x
      end
      grid_dirty = true
    end)
    params:add_control("delay R: ("..banks[i]..") send", "delay R: ("..banks[i]..") send", controlspec.new(0,1,'lin',0.1,0,""))
    params:set_action("delay R: ("..banks[i]..") send", function(x)
      if bank[i][bank[i].id].enveloped == false then
        softcut.level_cut_cut(i+1,6,(x*bank[i][bank[i].id].level)*bank[i].global_level)
      end
      for j = 1,16 do
        bank[i][j].right_delay_level = x
      end
      grid_dirty = true
    end)
  end

  for i = 1,2 do
    local sides = {"L","R"}
    params:add_control("delay "..sides[i]..": external input", "delay "..sides[i]..": external input", controlspec.new(0,1,'lin',0.1,0,""))
    params:set_action("delay "..sides[i]..": external input", function(x)
      softcut.level_input_cut(1,i+4,x)
      softcut.level_input_cut(2,i+4,x)
    end)
  end
  
  --params:add_separator()
  
  for i = 4,5 do
    local sides = {"L","R"}
    params:add_separator("delay filters "..sides[i-3])
    params:add_control("delay "..sides[i-3]..": filter cut", "delay "..sides[i-3]..": filter cut", controlspec.new(10,12000,'exp',1,12000,"Hz"))
    params:set_action("delay "..sides[i-3]..": filter cut",
    function(x)
      softcut.post_filter_fc(i+1,x)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","filter cut")
    end)
    params:add_control("delay "..sides[i-3]..": filter q", "delay "..sides[i-3]..": filter q", controlspec.new(0.001, 8.0, 'exp', 0, 1.0, ""))
    params:set_action("delay "..sides[i-3]..": filter q",
    function(x)
      softcut.post_filter_rq(i+1,x)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","filter q")
    end)
    params:add_control("delay "..sides[i-3]..": filter lp", "delay "..sides[i-3]..": filter lp", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action("delay "..sides[i-3]..": filter lp",
    function(x)
      softcut.post_filter_lp(i+1,x)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","filter lp")
    end)
    params:add_control("delay "..sides[i-3]..": filter hp", "delay "..sides[i-3]..": filter hp", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action("delay "..sides[i-3]..": filter hp",
    function(x)
      softcut.post_filter_hp(i+1,x)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","filter hp")
    end)
    params:add_control("delay "..sides[i-3]..": filter bp", "delay "..sides[i-3]..": filter bp", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action("delay "..sides[i-3]..": filter bp",
    function(x)
      softcut.post_filter_bp(i+1,x)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","filter bp")
    end)
    params:add_control("delay "..sides[i-3]..": filter dry", "delay "..sides[i-3]..": filter dry", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action("delay "..sides[i-3]..": filter dry",
    function(x)
      softcut.post_filter_dry(i+1,x)
      encoder_actions.check_delay_links(sides[i-3], sides[i-3] == "L" and "R" or "L","filter dry")
    end)
  end
  
  --params:add_separator()
  
  params:add_group("ignore",18)
  params:hide("ignore")
  
  --params:add{type = "trigger", id = "ignore", name = "ignore, data only:"}
  
  for i = 1,3 do
    local banks = {"(a)", "(b)", "(c)"}
    params:add_control("filter "..i.." cutoff", "filter "..banks[i].." cutoff", controlspec.new(10,12000,'lin',1,12000,"Hz"))
    params:set_action("filter "..i.." cutoff", function(x) softcut.post_filter_fc(i+1,x) bank[i][bank[i].id].fc = x end)
    params:add_control("filter "..i.." q", "filter "..banks[i].." q", controlspec.new(0.0005, 2.0, 'exp', 0, 0.32, ""))
    params:set_action("filter "..i.." q", function(x)
      softcut.post_filter_rq(i+1,x)
      for j = 1,16 do
        bank[i][j].q = x
      end
    end)
    params:add_control("filter "..i.." lp", "filter "..banks[i].." lp", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action("filter "..i.." lp", function(x) softcut.post_filter_lp(i+1,x) bank[i][bank[i].id].lp = x end)
    params:add_control("filter "..i.." hp", "filter "..banks[i].." hp", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action("filter "..i.." hp", function(x) softcut.post_filter_hp(i+1,x) bank[i][bank[i].id].hp = x end)
    params:add_control("filter "..i.." bp", "filter "..banks[i].." bp", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action("filter "..i.." bp", function(x) softcut.post_filter_bp(i+1,x) bank[i][bank[i].id].bp = x end)
    params:add_control("filter "..i.." dry", "filter "..banks[i].." dry", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action("filter "..i.." dry", function(x) softcut.post_filter_dry(i+1,x) bank[i][bank[i].id].fd = x end)
  end
  
end

return start_up