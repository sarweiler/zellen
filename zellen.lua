-- zellen
-- sequencer based on conway's game of life
--
-- grid: enter cell pattern
-- KEY2: play/pause sequence
-- KEY3: advance generation
-- hold KEY1 + press KEY3: delete board
-- ENC1: set speed (bpm)
-- ENC2: set play mode
-- ENC3: set play direction
--
-- see the parameters screen for more settings.

music = require("mark_eats/musicutil")

engine.name = "PolyPerc"
g = grid.connect()
m = midi.connect()


-- init
function init()
  
  GRID_SIZE = {
    ["X"] = 16,
    ["Y"] = 8
  }
  
  LEVEL = {
    ["ALIVE"] = 8,
    ["BORN"] = 12,
    ["REBORN"] = 13,
    ["DYING"] = 2,
    ["DEAD"] = 0,
    ["ALIVE_THRESHOLD"] = 7,
    ["ACTIVE"] = 15
  }
  
  SCREENS = {
    ["BOARD"] = 1,
    ["CONFIRM"] = 2
  }
  
  NOTE_NAMES_OCTAVE = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  NOTES = {}
  for i=0, 72 do
    NOTES[i] = {
      ["number"] = i,
      ["name"] = NOTE_NAMES_OCTAVE[i % 12 + 1] .. math.floor(i / 12),
      ["octave"] = math.floor(i / 12)
    }
  end
  NOTE_NAMES = table.map(function(note) return note.name end, NOTES)
  
  SCALE_NAMES = table.map(function(scale) return scale.name end, music.SCALES)
  SCALE_LENGTH = 24
  
  SEQ_MODES = {
    "manual",
    "semi-manual",
    "automatic"
  }
  
  PLAY_DIRECTIONS = {
    "up",
    "down",
    "random",
    "drunken up",
    "drunken down"
  }
  
  PLAY_MODES = {
  "reborn",
  "born",
  "ghost"
  }
  
  SYNTHS = {
    "internal",
    "midi",
    "both"
  }
  
  PLAYING_INDICATOR = ">"
  
  KEY1_DOWN = false
  KEY2_DOWN = false
  KEY3_DOWN = false
  
  -- params
  params:add_option("play_mode", "play mode", PLAY_MODES, 1)
  params:set_action("play_mode", set_play_mode)
  
  params:add_option("seq_mode", "seq mode", SEQ_MODES, 2)

  params:add_number("speed", "speed", 0, 1000, 100)
  params:set_action("speed", set_speed)
  
  params:add_option("scale", "scale", SCALE_NAMES, 1)
  params:set_action("scale", set_scale)
  
  params:add_option("root_note", "root note", NOTE_NAMES, 48)
  params:set_action("root_note", set_root_note)
  
  params:add_option("play_direction", "play direction", PLAY_DIRECTIONS, 1)
  params:set_action("play_direction", set_play_direction)
  
  params:add_number("ghost_offset", "ghost offset", -24, 24, 0)
  params:set_action("ghost_offset", set_ghost_offset)
  
  params:add_control("release", "release", controlspec.new(0.1, 5.0, "lin", 0.01, 0.5, "s"))
  params:set_action("release", set_release)
  
  params:add_control("cutoff", "cutoff", controlspec.new(50, 5000, "exp", 0, 1000, "hz"))
  params:set_action("cutoff", set_cutoff)
  
  params:add_option("synth", "synth", SYNTHS, 3)
  
  params:add_number("midi_device_number", "midi device number", 1, 5, 1)
  params:set_action("midi_device_number", set_midi_device_number)
  
  params:add_number("midi_note_velocity", "midi note velocity", 1, 127, 100)
  
  root_note = 36
  scale_name = SCALE_NAMES[13]
  scale = music.generate_scale_of_length(root_note, scale_name, SCALE_LENGTH)
  
  seq_counter = metro.alloc()
  seq_counter.time = bpm_to_seconds_16(params:get("speed"))
  seq_counter.count = -1
  seq_counter.callback = play_seq_step
  
  note_offset = 0
  playable_cells = {}
  active_notes = {}
  seq_running = false
  show_playing_indicator = false
  
  init_position()
  
  board = {}
  for x=1,GRID_SIZE.X do
    board[x] = {}
    for y=1,GRID_SIZE.Y do
      board[x][y] = LEVEL.DEAD
    end
  end
  
  init_engine()
