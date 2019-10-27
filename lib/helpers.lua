-- some helper functions

local helpers = {
  table = {}
}

helpers.table.clone = function(org)
  return {table.unpack(org)}
end

helpers.table.map = function(f, arr)
  local mapped_arr = {}
  for i,v in ipairs(arr) do
    mapped_arr[i] = f(v)
  end
  return mapped_arr
end

helpers.table.reverse = function(arr)
  local rev_arr = {}
  for i = #arr, 1, -1 do
    table.insert(rev_arr, arr[i])
  end
  return rev_arr
end

helpers.table.shuffle = function(arr)
  for i = #arr, 2, -1 do
    local j = math.random(i)
    arr[i], arr[j] = arr[j], arr[i]
  end
  return arr
end

helpers.clone_board = function(b)
  b_c = {}
  for i=1,#b do
    b_c[i] = helpers.table.clone(b[i])
  end
  return b_c
end

helpers.load_params = function()
  -- TODO: load board state
  params:read(_path.data .. "zellen/zellen.pset")
  params:bang()
end

helpers.update_playing_indicator = function(show_playing_indicator)
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

helpers.init_engine = function(engine)
  engine.release(params:get("release"))
  engine.cutoff(params:get("cutoff"))
end


return helpers