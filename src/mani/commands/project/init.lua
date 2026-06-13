local M = {}

function M.register(parser)
  local cmd = parser:command("init", "Initialize a new project with mani.build.lua.")
  cmd:flag("-y --yes", "Skip prompts and use defaults.")
end

local function prompt(msg, default)
  io.stderr:write(msg .. " [" .. default .. "]: ")
  local input = io.read()
  if input == nil or input == "" then
    return default
  end
  return input
end

function M.run(parsed, _project, _api)
  local log = require("mani.core.log")

  local f = io.open("mani.build.lua", "r")
  if f then
    f:close()
    log.warn("mani.build.lua already exists. Skipping init.")
    os.exit(0)
  end

  local name, version, license, homepage, summary

  if parsed.yes then
    name     = "my-project"
    version  = "0.1.0"
    license  = "MIT"
    homepage = "https://github.com/username/my-project"
    summary  = "A modern Lua project"
  else
    log.info("let's set up your project!")

    name     = prompt("Project name", "my-project")
    version  = prompt("Version", "0.1.0")
    license  = prompt("License", "MIT")
    homepage = prompt("Homepage", "https://github.com/username/" .. name)
    summary  = prompt("Summary", "A modern Lua project")
  end

  local template = string.format([[
local mani = require("mani")

mani.project {
  name = %q,
  version = %q,
  license = %q,
  homepage = %q,
  summary = %q,
}

mani.dependencies({
  -- "inspect^3.0",
})

mani.dev_dependencies({
  -- "busted^2.0",
})

mani.task("build", function()
  mani:log("Building...")
end)

mani.task("test", function()
  mani:exec("busted spec/")
end)

mani.task("default", { "build" }, function() end)
]], name, version, license, homepage, summary)

  local f_out = io.open("mani.build.lua", "w")
  if f_out then
    f_out:write(template)
    f_out:close()
    log.ok("Created mani.build.lua")
  end

  os.execute("mkdir -p src")
  local f_src = io.open("src/main.lua", "r")
  if not f_src then
    local fw = io.open("src/main.lua", "w")
    if fw then
      fw:write("print('Hello from " .. name .. "!')\n")
      fw:close()
      log.ok("Created src/main.lua")
    end
  else
    f_src:close()
  end

  os.exit(0)
end

return M