local M = {}

function M.register(parser)
  local cmd = parser:command("install", "Install project dependencies and write mani.lock.lua.")
  cmd:flag("--production", "Skip dev dependencies.")
  cmd:flag("--frozen-lockfile", "Install from lockfile only; error if mani.build.lua has changed.")
end

function M.run(parsed, project, _api)
  local installer = require("mani.core.installer")
  local rockspec = require("mani.core.rockspec")
  local log = require("mani.core.log")

  local production = parsed.production or false
  local frozen = parsed.frozen_lockfile or false

  local ok = installer.run(production, frozen, project)
  if not ok then
    log.error("Failed to install dependencies.")
    os.exit(1)
  end

  if not frozen then
    if rockspec.generate(project) then
      log.ok("Dependencies installed and rockspec generated.")
    else
      log.warn("Dependencies installed but failed to generate rockspec.")
    end
  end
end

return M