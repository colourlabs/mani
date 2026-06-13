local M = {}

function M.get(url)
  local ok, ssl = pcall(require, "ssl.https")
  if ok and type(ssl) == "table" and ssl.request then
    local body, code = ssl.request(url)
    if code == 200 then return body end
    return nil
  end

  local ok2, http = pcall(require, "socket.http")
  if ok2 and type(http) == "table" and http.request then
    http.TIMEOUT = 15
    local body, code = http.request(url)
    if code == 200 then return body end
    return nil
  end

  local handle = io.popen("curl -sL --connect-timeout 10 -w '\\n%{http_code}' " .. url .. " 2>/dev/null")
  if not handle then return nil end
  local output = handle:read("*a")
  handle:close()
  local body, code = output:match("^(.*)\n(%d+)$")
  if code and tonumber(code) == 200 then
    return body
  end
  return nil
end

return M
