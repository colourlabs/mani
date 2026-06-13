describe("init command (mani.commands.project.init)", function()
  local cmd
  local log
  local old_exit
  local build_lua_backup

  before_each(function()
    package.loaded["mani.commands.project.init"] = nil
    package.loaded["mani.core.log"] = nil

    log = {
      warn = spy.new(function() end),
      info = spy.new(function() end),
      ok = spy.new(function() end),
    }
    package.preload["mani.core.log"] = function() return log end

    cmd = require("mani.commands.project.init")
    old_exit = os.exit
    os.exit = spy.new(function() end)

    -- back up and remove mani.build.lua for clean tests
    local f = io.open("mani.build.lua", "r")
    if f then
      build_lua_backup = f:read("*a")
      f:close()
      os.remove("mani.build.lua")
    else
      build_lua_backup = nil
    end
  end)

  after_each(function()
    os.exit = old_exit
    package.preload["mani.commands.project.init"] = nil
    package.preload["mani.core.log"] = nil

    -- clean up files created by init
    os.remove("mani.build.lua")
    os.remove("src/main.lua")

    -- restore original build.lua if it existed
    if build_lua_backup then
      local f = io.open("mani.build.lua", "w")
      f:write(build_lua_backup)
      f:close()
    end
  end)

  it("registers parser with command and -y flag", function()
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
    assert.are.equal("init", called_name)
    assert.are.equal("Initialize a new project with mani.build.lua.", called_desc)
    assert.spy(cmd_obj.flag).was_called()
  end)

  it("warns and exits if mani.build.lua already exists", function()
    local f = io.open("mani.build.lua", "w")
    f:write("-- existing")
    f:close()

    cmd.run({ yes = true }, {}, nil)
    assert.spy(log.warn).was_called_with("mani.build.lua already exists. Skipping init.")
    assert.spy(os.exit).was_called_with(0)
  end)

  it("creates mani.build.lua with defaults via -y (silent, no prompts)", function()
    io.read = spy.new(function() return "" end)

    cmd.run({ yes = true }, {}, nil)

    assert.spy(log.info).was_not_called()
    assert.spy(io.read).was_not_called()

    local f = io.open("mani.build.lua", "r")
    assert.is_not_nil(f)
    local content = f:read("*a")
    f:close()

    assert.is_true(content:find('name = "my-project"', 1, true) ~= nil)
    assert.is_true(content:find('version = "0.1.0"', 1, true) ~= nil)
    assert.is_true(content:find('license = "MIT"', 1, true) ~= nil)
    assert.is_true(content:find('homepage = "https://github.com/username/my-project"', 1, true) ~= nil)
    assert.is_true(content:find('summary = "A modern Lua project"', 1, true) ~= nil)
    assert.spy(log.ok).was_called_with("Created mani.build.lua")
    assert.spy(os.exit).was_called_with(0)
  end)

  it("creates src/main.lua with project name via -y", function()
    cmd.run({ yes = true }, {}, nil)

    local f = io.open("src/main.lua", "r")
    assert.is_not_nil(f, "src/main.lua was not created")
    local content = f:read("*a")
    f:close()
    assert.is_true(content:find("Hello from my-project", 1, true) ~= nil)
    assert.spy(log.ok).was_called_with("Created src/main.lua")
  end)

  it("does not overwrite existing src/main.lua", function()
    os.execute("mkdir -p src")
    local f = io.open("src/main.lua", "w")
    f:write("-- existing main.lua")
    f:close()

    cmd.run({ yes = true }, {}, nil)

    local fr = io.open("src/main.lua", "r")
    local content = fr:read("*a")
    fr:close()
    assert.are.equal("-- existing main.lua", content)
  end)

  it("generates valid Lua file with -y", function()
    cmd.run({ yes = true }, {}, nil)

    local chunk, err = loadfile("mani.build.lua")
    assert.is_nil(err)
    assert.is_not_nil(chunk)
  end)

  it("uses user-provided input #interactive", function()
    local count = 0
    local answers = { "my-app", "2.0.0", "Apache-2.0", "https://example.com", "An awesome app" }
    io.read = function()
      count = count + 1
      return answers[count]
    end

    cmd.run({}, {}, nil)
    io.read = nil

    local f = io.open("mani.build.lua", "r")
    local content = f:read("*a")
    f:close()

    assert.is_true(content:find('name = "my-app"', 1, true) ~= nil)
    assert.is_true(content:find('version = "2.0.0"', 1, true) ~= nil)
    assert.is_true(content:find('license = "Apache-2.0"', 1, true) ~= nil)
    assert.is_true(content:find('homepage = "https://example.com"', 1, true) ~= nil)
    assert.is_true(content:find('summary = "An awesome app"', 1, true) ~= nil)
  end)
end)
