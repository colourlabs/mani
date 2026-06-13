# Contributing

## setup

```bash
git clone https://github.com/colourlabs/mani
cd mani
make dev
```

this installs dependencies into `.mani/tree/` and builds mani from source.

run tests:

```bash
make test        # excludes network/interactive tests
make test-all    # includes all tests
make lint
```

## project structure

```
src/mani/
├── main.lua                  # CLI entry point (argparse, command dispatch)
├── api.lua                   # Public API exposed to mani.build.lua
├── loader.lua                # Lua path setup (.mani/tree), build file loader
├── version.lua               # Version string
├── commands/
│   ├── lockfile/lock.lua     # mani lock --check/--regen
│   ├── packages/
│   │   ├── add.lua           # mani add <pkg>
│   │   ├── install.lua       # mani install
│   │   ├── remove.lua        # mani remove <pkg>
│   │   └── update.lua        # mani update [pkg]
│   ├── project/
│   │   ├── init.lua          # mani init
│   │   └── rockspec.lua      # mani rockspec
│   ├── run/
│   │   ├── exec.lua          # mani exec <cmd>
│   │   └── run.lua           # mani run <task>
│   └── self_updater/
│       └── self_update.lua   # mani self-update
├── core/
│   ├── exec.lua              # Shell command execution
│   ├── installer.lua         # Package add/remove/install/update logic
│   ├── lockfile.lua          # Lockfile read/write/verify
│   ├── log.lua               # Color-coded stderr logging
│   ├── project.lua           # Project metadata + dependency state
│   ├── resolver.lua          # Resolve installed packages
│   ├── rockspec.lua          # .rockspec generation
│   └── task.lua              # DAG task runner with dependency ordering
└── lib/
    ├── http.lua              # HTTP GET (ssl.https -> socket.http -> curl)
    ├── sha256.lua            # Pure-Lua SHA-256
    └── spdx.lua              # SPDX license identifier lookup
spec/                        # Mirrors src/ structure, _spec suffix
bin/mani                     # Shell entry point
rockspecs/                   # Release and dev rockspecs
```

## testing conventions

we use [busted](https://github.com/lunarmodules/busted/) for testing

- test files live in `spec/` mirroring `src/` with `_spec.lua` suffix
- use `describe`/`it` blocks with descriptive strings
- mock dependencies via `package.preload` in `before_each`, clean up in `after_each`
- use `spy.new()` and `assert.spy()` for call verification
- `assert.spy(fn).was_called()` / `was_called_with(...)` / `was_not_called()`

**tags:**

| tag            | meaning                     | excluded from `make test` |
| -------------- | --------------------------- | ------------------------- |
| `#network`     | requires real HTTP requests | yes                       |
| `#interactive` | simulates stdin prompts     | yes                       |

tags go in the description string:

```lua
describe("#network", function()
  it("fetches a real URL", function()
    -- ...
  end)
end)
```

## code style

- 2-space indentation, no tabs
- lowercase identifiers, snake_case
- no semicolons
- single-line comments only (`--`)
- match existing patterns in the file you're editing
- pass `luacheck src/ spec/` with no warnings

## pull requests

1. branch from `main`
2. add or update tests in `spec/`
3. run `make test && make lint` - both must pass
4. keep changes focused; separate refactors from features
5. open the PR against `main`

## notes

- mani supports Lua 5.3–5.5. avoid APIs that don't exist on 5.3.
- `require` on 5.4+ returns a second value (filepath). always capture with `local x = require(...)`.
- `io.popen:close()` returns different types across versions (number vs boolean). handle both.
- `.mani/tree` is gitignored, never commit it.

## licensing

mani is licensed under the permissive open-source [MIT License](https://tlo.mit.edu/understand-ip/exploring-mit-open-source-license-comprehensive-guide). See the details in the LICENSE file.