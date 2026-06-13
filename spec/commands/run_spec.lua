describe("run command (mani.commands.run.run)", function()
  local cmd
  local task
  local log
  local old_exit

  before_each(function()
    package.loaded["mani.commands.run.run"] = nil
    package.loaded["mani.core.task"] = nil
    package.loaded["mani.core.log"] = nil

    -- task.run must handle being called via colon syntax: task:run(name, params)
    -- which passes task as the first argument
    task = {
      run = spy.new(function(_, _, _) end),
    }
    log = {
      error = spy.new(function() end),
      warn = spy.new(function() end),
      info = spy.new(function() end),
      ok = spy.new(function() end),
    }

    package.preload["mani.core.task"] = function() return task end
    package.preload["mani.core.log"] = function() return log end

    cmd = require("mani.commands.run.run")
    old_exit = os.exit
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.run.run"] = nil
    package.preload["mani.core.task"] = nil
    package.preload["mani.core.log"] = nil
  end)

  it("registers parser with command, argument, option", function()
    local called_name, called_desc
    local cmd_obj = {
      argument = function(self) return self end,
      option = function(self) return self end,
      args = function(self) return self end,
      default = function(self) return self end,
    }
    local parser = {
      command = function(_, name, desc)
        called_name = name
        called_desc = desc
        return cmd_obj
      end,
    }
    cmd.register(parser)
    assert.are.equal("run", called_name)
    assert.are.equal("Run a task defined in mani.build.lua.", called_desc)
  end)

  it("runs the named task with dev profile by default", function()
    local project = {
      metadata = { profiles = {} },
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = "build", profile = "dev", task_args = {} }, project, nil)
    assert.spy(task.run).was_called()
    local task_arg = task.run.calls[1].vals[2]
    assert.are.equal("build", task_arg)
    local params = task.run.calls[1].vals[3]
    assert.are.equal("dev", params.profile)
    assert.are.same({}, params.args)
  end)

  it("defaults to task name 'default' when none given", function()
    local project = {
      metadata = { profiles = {} },
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = nil, profile = "dev", task_args = {} }, project, nil)
    local task_arg = task.run.calls[1].vals[2]
    assert.are.equal("default", task_arg)
  end)

  it("passes --profile to set_profile", function()
    local project = {
      metadata = { profiles = { prod = {} } },
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = "build", profile = "prod", task_args = {} }, project, nil)
    assert.spy(project.set_profile).was_called()
    -- colon call so first arg is the project table itself
    assert.are.equal("prod", project.set_profile.calls[1].vals[2])
  end)

  it("passes extra args to task params", function()
    local project = {
      metadata = { profiles = {} },
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = "deploy", profile = "dev", task_args = { "--env", "prod" } }, project, nil)
    local params = task.run.calls[1].vals[3]
    assert.are.same({ "--env", "prod" }, params.args)
  end)

  it("errors and exits when profile is unknown and profiles are defined", function()
    local project = {
      metadata = {
        profiles = { dev = {}, prod = {} },
      },
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = "build", profile = "staging", task_args = {} }, project, nil)
    assert.spy(log.error).was_called_with("Unknown profile 'staging'.")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("allows any profile when no profiles are defined", function()
    local project = {
      metadata = nil,
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = "build", profile = "anything", task_args = {} }, project, nil)
    assert.spy(task.run).was_called()
  end)

  it("allows any profile when profiles table is empty", function()
    local project = {
      metadata = { profiles = {} },
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = "build", profile = "whatever", task_args = {} }, project, nil)
    assert.spy(task.run).was_called()
  end)

  it("reports task failure and exits", function()
    task.run = spy.new(function() error("something went wrong") end)
    local project = {
      metadata = { profiles = {} },
      set_profile = spy.new(function() end),
      profile_config = {},
    }
    cmd.run({ task = "failing", profile = "dev", task_args = {} }, project, nil)
    assert.spy(log.error).was_called()
    assert.spy(os.exit).was_called_with(1)
  end)
end)
