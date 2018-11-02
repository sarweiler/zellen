-- conway
-- sequencer based on conway's game of life
--
-- grid: enter cell pattern
-- KEY2: start
-- KEY3: stop

music = require("mark_eats/musicutil")

engine.name = "PolyPerc"
g = grid.connect()


function init()
  params:add_control("release", "release", controlspec.new(0.1, 5.0, "lin", 0.01, 0.5, "s"))
  params:set_action("release", set_release)
  
  params:add_control("cutoff", "cutoff", controlspec.new(50, 5000, "exp", 0, 1000, "hz"))
  params:set_action("cutoff", set_cutoff)
  
  params:add_number("speed", "speed", 0, 1000, 140)
  params:set_action("speed", set_speed)
  
  --params:add_option("reborn_mode", "reborn mode", {
  --  ["yes"] = true,
  --  ["no"] = false
  --}, true)
  
  GRID_SIZE = {
    ["X"] = 16,
    ["Y"] = 8
  }
  
  LEVEL = {
    ["ALIVE"] = 8,
    ["BORN"] = 13,
    ["DYING"] = 2,
    ["DEAD"] = 0,
    ["ALIVE_THRESHOLD"] = 7,
    ["ACTIVE"] = 15
  }
  
  SCREENS = {
    ["BOARD"] = 1,
    ["CONFIRM"] = 2
  }
  
  current_screen = SCREENS.BOARD
  
  SCALE = music.generate_scale_of_length(48, "minor pentatonic", 32)
  
  seq_counter = metro.alloc()
  seq_counter.time = bpm_to_seconds_16(params:get("speed"))
  seq_counter.count = -1
  seq_counter.callback = play_seq
  
  born_cells = {}
  
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
  screen.text(string.format("%.0f", params:get("cutoff")))
  screen.level(7)
  screen.move(0, 36)
  screen.text("cutoff")
  
  screen.move(0, 48)
  screen.level(15)
  screen.text(params:get("release"))
  screen.level(7)
  screen.move(0, 56)
  screen.text("release")
  
  screen.update()
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

function enc(n, d)
  if (n == 1) then
    params:delta("speed", d)
  end
  if (n == 2) then
    params:delta("cutoff", d)
  end
  if (n == 3) then
    params:delta("release", d)
  end
  redraw()
end

-- default key function
local _key_default = function (n, z)
  if (n == 2 and z == 1) then
    game_step()
  end
  if (n == 3 and z == 1) then
    show_confirm("clear board")
  end
end

local _key = _key_default

function key(n, z)
  _key(n, z)
end

-- game logic
function game_step()
  print("step")
  local board_c = clone_board(board)
  for x=1,GRID_SIZE.X do
    for y=1,GRID_SIZE.Y do
      local num_neighbors = number_of_neighbors(x, y)
      local cell_active = is_active(x, y)
      if(is_dying(x, y)) then
        board_c[x][y] = LEVEL.DEAD
      end
      if (num_neighbors < 2 and cell_active) then
        --print("died (up):", x, y, num_neighbors)
        board_c[x][y] = LEVEL.DYING
      end
      if (num_neighbors > 3 and cell_active) then
        --print("died (op):", x, y, num_neighbors)
        board_c[x][y] = LEVEL.DYING
      end
      if (num_neighbors > 1 and num_neighbors < 4 and cell_active) then
        board_c[x][y] = LEVEL.ALIVE
      end
      if (num_neighbors == 3) then
        --print("born     : ", x, y, num_neighbors)
        board_c[x][y] = LEVEL.BORN
      end
    end
  end
  board = board_c
  play_pos = 1
  collect_born_cells()
  seq_counter:start()
  --grid_redraw()
end

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


-- sequencing
function collect_born_cells()
  born_cells = {}
  for x=1,GRID_SIZE.X do
    for y=1,GRID_SIZE.Y do
      if (was_born(x, y)) then
        table.insert(born_cells, {
          ["x"] = x,
          ["y"] = y
        })
      end
    end
  end
end

function play_seq()
  --print("play", #born_cells)
  if (play_pos <= #born_cells) then
    position = born_cells[play_pos]
    engine.hz(music.note_num_to_freq(SCALE[position.x + position.y]))
    play_pos = play_pos + 1
  else
    seq_counter:stop()
    init_position()
  end
  grid_redraw()
end

function init_position()
  position = {
    ["x"] = -1,
    ["y"] = -1
  }
end

function set_speed(bpm)
  seq_counter.time = bpm_to_seconds_16(bpm)
end


-- engine controls
function init_engine()
  engine.release(params:get("release"))
  engine.cutoff(params:get("cutoff"))
end

function set_release(r)
  engine.release(r)
end

function set_cutoff(f)
  engine.cutoff(f)
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
  grid_redraw()
end

function table.clone(org)
  return {table.unpack(org)}
end

function bpm_to_seconds_16(bpm)
  return 60 / bpm / 4
end

function redefine_key_for_confirm(callback_ok, callback_cancel)
  _key = function(n, z) 
    if (n == 2 and z == 1) then
      callback_cancel()
    end
    if (n == 3 and z == 1) then
      callback_ok()
    end
  end
end

function show_default() 
  _key = _key_default
  redraw()
end

function show_confirm(message)
  redefine_key_for_confirm(
    function()
      clear_board()
      show_default()
    end,
    show_default
  )
  
  local x_pos = 64
  local y_pos = 26
  local y_offset = 10
  screen.clear()
  screen.move(x_pos, y_pos)
  screen.level(15)
  screen.text_center(message)
  screen.level(4)
  screen.move(x_pos, y_pos + y_offset)
  screen.text_center("really?")
  screen.move(0, 60)
  screen.text("KEY2 - cancel")
  screen.move(128, 60)
  screen.text_right("KEY3 - ok")

  screen.update()
end

