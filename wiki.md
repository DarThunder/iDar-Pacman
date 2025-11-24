# SATD Specification Wiki

## Introduction

**SATD (Standard Automated Template Download)** is the packaging standard that powers iDar-Pacman. It defines how packages are structured, distributed, and installed across the CC:Tweaked ecosystem.

> _"Like pacman for Arch, but for turtles - and with more Lua sandboxing."_

## Core Concepts

### The Three Pillars of SATD

1. **Registry** - Central package database (iDar-Pacman-DB)
2. **Manifest** - Package metadata and instructions (`manifest.lua`)
3. **Repository** - GitHub-hosted package content with versioned tags

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

SATD uses a standardized URL pattern for package retrieval:

```lua
-- Base URL template
"https://raw.githubusercontent.com/{developer}/{repo}/refs/tags/{version}/"

-- Examples
"https://raw.githubusercontent.com/DarThunder/bigNum/refs/tags/v2.0.1/"
"https://raw.githubusercontent.com/SomeDev/cc-utils/refs/tags/v1.5.0/"
```

## Manifest Specification

### Required Fields

```lua
return {
    -- Installation directory under /iDar/
    directory = "MyPackage",

    -- Files to download (relative to repo root)
    files = {
        "main.lua",
        "lib/utils.lua",
        "config/default.conf"
    },

    -- Package dependencies
    dependencies = {
        { name = "idar-bignum", version = "v2.0.1" },
        { name = "text-utils", version = "latest" }
    }
}
```

### Optional Fields

```lua
return {
    -- ... required fields ...

    -- Package metadata
    description = "A cool package that does things",
    author = "YourName",
    license = "MIT",

    -- Installation hooks (future)
    pre_install = function() print("Preparing installation...") end,
    post_install = function() print("Installation complete!") end
}
```

### Manifest Sandboxing Rules

SATD manifests run in a **restricted environment** with the following limitations:

#### **Allowed Operations:**

- Table creation and manipulation
- Basic Lua functions (`print`, `type`, `pairs`, etc.)
- String operations
- Mathematical operations

#### **Blocked Operations:**

```lua
-- FILESYSTEM ACCESS
fs.open()      -- ❌ No file access
fs.delete()    -- ❌ No deletion
fs.makeDir()   -- ❌ No directory creation

-- NETWORK ACCESS
http.get()     -- ❌ No network calls

-- SYSTEM ACCESS
os.run()       -- ❌ No program execution
shell.run()    -- ❌ No shell commands

-- UNRESTRICTED CODE
loadstring()   -- ❌ No dynamic code loading
debug.*        -- ❌ No debug functions
```

#### **Timeout Protection:**

Manifests must execute within **0.05 seconds** or are automatically terminated.

## Registry Specification

### Package Entry Format

Each package in `iDar-Pacman-DB/registry.lua` follows this structure:

```lua
return {
    ["package-name"] = {
        developer = "GitHubUsername",
        package_name = "repo-name",
        latest = "v1.0.0",

        -- Installation tracking (managed by pacman)
        installed = true/false,
        installed_version = "v1.0.0"
    },

    ["bigNum"] = {
        developer = "DarThunder",
        package_name = "bigNum",
        latest = "v2.0.1",
        installed = true,
        installed_version = "v2.0.1"
    }
}
```

## Package Development Guide

### Creating a SATD-Compliant Package

#### Step 1: Repository Setup

```bash
# Create your GitHub repository
git init my-package
cd my-package

# Add required files
touch manifest.lua
mkdir src
```

#### Step 2: Write Your Manifest

```lua
-- manifest.lua
return {
    directory = "my-package",
    files = {
        "src/main.lua",
        "src/utils.lua"
    },
    dependencies = {
        { name = "idar-bignum", version = "v2.0.1" }
    },
    description = "My awesome CC:Tweaked package"
}
```

#### Step 3: Version and Release

```bash
# Commit and tag your release
git add .
git commit -m "Initial release"
git tag v1.0.0
git push origin main --tags
```

#### Step 4: Submit to Registry

Create a PR to **[iDar-Pacman-DB](https://github.com/DarThunder/iDar-Pacman-DB)** with your package entry.

## Security Model

### Trust Chain

```
GitHub (Content) → SATD Manifest (Metadata) → iDar-Pacman (Verification) → User
```

### Protection Mechanisms

1. **Sandboxed Manifest Execution** - No arbitrary code execution during dependency resolution
2. **Content Integrity** - HTTPS + GitHub integrity
3. **Timeout Protection** - Prevents infinite loops in manifests
4. **Registry Curation** - Manual approval process

## Error Handling

### Common SATD Errors

```lua
-- Missing required field
ERROR: Manifest missing required field 'directory'

-- Invalid file reference
ERROR: File 'nonexistent.lua' listed in manifest but not found in repo

-- Sandbox violation
ERROR: Manifest attempted to call restricted function: fs.open

-- Timeout
ERROR: Manifest took too long without yielding

-- Dependency resolution
ERROR: Circular dependency detected: package-a → package-b → package-a
```

## Examples

### Complete Working Example

**Repository:** `https://github.com/ExampleUser/cc-calculator`

**manifest.lua:**

```lua
return {
    directory = "calculator",
    files = {
        "calculator.lua",
        "lib/math_ops.lua"
    },
    dependencies = {
        { name = "idar-bignum", version = "v2.0.1" }
    },
    description = "A scientific calculator for CC:Tweaked",
    author = "ExampleUser"
}
```

**Installation:**

```bash
pacman -S cc-calculator
```

## Future Extensions

### Planned SATD Features

- **Digital Signatures** - Package verification via GPG
- **Checksum Validation** - File integrity checking
- **Conditional Dependencies** - Platform-specific requirements
- **Configuration Templates** - User setup during installation
