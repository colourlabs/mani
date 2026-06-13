describe("rockspec command (mani.commands.project.rockspec)", function()
  local cmd
  local rockspec
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.project.rockspec"] = nil
    package.loaded["mani.core.rockspec"] = nil
    package.loaded["mani.core.log"] = nil

    rockspec = {
      generate = spy.new(function() return true end),
    }
    log = {
      error = spy.new(function() end),
      ok = spy.new(function() end),
    }

    package.preload["mani.core.rockspec"] = function() return rockspec end
    package.preload["mani.core.log"] = function() return log end

    cmd = require("mani.commands.project.rockspec")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.project.rockspec"] = nil
    package.preload["mani.core.rockspec"] = nil
    package.preload["mani.core.log"] = nil
  end)

  it("registers parser with command", function()
    local called_name, called_desc
    local parser = {
      command = function(_, name, desc)
        called_name = name
        called_desc = desc
      end,
    }
    cmd.register(parser)
    assert.are.equal("rockspec", called_name)
    assert.are.equal("Regenerate the .rockspec file from project metadata.", called_desc)
  end)

  it("calls rockspec.generate and exits 0 on success", function()
    cmd.run({}, {}, nil)
    assert.spy(rockspec.generate).was_called()
    assert.spy(log.ok).was_called_with("Regenerated rockspec from project metadata.")
    assert.spy(os.exit).was_called_with(0)
  end)

  it("errors and exits 1 when rockspec.generate fails", function()
    rockspec.generate = spy.new(function() return false end)
    cmd.run({}, {}, nil)
    assert.spy(log.error).was_called_with("Failed to generate rockspec.")
    assert.spy(os.exit).was_called_with(1)
  end)
end)
