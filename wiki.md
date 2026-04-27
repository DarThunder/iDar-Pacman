# SATD Specification Wiki

## Introduction

**SATD (Standard Automated Template Download)** is the packaging standard that powers iDar-Pacman within the **iDar-Loom Microkernel** ecosystem. It defines how packages are structured, distributed, and safely installed across CC:Tweaked computers running the Loom kernel.

> _"Like pacman for Arch, but for turtles - and powered by kernel-level sandboxing."_

## Version Compatibility

| SATD Version | iDar-Pacman Version | Status         |
| ------------ | ------------------- | -------------- |
| SATD v2.6.x  | v2.2.0+             | **Current**    |
| SATD v2.5.x  | v2.1.0              | **Deprecated** |
| SATD v1.x    | v1.x.x              | **Deprecated** |

> ⚠️ **SATD v1 and v2.5 are no longer supported.** All new packages must use SATD v2.6+, which enforces FHS-compliant paths (`/lib`, `/opt`, `/bin`) utilizing the iDar-Loom Virtual File System (VFS).

## Core Concepts

### The Three Pillars of SATD

1.  **Registry** - Central package database (`iDar-Pacman-DB` and `sources.lua`).
2.  **Manifest** - Package metadata and instructions (`manifest.lua`).
3.  **Repository** - GitHub-hosted package content with versioned tags.

## iDar-Pacman Usage Guide

### Available Commands

Based on the current implementation (`pacman.lua`), these are the supported operations:

| Command                 | Description                                                                             |
| :---------------------- | :-------------------------------------------------------------------------------------- |
| `pacman -S <package>`   | Install one or more specific packages.                                                  |
| `pacman -Syy`           | Force synchronization of package databases (downloads `.lua` and verifies `.sum`).      |
| `pacman -Syu`           | Synchronize databases and perform a full system upgrade to the latest versions.         |
| `pacman -Ss <query>`    | Search for packages in the synchronized database.                                       |
| `pacman -R <package>`   | Remove a package (keeps its dependencies).                                              |
| `pacman -Rns <package>` | Remove a package and its dependencies if they are no longer needed (recursive cleanup). |
| `pacman -Q`             | List all installed packages and their versions.                                         |
| `pacman -Qtdq`          | List "orphan" packages (installed dependencies that are no longer required).            |

## Package Structure Specification

### Repository Requirements

#### Tagging System

```bash
# Valid version tags (semver-inspired)
v1.0.0    # Major release
v1.2.3    # Patch release
v2.1.0    # Minor release
latest    # Rolling release
```

#### File Structure

```text
my-package-repo/
├── manifest.lua          # REQUIRED - SATD manifest
├── src/
│   ├── main.lua
│   └── utils.lua
└── README.md
```

### URL Schema

SATD uses a standardized URL pattern for package retrieval directly from GitHub Raw:

```text
https://raw.githubusercontent.com/{developer}/{repo}/refs/tags/{version}/
```

## Manifest Specification

### Required Fields

```lua
return {
    -- Installation directory under /lib/ or /opt/ depending on whether it has binaries.
    -- Example: will be installed in /lib/MyPackage (if it's a library)
    directory = "MyPackage",

    -- Files to download: ["local/destination"] = "remote/source/in/repo"
    files = {
        ["init.lua"] = "src/init.lua",
        ["MBR.lua"] = "src/MBR.lua",
        ["tty_daemon.lua"] = "src/tty_daemon.lua"
    },

    -- Package dependencies
    dependencies = {
        { name = "idar-bignum", version = "v2.0.1" },
        { name = "text-utils", version = "latest" }
    }
}
```

### Optional Fields and Hooks

The system supports post-installation hooks managed by `fake_root`.

```lua
return {
    -- ... required fields ...

    description = "A cool package",
    author = "YourName",

    -- Installation Hooks (Executed in a fakeroot environment using sys.spawn)
    hooks = {
        {
            name = "setup_config",
            script = [[
                -- This script has limited access to the file system (sys)
                -- It can only write inside the temporary installation directory.
                local config = { theme = "dark" }
                local f = sys.open("/lib/MyPackage/config.lua", "w")
                sys.write(f, textutils.serialize(config))
                sys.close(f)
                print("Configuration generated.")
            ]]
        }
    }
}
```

### `bin` (Optional) — SATDv2.6+

Declares executable entry points for the package. Pacman will automatically
create `.ptr` files globally in `/bin/` pointing to the specified scripts utilizing Loom's VFS links. Furthermore, declaring a `bin` table will automatically route the package installation to `/opt/` instead of `/lib/`.

```lua
bin = {
    ["command-name"] = "relative/path/from/directory/to/script.lua"
}
```

**Example:**

```lua
bin = {
    ["vi"]  = "src/shell_programs/vi.lua",
    ["cat"] = "src/shell_programs/cat.lua",
}
```

These entries are managed by Pacman — on install, the `.ptr` files are created
automatically. On removal, they are cleaned up alongside the package directory.

