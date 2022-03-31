music = require 'musicutil'

engine.name = "TheMachine"
SCALE_NAMES = {}
for i, v in pairs(music.SCALES) do
  SCALE_NAMES[i] = v["name"]
end

scale = nil
sungNote = nil

function set_scale()
  scale = music.generate_scale(params:get("root") - 12, SCALE_NAMES[params:get("scale")], 10)
end

function init()
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
    print("on", d.note)
  elseif d.type == "note_off" then
    active_notes[d.note] = false
    engine.noteOff(d.note)
    print("off", d.note)
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
        print(newNote, pitch)
      end
      sungNote = newNote
      engine.acceptQuantizedPitch(music.note_num_to_freq(sungNote))
    end
  end
end

osc.event = osc_in