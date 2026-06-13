describe("Installer module (mani.core.installer)", function()
  local installer
  local log
  local exec_mock
  local lockfile_mock
  local resolver_mock

  local build_lua_backup
  local lock_lua_backup

  before_each(function()
    package.loaded["mani.core.installer"] = nil
    package.loaded["mani.core.log"] = nil
    package.loaded["mani.core.exec"] = nil
    package.loaded["mani.core.lockfile"] = nil
    package.loaded["mani.core.resolver"] = nil

    log = {
      warn = spy.new(function() end),
      info = spy.new(function() end),
      error = spy.new(function() end),
      ok = spy.new(function() end),
    }

    exec_mock = {
      run = spy.new(function(_) return true end),
      silent = spy.new(function(_) return "", "" end),
    }

    lockfile_mock = {
      compute_hash = spy.new(function(_) return "mock-manifest-hash" end),
      read_existing_lockfile_versions = spy.new(function() return {} end),
      read_full_lockfile = spy.new(function() return {} end),
      write_lockfile = spy.new(function(_, _) return true end),
      verify_integrity = spy.new(function(_) return true end),
      lua_version_str = function() return "5.4" end,
      rocks_dir = function() return "/mock/rocks" end,
    }

    resolver_mock = {
      resolve_installed_packages = spy.new(function() return {} end),
    }

    package.preload["mani.core.log"] = function() return log end
    package.preload["mani.core.exec"] = function() return exec_mock end
    package.preload["mani.core.lockfile"] = function() return lockfile_mock end
    package.preload["mani.core.resolver"] = function() return resolver_mock end

    installer = require("mani.core.installer")

    -- back up mani.build.lua
    local fb = io.open("mani.build.lua", "r")
    if fb then
      build_lua_backup = fb:read("*a")
      fb:close()
    else
      build_lua_backup = nil
    end

    -- write dummy mani.build.lua fixture
    local fbw = io.open("mani.build.lua", "w")
    fbw:write([[
mani.project({
  name = "test-proj",
  version = "1.0.0",
  license = "MIT"
})
mani.dependencies({
})
mani.dev_dependencies({
})
]])
    fbw:close()

    -- back up mani.lock.lua
    local fl = io.open("mani.lock.lua", "r")
    if fl then
      lock_lua_backup = fl:read("*a")
      fl:close()
      os.remove("mani.lock.lua")
    else
      lock_lua_backup = nil
    end
  end)

  after_each(function()
    package.preload["mani.core.log"] = nil
    package.preload["mani.core.exec"] = nil
    package.preload["mani.core.lockfile"] = nil
    package.preload["mani.core.resolver"] = nil

    -- restore mani.build.lua
    os.remove("mani.build.lua")
    if build_lua_backup then
      local fbw = io.open("mani.build.lua", "w")
      fbw:write(build_lua_backup)
      fbw:close()
    end

    -- restore mani.lock.lua
    os.remove("mani.lock.lua")
    if lock_lua_backup then
      local flw = io.open("mani.lock.lua", "w")
      flw:write(lock_lua_backup)
      flw:close()
    end
  end)

  describe("trim helper", function()
    it("trims leading and trailing whitespace", function()
      assert.are.equal("foo", installer._trim("  foo  "))
      assert.are.equal("foo bar", installer._trim("\tfoo bar\n"))
      assert.are.equal("", installer._trim("   "))
    end)
  end)

  describe("dep_name helper", function()
    it("extracts package name from constraint string", function()
      assert.are.equal("foo", installer._dep_name("foo>=1.0"))
      assert.are.equal("foo", installer._dep_name("foo ^1.2.3"))
      assert.are.equal("foo", installer._dep_name("foo"))
      assert.are.equal("foo-bar", installer._dep_name("foo-bar >= 2.0"))
    end)
  end)

  describe("topological_sort helper", function()
    it("sorts simple dependency tree", function()
      local packages = {
        a = { dependencies = { "b" } },
        b = { dependencies = {} },
        c = { dependencies = { "a" } }
      }
      local order = installer._topological_sort(packages)
      assert.are.same({ "b", "a", "c" }, order)
    end)

    it("detects dependency cycles and warns", function()
      local packages = {
        a = { dependencies = { "b" } },
        b = { dependencies = { "a" } }
      }
      local order = installer._topological_sort(packages)
      assert.spy(log.warn).was_called()
      assert.is_true(#order > 0)
    end)
  end)

  describe("Block manipulation helpers", function()
    local content = [[
mani.project({
  name = "test-project",
  version = "0.1.0"
})

mani.dependencies({
  "lyaml >= 6.2",
  "inspect >= 3.1",
})

mani.dev_dependencies({
  "busted >= 2.1",
})
]]

    local content_alt = [[
dependencies = {
  "lyaml >= 6.2",
}
]]

    it("finds the block range correctly", function()
      local s, e = installer._find_block_range(content, "mani%.dependencies")
      assert.is_true(s > 0)
      assert.is_true(e > s)
      local block = content:sub(s, e)
      assert.is_true(block:find("mani.dependencies", 1, true) ~= nil)
      assert.is_true(block:find("inspect >= 3.1", 1, true) ~= nil)
      assert.are.equal("}", block:sub(#block, #block))
    end)

    it("identifies insertion position right before the closing brace", function()
      local pos = installer._block_insert_pos(content, "mani%.dependencies")
      assert.is_true(pos > 0)
      assert.are.equal("}", content:sub(pos, pos))
    end)

    it("removes package from block successfully", function()
      local updated = installer._remove_from_block(content, "mani%.dependencies", "inspect")
      assert.is_nil(updated:find("inspect", 1, true))
      assert.is_not_nil(updated:find("lyaml", 1, true))

      local updated_alt = installer._remove_from_block(content_alt, "dependencies%s*=", "lyaml")
      assert.is_nil(updated_alt:find("lyaml", 1, true))
    end)
  end)

  describe("Orchestration logic", function()
    local proj

    before_each(function()
      proj = {
        dependencies = {},
        dev_dependencies = {}
      }
    end)

    it("add_package installs dependency and writes to mani.build.lua", function()
      resolver_mock.resolve_installed_packages = function()
        return {
          inspect = {
            version = "3.0-1",
            source = "git://...",
            hash = "xyz",
            integrity = "abc",
            dependencies = {}
          }
        }
      end

      -- add inspect package with no version constraint
      local success = installer.add_package("inspect", false, proj)
      assert.is_true(success)

      -- verify command executed (latest, so resolver lookup determines constraint)
      assert.spy(exec_mock.run).was_called()
      local last_cmd = exec_mock.run.calls[1].vals[1]
      assert.is_true(last_cmd:find("install --tree=.mani/tree 'inspect'", 1, true) ~= nil)

      -- verify mani.build.lua was mutated
      local f = io.open("mani.build.lua", "r")
      local content = f:read("*a")
      f:close()
      assert.is_true(content:find("inspect^3.0-1", 1, true) ~= nil)

      -- verify project in-memory dependencies was updated
      assert.are.same({ "inspect^3.0-1" }, proj.dependencies)

      -- Verify lockfile is saved
      assert.spy(lockfile_mock.write_lockfile).was_called()
    end)

    it("add_package with version constraint installs specified version", function()
      local success = installer.add_package("inspect@3.0", false, proj)
      assert.is_true(success)

      -- verify correct luarocks constraint was passed
      local last_cmd = exec_mock.run.calls[1].vals[1]
      assert.is_true(last_cmd:find("install --tree=.mani/tree 'inspect' '= 3.0'", 1, true) ~= nil)

      local f = io.open("mani.build.lua", "r")
      local content = f:read("*a")
      f:close()
      assert.is_true(content:find("inspect^3.0", 1, true) ~= nil)
    end)

    it("remove_package removes from build file and runs luarocks remove", function()
      proj.dependencies = { "inspect^3.0" }
      -- Pre-populate dependency in build.lua
      local f = io.open("mani.build.lua", "w")
      f:write([[
mani.dependencies({
  "inspect^3.0",
})
]])
      f:close()

      local success = installer.remove_package("inspect", proj)
      assert.is_true(success)

      -- check in-memory state
      assert.are.same({}, proj.dependencies)

      -- check shell remove executed
      local last_cmd = exec_mock.run.calls[1].vals[1]
      assert.is_true(last_cmd:find("remove --tree=.mani/tree 'inspect'", 1, true) ~= nil)

      -- check file mutated
      local fr = io.open("mani.build.lua", "r")
      local content = fr:read("*a")
      fr:close()
      assert.is_nil(content:find("inspect^3.0", 1, true))
    end)
  end)

  describe("find_package_in_list helper", function()
    it("finds package index in list by name", function()
      local deps = { "foo>=1.0", "bar ^2.0", "baz" }
      assert.are.equal(1, installer._find_package_in_list(deps, "foo"))
      assert.are.equal(2, installer._find_package_in_list(deps, "bar"))
      assert.are.equal(3, installer._find_package_in_list(deps, "baz"))
    end)

    it("returns 0 when package is not found", function()
      local deps = { "foo>=1.0", "bar ^2.0" }
      assert.are.equal(0, installer._find_package_in_list(deps, "nonexistent"))
    end)

    it("returns 0 for empty list", function()
      assert.are.equal(0, installer._find_package_in_list({}, "foo"))
    end)
  end)

  describe("update function", function()
    local proj

    before_each(function()
      proj = {
        dependencies = { "inspect>=3.0", "busted ^2.0" },
      }
    end)

    it("updates all dependencies when packages list is empty", function()
      local ok = installer.update({}, proj)
      assert.is_true(ok)

      -- should call install_and_lock with all deps
      assert.spy(exec_mock.run).was_called()
    end)

    it("updates only specified packages", function()
      local ok = installer.update({ "inspect" }, proj)
      assert.is_true(ok)
    end)

    it("returns true and logs info when no dependencies exist", function()
      proj.dependencies = {}
      local ok = installer.update({}, proj)
      assert.is_true(ok)
      assert.spy(log.info).was_called_with("no dependencies in project.")
      assert.spy(exec_mock.run).was_not_called()
    end)
  end)

  describe("check_lockfile function", function()
    before_each(function()
      -- write a valid lockfile for check tests
      local fl = io.open("mani.lock.lua", "w")
      fl:write([[
return {
  lockfile_version = "1.0",
  manifest_hash = "mock-manifest-hash",
  packages = {}
}
]])
      fl:close()
    end)

    it("fails when mani.lock.lua does not exist", function()
      os.remove("mani.lock.lua")
      local ok = installer.check_lockfile()
      assert.is_false(ok)
      assert.spy(log.error).was_called_with("mani.lock.lua not found")
    end)

    it("fails on syntax error in lockfile", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write("not valid lua {")
      fl:close()
      local ok = installer.check_lockfile()
      assert.is_false(ok)
      assert.spy(log.error).was_called()
    end)

    it("fails when lockfile returns non-table", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write("return 'string'")
      fl:close()
      local ok = installer.check_lockfile()
      assert.is_false(ok)
      assert.spy(log.error).was_called()
    end)

    it("fails when lockfile is missing required fields", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write("return {}")
      fl:close()
      local ok = installer.check_lockfile()
      assert.is_false(ok)
      assert.spy(log.error).was_called_with("mani.lock.lua: missing required fields")
    end)

    it("warns on unknown lockfile_version", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write([[
return {
  lockfile_version = "99.99",
  manifest_hash = "mock-manifest-hash",
  packages = {}
}
]])
      fl:close()
      installer.check_lockfile()
      assert.spy(log.warn).was_called()
    end)

    it("passes with valid lockfile", function()
      lockfile_mock.compute_hash = function() return "mock-manifest-hash" end
      lockfile_mock.verify_integrity = function() return true end
      local ok = installer.check_lockfile()
      assert.is_true(ok)
    end)
  end)

  describe("regen_lockfile function", function()
    it("regenerates lockfile from installed packages", function()
      resolver_mock.resolve_installed_packages = function()
        return {
          foo = { version = "1.0", source = "", hash = "", integrity = "", dependencies = {} }
        }
      end
      lockfile_mock.compute_hash = function() return "regen-hash" end
      lockfile_mock.write_lockfile = spy.new(function() return true end)

      local ok = installer.regen_lockfile()
      assert.is_true(ok)
      assert.spy(lockfile_mock.write_lockfile).was_called_with("regen-hash", {
        foo = { version = "1.0", source = "", hash = "", integrity = "", dependencies = {} }
      })
    end)

    it("fails when no installed packages found", function()
      resolver_mock.resolve_installed_packages = function() return {} end
      local ok = installer.regen_lockfile()
      assert.is_false(ok)
      assert.spy(log.warn).was_called_with("no installed packages found in .mani/tree")
    end)
  end)

  describe("write_build_lua_dep with realistic fixtures", function()
    before_each(function()
      -- write a realistic mani.build.lua with multi-line tables, comments, existing entries
      local f = io.open("mani.build.lua", "w")
      f:write([[
mani.project({
  name = "test-proj",
  version = "1.0.0",
  license = "MIT",
})

-- Main dependencies
mani.dependencies({
  "lyaml >= 6.2",
  "inspect >= 3.1",
})

-- Dev dependencies
mani.dev_dependencies({
  "busted >= 2.1",
})
]])
      f:close()
    end)

    it("inserts a production dependency in the right block", function()
      local ok = installer._write_build_lua_dep("luaunit^0.5", false)
      assert.is_true(ok)

      local f = io.open("mani.build.lua", "r")
      local content = f:read("*a")
      f:close()

      assert.is_true(content:find('"luaunit^0.5"', 1, true) ~= nil)
      -- Must be inside mani.dependencies block, not dev_dependencies
      local deps_start = content:find("mani%.dependencies%s-%(", 1)
      local deps_end = content:find("%)", deps_start)
      local deps_block = content:sub(deps_start, deps_end)
      assert.is_true(deps_block:find("luaunit", 1, true) ~= nil)
    end)

    it("inserts a dev dependency in the dev block", function()
      local ok = installer._write_build_lua_dep("luacheck^1.0", true)
      assert.is_true(ok)

      local f = io.open("mani.build.lua", "r")
      local content = f:read("*a")
      f:close()

      local dev_start = content:find("mani%.dev_dependencies%s-%(", 1)
      local dev_end = content:find("%)", dev_start)
      local dev_block = content:sub(dev_start, dev_end)
      assert.is_true(dev_block:find("luacheck", 1, true) ~= nil)
    end)

    it("fails when mani.build.lua is missing", function()
      os.remove("mani.build.lua")
      local ok = installer._write_build_lua_dep("foo^1.0", false)
      assert.is_false(ok)
      assert.spy(log.error).was_called_with("mani.build.lua not found")
    end)
  end)

  describe("install_and_lock normal paths", function()
    before_each(function()
      resolver_mock.resolve_installed_packages = function()
        return {
          foo = { version = "1.0", source = "", hash = "", integrity = "", dependencies = {} }
        }
      end
      lockfile_mock.compute_hash = function() return "hash" end
      lockfile_mock.write_lockfile = spy.new(function() return true end)
    end)

    it("installs deps and writes lockfile when deps are provided", function()
      -- We trigger install_and_lock via the run function
      local proj = { dependencies = { "foo" }, dev_dependencies = {} }
      local ok = installer.run(false, false, proj)
      assert.is_true(ok)
      assert.spy(exec_mock.run).was_called()
      assert.spy(lockfile_mock.write_lockfile).was_called()
    end)

    it("logs info and returns true when no deps to install", function()
      local proj = { dependencies = {}, dev_dependencies = {} }
      local ok = installer.run(false, false, proj)
      assert.is_true(ok)
      assert.spy(log.info).was_called_with("no dependencies to install.")
      assert.spy(exec_mock.run).was_not_called()
    end)

    it("logs warn when no installed packages found after install", function()
      resolver_mock.resolve_installed_packages = function() return {} end

      local proj = { dependencies = { "foo" }, dev_dependencies = {} }
      local ok = installer.run(false, false, proj)
      assert.is_true(ok)
      assert.spy(log.warn).was_called_with("no installed packages found in tree.")
    end)
  end)

  describe("--frozen-lockfile paths", function()
    local proj

    before_each(function()
      proj = {
        dependencies = { "inspect^3.0" },
        dev_dependencies = {}
      }
    end)

    it("fails early when lockfile is missing", function()
      -- ensure lockfile is absent
      os.remove("mani.lock.lua")

      local success = installer.run(false, true, proj)
      assert.is_false(success)
      assert.spy(log.error).was_called_with("--frozen-lockfile: could not load mani.lock.lua")
      assert.spy(exec_mock.run).was_not_called()
    end)

    it("fails early when lockfile contains invalid Lua format", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write("invalid_syntax {")
      fl:close()

      local success = installer.run(false, true, proj)
      assert.is_false(success)
      assert.spy(log.error).was_called_with("--frozen-lockfile: could not load mani.lock.lua")
      assert.spy(exec_mock.run).was_not_called()
    end)

    it("fails early when lockfile is empty or returns non-table", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write("return 'string-instead-of-table'")
      fl:close()

      local success = installer.run(false, true, proj)
      assert.is_false(success)
      assert.spy(log.error).was_called_with("--frozen-lockfile: invalid mani.lock.lua")
    end)

    it("fails early when manifest hash does not match build file", function()
      -- generate a lockfile with mismatching hash
      local fl = io.open("mani.lock.lua", "w")
      fl:write("return { manifest_hash = 'different-hash', packages = {} }")
      fl:close()

      lockfile_mock.compute_hash = function() return "matching-hash" end

      local success = installer.run(false, true, proj)
      assert.is_false(success)
      assert.spy(log.error).was_called_with("mani.build.lua has changed since lockfile was generated")
    end)

    it("fails early when lockfile packages is empty", function()
      -- valid hash, but no packages in lockfile
      local fl = io.open("mani.lock.lua", "w")
      fl:write("return { manifest_hash = 'hash123', packages = {} }")
      fl:close()

      lockfile_mock.compute_hash = function() return "hash123" end
      lockfile_mock.read_full_lockfile = function() return {} end

      local success = installer.run(false, true, proj)
      assert.is_false(success)
      assert.spy(log.error).was_called_with("lockfile is empty — run 'mani install' first")
    end)
  end)
end)
