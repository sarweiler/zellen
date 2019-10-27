-- zellen v1.2.0
--
-- sequencer based on
-- conway's game of life
--
-- grid: enter cell pattern
--
-- KEY2: play/pause sequence
-- KEY3: advance generation
-- hold KEY1 + press KEY3:
--   delete board
-- hold KEY1 + press KEY2:
--   save parameters
--
-- ENC1: set speed (bpm)
-- ENC2: set play mode
-- ENC3: set play direction
--
-- hold KEY3 + ENC3: time jog
--
-- see the parameters screen
-- for more settings.

engine.name = "PolyPerc"

-- local z_params = include("lib/z_params")
local helpers = include("lib/helpers")

local music = require("musicutil")
local beatclock = require("beatclock")
local er = require("er")
local g = grid.connect()
local list = include("lib/linkedlist") --borrowed circular linked list library we dont use the circular part... yet.

-- constants
local config = {
  GRID = {
    SIZE = {
      X = g.cols,
      Y = g.rows
    },
    LEVEL = {
      ALIVE = 8,
      BORN = 12,
      REBORN = 13,
      DYING = 2,
      DEAD = 0,
      ALIVE_THRESHOLD = 7,
      ACTIVE = 15
    }
  },
  MUSIC = {
    NOTE_NAMES_OCTAVE = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"},
    NOTES = {}, -- constructed on init
    NOTE_NAMES = {}, -- constructed on init
    SCALE_NAMES = {}, -- constructed on init
    SCALE_LENGTH = 24
  },
  SEQ = {
    MODES = {
      "manual",
      "semi-automatic",
      "automatic"
    },
    PLAY_DIRECTIONS = {
      "up",
      "down",
      "random",
      "drunken up",
      "drunken down"
    },
    PLAY_MODES = {
      "born",
      "reborn",
      "ghost"
    },
  },
  SYNTHS = {
    "internal",
    "midi",
    "both"
  },
}

-- initial values
local state = {
  keys = {
    key1_down = false,
    key2_down = false,
    key3_down = false
  },
  board = {
    current = {},
    the_past = {} --constructed on init. This linked list will hold ancestral boards so we may visit the past
  },
  seq = {
    position = {}
  },
  root_note = 36,
  scale_name = "",
  scale = {},
  note_offset = 0,
  playable_cells = {},
  play_pos = 0,
  active_notes = {},
  seq_running = false,
  show_playing_indicator = false,
  beats = {true},
  euclid_seq_len = 1,
  euclid_seq_beats = 1,
  beat_step = 0
}

-- beatclock
local clk = beatclock.new()
local midi_out = midi.connect(1)
local midi_in = midi.connect(1)
midi_in.event = function(data) clk:process_midi(data) end

-- note on/off
local function note_on(note, support_note)
  local note_num = math.min((note + state.note_offset), 127)
  local synth_mode = params:get("synth")
  if(synth_mode == 1 or synth_mode == 3) then
    local amp = params:get("amp")
    local amp_variance = math.random(params:get("midi_velocity_var")) / 100
    if(math.random(2) > 1) then
      amp = math.min(amp + amp_variance, 1.0)
    else
      amp = math.max(amp - amp_variance, 0)
    end
    engine.amp(amp)
    engine.hz(music.note_num_to_freq(note_num))
  end
  if(synth_mode == 2 or synth_mode == 3) then
    local velocity_variance = math.random(params:get("midi_velocity_var"))
    local velocity = params:get("midi_note_velocity")
    if(math.random(2) > 1) then
      velocity = math.min(velocity + velocity_variance, 127)
    else
      velocity = math.max(velocity - velocity_variance, 0)
    end
    midi_out:note_on(note_num, velocity, params:get("midi_channel"))
  end

  -- experimental crow support
  -- TODO: make switchable via param
  crow.output[1].volts = note/12 - 3 -- TODO: make cv octave offset configurable via param
  crow.output[2].execute()
  crow.output[3].volts = support_note/12 - 3 -- TODO: make cv octave offset configurable via param
  table.insert(state.active_notes, note_num)
end

local function notes_off()
  for i=1,#state.active_notes do
    midi_out:note_off(state.active_notes[i], 0, params:get("midi_channel"))
  end
  state.active_notes = {}
end


-- game logic
local function x_coord_wrap(x)
  x_mod = (x == 0 or x == config.GRID.SIZE.X) and config.GRID.SIZE.X or math.max(1, x % config.GRID.SIZE.X)
  return (x == 0 or x == config.GRID.SIZE.X) and config.GRID.SIZE.X or math.max(1, x % config.GRID.SIZE.X)
