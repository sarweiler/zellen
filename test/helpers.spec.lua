lu = require("luaunit")
helpers = require("lib/helpers")

TestHelpers = {}

function TestHelpers:test_table_clone()
  local input_table = {1, 3, 4}
  local result = helpers.table.clone(input_table)
  lu.assertEquals(result, input_table)
  input_table[1] = 9
  lu.assertNotEquals(result, input_table)
end

function TestHelpers:test_table_map()
  local input_table = {1, 2, 3}
  local expected = {2, 3, 4}
  local result = helpers.table.map(
    function(x) return x + 1 end,
    input_table
  )
  lu.assertEquals(result, expected)
end

function TestHelpers:test_table_reverse()
  local input_table = {1, 2, 3}
  local expected = {3, 2, 1}
  local result = helpers.table.reverse(input_table)
  lu.assertEquals(result, expected)
end

function TestHelpers:test_table_shuffle()
  local input_table = {1, 2, 3}
  local result = helpers.table.shuffle(input_table)
  lu.assertNotEquals(result, input_table)
end

function TestHelpers:test_clone_board()
  local input_board = {
    {1, 2, 3, 4},
    {2, 4, 6, 8},
    {3, 6, 9, 0}
  }
  local result = helpers.clone_board(input_board)
  lu.assertEquals(result, input_board)
  input_board[1][3] = 19
  lu.assertNotEquals(result, input_board)
end

os.exit( lu.LuaUnit.run() )
