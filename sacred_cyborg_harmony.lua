-- Sacred Cyborg
--  Harmony

-- @sixolet and @nonverbalpoetry

-- Plug in a MIDI keyboard.
-- Play a chord
-- Sing. Cyborgs sing with you.

-- All controls are in params.


music = require 'musicutil'
include('lib/passencorn')

engine.name = "TheMachine"
SCALE_NAMES = {}
for i, v in pairs(music.SCALES) do
  SCALE_NAMES[i] = v["name"]
end

scale = nil
scaleSet = {}
activePitchClasses = {}
sungNote = nil
amp = 0

function set_scale()
  scale = music.generate_scale(params:get("root") - 12, scale_name(), 10)
  scaleSet = {}
  for i, note in ipairs(scale) do
    scaleSet[note % 12] = true
  end
end

function scale_name()
  return SCALE_NAMES[params:get("scale")]
end



function redraw()
  screen.clear()
  screen.aa(1)
  local x, y
  screen.move(2, 58)
  if amp == 0 then
    screen.text("no input")
    screen.stroke()
  end
      
  for i=0,11,1 do
    if scaleSet[i] ~= nil then
      screen.level(15)
    else
      screen.level(0)
    end
    x = 64 - 35*math.sin(2 * math.pi * (i/12))
    y = 32 + 25*math.cos(2 * math.pi * (i/12))
    screen.circle(x, y, 2)
    screen.fill()
    if sungNote ~= nil and sungNote % 12 == i then
      if amp < 0.01 then
        screen.level(3)
      else
        screen.level(8)
      end        
      screen.move(64, 32)
      screen.line(x, y)
      screen.stroke()
    end
  end
  screen.level(8)
  local count = 0
  for i=0,11,1 do
    if activePitchClasses[i] == true then
      x = 64 - 35*math.sin(2 * math.pi * (i/12))
      y = 32 + 25*math.cos(2 * math.pi * (i/12))
      if count == 0 then
        screen.move(x, y)
      else
        screen.line(x, y)
      end
      count = count + 1
    end
  end
  if count > 1 then
    screen.close()
    screen.stroke()
  elseif count == 1 then
    screen.circle(x, y, 6)
    screen.stroke()
  end
  if unquantizedSungNote ~= nil then
    local i = unquantizedSungNote % 12
    local x = 64 - 10*math.sin(2 * math.pi * (i/12))
    local y = 32 + 7*math.cos(2 * math.pi * (i/12))
    if amp < 0.01 then
      screen.level(1)
    else
      screen.level(8)
    end
    screen.move(64, 32)
    screen.line(x, y)
    screen.stroke()
  end
  screen.update()
end

function change_range()
  if params:get("high") < 2*params:get("low") then
    params:set("high", 2*params:get("low"))
  end
  engine.setInputRange(params:get("low"), params:get("high"))
end

function change_input_mix()
  if params:get("style") == 1 then -- mix to mono
    engine.setMix(0.5, 0.5, 0, 0, 0);
    params:hide("background amp")
    params:hide("background pan")
  elseif params:get("style") == 2 then
    params:show("background amp")
    params:show("background pan")    
    engine.setMix(1, 0, 0, params:get("background amp"), params:get("background pan"))
  end
  if _menu.rebuild_params ~= nil then
    _menu.rebuild_params()
  end
end