end

local function y_coord_wrap(y)
  y_mod = (y == 0 or y == config.GRID.SIZE.Y) and config.GRID.SIZE.Y or math.max(1, y % config.GRID.SIZE.Y)
  return (y == 0 or y == config.GRID.SIZE.Y) and config.GRID.SIZE.Y or math.max(1, y % config.GRID.SIZE.Y)
end

local function is_active(x, y)
  return state.board.current[x_coord_wrap(x)][y_coord_wrap(y)] > config.GRID.LEVEL.ALIVE_THRESHOLD
end

local function is_dying(x, y)
  return state.board.current[x_coord_wrap(x)][y_coord_wrap(y)] == config.GRID.LEVEL.DYING
end

local function was_born(x, y)
  return state.board.current[x_coord_wrap(x)][y_coord_wrap(y)] == config.GRID.LEVEL.BORN
end

local function was_reborn(x, y)
  return state.board.current[x_coord_wrap(x)][y_coord_wrap(y)] == config.GRID.LEVEL.REBORN
end

local function number_of_neighbors(x, y)
  local num_neighbors = 0
  if (params:get("wrap_mode") == 1) then
    num_neighbors = num_neighbors + (is_active(x + 1, y) and 1 or 0)
    num_neighbors = num_neighbors + (is_active(x - 1, y) and 1 or 0)
    num_neighbors = num_neighbors + (is_active(x, y + 1) and 1 or 0)
    num_neighbors = num_neighbors + (is_active(x, y - 1) and 1 or 0)
    num_neighbors = num_neighbors + (is_active(x + 1, y + 1) and 1 or 0)
    num_neighbors = num_neighbors + (is_active(x + 1, y - 1) and 1 or 0)
    num_neighbors = num_neighbors + (is_active(x - 1, y + 1) and 1 or 0)
    num_neighbors = num_neighbors + (is_active(x - 1, y - 1) and 1 or 0)
  else
    if (x < config.GRID.SIZE.X) then
      num_neighbors = num_neighbors + (is_active(x + 1, y) and 1 or 0)
    end
    if (x > 1) then
      num_neighbors = num_neighbors + (is_active(x - 1, y) and 1 or 0)
    end
    if (y < config.GRID.SIZE.Y) then
      num_neighbors = num_neighbors + (is_active(x, y + 1) and 1 or 0)
    end
    if (y > 1) then
      num_neighbors = num_neighbors + (is_active(x, y - 1) and 1 or 0)
    end
    if (x < config.GRID.SIZE.X and y < config.GRID.SIZE.Y) then
      num_neighbors = num_neighbors + (is_active(x + 1, y + 1) and 1 or 0)
    end
    if (x < config.GRID.SIZE.X and y > 1) then
      num_neighbors = num_neighbors + (is_active(x + 1, y - 1) and 1 or 0)
    end
    if (x > 1 and y < config.GRID.SIZE.Y) then
      num_neighbors = num_neighbors + (is_active(x - 1, y + 1) and 1 or 0)
    end
    if (x > 1 and y > 1) then
      num_neighbors = num_neighbors + (is_active(x - 1, y - 1) and 1 or 0)
    end
  end

  return num_neighbors
end

local function collect_playable_cells()
  state.playable_cells = {}
  local mode = params:get("play_mode")
  for x=1,config.GRID.SIZE.X do
    for y=1,config.GRID.SIZE.Y do
      if (was_born(x, y) and mode == 1) then
        table.insert(state.playable_cells, {
          ["x"] = x,
          ["y"] = y
        })
      end
      if ((was_born(x, y) or was_reborn(x, y)) and mode == 2) then
        table.insert(state.playable_cells, {
          ["x"] = x,
          ["y"] = y
        })
      end
      if (is_dying(x, y) and mode == 3) then
        table.insert(state.playable_cells, {
          ["x"] = x,
          ["y"] = y
        })
      end
    end
  end
  
  local play_direction = params:get("play_direction")
  if(play_direction == 2 or play_direction == 5) then
    state.playable_cells = helpers.table.reverse(state.playable_cells)
  elseif(play_direction == 3) then
    state.playable_cells = helpers.table.shuffle(state.playable_cells)
  end
end

local function do_the_time_warp()
  state.board.current = helpers.clone_board(state.board.the_past.value) --set the board equal to the first entry in the past (last generation)
  state.board.the_past = list.eraseBackward(state.board.the_past) --remove the future. Because the future is deterministic.
  state.play_pos = 1
  collect_playable_cells()
  grid_redraw()
