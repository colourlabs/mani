local M = {}

function M.register(parser)
  local cmd = parser:command("run", "Run a task defined in mani.build.lua.")
  cmd:argument("task", "Name of the task to run."):args("?")
  cmd:option("--profile", "Profile to use (dev, prod, ...)."):default("dev")
  cmd:argument("task_args", "Extra arguments passed to the task."):args("*")
end

function M.run(parsed, project, _api)
  local task = require("mani.core.task")
  local log = require("mani.core.log")

  local task_name = parsed.task or "default"
  local profile = parsed.profile or "dev"

  -- validate profile if any are defined
  if project.metadata and project.metadata.profiles then
    local profiles = project.metadata.profiles
    if next(profiles) ~= nil and not profiles[profile] then
      local available = {}
      for k in pairs(profiles) do
        table.insert(available, k)
      end
      table.sort(available)
      log.error("Unknown profile '" .. profile .. "'.")
      log.error("Available: " .. table.concat(available, ", "))
      os.exit(1)
    end
  end

  project:set_profile(profile)

  local params = {
    profile = profile,
    profile_config = project.profile_config,
    args = parsed.task_args or {},
  }

  log.info("running task: " .. task_name)

  local ok, err = pcall(function()
    task:run(task_name, params)
  end)

  if not ok then
    log.error("task '" .. task_name .. "' failed: " .. tostring(err))
    os.exit(1)
  end
end

return M