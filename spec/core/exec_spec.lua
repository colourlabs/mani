describe("Exec module (mani.core.exec)", function()
  local exec
  local log

  before_each(function()
    package.loaded["mani.core.exec"] = nil
    package.loaded["mani.core.log"] = nil

    log = {
      cmd = spy.new(function() end),
      fail = spy.new(function() end),
    }
    package.preload["mani.core.log"] = function() return log end

    exec = require("mani.core.exec")
  end)

  after_each(function()
    package.preload["mani.core.log"] = nil
  end)

  describe("run", function()
    it("returns true on success", function()
      local success = exec.run("exit 0")
      assert.is_true(success)
      assert.spy(log.cmd).was_called_with("exit 0")
      assert.spy(log.fail).was_not_called()
    end)

    it("returns false on failure", function()
      local success = exec.run("exit 42")
      assert.is_false(success)
      assert.spy(log.cmd).was_called_with("exit 42")
      assert.spy(log.fail).was_called()
    end)
  end)

  describe("silent", function()
    it("returns output on success", function()
      local output, err = exec.silent("echo 'hello world'")
      assert.are.equal("hello world\n", output)
      assert.are.equal("", err)
    end)

    it("returns error output on failure", function()
      local output, err = exec.silent("echo 'something went wrong' && exit 5")
      assert.are.equal("", output)
      assert.are.equal("something went wrong\n", err)
    end)
  end)
end)