end

local function generation_step()
  state.board.the_past = list.insert(state.board.the_past, helpers.clone_board(state.board.current))
  notes_off()
  local board_c = helpers.clone_board(state.board.current)
  for x=1,config.GRID.SIZE.X do
    for y=1,config.GRID.SIZE.Y do
      local num_neighbors = number_of_neighbors(x, y)
      local cell_active = is_active(x, y)
      if(is_dying(x, y)) then
        board_c[x][y] = config.GRID.LEVEL.DEAD
      end
      if (num_neighbors < 2 and cell_active) then
        board_c[x][y] = config.GRID.LEVEL.DYING
      end
      if (num_neighbors > 3 and cell_active) then
        board_c[x][y] = config.GRID.LEVEL.DYING
      end
      if (num_neighbors > 1 and num_neighbors < 4 and cell_active) then
        board_c[x][y] = config.GRID.LEVEL.ALIVE
      end
      if (num_neighbors == 3 and cell_active) then
        board_c[x][y] = config.GRID.LEVEL.REBORN
      end
      if (num_neighbors == 3 and not cell_active) then
        board_c[x][y] = config.GRID.LEVEL.BORN
      end
    end
  end
  state.board.current = board_c
  state.play_pos = 1
  collect_playable_cells()
  grid_redraw()
end


-- sequencing
local function init_position()
  state.seq.position = {
    ["x"] = -1,
    ["y"] = -1
  }
end

local function reset_sequence()
  local seq_mode = params:get("seq_mode")
  state.play_pos = 1
  if (params:get("euclid_reset") == 1) then
    state.beat_step = 1
  end
  
  if(seq_mode == 3 or (seq_mode == 2 and params:get("loop_semi_auto_seq") == 1)) then
    if(seq_mode == 3) then
      init_position()
      generation_step()
    end
    if(not state.seq_running) then
      clk:start()
      state.seq_running = true
      state.show_playing_indicator = true
    end
  else
    clk:stop()
    state.seq_running = false
    state.show_playing_indicator = false
  end
end

