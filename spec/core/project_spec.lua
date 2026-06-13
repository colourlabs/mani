describe("Project (mani.core.project)", function()
  local project
  local log

  before_each(function()
    package.loaded["mani.core.project"] = nil
    package.loaded["mani.core.log"] = nil

    -- stub log so error/warn don't print noise and os.exit doesn't kill the test runner
    log = {
      error = spy.new(function() end),
      warn = spy.new(function() end),
      info = spy.new(function() end),
    }
    package.preload["mani.core.log"] = function() return log end

    project = require("mani.core.project")
  end)

  after_each(function()
    package.preload["mani.core.log"] = nil
  end)

  describe("define_project", function()
    it("defines project with required fields", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
      })
      assert.is_table(project.metadata)
      assert.are.equal("test", project.metadata.name)
      assert.are.equal("1.0.0", project.metadata.version)
      assert.are.equal("MIT", project.metadata.license)
    end)

    it("errors and exits if name is missing", function()
      local old_exit = os.exit
      os.exit = spy.new(function() end)

      project:define_project({
        version = "1.0.0",
        license = "MIT",
      })

      assert.spy(log.error).was_called()
      assert.spy(os.exit).was_called_with(1)

      os.exit = old_exit
    end)

    it("errors and exits if version is missing", function()
      local old_exit = os.exit
      os.exit = spy.new(function() end)

      project:define_project({
        name = "test",
        license = "MIT",
      })

      assert.spy(log.error).was_called()
      assert.spy(os.exit).was_called_with(1)

      os.exit = old_exit
    end)

    it("warns on unrecognised SPDX license", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "NotARealLicense",
      })
      assert.spy(log.warn).was_called()
    end)

    it("does not warn for a valid SPDX license", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
      })
      assert.spy(log.warn).was_not_called()
    end)

    it("does not warn when license is empty", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "",
      })
      assert.spy(log.warn).was_not_called()
    end)

    it("defaults bin to empty table", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
      })
      assert.is_table(project.metadata.bin)
      assert.is_nil(next(project.metadata.bin))
    end)

    it("accepts bin table", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
        bin = { ["test"] = "src/main.lua" },
      })
      assert.are.equal("src/main.lua", project.metadata.bin["test"])
    end)

    it("defaults lua_versions to current version", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
      })
      assert.is_table(project.metadata.lua_versions)
      assert.is_not.equal(0, #project.metadata.lua_versions)

      local expected = _VERSION:match("Lua (%d%.%d)") or "5.4"
      assert.are.equal(expected, project.metadata.lua_versions[1])
    end)

    it("accepts custom lua_versions", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
        lua_versions = { "5.1", "5.4" },
      })
      assert.are.equal(2, #project.metadata.lua_versions)
      assert.are.equal("5.1", project.metadata.lua_versions[1])
      assert.are.equal("5.4", project.metadata.lua_versions[2])
    end)

    it("defaults profiles to empty table", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
      })
      assert.is_table(project.metadata.profiles)
      assert.is_nil(next(project.metadata.profiles))
    end)

    it("accepts profiles", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
        profiles = {
          dev = { debug = true },
          prod = { debug = false },
        },
      })
      assert.is_true(project.metadata.profiles.dev.debug)
      assert.is_false(project.metadata.profiles.prod.debug)
    end)
  end)

  describe("set_profile", function()
    it("resolves profile_config for a known profile", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
        profiles = { dev = { x = 1 } },
      })
      project:set_profile("dev")
      assert.are.equal("dev", project.active_profile)
      assert.are.equal(1, project.profile_config.x)
    end)

    it("errors and exits on unknown profile when profiles exist", function()
      local old_exit = os.exit
      os.exit = spy.new(function() end)

      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
        profiles = { dev = { x = 1 }, prod = { x = 2 } },
      })
      project:set_profile("staging")

      assert.spy(log.error).was_called()
      assert.spy(os.exit).was_called_with(1)

      os.exit = old_exit
    end)

    it("allows any profile name when no profiles are defined", function()
      project:define_project({
        name = "test",
        version = "1.0.0",
        license = "MIT",
      })
      project:set_profile("anything")
      assert.are.equal("anything", project.active_profile)
      assert.are.same({}, project.profile_config)
    end)
  end)

  describe("define_dependencies", function()
    it("parses dependencies given as an array", function()
      project:define_dependencies({ "foo>=1.0", "bar" })
      assert.are.equal(2, #project.dependencies)
      assert.are.equal("foo>=1.0", project.dependencies[1])
      assert.are.equal("bar", project.dependencies[2])
    end)

    it("parses dependencies given as a name->version table", function()
      project:define_dependencies({ foo = ">=1.0" })
      assert.are.equal(1, #project.dependencies)
      assert.are.equal("foo >=1.0", project.dependencies[1])
    end)
  end)

  describe("define_dev_dependencies", function()
    it("parses dev dependencies as an array", function()
      project:define_dev_dependencies({ "busted>=2.0" })
      assert.are.equal(1, #project.dev_dependencies)
      assert.are.equal("busted>=2.0", project.dev_dependencies[1])
    end)
  end)

  describe("reset", function()
    it("clears state back to defaults", function()
      project:define_project({ name = "test", version = "1.0.0", license = "MIT" })
      project:define_dependencies({ "foo" })
      project:set_profile("dev")

      project:reset()

      assert.is_nil(project.metadata)
      assert.are.same({}, project.dependencies)
      assert.are.same({}, project.dev_dependencies)
      assert.are.equal("dev", project.active_profile)
      assert.are.same({}, project.profile_config)
    end)
  end)
end)