end

function init_engine()
  engine.release(params:get("release"))
  engine.cutoff(params:get("cutoff"))
end

-- UI handling
function redraw()
  screen.clear()
  screen.move(0, 8)
  screen.level(15)
  screen.text(params:get("speed"))
  screen.level(7)
  screen.move(0, 16)
  screen.text("speed")
  
  screen.move(0, 28)
  screen.level(15)
  screen.text(PLAY_MODES[params:get("play_mode")])
  screen.level(7)
  screen.move(0, 36)
  screen.text("play mode")
  
  screen.move(0, 48)
  screen.level(15)
  screen.text(PLAY_DIRECTIONS[params:get("play_direction")])
  screen.level(7)
  screen.move(0, 56)
  screen.text("play direction")
  
  update_playing_indicator()
  
  screen.update()
end

function update_playing_indicator()
  if (params:get("seq_mode") ~= 1) then
    if (show_playing_indicator) then
      screen.level(15)
    else
      screen.level(0)
    end
    screen.rect(125, 53, 3, 3)
    screen.fill()
  end
end

function grid_redraw()
  g.all(0)
  for x=1,GRID_SIZE.X do
    for y=1,GRID_SIZE.Y do
      if (position.x == x and position.y == y) then
        g.led(x, y, LEVEL.ACTIVE)
      else
        g.led(x, y, board[x][y])
      end
    end
  end
  g.refresh()
end


-- GRID handling
g.event = function(x, y, z)
  if (z == 1) then
    if (is_active(x, y)) then
      board[x][y] = LEVEL.DEAD
    else
      board[x][y] = LEVEL.ALIVE
    end
  end
  grid_redraw()
end


-- ENC handling
function enc(n, d)
  if (n == 1) then
    params:delta("speed", d)
  end
  if (n == 2) then
    params:delta("play_mode", d)
  end
  if (n == 3) then
    print("delta: " .. d)
    params:delta("play_direction", d)
  end
  redraw()
end


-- KEY handling
function key(n, z)
  local seq_mode = params:get("seq_mode")
  if (n == 1) then
    KEY1_DOWN = z == 1
  end
  if (n == 2) then
    KEY2_DOWN = z == 1
    if (KEY2_DOWN) then
      if(seq_mode == 1) then
        play_seq_step()
      elseif(seq_mode == 2 or seq_mode == 3) then
        if(seq_running) then
          seq_counter:stop()
          seq_running = false
          show_playing_indicator = false
        else
          seq_counter:start()
          seq_running = true
          show_playing_indicator = true
        end
      end
    end
  end
  if (n == 3) then
    KEY3_DOWN = z == 1
    if(KEY3_DOWN and KEY1_DOWN) then
      clear_board()
    elseif(KEY3_DOWN) then
      seq_counter:stop()
      seq_running = false
      show_playing_indicator = false
      generation_step()
    end
  end
  redraw()
end


-- parameter callbacks
function set_speed(bpm)
  seq_counter.time = bpm_to_seconds_16(bpm)
end

function set_play_mode(play_mode)
  print("play_mode: " .. play_mode)
  if(play_mode == 3) then
    note_offset = params:get("ghost_offset")
  else
    note_offset = 0
  end
  collect_playable_cells()
end

function set_play_direction()
  collect_playable_cells()
end

function set_ghost_offset()
  set_play_mode(params:get("play_mode"))
end

