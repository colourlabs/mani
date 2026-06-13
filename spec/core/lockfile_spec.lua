describe("Lockfile module (mani.core.lockfile)", function()
  local lockfile
  local log
  local original_open
  local lockfile_backup
  local test_dir = "/tmp/mani_test_lockfile"

  before_each(function()
    package.loaded["mani.core.lockfile"] = nil
    package.loaded["mani.core.log"] = nil

    log = {
      error = spy.new(function() end),
      warn = spy.new(function() end),
      info = spy.new(function() end),
      ok = spy.new(function() end),
    }
    package.preload["mani.core.log"] = function() return log end

    lockfile = require("mani.core.lockfile")

    -- back up existing mani.lock.lua
    local f = io.open("mani.lock.lua", "r")
    if f then
      lockfile_backup = f:read("*a")
      f:close()
      os.remove("mani.lock.lua")
    else
      lockfile_backup = nil
    end

    -- create test directory structure
    os.execute("mkdir -p " .. test_dir)

    -- intercept io.open to redirect .mani/tree to our test directory
    original_open = io.open
    io.open = function(path, mode)
      local target_path = path
      if path:sub(1, 10) == ".mani/tree" then
        target_path = test_dir .. "/tree" .. path:sub(11)
        -- ensure parent directories exist for writing
        if mode and mode:sub(1, 1) == "w" then
          local dir = target_path:match("(.+)/[^/]+$")
          if dir then os.execute("mkdir -p " .. dir) end
        end
      end
      return original_open(target_path, mode)
    end
  end)

  after_each(function()
    -- restore io.open
    io.open = original_open

    -- clean up test directory
    os.execute("rm -rf " .. test_dir)

    -- restore/cleanup mani.lock.lua
    os.remove("mani.lock.lua")
    if lockfile_backup then
      local f = io.open("mani.lock.lua", "w")
      f:write(lockfile_backup)
      f:close()
    end

    package.preload["mani.core.log"] = nil
  end)

  describe("compute_hash", function()
    it("returns stable hash for a file", function()
      local path = test_dir .. "/hash_test.txt"
      local f = io.open(path, "w")
      f:write("hello world")
      f:close()

      local h1 = lockfile.compute_hash(path)
      local h2 = lockfile.compute_hash(path)
      assert.are.equal(h1, h2)
      assert.are.equal("b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9", h1)
    end)

    it("returns empty string if file does not exist", function()
      local hash = lockfile.compute_hash(test_dir .. "/does_not_exist.txt")
      assert.are.equal("", hash)
    end)
  end)

  describe("read_rockspec_source and read_rockspec_deps", function()
    before_each(function()
      -- redirect rocks_dir to use test_dir
      lockfile.rocks_dir = function()
        return test_dir .. "/rocks"
      end

      -- create a mock rockspec
      local rock_path = test_dir .. "/rocks/pkg/1.0"
      os.execute("mkdir -p " .. rock_path)
      local f = io.open(rock_path .. "/pkg-1.0.rockspec", "w")
      f:write([[
        package = "pkg"
        version = "1.0"
        source = {
          url = "git+https://github.com/user/pkg.git"
        }
        dependencies = {
          "lua >= 5.1",
          "busted >= 2.0",
        }
      ]])
      f:close()
    end)

    it("reads source url from rockspec", function()
      local src = lockfile.read_rockspec_source("pkg", "1.0")
      assert.are.equal("git+https://github.com/user/pkg.git", src)
    end)

    it("reads dependencies from rockspec and filters out 'lua'", function()
      local deps = lockfile.read_rockspec_deps("pkg", "1.0")
      assert.are.same({ "busted" }, deps)
    end)
  end)

  describe("write_lockfile, read_full_lockfile and read_existing_lockfile_versions", function()
    it("performs serialization and deserialization round-trip", function()
      local packages = {
        ["foo"] = {
          version = "1.0.0",
          source = "git://foo",
          hash = "123",
          integrity = "456",
          dependencies = { "bar" }
        },
        ["bar"] = {
          version = "2.0.0",
          source = "git://bar",
          hash = "abc",
          integrity = "def",
          dependencies = {}
        }
      }

      local success = lockfile.write_lockfile("manifest-sha", packages)
      assert.is_true(success)

      -- verify integrity check message/ok mock
      assert.spy(log.ok).was_called_with("saved mani.lock.lua")

      local loaded = lockfile.read_full_lockfile()
      assert.are.same(packages, loaded)

      local versions = lockfile.read_existing_lockfile_versions()
      assert.are.same({ foo = "1.0.0", bar = "2.0.0" }, versions)
    end)

    it("returns empty table if lockfile is missing or corrupted", function()
      os.remove("mani.lock.lua")
      local loaded = lockfile.read_full_lockfile()
      assert.are.same({}, loaded)

      -- corrupted file
      local f = io.open("mani.lock.lua", "w")
      f:write("this is not lua code {")
      f:close()

      loaded = lockfile.read_full_lockfile()
      assert.are.same({}, loaded)
    end)
  end)

  describe("compute_integrity and verify_integrity", function()
    local lua_ver

    before_each(function()
      lockfile.rocks_dir = function()
        return test_dir .. "/rocks"
      end
      lua_ver = lockfile.lua_version_str()

      -- create directories for our test packages
      local rock_path = test_dir .. "/rocks/mypkg/1.2"
      os.execute("mkdir -p " .. rock_path)

      -- write rock_manifest
      local f = io.open(rock_path .. "/rock_manifest", "w")
      f:write([[
        rock_manifest = {
          lua = {
            ["mypkg/init.lua"] = "some-old-hash"
          }
        }
      ]])
      f:close()

      -- write the corresponding lua file inside the tree (using the io.open interceptor)
      local tree_file_path = ".mani/tree/share/lua/" .. lua_ver .. "/mypkg/init.lua"
      local tf = io.open(tree_file_path, "w")
      tf:write("print('hello mypkg')")
      tf:close()

      -- also write the rockspec file so compute_hash can read it during verify_integrity
      local rf = io.open(rock_path .. "/mypkg-1.2.rockspec", "w")
      rf:write("test rockspec content")
      rf:close()
    end)

    it("computes integrity from files in rock_manifest", function()
      local integrity = lockfile.compute_integrity("mypkg", "1.2")
      assert.is_string(integrity)
      assert.is_not.equal("", integrity)

      -- modifying the installed file should change the integrity hash
      local tree_file_path = ".mani/tree/share/lua/" .. lua_ver .. "/mypkg/init.lua"
      local tf = io.open(tree_file_path, "w")
      tf:write("print('hello mypkg modified')")
      tf:close()

      local integrity2 = lockfile.compute_integrity("mypkg", "1.2")
      assert.is_not.equal(integrity, integrity2)
    end)

    it("returns empty string when rock_manifest is missing", function()
      local integrity = lockfile.compute_integrity("nonexistent", "0.0")
      assert.are.equal("", integrity)
    end)
  end)

  describe("read_full_lockfile / legacy format", function()
    it("reads current format lockfile correctly", function()
      local packages = { foo = { version = "1.0", dependencies = {} } }
      lockfile.write_lockfile("hash", packages)
      local result = lockfile.read_full_lockfile()
      assert.is_table(result.foo)
      assert.are.equal("1.0", result.foo.version)
    end)

    it("reads legacy format (dependencies table)", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write("return { dependencies = { foo = '1.0', bar = '2.0' } }")
      fl:close()
      local result = lockfile.read_full_lockfile()
      assert.are.equal("1.0", result.foo.version)
      assert.are.equal("2.0", result.bar.version)
      assert.are.same({}, result.foo.dependencies)
    end)

    it("returns empty table when lockfile is missing", function()
      os.remove("mani.lock.lua")
      assert.are.same({}, lockfile.read_full_lockfile())
    end)

    it("returns empty table when lockfile has syntax error", function()
      local fl = io.open("mani.lock.lua", "w")
      fl:write("not valid lua")
      fl:close()
      assert.are.same({}, lockfile.read_full_lockfile())
    end)
  end)

  describe("serialize_lockfile", function()
    it("produces valid Lua that can be loaded back", function()
      local packages = {
        foo = { version = "1.0", source = "git://foo", hash = "abc", integrity = "def", dependencies = {} }
      }
      local serialized = lockfile.serialize_lockfile("manifest123", packages)
      local chunk = load(serialized, "=test", "t", {})
      assert.is_not_nil(chunk)
      local result = chunk()
      assert.is_table(result)
      assert.are.equal("1.0", result.lockfile_version)
      assert.are.equal("manifest123", result.manifest_hash)
      assert.are.equal("1.0", result.packages.foo.version)
    end)

    it("includes dependencies in serialized output", function()
      local packages = {
        bar = {
          version = "2.0",
          source = "",
          hash = "",
          integrity = "",
          dependencies = { "baz", "qux" }
        }
      }
      local serialized = lockfile.serialize_lockfile("h", packages)
      assert.is_true(serialized:find('"baz"', 1, true) ~= nil)
      assert.is_true(serialized:find('"qux"', 1, true) ~= nil)
    end)

    it("sorts packages alphabetically", function()
      local packages = {
        z = { version = "1", dependencies = {} },
        a = { version = "2", dependencies = {} },
        m = { version = "3", dependencies = {} },
      }
      local serialized = lockfile.serialize_lockfile("h", packages)
      local a_pos = serialized:find('["a"]', 1, true)
      local m_pos = serialized:find('["m"]', 1, true)
      local z_pos = serialized:find('["z"]', 1, true)
      assert.is_true(a_pos ~= nil, "['a'] not found")
      assert.is_true(m_pos ~= nil, "['m'] not found")
      assert.is_true(z_pos ~= nil, "['z'] not found")
      assert.is_true(a_pos < m_pos, "'a' should appear before 'm'")
      assert.is_true(m_pos < z_pos, "'m' should appear before 'z'")
    end)

    it("handles packages with no dependencies", function()
      local packages = {
        empty = { version = "1", source = "", hash = "", integrity = "", dependencies = {} }
      }
      local serialized = lockfile.serialize_lockfile("h", packages)
      assert.is_true(serialized:find("dependencies = {}", 1, true) ~= nil)
    end)
  end)

  describe("read_existing_lockfile_versions", function()
    it("returns name-to-version map", function()
      lockfile.write_lockfile("h", {
        foo = { version = "1.0", dependencies = {} },
        bar = { version = "2.0", dependencies = {} },
      })
      local versions = lockfile.read_existing_lockfile_versions()
      assert.are.equal("1.0", versions.foo)
      assert.are.equal("2.0", versions.bar)
    end)

    it("returns empty table when lockfile does not exist", function()
      os.remove("mani.lock.lua")
      assert.are.same({}, lockfile.read_existing_lockfile_versions())
    end)
  end)

  describe("verify_integrity edge cases", function()
    it("passes when locked_tree is empty", function()
      local ok = lockfile.verify_integrity({})
      assert.is_true(ok)
      assert.spy(log.ok).was_called_with("all package integrity checks passed.")
    end)

    it("passes when package has no hash or integrity fields", function()
      local ok = lockfile.verify_integrity({ foo = { version = "1.0" } })
      assert.is_true(ok)
    end)
  end)

  describe("compute_hash edge cases", function()
    it("returns different hashes for different files", function()
      local fa = io.open(test_dir .. "/a.txt", "w")
      fa:write("content a")
      fa:close()
      local fb = io.open(test_dir .. "/b.txt", "w")
      fb:write("content b")
      fb:close()

      local ha = lockfile.compute_hash(test_dir .. "/a.txt")
      local hb = lockfile.compute_hash(test_dir .. "/b.txt")
      assert.is_not.equal(ha, hb)
    end)
  end)

  describe("lua_version_str and rocks_dir", function()
    it("returns a valid Lua version string", function()
      local ver = lockfile.lua_version_str()
      assert.is_string(ver)
      assert.is_true(ver:match("%d+%.%d+") ~= nil)
    end)

    it("rocks_dir includes the version string", function()
      local dir = lockfile.rocks_dir()
      assert.is_true(dir:find("rocks-" .. lockfile.lua_version_str(), 1, true) ~= nil)
    end)
  end)

end)
