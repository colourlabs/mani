local M = {}

function M.register(parser)
  local cmd = parser:command("remove", "Remove a dependency from the project.")
  cmd:argument("package", "Package name to remove.")
end

function M.run(parsed, project, _api)
  local installer = require("mani.core.installer")
  local rockspec = require("mani.core.rockspec")
  local log = require("mani.core.log")

  local ok = installer.remove_package(parsed.package, project)
  if not ok then
    os.exit(1)
  end

  if rockspec.generate(project) then
    log.ok("Package removed and rockspec regenerated.")
  else
    log.warn("Package removed but failed to regenerate rockspec.")
  end
end

return M