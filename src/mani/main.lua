local root = arg[0]:match("(.+)/src/mani/[^/]+$") or "."
require("mani.loader").setup(root)

local project = require("mani.core.project")
local api = require("mani.api")
local loader = require("mani.loader")
local argparse = require("argparse")

-- map of cli name -> module path under mani.commands.
local command_index = {
  { name = "add", path = "packages.add" },
  { name = "remove", path = "packages.remove" },
  { name = "update", path = "packages.update" },
  { name = "install", path = "packages.install"},
  { name = "run", path = "run.run" },
  { name = "exec", path = "run.exec" },
  { name = "init", path = "project.init" },
  { name = "rockspec", path = "project.rockspec"},
  { name = "lock", path = "lockfile.lock" },
  { name = "self-update", path = "self_updater.self_update" },
}

local commands = {}
for _, entry in ipairs(command_index) do
  commands[entry.name] = require("mani.commands." .. entry.path)
end

local parser = argparse("mani", "A build tool and LuaRocks wrapper for Lua projects.")
parser:command_target("command")
parser:flag("-v --version", "Show version and exit.")

for _, entry in ipairs(command_index) do
  commands[entry.name].register(parser)
end

local parsed = parser:parse(arg)

if parsed.version then
  print(require("mani.version"))
  os.exit(0)
end

local cmd = commands[parsed.command]

if not cmd then
  print(parser:get_help())
  os.exit(0)
end

if parsed.command ~= "init" and parsed.command ~= "self-update" then
  loader.load_build_file(api)
end

cmd.run(parsed, project, api)