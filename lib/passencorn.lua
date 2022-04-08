music = require 'musicutil'

function find(array, value, low, high)
  if low == nil or low < 1 then low = 1 end
  if high == nil or high > #array then high = #array end
  if low == high then return low end
  local guess = math.floor((low + high)/2)
  if array[guess] == value then return guess end
  if array[guess] > value then return find(array, value, guess + 1, high) end
  if array[guess] < value then return find(array, value, low, guess) end
end

function chord_type_complexity(chord_type)
  if util.string_starts(v, "M") and not string.find(v, " ") then
    return 1
  elseif string.find(v, "11") or string.find(v, "13") or string.find(v, "th") then
    return 3
  end
  return 2  
end

function score_contrary_motion(prev_chord, chord)
  local direction = 0
  for i, note in ipairs(chord) do
    if prev_chord[i] ~= nil then
      if prev_chord[i] > note then 
        direction = direction + 1
      elseif prev_chord[i] < note then
        direction = direction - 1
      end
    end
  end
  return 3*(#chord - math.abs(direction))
end

function assign_voices(scale_root_num, root_num, chord_type, prev_chord, range_centers)
  ret, score =  assign_voices_helper(
    scale_root_num, 
    root_num,
    music.generate_chord(root_num, chord_type),
    prev_chord,
    range_centers,
    {})
  return ret, score
end

soprano = 76

alto = 68

tenor = 60

bass = 50

contrabass = 46


function assign_voices_helper(
  scale_root_num, root_num, chord, prev_chord, range_centers, so_far)
  if range_centers == nil then 
    range_centers = {contrabass, tenor, alto, soprano} 
  end
  if prev_chord == nil then 
    prev_chord = range_centers 
  end
  if #so_far == #range_centers then
    return so_far, score_contrary_motion(prev_chord, so_far)
  end
  local idx = #so_far + 1
  local prev_note = prev_chord[idx]
  if prev_note == nil then
    prev_note = range_centers[idx]
  end
  local best_score = 0
  local second_best_score = 0
  local best_note = 0
  local second_best_note = 0
  for i, candidate in ipairs(chord) do
    -- adjust the candidate toward the previous chord note and also the center of the range
    local pull_toward = 0.4*range_centers[idx] + 0.6*prev_note
    while candidate - pull_toward > 6 do
      candidate = candidate - 12
    end
    while candidate - pull_toward < -6 do
      candidate = candidate + 12
    end
    local score = 0
    local already = 0
    -- favor pitch classes we haven't put in yet
    for _, s in ipairs(so_far) do
      if (s % 12) == (candidate % 12) then
        already = already + 1
      end
    end

    score = score - (already * 8)
    
    -- Favor gentle motion
    if prev_note == candidate then
      score = score + 4
    elseif math.abs(prev_note - candidate) <= 2 then
      score = score + 3
    elseif math.abs(prev_note - candidate) <= 4 then
      score = score + 2
    end
    
    -- When in the first (bass) voice, favor the root when the chord is complex
    -- (inversions are better for triads)
    if idx == 1 and candidate % 12 == root_num % 12 then
      if #chord > 3 then
        score = score + 8
      else
        score = score + 1
      end
    end
    
    -- Favor resolving the leading tone to the tonic
    if candidate % 12 == scale_root_num % 12 and prev_note == candidate - 1 then
      score = score + 5
    end
    
    -- Favor being at least 40 hz above the previous note / avoid voice crossing and dissonance
    if (#so_far > 0 and 
      (music.note_num_to_freq(candidate) - music.note_num_to_freq(so_far[#so_far]) > 40)) then
      score = score + 5
    end
    
    if score >= best_score then
      second_best_score = best_score
      second_best_note = best_note
      best_score = score
      best_note = candidate
    end
  end
  
  so_far_one = {table.unpack(so_far)}
  table.insert(so_far_one, best_note)
  option_one, score_one = assign_voices_helper(
    scale_root_num, root_num, chord, prev_chord, range_centers, so_far_one)
  
  if second_best_score > 0 then
    so_far_two = {table.unpack(so_far)}
    table.insert(so_far_two, second_best_note)
    option_two, score_two = assign_voices_helper(
      scale_root_num, root_num, chord, prev_chord, range_centers, so_far_two)
  
    if score_one + best_score > score_two + second_best_score then
      return option_one, score_one + best_score
    else
      return option_two, score_two + second_best_score
    end
  else
    return option_one, score_one + best_score
  end
end

function freq_to_note_num_float(freq)
  return util.clamp(12 * math.log(freq / 440.0) / math.log(2) + 69, 0, 127)
end

function quantize(scale, pitch, prevNote)
  unquantizedNote = freq_to_note_num_float(pitch)
  if prevNote ~= nil then
    degree = find(scale, prevNote)
    upOneNote = scale[degree + 1]
    if upOneNote ~= nil and prevNote < unquantizedNote and unquantizedNote < upOneNote then
      unquantizedNote = (0.4*unquantizedNote + 0.6*prevNote)
    end
    downOneNote = scale[degree - 1]
    if downOneNote ~= nil and downOneNote < unquantizedNote and unquantizedNote < prevNote then
      unquantizedNote = (0.4*unquantizedNote + 0.6*prevNote)/2
    end
  end
  return music.snap_note_to_array(unquantizedNote, scale)
end

function new_chord()
  local ranges
  
  if params:get("population") == 1 then
    ranges = {soprano}
  elseif params:get("population") == 2 then
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
    
    local chord_name = possible_chords[ math.random(1, #possible_chords)]
    local chord_notes, score = assign_voices(params:get("root"), sungNote, chord_name, currentChord, ranges)
    if remember_chord_timer ~= nil then
      clock.cancel(remember_chord_timer)
    end
    remember_chord_timer = clock.run(function(name, chord, root, score) 
      clock.sleep(0.2)
      currentChordName = name
      currentChord = chord   
      currentRoot = root
      currentScore = score
      screen_dirty = true
    end, chord_name, chord_notes, sungNote, score)

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

