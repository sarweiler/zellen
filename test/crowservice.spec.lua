local cs = require("lib/crowservice")

describe("Busted unit testing framework", function()
  local crow_stub

  setup(function()
    -- test crow only has two outputs and one input
    crow_stub = {
      output = {
        {
          execute = function() end
        }, {
          execute = function() end
        }
      },
      input = {{}}
    }
  end)

  it("should set a voltage on an output", function()
    local c = cs:new(crow_stub)
    
    c:set_cv(1, 3)
    assert.are.equal(crow_stub.output[1].volts, 3)
  end)

  it("should set an action", function()
    local c = cs:new(crow_stub)
    local action = "{to(5,0), to(0, 0.25)}"

    c:set_action(2, action)
    assert.are.equal(crow_stub.output[2].action, action)
  end)

  it("should execute an action", function()
    local s = spy.on(crow_stub.output[1], "execute")
    local c = cs:new(crow_stub)

    c:execute_action(1)
    assert.spy(s).was_called()
  end)
end)