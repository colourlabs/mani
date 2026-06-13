local M = {}

function M.register(parser)
  parser:command("rockspec", "Regenerate the .rockspec file from project metadata.")
end

function M.run(_, _, _api)
  local rockspec = require("mani.core.rockspec")
  local log = require("mani.core.log")

  if rockspec.generate() then
    log.ok("Regenerated rockspec from project metadata.")
    os.exit(0)
  else
    log.error("Failed to generate rockspec.")
    os.exit(1)
  end
end

return M