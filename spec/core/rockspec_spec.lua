describe("Rockspec generator (mani.core.rockspec)", function()
  local rockspec
  local log
  local test_filename = "rockspecs/myproject-1.2.3-1.rockspec"

  before_each(function()
    package.loaded["mani.core.rockspec"] = nil
    package.loaded["mani.core.log"] = nil

    log = {
      error = spy.new(function() end),
      warn = spy.new(function() end),
      ok = spy.new(function() end),
    }
    package.preload["mani.core.log"] = function() return log end

    rockspec = require("mani.core.rockspec")

    -- xlean up any pre-existing test files
    os.remove(test_filename)
  end)

  after_each(function()
    os.remove(test_filename)
    os.execute("rmdir rockspecs 2>/dev/null") -- only removes if empty
    package.preload["mani.core.log"] = nil
  end)

  it("fails when project metadata is missing", function()
    local success = rockspec.generate({ dependencies = {} })
    assert.is_false(success)
    assert.spy(log.error).was_called_with("no project metadata found - call mani.project{} first")
  end)

  it("generates a valid rockspec and parses it back", function()
    local proj = {
      metadata = {
        name = "myproject",
        version = "1.2.3",
        license = "MIT",
        summary = "A cool project",
        homepage = "https://github.com/user/myproject",
        lua_versions = { "5.1", "5.2", "5.3", "5.4" },
        bin = { ["mycmd"] = "src/main.lua" }
      },
      dependencies = { "inspect^3.0", "busted^2.0" }
    }

    local success = rockspec.generate(proj)
    assert.is_true(success)

    -- assert it wrote the file
    local f = io.open(test_filename, "r")
    assert.is_not_nil(f)
    f:close()

    -- load the generated rockspec file in a clean environment
    local env = {}
    local chunk, err = loadfile(test_filename, "t", env)
    assert.is_nil(err)
    assert.is_not_nil(chunk)

    local run_ok, run_err = pcall(chunk)
    assert.is_true(run_ok, run_err)

    -- assert rockspec properties
    assert.are.equal("myproject", env.package)
    assert.are.equal("1.2.3-1", env.version)

    assert.is_table(env.source)
    assert.are.equal("git+https://github.com/user/myproject", env.source.url)
    assert.are.equal("v1.2.3", env.source.tag)

    assert.is_table(env.description)
    assert.are.equal("A cool project", env.description.summary)
    assert.are.equal("https://github.com/user/myproject", env.description.homepage)
    assert.are.equal("MIT", env.description.license)

    assert.is_table(env.dependencies)
    -- should have: Lua dependency, inspect dependency, busted dependency
    local has_lua, has_inspect, has_busted = false, false, false
    for _, dep in ipairs(env.dependencies) do
      if dep:find("lua", 1, true) then has_lua = true end
      if dep:find("inspect", 1, true) then has_inspect = true end
      if dep:find("busted", 1, true) then has_busted = true end
    end
    assert.is_true(has_lua)
    assert.is_true(has_inspect)
    assert.is_true(has_busted)

    assert.is_table(env.build)
    assert.are.equal("builtin", env.build.type)
    assert.is_table(env.build.modules)
    assert.is_table(env.build.install)
    assert.is_table(env.build.install.bin)
    assert.are.equal("src/main.lua", env.build.install.bin.mycmd)
  end)
end)
