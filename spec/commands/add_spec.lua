describe("add command (mani.commands.packages.add)", function()
  local cmd
  local installer
  local rockspec
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.packages.add"] = nil
    package.loaded["mani.core.installer"] = nil
    package.loaded["mani.core.rockspec"] = nil
    package.loaded["mani.core.log"] = nil

    installer = {
      add_package = spy.new(function() return true end),
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

    cmd = require("mani.commands.packages.add")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.packages.add"] = nil
    package.preload["mani.core.installer"] = nil
    package.preload["mani.core.rockspec"] = nil
    package.preload["mani.core.log"] = nil
  end)

  it("registers parser with command, argument and flag", function()
    local called_name, called_desc
    local cmd_obj = {
      argument = spy.new(function() end),
      flag = spy.new(function() end),
    }
    local parser = {
      command = function(_, name, desc)
        called_name = name
        called_desc = desc
        return cmd_obj
      end,
    }
    cmd.register(parser)
    assert.are.equal("add", called_name)
    assert.are.equal("Add a package and install it.", called_desc)
  end)

  it("runs add_package and regenerates rockspec on success", function()
    cmd.run({ package = "inspect@3.0", save_dev = false }, {}, nil)
    assert.spy(installer.add_package).was_called_with("inspect@3.0", false, {})
    assert.spy(rockspec.generate).was_called()
    assert.spy(log.ok).was_called()
    assert.spy(os.exit).was_not_called()
  end)

  it("accepts --save-dev flag and passes it through", function()
    cmd.run({ package = "busted", save_dev = true }, {}, nil)
    assert.spy(installer.add_package).was_called_with("busted", true, {})
  end)

  it("errors and exits when package argument is empty", function()
    cmd.run({ package = "", save_dev = false }, {}, nil)
    assert.spy(log.error).was_called_with("Usage: mani add <package>[@<version>]")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("errors and exits when package argument is nil", function()
    cmd.run({ package = nil, save_dev = false }, {}, nil)
    assert.spy(log.error).was_called_with("Usage: mani add <package>[@<version>]")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("errors and exits when installer.add_package returns false", function()
    installer.add_package = spy.new(function() return false end)
    cmd.run({ package = "inspect", save_dev = false }, {}, nil)
    assert.spy(log.error).was_called_with("Failed to add package.")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("warns instead of ok when rockspec generation fails", function()
    rockspec.generate = spy.new(function() return false end)
    cmd.run({ package = "inspect", save_dev = false }, {}, nil)
    assert.spy(log.warn).was_called_with("Package added but failed to regenerate rockspec.")
  end)
end)