function set_scale(new_scale_name)
  scale = music.generate_scale_of_length(root_note, new_scale_name, SCALE_LENGTH)
end

function set_root_note(new_root_note)
  root_note = new_root_note
  scale = music.generate_scale_of_length(new_root_note, scale_name, SCALE_LENGTH)
end

function set_release(r)
  engine.release(r)
end

function set_cutoff(f)
  engine.cutoff(f)
end

function set_midi_device_number()
  m:disconnect()
  m:reconnect(params:get("midi_device_number"))
end


-- game logic
function generation_step()
  notes_off()
  local board_c = clone_board(board)
  for x=1,GRID_SIZE.X do
    for y=1,GRID_SIZE.Y do
      local num_neighbors = number_of_neighbors(x, y)
      local cell_active = is_active(x, y)
      if(is_dying(x, y)) then
        board_c[x][y] = LEVEL.DEAD
      end
      if (num_neighbors < 2 and cell_active) then
        board_c[x][y] = LEVEL.DYING
      end
      if (num_neighbors > 3 and cell_active) then
        board_c[x][y] = LEVEL.DYING
      end
      if (num_neighbors > 1 and num_neighbors < 4 and cell_active) then
        board_c[x][y] = LEVEL.ALIVE
      end
      if (num_neighbors == 3 and cell_active) then
        board_c[x][y] = LEVEL.REBORN
      end
      if (num_neighbors == 3 and not cell_active) then
        board_c[x][y] = LEVEL.BORN
      end
    end
  end
  board = board_c
  play_pos = 1
  collect_playable_cells()
  grid_redraw()
end


-- game logic helpers
function number_of_neighbors(x, y)
  local num_neighbors = 0
  if (x < GRID_SIZE.X) then
    num_neighbors = num_neighbors + (is_active(x + 1, y) and 1 or 0)
  end
  if (x > 1) then
    num_neighbors = num_neighbors + (is_active(x - 1, y) and 1 or 0)
  end
  if (y < GRID_SIZE.Y) then
    num_neighbors = num_neighbors + (is_active(x, y + 1) and 1 or 0)
  end
  if (y > 1) then
    num_neighbors = num_neighbors + (is_active(x, y - 1) and 1 or 0)
  end
  if (x < GRID_SIZE.X and y < GRID_SIZE.Y) then
    num_neighbors = num_neighbors + (is_active(x + 1, y + 1) and 1 or 0)
  end
  if (x < GRID_SIZE.X and y > 1) then
    num_neighbors = num_neighbors + (is_active(x + 1, y - 1) and 1 or 0)
  end
  if (x > 1 and y < GRID_SIZE.Y) then
    num_neighbors = num_neighbors + (is_active(x - 1, y + 1) and 1 or 0)
  end
  if (x > 1 and y > 1) then
    num_neighbors = num_neighbors + (is_active(x - 1, y - 1) and 1 or 0)
  end
  
  return num_neighbors
end

function is_active(x, y)
  return board[x][y] > LEVEL.ALIVE_THRESHOLD
end

function is_dying(x, y)
  return board[x][y] == LEVEL.DYING
end

function was_born(x, y)
  return board[x][y] == LEVEL.BORN
end

function was_reborn(x, y)
  return board[x][y] == LEVEL.REBORN
end


-- sequencing
function collect_playable_cells()
  playable_cells = {}
  local mode = params:get("play_mode")
  --print("mode: " .. mode)
  for x=1,GRID_SIZE.X do
    for y=1,GRID_SIZE.Y do
      if ((was_born(x, y) or was_reborn(x, y)) and mode == 1) then
        table.insert(playable_cells, {
          ["x"] = x,
          ["y"] = y
        })
      end
      if (was_born(x, y) and mode == 2) then
        table.insert(playable_cells, {
          ["x"] = x,
          ["y"] = y
        })
      end
      if (is_dying(x, y) and mode == 3) then
        table.insert(playable_cells, {
          ["x"] = x,
          ["y"] = y
        })
      end
    end
  end
  
  local play_direction = params:get("play_direction")
  if(play_direction == 2 or play_direction == 5) then
    playable_cells = table.reverse(playable_cells)
  elseif(play_direction == 3) then
    playable_cells = table.shuffle(playable_cells)
  end
