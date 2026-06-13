-- public API for mani

local M = {}

local runner = require("mani.core.task")
local exec = require("mani.core.exec")
local log = require("mani.core.log")
local project = require("mani.core.project")

M.env = setmetatable({}, {
  __index = function(_, key)
    return os.getenv(key)
  end
})

function M.project(meta)
  project:define_project(meta)
end

function M.dependencies(deps)
  project:define_dependencies(deps)
end

function M.dev_dependencies(deps)
  project:define_dev_dependencies(deps)
end

function M.task(name, deps_or_fn, fn)
  local t = type(deps_or_fn)

  if t == "function" then
    -- task("name", function(params) ... end)
    runner:register(name, {}, deps_or_fn)

  elseif t == "table" and type(fn) == "function" then
    -- task("name", {"dep1", "dep2"}, function(params) ... end)
    runner:register(name, deps_or_fn, fn)

  elseif t == "table" and not fn then
    -- task("name", {"dep1", "dep2"}) -> Empty wrapper task
    runner:register(name, deps_or_fn, function() end)

  else
    log.error("invalid arguments passed to task '" .. tostring(name) .. "'")
    os.exit(1)
  end
end

function M.run(_, name, params)
  params = params or {}
  runner:run(name, params)
end

function M.exec(_, cmd)
  local ok = exec.run(cmd)
  if not ok then
    log.error("command failed: " .. cmd)
    os.exit(1)
  end
end

function M.log(_, msg) log.info(msg) end
function M.warn(_, msg) log.warn(msg) end

function M.error(_, msg)
  log.error(msg)
  os.exit(1)
end

return M
