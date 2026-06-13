# mani

mani is a modern build tool and package manager for Lua projects. it wraps LuaRocks to give you a per-project package tree, a lockfile, and a single command to install all dependencies - without touching your global environment.

## why

Makefiles for Lua projects are painful - they take time to write, break across platforms (`nmake`, `gmake`, BSD make), and have no standard. LuaRocks is a decent package manager but lacks a single install-all command and any concept of a project manifest. **mani fixes both of these issues! :)**

## features

- single command dependency installation with lockfile support
- per-project package tree - no global pollution
- task runner with dependency ordering and profiles
- lockfile integrity verification
- generates `.rockspec` from project metadata automatically

## requirements

- Lua 5.1 or 5.4
- LuaRocks

## installation

```bash
luarocks install mani
```

## development

clone the repo and build from source:

```bash
git clone https://github.com/colourlabs/mani
cd mani
make dev
```

run tests:

```bash
make test        # excludes interactive tests
make test-all    # includes all tests
make lint
```

## getting started

create a new project:

```bash
mani init
```

this creates a `mani.build.lua` in the current directory:

```lua
local mani = require("mani")

mani.project {
  name = "my-project",
  version = "0.1.0",
  license = "MIT",
}

mani.dependencies({
  -- "inspect^3.0",
})

mani.dev_dependencies({
  -- "busted^2.0",
})

mani.task("build", function()
  mani:log("building...")
end)

mani.task("test", function()
  mani:exec("busted spec/")
end)
```

install dependencies:

```bash
mani install
```

run a task:

```bash
mani run build
```

## commands

**package management**

| command             | description                                    |
| ------------------- | ---------------------------------------------- |
| `mani install`      | install all dependencies from `mani.build.lua` |
| `mani add <pkg>`    | add and install a package                      |
| `mani remove <pkg>` | remove a package                               |
| `mani update [pkg]` | update one or all dependencies to latest       |

**running**

| command           | description                                       |
| ----------------- | ------------------------------------------------- |
| `mani run <task>` | run a task defined in `mani.build.lua`            |
| `mani exec <cmd>` | run a shell command with the project tree on PATH |

**project**

| command         | description                                      |
| --------------- | ------------------------------------------------ |
| `mani init`     | create a new project                             |
| `mani rockspec` | regenerate the `.rockspec` from project metadata |

**lockfile**

| command             | description                                           |
| ------------------- | ----------------------------------------------------- |
| `mani lock --check` | verify lockfile integrity against installed packages  |
| `mani lock --regen` | regenerate lockfile from currently installed packages |

## adding packages

```bash
mani add inspect
mani add inspect@3.0
mani add -D busted
```

## tasks

tasks are defined in `mani.build.lua` and can depend on other tasks:

```lua
mani.task("build", function(params)
  local cfg = params.profile_config
  mani:exec("some-bundler --output " .. cfg.output)
end)

mani.task("test", { "build" }, function()
  mani:exec("busted spec/")
end)

mani.task("default", { "build" }, function() end)
```

run with a profile:

```bash
mani run build --profile prod
```

## profiles

profiles let you configure tasks differently per environment:

```lua
mani.project {
  name = "my-project",
  version = "0.1.0",

  profiles = {
    dev  = { output = "dist/my-project-dev.lua" },
    prod = { output = "dist/my-project.lua" },
  },
}
```

## lockfile

mani generates a `mani.lock.lua` after every install. commit this file to ensure reproducible installs across machines.

to install exactly what the lockfile specifies:

```bash
mani install --frozen-lockfile
```

## license

MIT
