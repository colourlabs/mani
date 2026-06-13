describe("npm_to_luarocks version conversion", function()
  local installer

  before_each(function()
    package.loaded["mani.core.installer"] = nil
    package.loaded["mani.core.log"] = nil
    package.loaded["mani.core.exec"] = nil
    package.loaded["mani.core.lockfile"] = nil
    package.loaded["mani.core.resolver"] = nil

    local quiet = {
      info = function(_) end,
      warn = function(_) end,
      error = function(_) end,
      ok = function(_) end,
    }

    package.preload["mani.core.log"] = function() return quiet end
    package.preload["mani.core.exec"] = function() return {} end
    package.preload["mani.core.lockfile"] = function() return {} end
    package.preload["mani.core.resolver"] = function() return {} end

    installer = require("mani.core.installer")
  end)

  after_each(function()
    package.preload["mani.core.log"] = nil
    package.preload["mani.core.exec"] = nil
    package.preload["mani.core.lockfile"] = nil
    package.preload["mani.core.resolver"] = nil
  end)

  local function npm_to_luarocks(spec)
    return installer._npm_to_luarocks(spec)
  end

  it("converts caret (^) to >= (major)", function()
    assert.are.equal(">= 1.2.3", npm_to_luarocks("^1.2.3"))
    assert.are.equal(">= 0.2.0", npm_to_luarocks("^0.2.0"))
    assert.are.equal(">= 2.0", npm_to_luarocks("^2.0"))
  end)

  it("converts tilde (~) to ~>", function()
    assert.are.equal("~> 2.1.0", npm_to_luarocks("~2.1.0"))
    assert.are.equal("~> 1.0", npm_to_luarocks("~1.0"))
  end)

  it("keeps existing luarocks operators with spacing", function()
    assert.are.equal(">= 3.0.0", npm_to_luarocks(">=3.0.0"))
    assert.are.equal("~> 2.0", npm_to_luarocks("~>2.0"))
    assert.are.equal("< 2.0", npm_to_luarocks("<2.0"))
    assert.are.equal("> 1.0", npm_to_luarocks(">1.0"))
    assert.are.equal("= 1.0", npm_to_luarocks("=1.0"))
    assert.are.equal("<= 2.0", npm_to_luarocks("<=2.0"))
  end)

  it("converts wildcard (1.x) to ~>", function()
    assert.are.equal("~> 1.0", npm_to_luarocks("1.x"))
    assert.are.equal("~> 2.5", npm_to_luarocks("2.5.x"))
  end)

  it("converts bare semver to exact (=)", function()
    assert.are.equal("= 1.2.3", npm_to_luarocks("1.2.3"))
    assert.are.equal("= 2.0", npm_to_luarocks("2.0"))
  end)

  it("returns empty for any/latest", function()
    assert.are.equal("", npm_to_luarocks("*"))
    assert.are.equal("", npm_to_luarocks("latest"))
    assert.are.equal("", npm_to_luarocks(""))
  end)

  it("returns unknown specs as-is", function()
    assert.are.equal("some-weird-format", npm_to_luarocks("some-weird-format"))
  end)
end)