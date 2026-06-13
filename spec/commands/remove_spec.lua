describe("remove command (mani.commands.packages.remove)", function()
  local cmd
  local installer
  local rockspec
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.packages.remove"] = nil
    package.loaded["mani.core.installer"] = nil
    package.loaded["mani.core.rockspec"] = nil
    package.loaded["mani.core.log"] = nil

    installer = {
      remove_package = spy.new(function() return true end),
    }
    rockspec = {
      generate = spy.new(function() return true end),
    }
    log = {
      error = spy.new(function() end),
      warn = spy.new(function() end),
      ok = spy.new(function() end),
    }

    package.preload["mani.core.installer"] = function() return installer end
    package.preload["mani.core.rockspec"] = function() return rockspec end
    package.preload["mani.core.log"] = function() return log end

    cmd = require("mani.commands.packages.remove")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.packages.remove"] = nil
    package.preload["mani.core.installer"] = nil
    package.preload["mani.core.rockspec"] = nil
    package.preload["mani.core.log"] = nil
  end)

  it("registers parser with command and argument", function()
    local called_name, called_desc
    local cmd_obj = {
      argument = spy.new(function() end),
    }
    local parser = {
      command = function(_, name, desc)
        called_name = name
        called_desc = desc
        return cmd_obj
      end,
    }
    cmd.register(parser)
    assert.are.equal("remove", called_name)
    assert.are.equal("Remove a dependency from the project.", called_desc)
  end)

  it("calls remove_package and regenerates rockspec on success", function()
    cmd.run({ package = "inspect" }, {}, nil)
    assert.spy(installer.remove_package).was_called_with("inspect", {})
    assert.spy(rockspec.generate).was_called()
    assert.spy(log.ok).was_called()
    assert.spy(os.exit).was_not_called()
  end)

  it("exits when installer.remove_package returns false", function()
    installer.remove_package = spy.new(function() return false end)
    cmd.run({ package = "nonexistent" }, {}, nil)
    assert.spy(os.exit).was_called_with(1)
  end)

  it("warns when rockspec generation fails", function()
    rockspec.generate = spy.new(function() return false end)
    cmd.run({ package = "inspect" }, {}, nil)
    assert.spy(log.warn).was_called_with("Package removed but failed to regenerate rockspec.")
  end)
end)
