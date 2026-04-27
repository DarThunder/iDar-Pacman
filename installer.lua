local REPO_URL = "https://raw.githubusercontent.com/DarThunder/iDar-Pacman/refs/heads/main/src/"
local CORE_DB_URL = "https://raw.githubusercontent.com/DarThunder/iDar-Pacman-DB/refs/heads/main/registry.lua"
local CORE_CHECKSUM_URL = "https://raw.githubusercontent.com/DarThunder/iDar-Pacman-DB/refs/heads/main/registry.sum"
local SYS_ROOT = "/iDar"
local INSTALL_DIR = SYS_ROOT .. "/opt/Pacman"
local ETC_DIR = SYS_ROOT .. "/etc"

local DIRS = {
    SYS_ROOT,
    SYS_ROOT .. "/boot",
    SYS_ROOT .. "/bin",
    SYS_ROOT .. "/lib",
    SYS_ROOT .. "/etc",
    SYS_ROOT .. "/opt",
    SYS_ROOT .. "/var",
    SYS_ROOT .. "/dev",
    SYS_ROOT .. "/tmp",
    SYS_ROOT .. "/mnt",
    SYS_ROOT .. "/home",
    SYS_ROOT .. "/root",

    SYS_ROOT .. "/opt/Pacman",
    SYS_ROOT .. "/opt/Pacman/helpers",
    SYS_ROOT .. "/opt/Pacman/utils",
    SYS_ROOT .. "/var/sync"
}

local FILES = {
    ["pacman.lua"] = INSTALL_DIR .. "/pacman.lua",
    ["helpers/core.lua"] = INSTALL_DIR .. "/helpers/core.lua",
    ["helpers/fake_root.lua"] = INSTALL_DIR .. "/helpers/fake_root.lua",
    ["helpers/fetcher.lua"] = INSTALL_DIR .. "/helpers/fetcher.lua",
    ["helpers/installer.lua"] = INSTALL_DIR .. "/helpers/installer.lua",
    ["helpers/manifest.lua"] = INSTALL_DIR .. "/helpers/manifest.lua",
    ["helpers/registry.lua"] = INSTALL_DIR .. "/helpers/registry.lua",
    ["helpers/solver.lua"] = INSTALL_DIR .. "/helpers/solver.lua",
    ["utils/fs_utils.lua"] = INSTALL_DIR .. "/utils/fs_utils.lua",
    ["utils/text_utils.lua"] = INSTALL_DIR .. "/utils/text_utils.lua",
}

local function write_file(path, content)
    local file = fs.open(path, "w")
    if file then
        file.write(content)
        file.close()
        return true
    end
    return false
end

local function downloadAndSave(source_path, dest_path)
    local url = REPO_URL .. source_path
    local response = http.get(url)

    if not response then
        print(string.format("ERROR: Connection failed while downloading %s.", source_path))
        return false
    end

    local code = response.getResponseCode()
    if code ~= 200 then
        print(string.format("ERROR: Server returned HTTP %d for %s.", code, source_path))
        response.close()
        return false
    end

    local content = response.readAll()
    response.close()

    if not write_file(dest_path, content) then
        print(string.format("ERROR: Failed to write file: %s.", dest_path))
        return false
    end

    return true
end

local function ensureDirs(dir_list)
    print(":: Creating directory structure...")
    for _, path in ipairs(dir_list) do
        if not fs.exists(path) then
            fs.makeDir(path)
            print(string.format("   - Created: %s", path))
        else
            print(string.format("   - Existing: %s", path))
        end
    end
end

local function manual_package_install(pkg_name, base_url, dest_dir, file_list)
    print(":: Installing " .. pkg_name .. "...")

    for _, file in ipairs(file_list) do
        local dest_path = fs.combine(dest_dir, file)

        local folder = fs.getDir(dest_path)
        if not fs.exists(folder) then fs.makeDir(folder) end

        term.write("   - " .. file .. "...")
        local response = http.get(base_url .. file)

        if response and response.getResponseCode() == 200 then
            local content = response.readAll()
            response.close()

            local f = fs.open(dest_path, "w")
            f.write(content)
            f.close()
            print(" [OK]")
        else
            if response then response.close() end
            print(" [FAILED]")
            return false
        end
    end
    return true
end

print("-----------------------------------------")
print(" iDar-Pacman Alpha 2.2 Installer")
print("-----------------------------------------")

if not http then
    print("ERROR: Network card (Wireless Modem) is required.")
    return
end

ensureDirs(DIRS)

local success = true
print(":: Downloading main files...")

for source, dest in pairs(FILES) do
    io.write(string.format("   - %-30s...", source))
    if downloadAndSave(source, dest) then
        print(" [OK]")
    else
        print(" [FAILED]")
        success = false
    end
end

if not success then
    print("WARNING: One or more main files failed to download. Operation aborted.")
    fs.delete(SYS_ROOT)
    return
end

print(":: Initializing system files...")

if write_file(ETC_DIR .. "/sources.lua", string.format("return {{name = \"%s\", url = \"%s\", checksum = \"%s\"}}", "core", CORE_DB_URL, CORE_CHECKSUM_URL)) then
    print("   - Created: core.lua")
end

local function ensurePersistentAlias()
    local file = io.open(SYS_ROOT .. "/bin/pacman.ptr", "w")
    if not file then return false end

    file:write("/opt/Pacman/pacman.lua")
    file:close()
    return true
end

if shell and ensurePersistentAlias() then
    print(":: Alias 'pacman' created successfully.")
else
    print("WARNING: Could not create 'pacman' alias.")
end

local installer_name = fs.getName(shell.getRunningProgram())
if fs.exists(installer_name) and installer_name ~= "startup.lua" then
    fs.delete(installer_name)
    print(string.format(":: Installer file (%s) deleted.", installer_name))
