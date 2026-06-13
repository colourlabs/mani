local M = {
  dependencies = {},
  dev_dependencies = {},
  active_profile = "dev",
  profile_config = {},
}

local log = require("mani.core.log")
local VALID_LICENSES = require("mani.lib.spdx")

local function default_lua_versions()
  local ver = _VERSION:match("Lua (%d%.%d)") or "5.4"
  return { ver }
end

local function parse_deps(deps)
  local list = {}
  if deps[1] ~= nil then
    for _, dep in ipairs(deps) do
      table.insert(list, dep)
    end
  else
    for name, ver in pairs(deps) do
      table.insert(list, name .. " " .. ver)
    end
  end
  return list
end

function M:define_project(meta)
  if not meta.name or meta.name == "" then
    log.error("project name is required")
    os.exit(1)
  end
  if not meta.version or meta.version == "" then
    log.error("project version is required")
    os.exit(1)
  end

  local license = meta.license or ""
  if license ~= "" and not VALID_LICENSES[license] then
    log.warn("'" .. license .. "' is not a recognised SPDX identifier — see https://spdx.org/licenses/")
  end

  if not meta.bin then
    meta.bin = {}
  end
  if not meta.lua_versions or #meta.lua_versions == 0 then
    meta.lua_versions = default_lua_versions()
  end
  if not meta.profiles then
    meta.profiles = {}
  end

  self.metadata = meta
end

function M:set_profile(name)
  local profiles = self.metadata and self.metadata.profiles
  if profiles and next(profiles) ~= nil and not profiles[name] then
    local available = {}
    for k in pairs(profiles) do
      table.insert(available, k)
    end
    table.sort(available)
    log.error("unknown profile '" .. name .. "'. available: " .. table.concat(available, ", "))
    os.exit(1)
  end
  self.active_profile = name
  self.profile_config = (profiles and profiles[name]) or {}
end

function M:define_dependencies(deps)
  self.dependencies = parse_deps(deps)
end

function M:define_dev_dependencies(deps)
  self.dev_dependencies = parse_deps(deps)
end

function M:reset()
  self.metadata = nil
  self.dependencies = {}
  self.dev_dependencies = {}
  self.active_profile = "dev"
  self.profile_config = {}
end

return M