end

function play_seq_step()
  local seq_mode = params:get("seq_mode")
  local play_direction = params:get("play_direction")
  notes_off()
  
  show_playing_indicator = not show_playing_indicator
  
  if (play_pos <= #playable_cells) then
    position = playable_cells[play_pos]
    local midi_note = scale[(position.x - 1) + position.y]
    note_on(midi_note)
    if(play_direction == 4 or play_direction == 5) then
      if(math.random(2) == 1 and play_pos > 1) then
        play_pos = play_pos - 1
      else
        play_pos = play_pos + 1
      end
    else
      play_pos = play_pos + 1
    end
  else
    play_pos = 1
    init_position()
    
    if(seq_mode == 3) then
      generation_step()
      if(not seq_running) then
        seq_counter:start()
        seq_running = true
        show_playing_indicator = true
      end
    else
      seq_counter:stop()
      seq_running = false
      show_playing_indicator = false
    end
  end
  redraw()
  grid_redraw()
end

function init_position()
  position = {
    ["x"] = -1,
    ["y"] = -1
  }
end

-- notes
function note_on(note)
  local note_num = math.min((note + note_offset), 127)
  local synth_mode = params:get("synth")
  if(synth_mode == 1 or synth_mode == 3) then
    engine.hz(music.note_num_to_freq(note_num))
  end
  if(synth_mode == 2 or synth_mode == 3) then
    m.note_on(note_num, params:get("midi_note_velocity"))
  end
  table.insert(active_notes, note_num)
end

function notes_off()
  for i=1,#active_notes do
    m.note_off(active_notes[i])
  end
  active_notes = {}
end

-- helpers
function clone_board(b)
  b_c = {}
  for i=1,#b do
    b_c[i] = table.clone(b[i])
  end
  return b_c
end

function clear_board()
  for x=1,GRID_SIZE.X do
    for y=1,GRID_SIZE.Y do
      board[x][y] = LEVEL.DEAD
    end 
  end
  notes_off()
  init_position()
  grid_redraw()
end

function table.clone(org)
  return {table.unpack(org)}
end

function table.map(f, arr)
  local mapped_arr = {}
  for i,v in ipairs(arr) do
    mapped_arr[i] = f(v)
  end
  return mapped_arr
end

function table.reverse(arr)
  local rev_arr = {}
  for i = #arr, 1, -1 do
    table.insert(rev_arr, arr[i])
  end
  return rev_arr
end

function table.shuffle(arr)
  for i = #arr, 2, -1 do
    local j = math.random(i)
    arr[i], arr[j] = arr[j], arr[i]
  end
  return arr
end

function note_name_to_num(name)
  local NOTE_NAME_INDEX = {
    ["C"] = 0,
    ["C#"] = 1,
    ["D"] = 2,
    ["D#"] = 3,
    ["E"] = 4,
    ["F"] = 5,
    ["F#"] = 6,
    ["G"] = 7,
    ["G#"] = 8,
    ["A"] = 9,
    ["A#"] = 10,
    ["B"] = 11
  }
  local name_len = #name
  local note_name = "C"
  local octave = "0"
  if (name_len == 2) then
    note_name = name:sub(1,1)
    octave = name:sub(2,2)
  elseif (name_len == 3) then
    note_name = name:sub(1,2)
    octave = name:sub(3,3)
  end
  local note_index = NOTE_NAME_INDEX[note_name]
  return tonumber(octave) * 12 + note_index
end

function bpm_to_seconds_16(bpm)
  return 60 / bpm / 4
end

