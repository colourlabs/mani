local M = {}

local exec = require("mani.core.exec")
local log = require("mani.core.log")
local lockfile = require("mani.core.lockfile")
local resolver = require("mani.core.resolver")

local function trim(s)
  return (s:match("^%s*(.-)%s*$"))
end

local function luarocks_env()
  return "PATH=\"$PWD/.mani/tree/bin:$PATH\" "
end

local function luarocks_cmd(args)
  return luarocks_env() .. "luarocks " .. args
end

local function dep_name(dep)
  local name = dep:match("^([^%^%s%@%><%=~]+)")
  return trim(name or "")
end

local function find_package_in_list(deps, name)
  for i, dep in ipairs(deps) do
    if dep_name(dep) == name then return i end
  end
  return 0
end

-- topological sort with cycle detection
local function topological_sort(packages)
  local visited = {}
  local in_progress = {}
  local result = {}

  local function visit(name)
    if visited[name] then return end
    if in_progress[name] then
      log.warn("dependency cycle detected at: " .. name .. " (installing anyway)")
      return
    end
    in_progress[name] = true
    if packages[name] and packages[name].dependencies then
      for _, dep in ipairs(packages[name].dependencies) do
        if packages[dep] then visit(dep) end
      end
    end
    in_progress[name] = false
    visited[name]     = true
    table.insert(result, name)
  end

  local names = {}
  for name in pairs(packages) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do visit(name) end

  return result
end

