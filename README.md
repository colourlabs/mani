# mani

mani is a modern build tool and package manager for Lua projects. it wraps LuaRocks to give you a per-project package tree, a lockfile, and a single command to install all dependencies - without touching your global environment.

## why

Makefiles for Lua projects are painful - they take time to write, break across platforms (`nmake`, `gmake`, BSD make), and have no standard. LuaRocks is a decent package manager but lacks a single install-all command and any concept of a project manifest. **mani fixes both of these issues! :)**

## features

- single command dependency installation with lockfile support
- per-project package tree (`.mani/tree`) - no global pollution
- task runner with dependency ordering and profiles
- lockfile integrity verification
- generates `.rockspec` from project metadata automatically
- `self-update` command to upgrade mani itself

## requirements

- Lua 5.3 to 5.5
- LuaRocks

## how it works

mani creates a `.mani/tree` directory in your project root. this is a self-contained LuaRocks tree — all dependencies are installed here, completely isolated from your system's global LuaRocks packages. this means:

- no conflicts between projects
- no `sudo luarocks install`
- reproducible environments per project

the lockfile (`mani.lock.lua`) pins exact versions so that every install is identical across machines.

## installation

```bash
luarocks install mani
```

## development

clone the repo and build from source:

```bash
# install GNU make on the host
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

pass `-y` to skip prompts and use defaults:

```bash
mani init -y
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

**maintenance**

| command            | description                              |
| ------------------ | ---------------------------------------- |
| `mani self-update` | update mani itself to the latest version |

## adding packages

```bash
mani add inspect
mani add inspect@3.0
mani add -D busted
```

## project metadata

`mani.project{}` accepts the following fields:

| field         | required | default           | description                                                 |
| ------------- | -------- | ----------------- | ----------------------------------------------------------- |
| `name`        | yes      | —                 | project name                                                |
| `version`     | no       | `"0.1.0"`         | project version                                             |
| `license`     | no       | `"MIT"`           | SPDX license identifier (see at https://spdx.org/licenses/) |
| `homepage`    | no       | —                 | project homepage URL                                        |
| `summary`     | no       | `"A Lua project"` | short description                                           |
| `description` | no       | —                 | longer description                                          |
| `profiles`    | no       | `{}`              | environment-specific configs (see profiles)                 |

these fields are used when generating a `.rockspec` via `mani rockspec`.

## tasks

tasks are defined in `mani.build.lua` and can depend on other tasks:

```lua
mani.task("build", function(params)
  mani:exec("luacheck src/")
end)

mani.task("test", { "build" }, function()
  mani:exec("busted spec/")
end)

mani.task("default", { "build" }, function() end)
```

the first task argument is a `params` table that includes `params.profile` (the current profile name) and `params.profile_config` (that profile's config table). see [profiles](#profiles) below.

run a task:

```bash
mani run build
```

run the default task (no name needed):

```bash
mani run
```

## exec

`mani exec` runs any shell command with `.mani/tree/bin` added to `PATH`, so installed tools are available without global install:

```bash
mani exec luacheck src/
mani exec busted spec/
```

this is equivalent to running:

```bash
PATH="$PWD/.mani/tree/bin:$PATH" luacheck src/
```

## profiles

profiles let you pass different configuration to tasks depending on the environment. they are declared in `mani.project{}` as a table of named configs:

```lua
mani.project {
  name = "my-project",
  version = "0.1.0",

  profiles = {
    dev  = { output = "dist/my-project-dev.lua", debug = true },
    prod = { output = "dist/my-project.lua",     debug = false },
  },
}
```

each key is a profile name mapped to an arbitrary config table. the config is accessible in any task via `params.profile_config`:

```lua
mani.task("build", function(params)
  local cfg = params.profile_config
  -- cfg is { output = "dist/my-project-dev.lua", debug = true } when using dev
  mani:exec("bundler --output " .. cfg.output)
end)
```

select a profile at run time:

```bash
mani run build --profile prod
```

the default profile is `dev`. when no profiles are defined (`profiles = {}` or omitted), any profile name is accepted and `profile_config` will be an empty table.

## lockfile

every `mani install` writes a `mani.lock.lua` that pins exact versions of every dependency. commit this file to ensure reproducible installs across machines.

**workflow:**

```bash
# first install creates the lockfile
mani install

# later, install exactly what the lockfile says
mani install --frozen-lockfile

# verify the lockfile matches what's installed
mani lock --check

# regenerate the lockfile from current install state
mani lock --regen
```

`--frozen-lockfile` fails if the lockfile doesn't match the declared dependencies in `mani.build.lua` (e.g., after adding a package but before installing it), preventing accidental drift.

## license

MIT