function init()
  osc.event = osc_in
  screen_redraw_clock = clock.run(
    function()
      while true do
        clock.sleep(1/15) 
        if screen_dirty == true then
          redraw()
          screen_dirty = false
        end
      end
    end
  )
  params:add_separator("quantization")
  params:add_number("root","root",24,35,24, 
    function(param) return music.note_num_to_name(param:get()) end,
    true
    )
  params:set_action("root", set_scale)
  params:add_option("scale", "scale", SCALE_NAMES, 1)
  params:set_action("scale", set_scale)
  hysteresis_spec = controlspec.UNIPOLAR:copy()
  hysteresis_spec.default = 0.2
  params:add_control("hysteresis", "hysteresis", hysteresis_spec)
  local lowspec = controlspec.FREQ:copy()
  lowspec.default = 82
  local highspec = controlspec.FREQ:copy()
  highspec.default = 1046
  params:add_control("low", "in range low", lowspec)
  params:add_control("high", "in range high", highspec)
  
  params:add_separator("lead cyborg")
  local pull_spec = controlspec.UNIPOLAR:copy()
  pull_spec.default = 1
  params:add_control("pull", "quantize amount", pull_spec)
  local amp_spec = controlspec.AMP:copy()
  amp_spec.default = 0.5 
  params:add_control("lead amp", "amp", amp_spec)
  params:add_control("lead formants", "formants", controlspec.new(0.5, 2, 'lin', 0, 1, ""))
  params:add_control("lead acquisition", "acquisition speed", controlspec.new(0.01, 0.5, 'exp', 0, 0.1, "s"))
  params:add_control("lead pan", "pan", controlspec.BIPOLAR)
  
  
  params:add_separator("cyborg choir")
  local my_delay = controlspec.DELAY:copy()
  my_delay.default = 0.02
  params:add_control("delay", "max random delay", my_delay)
  params:add_control("vibrato", "vibrato amount", controlspec.new(0, 3, 'lin', 0, 0, ""))
  params:add_control("vibrato speed", "vibrato speed", controlspec.LOFREQ)
  params:add_control("choir amp", "amp", amp_spec)
  params:add_control("choir formants", "formants @C3", controlspec.new(0.5, 2, 'lin', 0, 1, ""))
  params:add_control("keytrack", "formant keytrack", controlspec.new(-1, 2, 'lin', 0, 0.15, ""))
  params:add_control("choir pan", "pan", controlspec.BIPOLAR)
  params:add_option("sensitivity", "velocity sensitivity", {"none", "linear", "square"}, 1)  
  
  
  midi_device = {} -- container for connected midi devices
  midi_device_names = {}
  target = 1

  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
    local full_name = 
    table.insert(midi_device_names,"port "..i..": "..util.trim_string_to_width(midi_device[i].name,40)) -- register its name
  end
  
  
  params:add_separator("midi")
  params:add_option("midi target", "midi target",midi_device_names,1)
  params:set_action("midi target", midi_target)
  
  params:add_separator("source")
  params:add_option("style", "style", {"mix LR mono", "L voice R background"}, 1)
  params:set_action("style", change_input_mix)
  params:add_control("background amp", "background amp", amp_spec)
  params:set_action("background amp", change_input_mix)
  params:add_control("background pan", "background pan", controlspec.BIPOLAR)
  params:set_action("background pan", change_input_mix)

  params:read()
  params:bang()
end

active_notes = {}

function midi_target(x)
  midi_device[target].event = nil
  target = x
  midi_device[target].event = process_midi
end

function process_midi(data)
  local d = midi.to_msg(data)
  if d.type == "note_on" then
    -- global
    note = d.note
    active_notes[d.note] = true
    activePitchClasses[d.note % 12] = true
    local hz = music.note_num_to_freq(d.note)
    local formant = params:get("choir formants")*(hz/music.note_num_to_freq(60))^params:get("keytrack")
    engine.noteOn(
      hz, 
      params:get("choir amp")*(d.vel/127)^(params:get("sensitivity")-1), 
      math.random()*params:get("delay"), 
      params:get("vibrato"), 
      params:get("vibrato speed"),
      formant,
      params:get("choir pan"),
      d.note)
    screen_dirty = true
    -- print("on", d.note)
  elseif d.type == "note_off" then
    active_notes[d.note] = false
    activePitchClasses[d.note % 12] = nil
    engine.noteOff(d.note)
    screen_dirty = true
    -- print("off", d.note)
  -- elseif d.type == "pitchbend" then
  --   local bend_st = (util.round(d.val / 2)) / 8192 * 2 -1 -- Convert to -1 to 1
  --   set_pitch_bend(d.ch, bend_st * params:get("bend_range"))
  end
end

function osc_in(path, args, from)

  if path == "/measuredPitch" then
    local pitch = args[1]
    amp = args[2]
    -- print(pitch)
    unquantizedSungNote = freq_to_note_num_float(pitch)
    screen_dirty = true
    if scale == nil then
      return
    end
    -- Introduce a little bit of hysteresis if we're near
    if scale ~= nil then
      local newNote = quantize(scale, pitch, sungNote, params:get("hysteresis"))
      if sungNote ~= newNote then
        -- print("pitch", pitch, "unquant", unquantizedSungNote, "quant", newNote)
        sungNote = newNote
        engine.acceptQuantizedPitch(
          music.note_num_to_freq(sungNote), params:get("pull"), params:get("lead amp"), params:get("lead formants"), params:get("lead acquisition"), params:get("lead pan"))
      end
    end
  end
end
