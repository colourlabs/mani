local M = {}

function M.setup(root)
  local lua_ver = _VERSION:match("Lua (%d%.%d)") or "5.4"
  local tree = root .. "/.mani/tree"

  -- only require the base src path; namespaces handle the subfolders
  package.path = root .. "/src/?.lua;"
      .. tree .. "/share/lua/" .. lua_ver .. "/?.lua;"
      .. package.path

  package.cpath = tree .. "/lib/lua/" .. lua_ver .. "/?.so;"
      .. package.cpath
end

function M.load_build_file(api)
  local build_files = { "mani.build.lua", "mani.lua" }

  for _, name in ipairs(build_files) do
    local f = io.open(name, "r")
    if f then
      f:close()
      package.loaded["mani"] = api
      local chunk, err = loadfile(name)
      if not chunk then
        require("mani.core.log").error("failed to load " .. name .. ": " .. (err or ""))
        os.exit(1)
      end
      chunk()
      return
    end
  end

  require("mani.core.log").error("no mani.build.lua found. Run 'mani init' to start.")
  os.exit(1)
end

return M
