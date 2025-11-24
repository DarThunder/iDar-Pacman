# iDar-Pacman

**The definitive package manager for ComputerCraft: Tweaked.**

> _"I use Arch btw... and now my turtles do too."_

**iDar-Pacman** brings the power, aesthetics, and logic of Arch Linux's `pacman` to CC: Tweaked. Unlike simple download scripts, iDar-Pacman is a fully-featured package manager capable of **resolving complex dependency trees**, managing versioning, and handling system updates intelligently.

It serves as the backbone of the **iDar Ecosystem**, ensuring that libraries like [`iDar-CryptoLib`](https://github.com/DarThunder/iDar-CryptoLib) and [`iDar-BigNum`](https://github.com/DarThunder/iDar-BigNum) are installed correctly with all their requirements.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic Commands](#basic-commands)
  - [The Update Cycle](#the-update-cycle)
- [For Developers](#for-developers)
  - [Creating a Package](#creating-a-package)
  - [Manifest Specification](#manifest-specification)
- [FAQ](#faq)
- [License](#license)

## Features

- **True Dependency Resolution**: Automatically detects, downloads, and installs required libraries for any package (recursive resolution).
- **Arch Linux Aesthetics**: Pixel-perfect recreation of the CLI experience, including progress bars, operation tags (`::`), and the sacred `[Y/n]` prompt.
- **Smart Upgrades (`-Syu`)**: Compares your local versions against the remote database to perform necessary updates only.
- **Sandboxed Manifests**: Loads package metadata in a restricted environment to prevent malicious code execution during dependency checks.
- **Clean Filesystem**: Organizes packages efficiently within the `/iDar/` directory hierarchy.
- **Offline-ish Mode**: Caches the registry to check for updates without unnecessary downloads.

## Installation

To bootstrap **iDar-Pacman** on your computer or turtle, run the following command:

```lua
wget run https://raw.githubusercontent.com/DarThunder/iDar-Pacman/refs/heads/main/installer.lua
```

_Note: This will install the base system and create the necessary directory structures._

## Usage

The syntax is designed to be immediately familiar to any Linux user.

### Basic Commands

| Operation   | Flag                 | Description                                  |
| :---------- | :------------------- | :------------------------------------------- |
| **Install** | `pacman -S <pkg>`    | Installs a package and its dependencies.     |
| **Remove**  | `pacman -R <pkg>`    | Uninstalls a package and deletes its files.  |
| **Search**  | `pacman -Ss <query>` | Searches the remote database for packages.   |
| **Query**   | `pacman -Q`          | Lists all locally installed packages.        |
| **Sync DB** | `pacman -Syy`        | Forces a refresh of the package database.    |
| **Upgrade** | `pacman -Syu`        | Syncs DB and performs a full system upgrade. |

### Example: Installing a Library

```text
> pacman -S idar-cryptolib
:: Resolving dependencies...

Packages (2) idar-bignum-v2.0.1  idar-cryptolib-latest

:: Proceed with installation? [Y/n]
:: Getting the packages...
bigNum           [####################] 100%        7.8KB/s
chacha20         [####################] 100%       23.7KB/s
aes              [####################] 100%        8.3KB/s
...
Installation complete!
```

### The Update Cycle

Just like in real life, keep your system updated to get the latest bug fixes and features for your libraries.

```text
> pacman -Syu
:: Synchronizing package databases...
:: Starting full system update...
Update available for idar-bignum: v2.0.0 -> v2.0.1
:: Resolving dependencies...
:: Getting the packages...
bigNum           [####################] 100%        8.0KB/s
Installation complete!
```

## For Developers

Want to distribute your own programs via iDar-Pacman? You need to create a `manifest.lua` file in your repository.

### Manifest Specification

The manifest tells Pacman where to put your files and what other packages you need.

**Example `manifest.lua`:**

```lua
return {
    -- The directory inside /iDar/ where files will be saved
    directory = "MyProgram",

    -- List of source files to download relative to your repo root
    files = {
        "src/main.lua",
        "src/api/utils.lua"
    },

    -- Dependencies that must be installed
    dependencies = {
        { name = "program1", version = "v2.0.1" },
        { name = "program2", version = "latest" }
    }
}
```

To get your package added to the global registry, submit a Pull Request to the **[iDar-Pacman-DB](https://github.com/DarThunder/iDar-Pacman-DB)** repository.

## FAQ

**Q: Can I install `npm` packages with this?**
A: No. If you want to download 12GB of `node_modules` to check if a number is odd, you are in the wrong mod. We optimize for storage here.

**Q: Is the "lag" during download real?**
A: The download speed simulates realistic network conditions (and definitely isn't a tactical `os.sleep` to make the progress bar look cool).

**Q: Does it support AUR?**
A: A man can dream. For now, the official repository is the only source of truth.

**Q: Why create this when `pastebin get` exists?**
A: Because managing 6 different libraries with manual `wget` commands is a nightmare. iDar-Pacman handles the dependency hell so you don't have to.

## Current Packages in Ecosystem

- [iDar-BigNum](https://github.com/DarThunder/iDar-BigNum) - Arbitrary precision arithmetic Library
- [iDar-CryptoLib](https://github.com/DarThunder/iDar-CryptoLib) - Cryptographic suite
- [iDar-Codecs](https://github.com/DarThunder/iDar-Codecs) - Compression Library
- [iDar-Structures](https://github.com/DarThunder/iDar-Structures) - Data structures Library
- [iDar-DB](https://github.com/DarThunder/iDar-DB) - Embedded and lightweight database (WIP)
- [Add yours!](#for-developers)

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
