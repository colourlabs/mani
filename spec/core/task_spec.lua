local quiet, runner

describe("Task runner (mani.core.task)", function()
  before_each(function()
    package.loaded["mani.core.task"] = nil
    package.loaded["mani.core.log"] = nil

    quiet = {
      error = spy.new(function() end),
      warn = spy.new(function() end),
      info = spy.new(function() end),
      ok = spy.new(function() end),
    }

    package.preload["mani.core.log"] = function() return quiet end

    runner = require("mani.core.task")
  end)

  it("registers and runs a task", function()
    local ran = false
    runner:register("test", {}, function(_)
      ran = true
    end)
    runner:run("test", {})
    assert.is_true(ran)
  end)

  it("runs dependency tasks before the task", function()
    local order = {}
    runner:register("a", {}, function(_)
      table.insert(order, "a")
    end)
    runner:register("b", { "a" }, function(_)
      table.insert(order, "b")
    end)
    runner:run("b", {})
    assert.are.equal("a", order[1])
    assert.are.equal("b", order[2])
  end)

  it("passes params to task function", function()
    local received = nil
    runner:register("test", {}, function(params)
      received = params
    end)
    runner:run("test", { foo = "bar" })
    assert.are.equal("bar", received.foo)
  end)

  it("runs each task only once", function()
    local count = 0
    runner:register("a", {}, function(_)
      count = count + 1
    end)
    runner:register("b", { "a", "a" }, function(_)
      count = count + 1
    end)
    runner:run("b", {})
    assert.are.equal(2, count)
  end)

  it("errors and exits when running an unregistered task", function()
    local old_exit = os.exit
    os.exit = spy.new(function() end)

    runner:run("unregistered", {})

    assert.spy(quiet.error).was_called_with("unknown task: unregistered")
    assert.spy(os.exit).was_called_with(1)

    os.exit = old_exit
  end)

  it("errors and exits when a dependency cycle is detected", function()
    local old_exit = os.exit
    os.exit = spy.new(function() end)

    runner:register("a", { "b" }, function(_) end)
    runner:register("b", { "a" }, function(_) end)
    runner:run("a", {})

    assert.spy(quiet.error).was_called_with("dependency cycle detected at task: a")
    assert.spy(os.exit).was_called_with(1)

    os.exit = old_exit
  end)
end)