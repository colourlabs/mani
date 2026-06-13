local M = {}

local lockfile = require("mani.core.lockfile")

-- scans the .mani/tree system and constructs the current state metadata map
function M.resolve_installed_packages()
  local result = {}
  local handle = io.popen("luarocks list --tree=.mani/tree --porcelain 2>/dev/null")
  if not handle then
    return result
  end

  for line in handle:lines() do
    -- LuaRocks porcelain format: package_name version status deployment_dir
    local name, version, _, rock_dir = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
    if not name or not version then
      name, version = line:match("^(%S+)%s+(%S+)")
    end

    if name and version then
      local base_dir = rock_dir or lockfile.rocks_dir()
      local rockspec_path = base_dir .. "/" .. name .. "/" .. version .. "/" .. name .. "-" .. version .. ".rockspec"

      result[name] = {
        version = version,
        source = lockfile.read_rockspec_source(name, version),
        hash = lockfile.compute_hash(rockspec_path),
        integrity = lockfile.compute_integrity(name, version),
        dependencies = lockfile.read_rockspec_deps(name, version),
      }
    end
  end

  handle:close()
  return result
end

return M