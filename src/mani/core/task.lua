local M = {
  tasks = {},
  ran = {},
}

local log = require("mani.core.log")
local project = require("mani.core.project")

function M:register(name, deps, fn)
  self.tasks[name] = {
    name = name,
    deps = deps,
    fn   = fn,
  }
end

function M:run(name, params)
  params = params or {}

  local task = self.tasks[name]
  if not task then
    log.error("unknown task: " .. name)
    os.exit(1)
    return
  end

  if not params.profile_config then
    local profile_name = params.profile or project.active_profile or "dev"
    project:set_profile(profile_name)
    params.profile = profile_name
    params.profile_config = project.profile_config
  end

  local cache_key = name .. ":" .. params.profile
  if self.ran[cache_key] then return end

  self.in_progress = self.in_progress or {}
  if self.in_progress[name] then
    log.error("dependency cycle detected at task: " .. name)
    os.exit(1)
    return
  end
  self.in_progress[name] = true

  for _, dep in ipairs(task.deps) do
    self:run(dep, params)
  end

  self.in_progress[name] = nil

  log.info("running task: " .. name)
  task.fn(params)

  self.ran[cache_key] = true
  log.ok(name)
end

function M:list()
  print("available tasks:")
  for name, task in pairs(self.tasks) do
    local deps = #task.deps > 0
      and " (deps: " .. table.concat(task.deps, ", ") .. ")"
      or  ""
    print("  " .. name .. deps)
  end
end

return M