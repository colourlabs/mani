describe("lock command (mani.commands.lockfile.lock)", function()
  local cmd
  local installer
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.lockfile.lock"] = nil
    package.loaded["mani.core.installer"] = nil
    package.loaded["mani.core.log"] = nil

    installer = {
      check_lockfile = spy.new(function() return true end),
      regen_lockfile = spy.new(function() return true end),
    }
    log = {
      error = spy.new(function() end),
    }

    package.preload["mani.core.installer"] = function() return installer end
    package.preload["mani.core.log"] = function() return log end

    cmd = require("mani.commands.lockfile.lock")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.lockfile.lock"] = nil
    package.preload["mani.core.installer"] = nil
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
    assert.are.equal("lock", called_name)
    assert.are.equal("Manage mani.lock.lua.", called_desc)
  end)

  it("calls check_lockfile with --check flag", function()
    cmd.run({ check = true, regen = false }, {}, nil)
    assert.spy(installer.check_lockfile).was_called()
    assert.spy(installer.regen_lockfile).was_not_called()
  end)

  it("calls regen_lockfile with --regen flag", function()
    cmd.run({ check = false, regen = true }, {}, nil)
    assert.spy(installer.regen_lockfile).was_called()
    assert.spy(installer.check_lockfile).was_not_called()
  end)

  it("handles both --check and --regen together", function()
    cmd.run({ check = true, regen = true }, {}, nil)
    assert.spy(installer.check_lockfile).was_called()
    assert.spy(installer.regen_lockfile).was_called()
  end)

  it("exits 1 when check_lockfile returns false", function()
    installer.check_lockfile = spy.new(function() return false end)
    cmd.run({ check = true, regen = false }, {}, nil)
    assert.spy(os.exit).was_called_with(1)
  end)

  it("exits 1 when regen_lockfile returns false", function()
    installer.regen_lockfile = spy.new(function() return false end)
    cmd.run({ check = false, regen = true }, {}, nil)
    assert.spy(os.exit).was_called_with(1)
  end)

  it("errors and exits when neither --check nor --regen is provided", function()
    cmd.run({ check = false, regen = false }, {}, nil)
    assert.spy(log.error).was_called_with("Usage: mani lock --check | --regen")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("errors and exits when both flags are false/nil", function()
    cmd.run({}, {}, nil)
    assert.spy(log.error).was_called_with("Usage: mani lock --check | --regen")
    assert.spy(os.exit).was_called_with(1)
  end)
end)
