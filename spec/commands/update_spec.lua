describe("update command (mani.commands.packages.update)", function()
  local cmd
  local installer
  local rockspec
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.packages.update"] = nil
    package.loaded["mani.core.installer"] = nil
    package.loaded["mani.core.rockspec"] = nil
    package.loaded["mani.core.log"] = nil

    installer = {
      update = spy.new(function() return true end),
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

    cmd = require("mani.commands.packages.update")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.packages.update"] = nil
    package.preload["mani.core.installer"] = nil
    package.preload["mani.core.rockspec"] = nil
    package.preload["mani.core.log"] = nil
  end)

  it("registers parser with command", function()
    local called_name, called_desc
    local cmd_obj = {
      argument = function(self) return self end,
      args = function(self) return self end,
    }
    local parser = {
      command = function(_, name, desc)
        called_name = name
        called_desc = desc
        return cmd_obj
      end,
    }
    cmd.register(parser)
    assert.are.equal("update", called_name)
    assert.are.equal("Update dependencies to latest compatible versions.", called_desc)
  end)

  it("calls installer.update with given packages", function()
    cmd.run({ packages = { "inspect" } }, {}, nil)
    assert.spy(installer.update).was_called_with({ "inspect" }, {})
    assert.spy(rockspec.generate).was_called()
  end)

  it("calls installer.update with empty list when no packages given", function()
    cmd.run({ packages = {} }, {}, nil)
    assert.spy(installer.update).was_called_with({}, {})
  end)

  it("calls installer.update with nil packages gracefully", function()
    cmd.run({}, {}, nil)
    assert.spy(installer.update).was_called_with({}, {})
  end)

  it("errors and exits when installer.update returns false", function()
    installer.update = spy.new(function() return false end)
    cmd.run({ packages = { "inspect" } }, {}, nil)
    assert.spy(log.error).was_called_with("Failed to update packages.")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("warns when rockspec generation fails", function()
    rockspec.generate = spy.new(function() return false end)
    cmd.run({ packages = { "inspect" } }, {}, nil)
    assert.spy(log.warn).was_called_with("Packages updated but failed to regenerate rockspec.")
  end)
end)
