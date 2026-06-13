-- lua implemenation of the SHA256 algo

local k = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local MASK = 0xFFFFFFFF

local function rrotate(x, n)
  x = x & MASK
  return ((x >> n) | (x << (32 - n))) & MASK
end

local function str2hexa(s)
  return (s:gsub(".", function(c)
    return string.format("%02x", c:byte())
  end))
end

local function num2s(l, n)
  local s = ""
  for _ = 1, n do
    s = string.char(l % 256) .. s
    l = l >> 8
  end
  return s
end

local function s232num(s, i)
  local n = 0
  for j = i, i + 3 do
    n = (n << 8) | s:byte(j)
  end
  return n
end

local function preproc(msg, len)
  local extra = 64 - ((len + 1 + 8) % 64)
  local lenbits = num2s(8 * len, 8)
  msg = msg .. "\128" .. string.rep("\0", extra) .. lenbits
  assert(#msg % 64 == 0)
  return msg
end

local function digestblock(msg, i, H)
  local w = {}
  for j = 1, 16 do
    w[j] = s232num(msg, i + (j - 1) * 4)
  end

  for j = 17, 64 do
    local v = w[j - 15]
    local s0 = rrotate(v, 7) ~ rrotate(v, 18) ~ (v >> 3)
    v = w[j - 2]
    local s1 = rrotate(v, 17) ~ rrotate(v, 19) ~ (v >> 10)
    w[j] = (w[j - 16] + s0 + w[j - 7] + s1) & MASK
  end

  local a, b, c, d, e, f, g, h =
      H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

  for i2 = 1, 64 do
    local s0 = rrotate(a, 2) ~ rrotate(a, 13) ~ rrotate(a, 22)
    local maj = (a & b) ~ (a & c) ~ (b & c)
    local t2 = (s0 + maj) & MASK
    local s1 = rrotate(e, 6) ~ rrotate(e, 11) ~ rrotate(e, 25)
    local ch = (e & f) ~ ((~e & MASK) & g)
    local t1 = (h + s1 + ch + k[i2] + w[i2]) & MASK

    h = g
    g = f
    f = e
    e = (d + t1) & MASK
    d = c
    c = b
    b = a
    a = (t1 + t2) & MASK
  end

  H[1] = (H[1] + a) & MASK
  H[2] = (H[2] + b) & MASK
  H[3] = (H[3] + c) & MASK
  H[4] = (H[4] + d) & MASK
  H[5] = (H[5] + e) & MASK
  H[6] = (H[6] + f) & MASK
  H[7] = (H[7] + g) & MASK
  H[8] = (H[8] + h) & MASK
end

local function sha256(msg)
  local H = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  }

  msg = preproc(msg, #msg)

  for i = 1, #msg, 64 do
    digestblock(msg, i, H)
  end

  return str2hexa(
    num2s(H[1], 4) .. num2s(H[2], 4) .. num2s(H[3], 4) .. num2s(H[4], 4) ..
    num2s(H[5], 4) .. num2s(H[6], 4) .. num2s(H[7], 4) .. num2s(H[8], 4)
  )
end

return {
  sha256 = sha256,
}