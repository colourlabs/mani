describe("exec command (mani.commands.run.exec)", function()
  local cmd
  local exec
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.run.exec"] = nil
    package.loaded["mani.core.exec"] = nil
    package.loaded["mani.core.log"] = nil

    exec = {
      run = spy.new(function() return true end),
    }
    log = {
      error = spy.new(function() end),
    }

    package.preload["mani.core.exec"] = function() return exec end
    package.preload["mani.core.log"] = function() return log end

    cmd = require("mani.commands.run.exec")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.run.exec"] = nil
    package.preload["mani.core.exec"] = nil
    package.preload["mani.core.log"] = nil
  end)

  it("registers parser with command and argument", function()
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
    assert.are.equal("exec", called_name)
    assert.are.equal("Run a shell command with the project tree on PATH.", called_desc)
  end)

  it("joins cmd array into a single string and runs it", function()
    cmd.run({ cmd = { "luacheck", "src/" } }, {}, nil)
    assert.spy(exec.run).was_called_with("luacheck src/")
    assert.spy(os.exit).was_not_called()
  end)

  it("runs single-word commands", function()
    cmd.run({ cmd = { "make" } }, {}, nil)
    assert.spy(exec.run).was_called_with("make")
  end)

  it("errors and exits when command fails", function()
    exec.run = spy.new(function() return false end)
    cmd.run({ cmd = { "false" } }, {}, nil)
    assert.spy(log.error).was_called_with("command failed: false")
    assert.spy(os.exit).was_called_with(1)
  end)
end)
