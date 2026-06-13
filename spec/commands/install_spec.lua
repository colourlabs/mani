describe("install command (mani.commands.packages.install)", function()
  local cmd
  local installer
  local rockspec
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.packages.install"] = nil
    package.loaded["mani.core.installer"] = nil
    package.loaded["mani.core.rockspec"] = nil
    package.loaded["mani.core.log"] = nil

    installer = {
      run = spy.new(function() return true end),
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

    cmd = require("mani.commands.packages.install")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.packages.install"] = nil
    package.preload["mani.core.installer"] = nil
    package.preload["mani.core.rockspec"] = nil
    package.preload["mani.core.log"] = nil
  end)

  it("registers parser with command and flags", function()
    local called_name, called_desc
    local cmd_obj = {
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
    assert.are.equal("install", called_name)
    assert.are.equal("Install project dependencies and write mani.lock.lua.", called_desc)
  end)

  it("calls installer.run with production=false, frozen=false by default", function()
    cmd.run({ production = false, frozen_lockfile = false }, {}, nil)
    assert.spy(installer.run).was_called_with(false, false, {})
    assert.spy(rockspec.generate).was_called()
  end)

  it("passes --production flag to installer.run", function()
    cmd.run({ production = true, frozen_lockfile = false }, {}, nil)
    assert.spy(installer.run).was_called_with(true, false, {})
  end)

  it("passes --frozen-lockfile flag to installer.run", function()
    cmd.run({ production = false, frozen_lockfile = true }, {}, nil)
    assert.spy(installer.run).was_called_with(false, true, {})
  end)

  it("errors and exits when installer.run returns false", function()
    installer.run = spy.new(function() return false end)
    cmd.run({ production = false, frozen_lockfile = false }, {}, nil)
    assert.spy(log.error).was_called_with("Failed to install dependencies.")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("skips rockspec generation when --frozen-lockfile is used", function()
    cmd.run({ production = false, frozen_lockfile = true }, {}, nil)
    assert.spy(rockspec.generate).was_not_called()
    assert.spy(log.ok).was_not_called()
  end)

  it("warns when rockspec generation fails in non-frozen mode", function()
    rockspec.generate = spy.new(function() return false end)
    cmd.run({ production = false, frozen_lockfile = false }, {}, nil)
    assert.spy(log.warn).was_called_with("Dependencies installed but failed to generate rockspec.")
  end)

  it("handles nil parsed flags gracefully", function()
    cmd.run({}, {}, nil)
    assert.spy(installer.run).was_called_with(false, false, {})
  end)
end)