local function play_seq_step()
  
  local play_direction = params:get("play_direction")
  local seq_mode = params:get("seq_mode")
  notes_off()

  crow.output[4].execute()
  
  state.show_playing_indicator = not state.show_playing_indicator
  
  local beat_seq_lengths = #state.beats
  
  if (state.beats[(state.beat_step % beat_seq_lengths) + 1] or seq_mode == 1) then
    if (state.play_pos <= #state.playable_cells) then
      state.seq.position = state.playable_cells[state.play_pos]
      local midi_note = state.scale[(state.seq.position.x - 1) + state.seq.position.y]
      -- TODO: make support note mode configurable
      local support_note = state.scale[math.ceil((state.seq.position.x)/state.seq.position.y)]
      note_on(midi_note, support_note)
      if(play_direction == 4 or play_direction == 5) then
        if(math.random(2) == 1 and state.play_pos > 1) then
          state.play_pos = state.play_pos - 1
        else
          state.play_pos = state.play_pos + 1
        end
        state.beat_step = state.beat_step + 1
      else
        if (state.play_pos < #state.playable_cells or (seq_mode == 2  and not params:get("loop_semi_auto_seq") == 1)) then
          state.play_pos = state.play_pos + 1
          state.beat_step = state.beat_step + 1
        else
          reset_sequence()
        end
      end
    else
      init_position()
      reset_sequence()
    end
  else
    state.beat_step = state.beat_step + 1
  end
  redraw()
  grid_redraw()
end

local function clear_board()
  for x=1,config.GRID.SIZE.X do
    for y=1,config.GRID.SIZE.Y do
      state.board.current[x][y] = config.GRID.LEVEL.DEAD
    end 
  end
  notes_off()
  init_position()
  state.playable_cells = {}
  grid_redraw()
end


-- parameter callbacks

local function set_play_mode(play_mode)
  if(play_mode == 3) then
    state.note_offset = params:get("ghost_offset")
  else
    state.note_offset = 0
  end
  collect_playable_cells()
end

local function set_play_direction()
  collect_playable_cells()
end

local function set_ghost_offset()
  set_play_mode(params:get("play_mode"))
end

local function set_scale(new_scale_name)
  state.scale= music.generate_scale_of_length(state.root_note, new_scale_name, config.MUSIC.SCALE_LENGTH)
end

local function set_root_note(new_root_note)
  state.root_note = new_root_note
  state.scale= music.generate_scale_of_length(new_root_note, state.scale_name, config.MUSIC.SCALE_LENGTH)
end

local function set_euclid_seq_len(new_euclid_seq_len)
  if (new_euclid_seq_len < state.euclid_seq_beats) then
    new_euclid_seq_len = state.euclid_seq_beats
    params:set("euclid_seq_len", new_euclid_seq_len)
  end
  state.euclid_seq_len = new_euclid_seq_len
  state.beats = er.gen(state.euclid_seq_beats, new_euclid_seq_len)
end

local function set_euclid_seq_beats(new_euclid_seq_beats)
  if(new_euclid_seq_beats > state.euclid_seq_len) then
    new_euclid_seq_beats = state.euclid_seq_len
    params:set("euclid_seq_beats", new_euclid_seq_beats)
  end
  state.euclid_seq_beats = new_euclid_seq_beats
  state.beats = er.gen(new_euclid_seq_beats, state.euclid_seq_len)
end

local function set_release(r)
  engine.release(r)
end

local function set_cutoff(f)
  engine.cutoff(f)
end

local function set_midi_out_device_number()
  midi_out = midi.connect(params:get("midi_out_device_number"))
end

local function set_midi_in_device_number()
  midi_in.event = nil
  midi_in = midi.connect(params:get("midi_in_device_number"))
  midi_in.event = function(data) clk:process_midi(data) end
end


-------------
-- GLOBALS --
-------------


-- init
function init()
  for i=0, 72 do
    config.MUSIC.NOTES[i] = {
      ["number"] = i,
      ["name"] = config.MUSIC.NOTE_NAMES_OCTAVE[i % 12 + 1] .. math.floor(i / 12),
      ["octave"] = math.floor(i / 12)
    }
  end
  config.MUSIC.NOTE_NAMES = helpers.table.map(function(note) return note.name end, config.MUSIC.NOTES)
  config.MUSIC.SCALE_NAMES = helpers.table.map(function(scale) return scale.name end, music.SCALES)
  
  -- params
  params:add_option("seq_mode", "seq mode", config.SEQ.MODES, 2)
  params:add_option("loop_semi_auto_seq", "loop seq in semi-auto mode", {"Y", "N"}, 1)
  
  params:add_option("scale", "scale", config.MUSIC.SCALE_NAMES, 1)
  params:set_action("scale", set_scale)
  
  params:add_option("state.root_note", "root note", config.MUSIC.NOTE_NAMES, 36)
  params:set_action("state.root_note", set_root_note)
  
  params:add_number("ghost_offset", "ghost offset", -24, 24, 0)
  params:set_action("ghost_offset", set_ghost_offset)
  
  params:add_option("play_mode", "play mode", config.SEQ.PLAY_MODES, 1)
  params:set_action("play_mode", set_play_mode)
  
  params:add_option("play_direction", "play direction", config.SEQ.PLAY_DIRECTIONS, 1)
  params:set_action("play_direction", set_play_direction)

  params:add_option("wrap_mode", "wrap board at edges", {"Y", "N"}, 1)
  
  params:add_separator()
  clk:add_clock_params()
  params:add_separator()
  
  params:add_number("euclid_seq_len", "euclid seq length", 1, 100, 1)
  params:set_action("euclid_seq_len", set_euclid_seq_len)
  
  params:add_number("euclid_seq_beats", "euclid seq beats", 1, 100, 1)
  params:set_action("euclid_seq_beats", set_euclid_seq_beats)
  
  params:add_option("euclid_reset", "reset seq at start of gen", { "Y", "N" }, 2)
  
  params:add_separator()
  
  params:add_control("amp", "amp", controlspec.new(0.1, 1.0, "lin", 0.01, 0.8, ""))

  params:add_control("release", "release", controlspec.new(0.1, 5.0, "lin", 0.01, 0.5, "s"))
  params:set_action("release", set_release)
  
  params:add_control("cutoff", "cutoff", controlspec.new(50, 5000, "exp", 0, 1000, "hz"))
  params:set_action("cutoff", set_cutoff)
  
  params:add_separator()
  
  params:add_option("synth", "synth", config.SYNTHS, 3)
  
  params:add_control("midi_note_velocity", "midi note velocity", controlspec.new(1, 127, "lin", 1, 100, ""))
  params:add_control("midi_velocity_var", "midi velocity variance", controlspec.new(1, 100, "lin", 1, 20, ""))
  
  params:add_number("midi_channel", "midi channel", 1, 16, 1)
  
  params:add_number("midi_out_device_number", "midi out device number", 1, 4, 1)
  params:set_action("midi_out_device_number", set_midi_out_device_number)
  
  params:add_number("midi_in_device_number", "midi in device number", 1, 4, 1)
  params:set_action("midi_in_device_number", set_midi_in_device_number)
  
  state.scale_name = config.MUSIC.SCALE_NAMES[13]
  state.scale= music.generate_scale_of_length(state.root_note, state.scale_name, config.MUSIC.SCALE_LENGTH)
  
  for x=1,config.GRID.SIZE.X do
  state.board.current[x] = {}
    for y=1,config.GRID.SIZE.Y do
      state.board.current[x][y] = config.GRID.LEVEL.DEAD
    end
  end
  state.board.the_past = list.construct(helpers.clone_board(state.board.current)) -- initial construction of the past with a single 'dead' board
  helpers.load_params()
  
  init_position()
  helpers.init_engine(engine)
  
  clk.on_step = play_seq_step

  -- crow init
  crow.output[2].action = "{to(5,0), to(0, 0.25)}"
  crow.output[4].action = "{to(5,0), to(0, 0.1)}"
end


-- display UI
function redraw()
  screen.clear()
  screen.move(0, 8)
  screen.level(15)
  if not clk.external then
    screen.text(params:get("bpm"))
  else
    screen.text("(midi clock)")
  end
  screen.level(7)
  screen.move(0, 16)
  screen.text("bpm")
  
  screen.move(0, 28)
  screen.level(15)
  screen.text(config.SEQ.PLAY_MODES[params:get("play_mode")])
  screen.level(7)
  screen.move(0, 36)
  screen.text("play mode")
  
  screen.move(0, 48)
  screen.level(15)
  screen.text(config.SEQ.PLAY_DIRECTIONS[params:get("play_direction")])
  screen.level(7)
  screen.move(0, 56)
  screen.text("play direction")
  
  helpers.update_playing_indicator(state.show_playing_indicator)
  
  screen.update()
end

-- grid UI
function grid_redraw()
  g:all(0)
  for x=1,config.GRID.SIZE.X do
    for y=1,config.GRID.SIZE.Y do
      if (state.seq.position.x == x and state.seq.position.y == y) then
        g:led(x, y, config.GRID.LEVEL.ACTIVE)
      else
        g:led(x, y, state.board.current[x][y])
      end
    end
  end
  g:refresh()
end


-- ENC input handling
function enc(n, d)
  if (n == 1) then
    params:delta("bpm", d)
  end
  if (n == 2) then
    params:delta("play_mode", d)
  end
  if (n == 3) then
    if (state.keys.key3_down == false) then
      params:delta("play_direction", d)
    else
      if (d == 1) then
        generation_step()
      else
        do_the_time_warp()
      end
    end
  end
  redraw()
end


-- KEY input handling
function key(n, z)
  local seq_mode = params:get("seq_mode")
  if (n == 1) then
    state.keys.key1_down = z == 1
  end
  if (n == 2) then
    state.keys.key2_down = z == 1
    if(state.keys.key2_down and state.keys.key1_down) then
      -- TODO: save board state
      --save_state()
    elseif (state.keys.key2_down) then
      if(seq_mode == 1) then
        if (#state.playable_cells == 0) then
          generation_step()
        end
        play_seq_step()
      elseif(seq_mode == 2 or seq_mode == 3) then
        if(state.seq_running) then
          clk:stop()
          state.seq_running = false
          state.show_playing_indicator = false
        else
          if (#state.playable_cells == 0) then
            generation_step()
          end
          clk:start()
          state.seq_running = true
          state.show_playing_indicator = true
        end
      end
    end
  end
  if (n == 3) then
    state.keys.key3_down = z == 1
    if(state.keys.key3_down and state.keys.key1_down) then
      clear_board()
    elseif(state.keys.key3_down) then
      if(not (seq_mode == 2 and params:get("loop_semi_auto_seq") == 1)) then --true only if semi-auto and loop
        clk:stop()
        state.seq_running = false
        state.show_playing_indicator = false
      end
      generation_step() --if you continue to hold key 3 you can twist enc3 for lots of generations
    end
  end
  redraw()
end


-- GRID input handling
g.key = function(x, y, z)
  if (z == 1) then
    if (is_active(x, y)) then
      state.board.current[x][y] = config.GRID.LEVEL.DEAD
    else
      state.board.current[x][y] = config.GRID.LEVEL.ALIVE
    end
  end
  grid_redraw()
end
