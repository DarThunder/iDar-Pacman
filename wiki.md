# SATD Specification Wiki

## Introduction

**SATD (Standard Automated Template Download)** is the packaging standard that powers iDar-Pacman. It defines how packages are structured, distributed, and installed across the CC:Tweaked ecosystem.

> _"Like pacman for Arch, but for turtles - and with more Lua sandboxing."_

## Version Compatibility

| SATD Version | iDar-Pacman Version | Status         |
| ------------ | ------------------- | -------------- |
| SATD v2.x    | v2.0.0+             | **Current**    |
| SATD v1.x    | v1.x.x              | **Deprecated** |

> ⚠️ **SATD v1 is no longer supported.** All new packages must use SATD v2.

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

```
my-package-repo/
├── manifest.lua          # REQUIRED - SATD manifest
├── src/
│   ├── main.lua
│   └── utils.lua
└── README.md
```

### URL Schema

SATD uses a standardized URL pattern for package retrieval directly from GitHub Raw:

```lua
"[https://raw.githubusercontent.com/](https://raw.githubusercontent.com/){developer}/{repo}/refs/tags/{version}/"
```

## Manifest Specification

### Required Fields

```lua
return {
    -- Installation directory under /iDar/
    -- Example: will be installed in /iDar/MyPackage
    directory = "MyPackage",

    -- Files to download (relative to repo root)
    files = {
        "main.lua",
        lib = {
            "utils.lua"
        },
        config = {
            "default.conf"
        }
    },

    -- Package dependencies
    dependencies = {
        { name = "idar-bignum", version = "v2.0.1" },
        { name = "text-utils", version = "latest" }
    }
}
```

### Optional Fields and Hooks

The system now supports post-installation hooks managed by `fake_root`.

```lua
return {
    -- ... required fields ...

    description = "A cool package",
    author = "YourName",

    -- Installation Hooks (Executed in a fakeroot environment)
    hooks = {
        {
            name = "setup_config",
            script = [[
                -- This script has limited access to the file system (fs)
                -- It can only write inside the temporary installation directory.
                local config = { theme = "dark" }
                local f = fs.open("/iDar/MyPackage/config.lua", "w")
                f.write(textutils.serialize(config))
                f.close()
                print("Configuration generated.")
            ]]
        }
    }
}
```

### Sandboxing Rules

There are two security levels in SATD:

#### 1\. Manifest Sandboxing (`manifest.lua`)

When loading the manifest to resolve dependencies, the environment is **strictly restricted**:

- **Allowed:** Table manipulation, strings, basic math.
- **Blocked:** `fs.*`, `http.*`, `os.*`, `shell.*`.
- **Timeout:** 0.05 seconds.

#### 2\. Hook Sandboxing (`fake_root`)

During post-installation, scripts defined in `hooks` run in a `fake_root` environment:

- **Virtualized File System:** Calls to `fs.*` are redirected to `/iDar/tmp/<session_id>/root/`.
- **Atomic Commit:** Changes are only moved to the real system if the hook completes successfully.
- **Timeout:** 5 seconds.

## Registry Specification

### Package Entry Format

Each package in `iDar-Pacman-DB` or external sources follows this structure:

```lua
return {
    ["package-name"] = {
        dev = "GitHubUsername",
        package_name = "repo-name",
        latest = "v1.0.0",

        -- Data managed locally by pacman in /iDar/var/local.lua
        -- installed = true,
        -- package_type = "explicit" | "implicit"
    }
}
```

## Repository and Source Management

iDar-Pacman is not limited to a single central repository. The system supports multiple package sources (third-party or private repositories) through a configuration file.

### Configuration File

**Location:** `/iDar/etc/sources.lua`

This file returns a Lua table containing the list of active repositories. Pacman will iterate through this list when executing `pacman -Syy` or `pacman -Syu`.

### Source Structure

To register a new repository, add a new table with the following fields:

- **name**: A unique local identifier for the repository (used for cache files in `/iDar/var/sync/`).
- **url**: Direct (Raw) link to the remote repository's `registry.lua` file.
- **checksum**: Direct (Raw) link to the remote repository's `.sum` (SHA256) file for integrity verification before downloading the database.

### Configuration Example

```lua
return {
    -- Core Repository (Official)
    {
        name = "core",
        url = "https://raw.githubusercontent.com/DarThunder/iDar-Pacman-DB/main/registry.lua",
        checksum = "https://raw.githubusercontent.com/DarThunder/iDar-Pacman-DB/main/registry.sum"
    },

    -- Community Repository (Example)
    {
        name = "community",
        url = "https://raw.githubusercontent.com/AnotherUser/My-CC-Repo/main/registry.lua",
        checksum = "https://raw.githubusercontent.com/AnotherUser/My-CC-Repo/main/registry.sum"
    },

    -- Corporate Repository (Example)
    {
        name = "corporate",
        url = "https://raw.githubusercontent.com/MyCompany/Private-Packages/main/registry.lua",
        checksum = "https://raw.githubusercontent.com/MyCompany/Private-Packages/main/registry.sum"
    }
}
```

### Usage Notes

- **Security**: Only use repositories from trusted sources
- **Cache Management**: Each repository creates separate cache files (`/iDar/var/sync/{name}.lua` and `/iDar/var/sync/{name}.sum`)
- **Update Required**: After adding a new source, you **must** run `pacman -Syy` to download the database and checksum for the first time
- **Priority**: Packages are searched in the order repositories are listed (first match wins)

### Checksum Verification

The checksum file should contain a SHA256 hash of the registry.lua file. Pacman uses this to ensure database integrity and prevent corrupted or tampered downloads.

---

**Note**: This multi-repository architecture enables enterprise deployments, community package sharing, and development/testing environments while maintaining the security model of the original design.

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
        ["src"] = {
            "main.lua"
        }
    },
    dependencies = {
        { name = "idar-bignum", version = "v2.0.1" }
    },
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
3.  **Safe Execution:**
    - Manifests cannot touch the disk or network.
    - Installation scripts (hooks) cannot damage the file system outside their assigned directory thanks to `fake_root`.

## Error Handling

### Common SATD Errors

- **Circular dependency detected:** `solver.lua` detected a loop (A depends on B, B depends on A).
- **Manifest took too long:** The manifest or a hook exceeded its execution time limit.
- **HTTP Error:** Failed to download from GitHub (check connection or tag existence).

## Future Extensions

### Planned Features (TODO)

- **Digital Signatures (GPG):** Cryptographic verification of the package author.
- **Conditional Dependencies:** Platform-specific requirements (e.g., "requires: advanced_computer").
- **Interactive Configuration Templates:** User-guided setup during installation (wizard).

_(Note: Installation Hooks and basic database integrity validation have already been implemented)._

## Using iDar Libraries in Your Programs

Because CC:Tweaked resets `package.path`, it is recommended to use absolute paths or configure the path at the start:

```lua
-- Configure path at the start of your program
package.path = "/iDar/?.lua;/iDar/?/init.lua;" .. package.path

-- Require using relative names
local bigNum = require("Bignum.BigNum")
```
