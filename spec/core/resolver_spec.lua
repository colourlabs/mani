describe("Resolver module (mani.core.resolver)", function()
  local resolver
  local lockfile
  local original_popen

  before_each(function()
    package.loaded["mani.core.resolver"] = nil
    package.loaded["mani.core.lockfile"] = nil

    -- create mock lockfile
    lockfile = {
      rocks_dir = function() return "/mock/rocks" end,
      read_rockspec_source = spy.new(function(name, _) return "source-url-for-" .. name end),
      compute_hash = spy.new(function(path) return "hash-for-" .. path end),
      compute_integrity = spy.new(function(name, _) return "integrity-for-" .. name end),
      read_rockspec_deps = spy.new(function(name, _) return { name .. "-dep" } end),
    }
    package.preload["mani.core.lockfile"] = function() return lockfile end

    resolver = require("mani.core.resolver")

    original_popen = io.popen
  end)

  after_each(function()
    io.popen = original_popen
    package.preload["mani.core.lockfile"] = nil
  end)

  it("handles empty or failed luarocks command", function()
    io.popen = function(_, _)
      return nil
    end

    local result = resolver.resolve_installed_packages()
    assert.are.same({}, result)
  end)

  it("parses 4-column and 2-column porcelain lines and returns correct structure", function()
    local mock_lines = {
      "busted 2.2.0-1 installed /mock/rocks",
      "luafilesystem 1.8.0-1",
    }

    io.popen = function(cmd, _)
      assert.is_true(cmd:find("luarocks list --tree=.mani/tree --porcelain", 1, true) ~= nil)
      local i = 0
      return {
        lines = function()
          return function()
            i = i + 1
            return mock_lines[i]
          end
        end,
        close = function() end
      }
    end

    local result = resolver.resolve_installed_packages()

    -- check busted
    assert.is_table(result.busted)
    assert.are.equal("2.2.0-1", result.busted.version)
    assert.are.equal("source-url-for-busted", result.busted.source)
    assert.are.equal("hash-for-/mock/rocks/busted/2.2.0-1/busted-2.2.0-1.rockspec", result.busted.hash)
    assert.are.equal("integrity-for-busted", result.busted.integrity)
    assert.are.same({ "busted-dep" }, result.busted.dependencies)

    -- check luafilesystem
    assert.is_table(result.luafilesystem)
    assert.are.equal("1.8.0-1", result.luafilesystem.version)
    assert.are.equal("source-url-for-luafilesystem", result.luafilesystem.source)
    -- should use fallback rocks_dir (since column 4 is missing)
    local expected_hash = "hash-for-/mock/rocks/luafilesystem/1.8.0-1/luafilesystem-1.8.0-1.rockspec"
    assert.are.equal(expected_hash, result.luafilesystem.hash)
    assert.are.equal("integrity-for-luafilesystem", result.luafilesystem.integrity)
    assert.are.same({ "luafilesystem-dep" }, result.luafilesystem.dependencies)
  end)
end)
