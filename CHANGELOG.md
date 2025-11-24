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
