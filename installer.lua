local REPO_URL = "https://raw.githubusercontent.com/DarThunder/iDar-Pacman/main/src/"
local INSTALL_DIR = "/iDar/Pacman"
local VAR_DIR = "/iDar/var"
local FILESYSTEM_BASE = "/iDar"

local DIRS = {
    FILESYSTEM_BASE,
    INSTALL_DIR,
    INSTALL_DIR .. "/helpers",
    INSTALL_DIR .. "/utils",
    VAR_DIR
}

local FILES = {
    ["pacman.lua"] = INSTALL_DIR .. "/pacman.lua",
    ["helpers/core.lua"] = INSTALL_DIR .. "/helpers/core.lua",
    ["helpers/fetcher.lua"] = INSTALL_DIR .. "/helpers/fetcher.lua",
    ["helpers/manifest.lua"] = INSTALL_DIR .. "/helpers/manifest.lua",
    ["helpers/registry.lua"] = INSTALL_DIR .. "/helpers/registry.lua",
    ["helpers/installer.lua"] = INSTALL_DIR .. "/helpers/installer.lua",
    ["utils/fs_utils.lua"] = INSTALL_DIR .. "/utils/fs_utils.lua",
    ["utils/text_utils.lua"] = INSTALL_DIR .. "/utils/text_utils.lua"
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

print("-----------------------------------------")
print(" iDar-Pacman Alpha Installer")
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
    return
end

print(":: Initializing system files...")

if write_file(VAR_DIR .. "/registry.cache", "") then
    print("   - Created: registry.cache")
end

if write_file(VAR_DIR .. "/registry.lua", "return {}") then
    print("   - Created: registry.lua")
end

local pacman_path = INSTALL_DIR .. "/pacman.lua"
local PERSISTENT_ALIAS_CMD = string.format('shell.setAlias("pacman", "%s")', pacman_path)
local STARTUP_PATH = "startup.lua"

local function ensurePersistentAlias()
    local current_content = ""
    local fs_exists = fs.exists(STARTUP_PATH)

    if fs_exists then
        local f = fs.open(STARTUP_PATH, "r")
        current_content = f.readAll() or ""
        f.close()
    end

    if current_content:find(PERSISTENT_ALIAS_CMD) then
        print(":: Alias 'pacman' already is persistent.")
        return
    end

    local new_content = current_content

    if new_content ~= "" and not new_content:match("\n$") then
        new_content = new_content .. "\n"
    end

    new_content = new_content .. PERSISTENT_ALIAS_CMD .. "\n"
    local f_write = fs.open(STARTUP_PATH, "w")

    if f_write then
        f_write.write(new_content)
        f_write.close()
        print(string.format(":: 'pacman' persistent added to %s.", STARTUP_PATH))
    else
        print(string.format("ERROR: can't write in %s for persistent.", STARTUP_PATH))
        return
    end

    shell.setAlias("pacman", pacman_path)
    return true
end

if shell and ensurePersistentAlias() then
    print(":: Alias 'pacman' created successfully.")
else
    print("WARNING: Could not create 'pacman' alias. Run: alias pacman " .. pacman_path)
end

local installer_name = fs.getName(shell.getRunningProgram())
if fs.exists(installer_name) and installer_name ~= "startup.lua" then
    fs.delete(installer_name)
    print(string.format(":: Installer file (%s) deleted.", installer_name))
end

print("-----------------------------------------")
print(" iDar-Pacman successfully installed!")
print(" Run 'pacman -Syy' to sync the database.")
print("-----------------------------------------")