> Note: Paths are relative to the package `directory`, not the repo root.

### Sandboxing Rules

Thanks to the iDar-Loom microkernel, there are two strict security levels enforced via `sys.spawn` and the Scheduler:

#### 1. Manifest Sandboxing (`manifest.lua`)

When loading the manifest to resolve dependencies, it is launched as a restricted child process:

- **Allowed:** Table manipulation, strings, basic math.
- **Blocked:** `sys.*`, `fs.*`, `http.*`, `os.*`, `shell.*`.
- **Enforcement:** If it exceeds 0.05 seconds of execution without yielding, the Loom kernel forces a `sys.kill`.

#### 2. Hook Sandboxing (`fake_root`)

During post-installation, scripts defined in `hooks` run in a strictly isolated `fake_root` process thread:

- **Virtualized File System:** Calls to `sys.*` methods (like `sys.open` and `sys.delete`) are intercepted and redirected to `/tmp/<session_id>/root/`.
- **Atomic Commit:** Changes are only mapped to the real VFS (`/opt/` or `/lib/`) if the hook completes successfully.
- **Timeout:** If the hook takes more than 5 seconds, Loom scheduler kills it automatically, triggering a rollback.

## Registry Specification

### Package Entry Format

Each package in `iDar-Pacman-DB` or external sources follows this structure:

```lua
return {
    ["package-name"] = {
        dev = "GitHubUsername",
        package_name = "repo-name",
        latest = "v1.0.0",

        -- Data managed locally by pacman in /var/local.lua
        -- installed = true,
        -- package_type = "explicit" | "implicit"
    }
}
```

## Repository and Source Management

iDar-Pacman is not limited to a single central repository. The system supports multiple package sources (third-party or private repositories) through a configuration file.

### Configuration File

**Location:** `/etc/sources.lua`

This file returns a Lua table containing the list of active repositories. Pacman will iterate through this list when executing `pacman -Syy` or `pacman -Syu`.

### Source Structure

To register a new repository, add a new table with the following fields:

- **name**: A unique local identifier for the repository (used for cache files in `/var/sync/`).
- **url**: Direct (Raw) link to the remote repository's `registry.lua` file.
- **checksum**: Direct (Raw) link to the remote repository's `.sum` (SHA256) file for integrity verification before downloading the database.

### Usage Notes

- **Security**: Only use repositories from trusted sources.
- **Cache Management**: Each repository creates separate cache files (`/var/sync/{name}.lua` and `/var/sync/{name}.sum`).
- **Update Required**: After adding a new source, you **must** run `pacman -Syy` to download the database and checksum for the first time.
- **Priority**: Packages are searched in the order repositories are listed (first match wins).

### Checksum Verification

The checksum file should contain a SHA256 hash of the `registry.lua` file. Pacman uses this to ensure database integrity and prevent corrupted or tampered downloads.

## Package Development Guide

### Creating a SATD-Compliant Package

#### Step 1: Repository Setup

```bash
git init my-package
cd my-package
touch manifest.lua
mkdir src
```

#### Step 2: Write Your Manifest

```lua
-- manifest.lua
return {
    directory = "my-package",
    files = {
        ["init.lua"] = "src/init.lua",
    },
    dependencies = {
        { name = "idar-bignum", version = "v2.0.1" }
    },
    bin = {
        ["my-package"] = "/opt/my-package/init.lua",
    }
    description = "My awesome CC:Tweaked package"
}
```

#### Step 3: Version and Release

```bash
git add .
git commit -m "Initial release"
git tag v1.0.0
git push origin main --tags
```

#### Step 4: Publish

Add your package to `iDar-Pacman-DB` or configure it in your own `sources.lua`.

## Security Model

### Trust Chain

1.  **Source Integrity:** HTTPS + GitHub ensure content is not altered in transit.
2.  **Database Integrity:** `pacman` verifies the checksum (`.sum`) of remote databases before synchronizing.
3.  **Kernel-Level Execution Safety:**
    - Manifests are spawned in empty environments and brutally killed by the Loom Scheduler if they try to stall the system.
    - Installation hooks (`fake_root`) are jailed within temporary VFS paths and terminated by `sys.kill` if they exceed the time slice limit.

## Error Handling

### Common SATD Errors

- **Circular dependency detected:** `solver.lua` detected a loop (A depends on B, B depends on A).
- **Manifest took too long:** Loom's Scheduler forcibly killed the manifest process thread for exceeding its execution time limit without yielding.
- **HTTP Error:** Failed to download from GitHub (check connection or tag existence).

## Using iDar Libraries in Your Programs

Because CC:Tweaked resets `package.path`, and since iDar-Pacman now installs pure libraries globally into the Loom VFS `/lib/`, it is recommended to configure your path at the start of your userland code:

```lua
-- No configuration needed! Loom's custom require resolver
-- automatically searches /lib/ and /opt/ before the default paths.
-- Just require directly:
local bigNum = require("Bignum.BigNum")
```
