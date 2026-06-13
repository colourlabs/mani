local M = {}

function M.register(parser)
  local cmd = parser:command("exec", "Run a shell command with the project tree on PATH.")
  cmd:argument("cmd", "Command to run."):args("+")
end

function M.run(parsed, _project, _api)
  local exec = require("mani.core.exec")
  local log = require("mani.core.log")

  local cmd = table.concat(parsed.cmd, " ")
  local ok = exec.run(cmd)

  if not ok then
    log.error("command failed: " .. cmd)
    os.exit(1)
  end
end

return M