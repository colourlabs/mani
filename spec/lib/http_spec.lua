describe("HTTP library (mani.lib.http)", function()
  local http_lib
  local old_popen

  before_each(function()
    package.loaded["mani.lib.http"] = nil
    package.loaded["ssl.https"] = nil
    package.loaded["socket.http"] = nil
    old_popen = io.popen

    -- stub both native modules by default so tests never hit the real network
    package.preload["ssl.https"] = function() return {} end
    package.preload["socket.http"] = function() return {} end

    http_lib = require("mani.lib.http")
  end)

  after_each(function()
    io.popen = old_popen
    package.preload["ssl.https"] = nil
    package.preload["socket.http"] = nil
    package.loaded["ssl.https"] = nil
    package.loaded["socket.http"] = nil
  end)

  it("uses ssl.https when available", function()
    local called_url
    package.preload["ssl.https"] = function()
      return { request = function(url) called_url = url; return "ssl body", 200 end }
    end

    local body = http_lib.get("https://example.com")
    assert.are.equal("ssl body", body)
    assert.are.equal("https://example.com", called_url)
  end)

  it("returns nil from ssl.https on non-200", function()
    package.preload["ssl.https"] = function()
      return { request = function() return "not found", 404 end }
    end

    assert.is_nil(http_lib.get("https://example.com"))
  end)

  it("falls through to socket.http when ssl.https has no request", function()
    local called_url
    package.preload["socket.http"] = function()
      return { request = function(url) called_url = url; return "socket body", 200 end }
    end

    local body = http_lib.get("https://example.com")
    assert.are.equal("socket body", body)
    assert.are.equal("https://example.com", called_url)
  end)

  it("uses socket.http when ssl.https not installed", function()
    package.preload["ssl.https"] = function()
      -- Simulate module that raises error when loaded
      error("module not found")
    end

    local called_url
    package.preload["socket.http"] = function()
      return { request = function(url) called_url = url; return "socket body", 200 end }
    end

    local body = http_lib.get("https://example.com")
    assert.are.equal("socket body", body)
    assert.are.equal("https://example.com", called_url)
  end)

  it("returns nil from socket.http on non-200", function()
    package.preload["socket.http"] = function()
      return { request = function() return "bad request", 400 end }
    end

    assert.is_nil(http_lib.get("https://example.com"))
  end)

  it("falls back to curl when no native modules available", function()
    io.popen = function(cmd)
      assert.are.equal("curl -sL --connect-timeout 10 -w '\\n%{http_code}' https://example.com 2>/dev/null", cmd)
      return { read = function() return "curl body\n200" end, close = function() end }
    end

    local body = http_lib.get("https://example.com")
    assert.are.equal("curl body", body)
  end)

  it("returns nil from curl fallback when io.popen fails", function()
    io.popen = function() return nil end

    assert.is_nil(http_lib.get("https://example.com"))
  end)

  it("returns nil from curl fallback when response is empty", function()
    io.popen = function()
      return { read = function() return "" end, close = function() end }
    end

    assert.is_nil(http_lib.get("https://example.com"))
  end)

  -- Network tests — excluded by default via `make test`; run with `make test-all`
  describe("#network", function()
    before_each(function()
      -- Clear stubs so real native modules are used
      package.loaded["ssl.https"] = nil
      package.loaded["socket.http"] = nil
      package.preload["ssl.https"] = nil
      package.preload["socket.http"] = nil
      -- Reload http module fresh so it re-evaluates pcall results
      -- (actually not needed since pcall is inside M.get(), but
      -- clearing loaded prevents stale module issues)
      package.loaded["mani.lib.http"] = nil
      http_lib = require("mani.lib.http")
    end)

    it("fetches example.com successfully", function()
      local body = http_lib.get("https://example.com")
      assert.is_not_nil(body)
      assert.truthy(body:find("Example Domain"))
    end)

    it("returns nil for a URL that returns 404", function()
      local body = http_lib.get("https://example.com/nonexistent")
      assert.is_nil(body)
    end)

    it("returns nil for unresolvable host", function()
      local body = http_lib.get("https://thishostdoesnotexist.invalid")
      assert.is_nil(body)
    end)
  end)
end)
