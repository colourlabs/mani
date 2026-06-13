rockspec_format = "3.0"
package = "mani"
version = "dev-1"

source = {
  url = "git+https://github.com/colourlabs/mani",
}

description = {
  summary = "a modern build tool and LuaRocks wrapper for Lua projects",
  license = "MIT",
  homepage = "https://github.com/colourlabs/mani",
}

dependencies = {
  "lua >= 5.3",
  "argparse >= 0.7.0",
}

test_dependencies = {
  "busted >= 2.3.0",
  "luacheck",
}

build = {
  type = "builtin",
  modules = {
    ["mani.main"]     = "src/mani/main.lua",
    ["mani.loader"]   = "src/mani/loader.lua",
    ["mani.api"]      = "src/mani/api.lua",
    
    -- core
    ["mani.log"]      = "src/mani/core/log.lua",
    ["mani.exec"]     = "src/mani/core/exec.lua",
    ["mani.project"]  = "src/mani/core/project.lua",
    ["mani.task"]     = "src/mani/core/task.lua",

    -- libs
    ["mani.sha256"]   = "src/mani/lib/sha256.lua",
    ["mani.spdx"]     = "src/mani/lib/spdx.lua",
    ["mani.lib.http"] = "src/mani/lib/http.lua",

    -- version
    ["mani.version"]  = "src/mani/version.lua",

    -- commands
    ["mani.commands.self_updater.self_update"] = "src/mani/commands/self_updater/self_update.lua",
  },
  install = {
    bin = { mani = "bin/mani" }
  }
}