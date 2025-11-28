# Changelog

## Alpha

### v1.0.0

### Core

- **Initial Release:** Introduction of iDar-Pacman, the definitive package manager for ComputerCraft: Tweaked.
- **Full CLI Implementation:** Added all primary operations familiar to Arch Linux users, including installation (`-S`), database synchronization (`-Syy`), full system upgrade (`-Syu`), package search (`-Ss`), removal (`-R`), and query of installed packages (`-Q`).
- **True Dependency Resolution:** Implemented logic to recursively detect, resolve, and queue all necessary dependencies before installation begins.
- **Core Package Registry:** Introduced a local database (`/iDar/var/registry.lua`) to track package metadata, installed versions, and remote repository details.
- **GitHub as CDN:** Package URLs are dynamically generated to fetch manifests and files directly from GitHub tags, ensuring version stability.

### Security & Stability

- **Sandboxed Manifest Execution:** Package metadata (manifests) are loaded and executed in a restricted environment (`sandbox = {}`) to prevent malicious code from running during dependency checks.
- **Manifest Timeout Hook:** Implemented a watchdog timer using `debug.sethook` to prevent package manifests from causing infinite loops or excessive resource usage.
- **Robust HTTP Fetching:** Added comprehensive checks for server responses (HTTP 200) and connection errors during downloads.

### User Experience

- **Arch Linux Aesthetics:** Pixel-perfect TTY visual style, including operation tags (`::`), command headers, and the iconic installation prompt `[Y/n]`.
- **Custom Progress Bars:** Implemented a real-time progress rendering utility that calculates download speed (KB/s), percentage, and visually updates the terminal line for each file being downloaded.
- **Simulated Network Speed:** Added a small, randomized delay (`os.sleep`) during chunk downloads to simulate realistic network conditions and provide a better visual experience for the progress bar.

### v1.0.1

### Core

**Critical Dependency Fix**: Internal package.path injection has been implemented within pacman.lua to ensure the main program and all its internal modules resolve correctly.

**Sandboxing Solution**: This injection fixes the issue in environments where package.path is reset by CC: Tweaked's sandboxing, eliminating the 'module not found' error.

### Documentation & Standards

**Library Usage Guide**: A new section called "Using iDar Libraries in Your Programs" has been added to the SATD Specification Wiki.

**Environment Clarification**: The new guide warns developers about CC: Tweaked's limitation of resetting package.path, recommending the use of absolute paths or modifying the path only in the program's main file.

### Installer Refinement

**Ineffective Logic Removal**: The ineffective logic attempting to persistently modify package.path through startup.lua has been removed from installer.lua. (Ensuring the base installer remains clean and only configures the alias).

### v2.0.0

### Core System & Architecture

- **Atomic Transactions (FakeRoot):** Implemented a fully transactional installation architecture. Packages are first staged in a temporary environment (`/iDar/tmp/<session_id>/root`). Changes are only committed to the real filesystem once all downloads, validations, and hooks succeed. Automatic rollback prevents corrupt or partial installations.
- **State Management (Explicit vs Implicit):** The internal registry (`registry.lua`) now intelligently tracks whether a package was installed explicitly by the user or implicitly as a dependency. This is crucial for the new cleanup and orphan detection logic.

### New CLI Operations

- **Cascade Removal (`-Rns`):** Added a new flag for deep uninstallation. This allows removing a package and recursively its dependencies (provided they are not required by other installed packages), keeping the system clean of unused libraries.
- **Orphan Query (`-Qtdq`):** Added the ability to audit the system for "orphan" packages—those installed as dependencies that are no longer needed—allowing users to easily identify bloatware.

### Security & Stability

- **Secure Post-Install Hooks:** The hook system has been integrated with the `FakeRoot` environment. Post-installation scripts defined in manifests now run within the temporary sandbox, ensuring any configuration or file generation occurs safely before touching the real system.
- **Uninstall Protection:** Added a security interaction layer to the removal process (`-R`), requesting explicit `[Y/n]` confirmation before deleting files from disk.
