local M = {}

function M.register(parser)
  local cmd = parser:command("self-update", "Update mani to the latest version.")
  cmd:argument("version", "Specific version to install (default: latest)."):args("?")
end

local function parse_tag(tag)
  if not tag then return "" end
  return tag:match("^v(.+)$") or tag
end

local function fetch_latest_release()
  local http = require("mani.lib.http")
  return http.get("https://api.github.com/repos/colourlabs/mani/releases/latest")
end

function M.run(parsed, _project, _api)
  local log = require("mani.core.log")
  local current = require("mani.version")

  log.info("current: " .. current)

  if parsed.version then
    log.info("requested: " .. parsed.version)
    os.execute("luarocks install mani " .. parsed.version)
    return
  end

  log.info("checking GitHub for latest release...")
  local response = fetch_latest_release()
  if not response then
    log.error("failed to check for updates (curl not available or no network)")
    os.exit(1)
    return
  end

  local latest = response:match('"tag_name"%s*:%s*"([^"]+)"')
  if not latest then
    log.error("could not parse GitHub release data")
    os.exit(1)
    return
  end

  latest = parse_tag(latest)
  log.info("latest: " .. latest)

  if latest == current then
    log.ok("mani is already up to date!")
    return
  end

  log.info("installing " .. latest .. "...")
  local ok = os.execute("luarocks install mani")
  if not ok then
    log.error("self-update failed")
    os.exit(1)
    return
  end
  log.ok("updated to " .. latest)
end

return M
