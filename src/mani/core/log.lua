local M = {}

M.verbose = false

local levels = {
  info  = { label = "  info", color = "cyan"   },
  ok    = { label = "    ok", color = "green"  },
  warn  = { label = "  warn", color = "yellow" },
  error = { label = " error", color = "red"    },
  cmd   = { label = "     $", color = "green"  },
  check = { label = "     ✓", color = "green"  },
  fail  = { label = "     ✗", color = "red"    },
}

local function write(level, msg)
  local l = levels[level]
  if not l then return end
  io.stderr:write(M.colorize(l.color, l.label) .. "  " .. msg .. "\n")
end

function M.info(msg) write("info",  msg) end
function M.ok(msg) write("ok",    msg) end
function M.warn(msg) write("warn",  msg) end
function M.error(msg) write("error", msg) end
function M.cmd(msg) write("cmd",   msg) end
function M.check(msg) write("check", msg) end
function M.fail(msg) write("fail",  msg) end

function M.colorize(color, text)
  if not M.is_tty() then return text end
  local codes = {
    red    = "\27[31m",
    green  = "\27[32m",
    yellow = "\27[33m",
    cyan   = "\27[36m",
    reset  = "\27[0m",
  }
  return (codes[color] or "") .. text .. (codes.reset or "")
end

function M.is_tty()
  local ok, system = pcall(require, "system")
  if ok and system.isatty then
    return system.isatty(io.stderr)
  end
  return true
end

return M