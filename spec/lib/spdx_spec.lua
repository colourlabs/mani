describe("SPDX License library (mani.lib.spdx)", function()
  local spdx

  before_each(function()
    spdx = require("mani.lib.spdx")
  end)

  it("identifies MIT as a valid license", function()
    assert.is_true(spdx["MIT"])
  end)

  it("identifies Apache-2.0 as a valid license", function()
    assert.is_true(spdx["Apache-2.0"])
  end)

  it("identifies an invalid license name as falsy", function()
    assert.is_nil(spdx["NotALicense"])
  end)

  it("contains a large dataset of licenses", function()
    local count = 0
    for _ in pairs(spdx) do
      count = count + 1
    end
    assert.is_true(count > 500)
  end)
end)
