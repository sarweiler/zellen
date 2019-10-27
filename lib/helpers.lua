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


return helpers