music = require 'musicutil'

function soprano(note)
  while note < 60 do
    note = note + 12
  end
  return note
end

function alto(note)
  while note < 55 do
    note = note + 12
  end
  while note > 79 do
    note = note - 12
  end
  return note
end

function tenor(note)
  while note < 48 do
    note = note + 12
  end
  while note > 72 do
    note = note - 12
  end
  return note
end

function bass(note)
  while note > 60 do
    note = note - 12
  end
  return note
end

function contrabass(note)
  while note > 55 do
    note = note - 12
  end
  return note
end