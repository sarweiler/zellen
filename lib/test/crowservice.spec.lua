local cs = require("lib/crowservice")

describe("CrowService", function()
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
      input = {
        {
          mode = function() end
        }
     },
     ii = {
      jf = {
        play_note = function() end,
        mode = function() end
      },
      pullup = function() end
     }
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

  it("should set an input to accept triggers", function()
    local mode_spy = spy.on(crow_stub.input[1], "mode")
    local c = cs:new(crow_stub)
    local change_fn = function() print("change") end

    c:set_trigger_input(1, change_fn)

    assert.are.equal(crow_stub.input[1].change, change_fn)
    assert.spy(mode_spy).was_called()
  end)

  it("should set an input to accept cv", function()
    local mode_spy = spy.on(crow_stub.input[1], "mode")
    local c = cs:new(crow_stub)
    local stream_fn = function() print("stream") end

    c:set_cv_input(1, stream_fn)

    assert.are.equal(crow_stub.input[1].stream, stream_fn)
    assert.spy(mode_spy).was_called()
  end)

  it("should activate ii pullup", function()
    local ii_pullup_spy = spy.on(crow_stub.ii, "pullup")
    local c = cs:new(crow_stub)

    c:activate_ii_pullup()
    assert.spy(ii_pullup_spy).was_called_with(true)
  end)

  it("should activate jf ii mode", function()
    local ii_jf_mode_spy = spy.on(crow_stub.ii.jf, "mode")
    local c = cs:new(crow_stub)

    c:activate_jf_ii()
    assert.spy(ii_jf_mode_spy).was_called_with(1)
  end)

  it("should deactivate jf ii mode", function()
    local ii_jf_mode_spy = spy.on(crow_stub.ii.jf, "mode")
    local c = cs:new(crow_stub)

    c:deactivate_jf_ii()
    assert.spy(ii_jf_mode_spy).was_called_with(0)
  end)

  it("should send a note value to just friends", function()
    local ii_jf_note_spy = spy.on(crow_stub.ii.jf, "play_note")
    local c = cs:new(crow_stub)

    c:jf_play_note(3)
    assert.spy(ii_jf_note_spy).was_called_with(3, 4.0)
  end)


end)