end

print("\n-----------------------------------------")
print(":: Bootstrapping iDar OS Base System")
print("-----------------------------------------")

local function fetchRemoteRegistry()
    print(":: Obteniendo base de datos remota para chequear versiones...")
    local response = http.get(CORE_DB_URL)

    if not response then
        print("WARNING: No se pudo contactar al registro. Se usará 'latest' por defecto.")
        return nil
    end

    local registry_text = response.readAll()
    response.close()

    local func, err = load(registry_text)
    if func then
        return func()
    else
        print("WARNING: Error al parsear el registry remoto: " .. tostring(err))
        return nil
    end
end

local remote_registry = fetchRemoteRegistry() or {}

local function getVersionFor(pkg_name)
    if remote_registry[pkg_name] and remote_registry[pkg_name].latest then
        return remote_registry[pkg_name].latest
    end
    return "latest"
end

local loom_url = "https://raw.githubusercontent.com/DarThunder/iDar-Loom/refs/heads/main/src/"
local loom_files = {
    "core.lua",
    "krng.lua",
    "scheduler.lua",
    "sandbox.lua",
    "vfs.lua",
    "config.lua"
}
local loom_ok = manual_package_install("idar-loom", loom_url, "/iDar/opt/Loom", loom_files)

local boot_url = "https://raw.githubusercontent.com/DarThunder/iDar-Boot/refs/heads/main/src/"
local boot_files = { "MBR.lua", "init.lua", "tty_daemon.lua" }
local boot_ok = manual_package_install("idar-boot", boot_url, "/iDar/boot", boot_files)

local shell_url = "https://raw.githubusercontent.com/DarThunder/iDar-Shell/refs/heads/main/src/"
local shell_files = {
    "shell.lua",
    "helpers/command_helper.lua",
    "shell_programs/builtins.lua",
    "shell_programs/cat.lua",
    "shell_programs/fastfetch.lua",
    "shell_programs/grep.lua",
    "shell_programs/ls.lua",
    "shell_programs/mkdir.lua",
    "shell_programs/rm.lua",
    "shell_programs/touch.lua",
    "shell_programs/vi.lua",
}

local shell_bin_map = {
    ["sh"] = "shell.lua",
    ["cat"] = "/opt/Shell/shell_programs/cat.lua",
    ["fastfetch"] = "/opt/Shell/shell_programs/fastfetch.lua",
    ["grep"] = "/opt/Shell/shell_programs/grep.lua",
    ["ls"] = "/opt/Shell/shell_programs/ls.lua",
    ["lua"] = "/opt/shell_programs/lua.lua",
    ["mkdir"] = "/opt/Shell/shell_programs/mkdir.lua",
    ["rm"] = "/opt/Shell/shell_programs/rm.lua",
    ["touch"] = "/opt/Shell/shell_programs/touch.lua",
    ["vi"] = "/opt/Shell/shell_programs/vi.lua",
}

local shell_ok = manual_package_install("idar-shell", shell_url, "/iDar/opt/Shell", shell_files)

if shell_ok then
    print(":: Creating bin pointers for Shell programs...")
    for cmd, rel_path in pairs(shell_bin_map) do
        local ptr_path = SYS_ROOT .. "/bin/" .. cmd .. ".ptr"
        local vfs_target = rel_path

        if write_file(ptr_path, vfs_target) then
            print(string.format("   - Linked /bin/%s -> %s", cmd, vfs_target))
        else
            print(string.format("   - FAILED to link /bin/%s", cmd))
        end
    end
end

print(":: Registering base system in local database...")
local timestamp = os.epoch("utc")
local local_db = {
    --sneak peek of the iDar-Pacman Alpha 3, Coming Fall (maybe, i'm a lazy ass bitch lol)
    --[[["idar-pacman"] = {
        install_dir = "/opt/Pacman",
        package_type = "explicit",
        installed_version = "Alpha-v3.0.0",
        bin = { ["pacman"] = "pacman.lua" },
        dependencies = {},
        installed_at = timestamp
    },]]
    ["idar-loom"] = {
        install_dir = "/opt/Loom",
        package_type = "explicit",
        installed_version = getVersionFor("idar-loom"),
        bin = {},
        dependencies = {},
        installed_at = timestamp
    },
    ["idar-boot"] = {
        install_dir = "/boot",
        package_type = "explicit",
        installed_version = getVersionFor("idar-boot"),
        bin = {},
        dependencies = {},
        installed_at = timestamp
    },
    ["idar-shell"] = {
        install_dir = "/opt/Shell",
        package_type = "explicit",
        installed_version = getVersionFor("idar-shell"),
        bin = shell_bin_map,
        dependencies = {},
        installed_at = timestamp
    }
}

local db_path = SYS_ROOT .. "/var/local.lua"
if write_file(db_path, "return " .. textutils.serialize(local_db)) then
    print("   - Created: /var/local.lua")
else
    print("   - FAILED to create local registry.")
end

if loom_ok and boot_ok and shell_ok then
    local f = io.open("startup.lua", "w")

    if not f then print("\nERROR: Base system installation failed.") fs.delete("/iDar") end

    f:write("local boot = require(\"iDar.boot.MBR\")")
    f:close()

    print("\n-----------------------------------------")
    print(" iDar OS successfully installed!")
    print(" Please reboot the system to start the OS.")
    print("-----------------------------------------")

    local installer_name = fs.getName(shell.getRunningProgram())
    if fs.exists(installer_name) and installer_name ~= "startup.lua" then
        fs.delete(installer_name)
    end
else
    print("\nERROR: Base system installation failed.")
    fs.delete("/iDar")
end