local function install_locked_tree(locked_tree)
  local order = topological_sort(locked_tree)
  log.info("Installing " .. #order .. " packages from lockfile...")
  for _, name in ipairs(order) do
    local info = locked_tree[name]
    if not info then
      log.warn("skipping unknown lockfile entry: " .. name)
    else
      local ver = info.version or ""
      if ver ~= "" then
        log.info("  " .. name .. " " .. ver .. " (locked)")
        local cmd = luarocks_cmd("install --tree=.mani/tree '" .. name .. "' '" .. ver .. "'")
        if not exec.run(cmd) then
          log.error("failed to install locked package: " .. name)
          return false
        end
      end
    end
  end
  return true
end

local function install_deps(deps, use_locked)
  local locked_versions = use_locked and lockfile.read_existing_lockfile_versions() or {}

  for _, dep in ipairs(deps) do
    local name           = dep_name(dep)
    local raw_constraint = dep:match("^[^%^]+%^(.+)$") or dep:match("^%S+%s+(.+)$") or ""
    raw_constraint       = trim(raw_constraint):gsub("^@", "")

    local version_to_install = ""
    if raw_constraint:match("^%^") then
      version_to_install = ">= " .. raw_constraint:match("^%^(.+)$")
    elseif raw_constraint:match("^[><%=~]") then
      version_to_install = raw_constraint
    elseif raw_constraint ~= "" then
      version_to_install = "= " .. raw_constraint
    end

    if use_locked and locked_versions[name] then
      version_to_install = locked_versions[name]
    end

    local ver_str = version_to_install ~= "" and version_to_install or "any version"
    log.info("installing " .. name .. " (" .. ver_str .. ")...")

    local cmd = luarocks_cmd("install --tree=.mani/tree '" .. name .. "'")
    if version_to_install ~= "" then
      cmd = cmd .. " '" .. version_to_install .. "'"
    end

    if not exec.run(cmd) then
      log.error("failed to install dependency: " .. name)
      return false
    end
  end
  return true
end

local function install_and_lock(deps, use_locked, frozen)
  if not deps or #deps == 0 then
    log.info("no dependencies to install.")
    return true
  end

  local manifest_hash = lockfile.compute_hash("mani.build.lua")

  if frozen then
    if not use_locked then
      log.error("--frozen-lockfile requires an existing lockfile (run 'mani install' first)")
      return false
    end

    local lock_chunk = loadfile("mani.lock.lua")
    if not lock_chunk then
      log.error("--frozen-lockfile: could not load mani.lock.lua")
      return false
    end
    local ok, lock_data = pcall(lock_chunk)
    if not ok or type(lock_data) ~= "table" then
      log.error("--frozen-lockfile: invalid mani.lock.lua")
      return false
    end
    if (lock_data.manifest_hash or "") ~= manifest_hash then
      log.error("mani.build.lua has changed since lockfile was generated")
      log.error("  run 'mani install' (without --frozen-lockfile) to update")
      return false
    end

    local locked_tree = lockfile.read_full_lockfile()
    if not locked_tree or not next(locked_tree) then
      log.error("lockfile is empty — run 'mani install' first")
      return false
    end

    if not install_locked_tree(locked_tree) then return false end
    if not lockfile.verify_integrity(locked_tree) then return false end
    log.ok("frozen install complete. lockfile unchanged.")
    return true
  end

  -- normal install
  if use_locked then
    local locked_tree = lockfile.read_full_lockfile()
    if locked_tree and next(locked_tree) then
      if not install_locked_tree(locked_tree) then return false end
    else
      if not install_deps(deps, true) then return false end
    end
  else
    if not install_deps(deps, false) then return false end
  end

  local installed = resolver.resolve_installed_packages()
  if not installed or not next(installed) then
    log.warn("no installed packages found in tree.")
  end

  return lockfile.write_lockfile(manifest_hash, installed)
end

-- public API — all functions take project as a parameter

function M.run(production, frozen, project)
  local deps = {}
  for _, d in ipairs(project.dependencies)     do table.insert(deps, d) end
  if not production then
    for _, d in ipairs(project.dev_dependencies) do table.insert(deps, d) end
  end
  return install_and_lock(deps, true, frozen)
end

function M.update(packages, project)
  local deps = project.dependencies
  if not deps or #deps == 0 then
    log.info("no dependencies in project.")
    return true
  end

  local to_install = {}
  if #packages == 0 then
    to_install = deps
  else
    local pkg_set = {}
    for _, p in ipairs(packages) do pkg_set[p] = true end
    for _, dep in ipairs(deps) do
      local name = dep_name(dep)
      if name ~= "" and pkg_set[name] then
        table.insert(to_install, dep)
      end
    end
  end

  return install_and_lock(to_install, false, false)
end

function M.check_lockfile()
  local f = io.open("mani.lock.lua", "r")
  if not f then
    log.error("mani.lock.lua not found")
    return false
  end
  f:close()

  local chunk, load_err = loadfile("mani.lock.lua")
  if not chunk then
    log.error("mani.lock.lua: syntax error — " .. (load_err or "unknown"))
    return false
  end

  local ok, data = pcall(chunk)
  if not ok or type(data) ~= "table" then
    log.error("mani.lock.lua: runtime error or invalid format")
    return false
  end

  if not data.lockfile_version or not data.manifest_hash or type(data.packages) ~= "table" then
    log.error("mani.lock.lua: missing required fields")
    return false
  end

  if data.lockfile_version ~= "1.0" then
    log.warn("mani.lock.lua: unknown lockfile_version \"" .. tostring(data.lockfile_version) .. "\"")
  end

  local current_hash = lockfile.compute_hash("mani.build.lua")
  if data.manifest_hash ~= current_hash then
    log.warn("mani.build.lua has changed since lockfile was generated")
  else
    log.ok("manifest hash matches mani.build.lua")
  end

  return lockfile.verify_integrity(data.packages)
end

function M.regen_lockfile()
  local installed = resolver.resolve_installed_packages()
  if not installed or not next(installed) then
    log.warn("no installed packages found in .mani/tree")
    return false
  end
  local manifest_hash = lockfile.compute_hash("mani.build.lua")
  return lockfile.write_lockfile(manifest_hash, installed)
end

-- npm-style version spec -> luarocks constraint
local function npm_to_luarocks(spec)
  spec = trim(spec)
  if spec == "" or spec == "*" or spec == "latest" then return "" end

  local caret = spec:match("^%^(%d+%.%d+%.?%d*)")
  if caret then return ">= " .. caret end

  local tilde = spec:match("^~(%d+%.%d+%.?%d*)")
  if tilde then return "~> " .. tilde end

  if spec:match("^[><=~]") then
    local op  = spec:match("^([><=~]+)%s*")
    local ver = spec:match("^[><=~]+%s*(.*)$")
    if op and ver then return op .. " " .. trim(ver) end
    return spec
  end

  if spec:match("^(%d+)%.x$") then
    return "~> " .. spec:match("^(%d+)") .. ".0"
  end
  if spec:match("^(%d+%.%d+)%.x$") then
    return "~> " .. spec:match("^(%d+%.%d+)")
  end

  if spec:match("^%d+%.%d+%.%d+$") or spec:match("^%d+%.%d+$") then
    return "= " .. spec
  end
  return spec
end

-- * exposed for unit testing only!
M._npm_to_luarocks = npm_to_luarocks

local function block_insert_pos(content, keyword_pat)
  local _, match_end = content:find(keyword_pat)
  if not match_end then return 0 end
  local brace_pos = content:find("{", match_end + 1)
  if not brace_pos then return 0 end

  local depth = 1
  local pos   = brace_pos + 1
  while depth > 0 and pos <= #content do
    local c = content:sub(pos, pos)
    if     c == "{" then depth = depth + 1
    elseif c == "}" then depth = depth - 1 end
    pos = pos + 1
  end
  return depth == 0 and (pos - 1) or 0
end

local function find_block_range(content, keyword_pat)
  local start, match_end = content:find(keyword_pat)
  if not start then return 0, 0 end
  local brace_pos = content:find("{", match_end + 1)
  if not brace_pos then return 0, 0 end

  local depth = 1
  local pos   = brace_pos + 1
  while depth > 0 and pos <= #content do
    local c = content:sub(pos, pos)
    if     c == "{" then depth = depth + 1
    elseif c == "}" then depth = depth - 1 end
    pos = pos + 1
  end
  if depth ~= 0 then return 0, 0 end
  return start, pos - 1
end

local function remove_from_block(content, keyword_pat, pkg_name)
  local block_start, block_end = find_block_range(content, keyword_pat)
  if block_start == 0 then return content end

  local block   = content:sub(block_start, block_end)
  local escaped = pkg_name:gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
  local pattern = '%s*"' .. escaped .. '[^"]*",%s*\n?'

  local new_block, n = block:gsub(pattern, "", 1)
  if n == 0 then return content end
  return content:sub(1, block_start - 1) .. new_block .. content:sub(block_end + 1)
end

local function write_build_lua_dep(dep_line, dev)
  local f = io.open("mani.build.lua", "r")
  if not f then
    log.error("mani.build.lua not found")
    return false
  end
  local content = f:read("*a")
  f:close()

  local insert_pos
  if dev then
    insert_pos = block_insert_pos(content, "mani%.dev_dependencies")
    if insert_pos == 0 then
      insert_pos = block_insert_pos(content, "dev_dependencies%s*=")
    end
  else
    insert_pos = block_insert_pos(content, "mani%.dependencies")
    if insert_pos == 0 then
      insert_pos = block_insert_pos(content, "dependencies%s*=")
    end
  end

  if insert_pos == 0 then
    log.error("could not find target block in mani.build.lua")
    return false
  end

  local new_content = content:sub(1, insert_pos - 1)
                   .. '  "' .. dep_line .. '",\n'
                   .. content:sub(insert_pos)

  local fw = io.open("mani.build.lua", "w")
  if not fw then
    log.error("could not write mani.build.lua")
    return false
  end
  fw:write(new_content)
  fw:close()
  return true
end

function M.remove_package(name, project)
  name = trim(name)
  if name == "" then
    log.error("package name is required.")
    return false
  end

  local in_deps = find_package_in_list(project.dependencies, name) > 0
  local in_dev  = find_package_in_list(project.dev_dependencies, name) > 0

  if not in_deps and not in_dev then
    log.error("package '" .. name .. "' not found in dependencies or dev_dependencies.")
    return false
  end

  local f = io.open("mani.build.lua", "r")
  if not f then
    log.error("mani.build.lua not found")
    return false
  end
  local content = f:read("*a")
  f:close()

  if in_deps then
    content = remove_from_block(content, "mani%.dependencies", name)
    content = remove_from_block(content, "dependencies%s*=", name)
  end
  if in_dev then
    content = remove_from_block(content, "mani%.dev_dependencies", name)
    content = remove_from_block(content, "dev_dependencies%s*=", name)
  end

  local fw = io.open("mani.build.lua", "w")
  if not fw then
    log.error("could not write mani.build.lua")
    return false
  end
  fw:write(content)
  fw:close()

  -- update in-memory state
  if in_deps then
    local idx = find_package_in_list(project.dependencies, name)
    if idx > 0 then table.remove(project.dependencies, idx) end
  end
  if in_dev then
    local idx = find_package_in_list(project.dev_dependencies, name)
    if idx > 0 then table.remove(project.dev_dependencies, idx) end
  end

  log.info("removing " .. name .. " from tree...")
  if not exec.run(luarocks_cmd("remove --tree=.mani/tree '" .. name .. "'")) then
    log.warn("luarocks remove failed for " .. name .. " (may already be absent)")
  end

  local installed = resolver.resolve_installed_packages()
  if installed and next(installed) then
    lockfile.write_lockfile(lockfile.compute_hash("mani.build.lua"), installed)
  else
    os.execute("rm -f mani.lock.lua")
  end

  log.ok("removed " .. name .. " from project.")
  return true
end

function M.add_package(npm_spec, dev, project)
  local add_name, version_spec = npm_spec:match("^([^@]+)@?(.*)$")
  if add_name then add_name = trim(add_name) end
  if version_spec then version_spec = trim(version_spec) end

  if not add_name or add_name == "" then
    log.error("invalid package spec: " .. npm_spec)
    return false
  end

  local target_list = dev and project.dev_dependencies or project.dependencies
  local other_list = dev and project.dependencies or project.dev_dependencies

  if find_package_in_list(target_list, add_name) > 0 then
    local list_name = dev and "dev_dependencies" or "dependencies"
    log.error("package '" .. add_name .. "' is already in " .. list_name .. ".")
    return false
  end

  if find_package_in_list(other_list, add_name) > 0 then
    local other_name = dev and "dependencies" or "dev_dependencies"
    log.warn("package '" .. add_name .. "' already exists in " .. other_name .. ".")
  end

  if version_spec == "" then
    -- install latest, then pin to resolved version
    if not install_and_lock({ add_name }, false, false) then return false end

    local installed = resolver.resolve_installed_packages()
    local pkg = installed[add_name]
    if not pkg then
      log.error("failed to resolve installed version for " .. add_name)
      return false
    end

    local dep_line = add_name .. "^" .. pkg.version
    if not write_build_lua_dep(dep_line, dev) then return false end
    table.insert(target_list, dep_line)

    local list_name = dev and "dev_dependencies" or "dependencies"
    log.ok("added " .. dep_line .. " to " .. list_name)

    lockfile.write_lockfile(
      lockfile.compute_hash("mani.build.lua"),
      resolver.resolve_installed_packages()
    )
    return true
  end

  -- version specified
  local v = version_spec:match("^%^(.+)$") or version_spec
  local dep_line = add_name .. "^" .. v

  if not write_build_lua_dep(dep_line, dev) then return false end
  table.insert(target_list, dep_line)

  local list_name = dev and "dev_dependencies" or "dependencies"
  log.ok("added " .. dep_line .. " to " .. list_name)

  local constraint = npm_to_luarocks(version_spec)
  local install_line = constraint ~= "" and (add_name .. " " .. constraint) or add_name

  return install_and_lock({ install_line }, false, false)
end

M._trim = trim
M._dep_name = dep_name
M._topological_sort = topological_sort
M._block_insert_pos = block_insert_pos
M._find_block_range = find_block_range
M._remove_from_block = remove_from_block
M._write_build_lua_dep = write_build_lua_dep
M._find_package_in_list = find_package_in_list

return M