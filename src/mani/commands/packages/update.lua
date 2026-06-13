local M = {}

function M.register(parser)
  local cmd = parser:command("update", "Update dependencies to latest compatible versions.")
  cmd:argument("packages", "Package(s) to update (leave empty to update all)."):args("*")
end

function M.run(parsed, project, _api)
  local installer = require("mani.core.installer")
  local rockspec = require("mani.core.rockspec")
  local log = require("mani.core.log")

  local ok = installer.update(parsed.packages or {}, project)
  if not ok then
    log.error("Failed to update packages.")
    os.exit(1)
  end

  if rockspec.generate(project) then
    log.ok("Packages updated and rockspec regenerated.")
  else
    log.warn("Packages updated but failed to regenerate rockspec.")
  end
end

return M