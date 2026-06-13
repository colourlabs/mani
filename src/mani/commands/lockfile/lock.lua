local M = {}

function M.register(parser)
  local cmd = parser:command("lock", "Manage mani.lock.lua.")
  cmd:flag("--check", "Verify the lockfile is valid and matches mani.build.lua.")
  cmd:flag("--regen", "Regenerate the lockfile from currently installed packages.")
end

function M.run(parsed, _project, _api)
  local installer = require("mani.core.installer")
  local log = require("mani.core.log")

  local did_something = false

  if parsed.check then
    did_something = true
    if not installer.check_lockfile() then
      os.exit(1)
    end
  end

  if parsed.regen then
    did_something = true
    if not installer.regen_lockfile() then
      os.exit(1)
    end
  end

  if not did_something then
    log.error("Usage: mani lock --check | --regen")
    os.exit(1)
  end
end

return M