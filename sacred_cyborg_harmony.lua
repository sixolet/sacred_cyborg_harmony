music = require 'musicutil'
include('lib/passencorn')

engine.name = "TheMachine"
SCALE_NAMES = {}
for i, v in pairs(music.SCALES) do
  SCALE_NAMES[i] = v["name"]
end

AUTO_OPTS = {"off", "root"}

AUTO_OPT_OFF = 1
AUTO_OPT_ROOT = 2

ACTIONS = {"none", "target", "passing"}

ACTION_NONE = 1
ACTION_TARGET = 2
ACTION_PASSING = 3

scale = nil
sungNote = nil

function set_scale()
  scale = music.generate_scale(params:get("root") - 12, scale_name(), 10)
end

function scale_name()
  return SCALE_NAMES[params:get("scale")]
end

function new_chord()
  local ranges
  if params:get("population") == 2 then
    ranges = {bass, soprano}
  elseif params:get("population") == 3 then
    ranges = {bass, tenor, soprano}
  elseif params:get("population") == 4 then
    ranges = {contrabass, tenor, alto, soprano}
  elseif params:get("population") == 5 then
    ranges = {contrabass, tenor, alto, alto, soprano}
  end
  
  if params:get("style") == AUTO_OPT_ROOT then
    local possible_chords = {}
    local all_chords = music.chord_types_for_note(
      sungNote, params:get("root"), scale_name())
    for i, v in ipairs(all_chords) do
      if params:get("population") <= 3 then
        -- Only triads
        if util.string_starts(v, "M") and not string.find(v, " ") then
          table.insert(possible_chords, v)
        end
      elseif params:get("population") == 4 then
        -- Exclude the big jazz chords
        if not (string.find(v, "11") or string.find(v, "13") or string.find(v, "th")) then 
          table.insert(possible_chords, v)
        end
      else
        table.insert(possible_chords, v)
      end
    end
    
    if #possible_chords == 0 then
      return
    end
    
    chord_name = possible_chords[ math.random(1, #possible_chords)]
    local chord_notes = music.generate_chord(sungNote, chord_name)
    while #chord_notes > params:get("population") do
      if params:get("population") == 2 then
        table.remove(1)
      else
        table.remove(chord_notes, math.ceil(#chord_notes/2))
      end
    end
    while #chord_notes < params:get("population") do
      table.insert(chord_notes, chord_notes[math.random(1, #chord_notes)])
    end
    for i, v in ipairs(chord_notes) do
      chord_notes[i] = ranges[i](v)
    end
    for i=1,5,1 do
      if chord_notes[i] == nil then
        engine.noteOff(i)
      else
        local freq = music.note_num_to_freq(chord_notes[i])
        engine.noteOn(freq, 0.5, i)
      end
    end
  else
    if chord_name ~= nil then
      for i = 1,5,1 do
        engine.noteOff(i)
      end
    end
    chord_name = nil
  end
end

function redraw()
  screen.clear()
  if chord_name then
    screen.move(0,40)
    screen.level(15)
    screen.text(music.note_num_to_name(sungNote) .. " " .. chord_name)
  end
  screen.update()
end

function init()
  
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
  params:add_number("root","root",24,35,24, 
    function(param) return music.note_num_to_name(param:get(), true) end,
    true
    )
  params:set_action("root", set_scale)
  params:add_option("scale", "scale", SCALE_NAMES, 1)
  params:set_action("scale", set_scale)
  
  midi_device = {} -- container for connected midi devices
  midi_device_names = {}
  target = 1

  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
    local full_name = 
    table.insert(midi_device_names,"port "..i..": "..util.trim_string_to_width(midi_device[i].name,40)) -- register its name
  end
  params:add_separator("cyborg choir")
  params:add_option("style", "harmony style", AUTO_OPTS, AUTO_OPT_OFF)
  params:add_option("new note", "new note action", ACTIONS, ACTION_TARGET)
  params:add_number("population", "population", 2, 5, 3)
  
  
  params:add_separator("midi")
  params:add_option("midi target", "midi target",midi_device_names,1)
  params:set_action("midi target", midi_target)
  params:add_number("bend range", "bend range", 1, 48, 2)

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
    engine.noteOn(music.note_num_to_freq(d.note), d.vel/127, d.note)
    -- print("on", d.note)
  elseif d.type == "note_off" then
    active_notes[d.note] = false
    engine.noteOff(d.note)
    -- print("off", d.note)
  -- elseif d.type == "pitchbend" then
  --   local bend_st = (util.round(d.val / 2)) / 8192 * 2 -1 -- Convert to -1 to 1
  --   set_pitch_bend(d.ch, bend_st * params:get("bend_range"))
  end
end

function osc_in(path, args, from)

  if path == "/measuredPitch" then
    local pitch = args[1]
    if scale == nil then
      return
    end
    -- Introduce a little bit of hysteresis if we're near
    if sungNote ~= nil and pitch < music.note_num_to_freq(sungNote + 1)  and pitch > music.note_num_to_freq(sungNote - 1) then
      pitch = (pitch + music.note_num_to_freq(sungNote))/2
    end
    local rawNote = music.freq_to_note_num(pitch)
    if scale ~= nil then
      local newNote = music.snap_note_to_array(rawNote, scale)
      if sungNote ~= newNote then
        sungNote = newNote
        screen_dirty = true
        engine.acceptQuantizedPitch(music.note_num_to_freq(sungNote))
        if params:get("new note") == ACTION_TARGET then
          new_chord()
        end
        -- print(newNote, pitch)
      end
    end
  end
end

osc.event = osc_in