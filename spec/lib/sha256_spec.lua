describe("SHA256 library (mani.lib.sha256)", function()
  local sha256_lib

  before_each(function()
    sha256_lib = require("mani.lib.sha256")
  end)

  it("hashes empty string correctly", function()
    local hash = sha256_lib.sha256("")
    assert.are.equal("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", hash)
  end)

  it("hashes 'abc' correctly", function()
    local hash = sha256_lib.sha256("abc")
    assert.are.equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hash)
  end)

  it("hashes longer standard test vector correctly", function()
    local hash = sha256_lib.sha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
    assert.are.equal("248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", hash)
  end)
end)
