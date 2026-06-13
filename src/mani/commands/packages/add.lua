local M = {}

function M.register(parser)
  local cmd = parser:command("add", "Add a package and install it.")
  cmd:argument("package", "Package name with optional version (e.g. inspect or inspect@3.0).")
  cmd:flag("-D --save-dev", "Add to dev_dependencies instead of dependencies.")
end

function M.run(parsed, project, _api)
  local installer = require("mani.core.installer")
  local rockspec = require("mani.core.rockspec")
  local log = require("mani.core.log")

  local pkg = parsed.package
  if not pkg or pkg == "" then
    log.error("Usage: mani add <package>[@<version>]")
    os.exit(1)
  end

  local ok = installer.add_package(pkg, parsed.save_dev, project)
  if not ok then
    log.error("Failed to add package.")
    os.exit(1)
  end

  if rockspec.generate() then
    log.ok("Package added and rockspec regenerated.")
  else
    log.warn("Package added but failed to regenerate rockspec.")
  end
end

return M