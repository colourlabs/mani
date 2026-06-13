local M = {}

local log = require("mani.core.log")

local function with_tree_path(cmd)
  return "PATH=\"$PWD/.mani/tree/bin:$PATH\" " .. cmd
end

function M.run(cmd)
  log.cmd(cmd)

  local full_cmd = with_tree_path(cmd)

  local res, _, code = os.execute(full_cmd)

  -- cross-version Lua check for os.execute behavior
  --   Lua 5.2+ returns: true/nil, string ("exit"/"signal"), error_code
  --   Lua 5.1 returns: a raw exit status number (0 = success)
  local success = false
  local exit_code = 1

  if type(res) == "boolean" then
    success = res
    exit_code = code or 1
  elseif type(res) == "number" then
    success = (res == 0)
    exit_code = res
  end

  if not success then
    log.fail("command failed with exit code " .. exit_code)
    return false
  end

  return true
end

function M.silent(cmd)
  local handle = io.popen(with_tree_path(cmd) .. " 2>&1")
  if not handle then
    return "", "failed to open process"
  end
  local output = handle:read("*a")
  local ok = handle:close()
  local failed
  if type(ok) == "number" then
    failed = ok ~= 0
  else
    failed = not ok
  end
  if failed then
    return "", output
  end
  return output, ""
end

return M
