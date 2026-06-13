describe("self-update command (mani.commands.self_updater.self_update)", function()
  local cmd
  local log
  local old_exit
  local old_execute
  local old_popen

  before_each(function()
    package.loaded["mani.commands.self_updater.self_update"] = nil
    package.loaded["mani.core.log"] = nil
    package.loaded["mani.version"] = nil
    package.loaded["mani.lib.http"] = nil
    package.loaded["socket.http"] = nil
    package.loaded["ssl.https"] = nil

    package.preload["socket.http"] = function() return {} end
    package.preload["ssl.https"] = function() return {} end

    log = {
      error = spy.new(function() end),
      warn = spy.new(function() end),
      info = spy.new(function() end),
      ok = spy.new(function() end),
    }
    package.preload["mani.core.log"] = function() return log end
    package.preload["mani.version"] = function() return "0.1.0" end

    cmd = require("mani.commands.self_updater.self_update")
    old_exit = os.exit
    old_execute = os.execute
    old_popen = io.popen
    os.exit = spy.new(function() end)
  end)

  after_each(function()
    os.exit = old_exit
    os.execute = old_execute
    io.popen = old_popen
    package.preload["mani.commands.self_updater.self_update"] = nil
    package.preload["mani.core.log"] = nil
    package.preload["mani.version"] = nil
    package.preload["mani.lib.http"] = nil
    package.preload["socket.http"] = nil
    package.preload["ssl.https"] = nil
  end)

  local function make_handle(body)
    return {
      read = function() return body end,
      close = function() end,
    }
  end

  it("registers parser with command and optional argument", function()
    local called_name, called_desc
    local arg_called_with
    local cmd_obj = {}
    cmd_obj.argument = function(_, name, desc)
      arg_called_with = { name = name, desc = desc }
      return cmd_obj
    end
    cmd_obj.args = function(_) return cmd_obj end
    local parser = {
      command = function(_, name, desc)
        called_name = name
        called_desc = desc
        return cmd_obj
      end,
    }
    cmd.register(parser)
    assert.are.equal("self-update", called_name)
    assert.are.equal("Update mani to the latest version.", called_desc)
    assert.are.equal("version", arg_called_with.name)
    assert.are.equal("Specific version to install (default: latest).", arg_called_with.desc)
  end)

  it("reports up-to-date when current matches latest", function()
    io.popen = function()
      return make_handle('{"tag_name": "v0.1.0"}')
    end

    cmd.run({ version = nil }, {}, nil)
    assert.spy(log.ok).was_called_with("mani is already up to date!")
    assert.spy(os.exit).was_not_called()
  end)

  it("errors and exits when curl fails", function()
    io.popen = function() return nil end

    cmd.run({ version = nil }, {}, nil)
    assert.spy(log.error).was_called_with("failed to check for updates (curl not available or no network)")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("errors and exits on unparseable GitHub response", function()
    io.popen = function()
      return make_handle("not valid json")
    end

    cmd.run({ version = nil }, {}, nil)
    assert.spy(log.error).was_called_with("could not parse GitHub release data")
    assert.spy(os.exit).was_called_with(1)
  end)

  it("installs newer version via luarocks", function()
    io.popen = function()
      return make_handle('{"tag_name": "v0.2.0"}')
    end
    os.execute = spy.new(function() return true end)

    cmd.run({ version = nil }, {}, nil)
    assert.spy(log.info).was_called_with("installing 0.2.0...")
    assert.spy(os.execute).was_called_with("luarocks install mani")
    assert.spy(log.ok).was_called()
    assert.spy(os.exit).was_not_called()
  end)

  it("installs specified version when argument is given", function()
    os.execute = spy.new(function() return true end)

    cmd.run({ version = "0.2.0" }, {}, nil)
    assert.spy(os.execute).was_called_with("luarocks install mani 0.2.0")
  end)

  it("handles tags without v prefix", function()
    io.popen = function()
      return make_handle('{"tag_name": "0.2.0"}')
    end
    os.execute = spy.new(function() return true end)

    cmd.run({ version = nil }, {}, nil)
    assert.spy(log.info).was_called_with("installing 0.2.0...")
  end)
end)
