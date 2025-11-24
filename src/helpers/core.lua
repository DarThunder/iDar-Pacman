local fetcher = require("Pacman.helpers.fetcher")
local registry = require("Pacman.helpers.registry")
local manifest = require("Pacman.helpers.manifest")
local text_utils = require("Pacman.utils.text_utils")
local fs_utils = require("Pacman.utils.fs_utils")

local pacman = {}
local REGISTRY_URL = "https://raw.githubusercontent.com/DarThunder/iDar-Pacman-DB/main/registry.lua"
local REGISTRY_CACHE = "/iDar/var/registry.cache"

function pacman.update()
    local last_remote_db = fs_utils.read_file(REGISTRY_CACHE) or ""
    local success, raw_binary = text_utils.run_safe(fetcher.download_raw, "Error: can't download the database.", REGISTRY_URL)

    if not success or not raw_binary then return false end
    if last_remote_db == raw_binary then
        print(" core is up to date")
    else
        print(" downloading core...")
        fs_utils.write_file(REGISTRY_CACHE, raw_binary)
        registry.update(raw_binary)
    end
end

function pacman.install(packages)
    print(":: Resolving dependencies...")
    for _, package in ipairs(packages) do
        local name = package.name
        local version = package.version
        local url = registry.get_manifest_url(name, version)
        local success, raw_manifest = text_utils.run_safe(fetcher.download_raw, "Error: can't download manifest of package '" .. name .. "'.", url)

        if not success then return false end

        success, _ = text_utils.run_safe(manifest.load, "Error: can't load manifest of package '" .. name .. "'.", name, raw_manifest)

        if not success then return false end

        if registry.is_installed(name) and registry.get_installed_version(name) == version then
            print("warning: " .. name .. " is up to date -- reinstalling")
            os.sleep(0.1)
        end

        for _, dependencie in ipairs(manifest.get_dependencies(name)) do
            if not packages[dependencie.name] then
                if not registry.is_installed(dependencie.name) then
                    table.insert(packages, {version = dependencie.version, name = dependencie.name})
                    packages[dependencie.name] = true
                end
            end
        end
    end

    local pkg_list = {}

    for _, pkg in ipairs(packages) do
        table.insert(pkg_list, pkg.name .. "-" .. (pkg.version or "latest"))
    end

    print("") 
    print("Packages (" .. #packages .. ") " .. table.concat(pkg_list, "  "))
    print("")

    term.write(":: Proceed with installation? [Y/n] ")
    local input = read()

    if input:lower() == "n" then
        print("")
        print("error: operation canceled")
        return false
    end

    print("")

    print(":: Getting the packages...")
    for _, package in ipairs(packages) do
        local name = package.name
        local version = package.version
        local url = registry.get_package_url(name, version)
        local manifest_files = manifest.get_files(name)
        local success, raw_files = text_utils.run_safe(fetcher.download_packages, "Error: can't download files of package '" .. package.name .. "'.", url, manifest_files)

        if not success or not raw_files then return false end

        registry.set_installed(name, version)
        for file_index, file in ipairs(raw_files) do
            fs_utils.write_file(fs_utils.combine("iDar", manifest.get_directory(name) .. "/" .. manifest_files[file_index]), file)
        end
    end

    print("Installation complete!")
end

function pacman.upgrade()
    local to_update = {}

    local db = registry.get_all_packages()

    for name, info in pairs(db) do
        if info.installed then
            local current = info.installed_version
            local latest = info.latest

            if current ~= latest and current ~= "latest" then
                print("Update available for " .. name .. ": " .. current .. " -> " .. latest)
                table.insert(to_update, {name = name, version = latest})
            end
        end
    end

    if #to_update > 0 then
        pacman.install(to_update)
    else
        print("Nothing to do.")
    end
end

function pacman.remove(targets)
    if #targets == 0 then return end

    print(":: checking dependencies...")
    -- TODO later (maybe lmao)

    print(":: Packages to remove (" .. #targets .. "): " .. table.concat(targets, " "))

    term.write(":: Do you want to remove these packages? [Y/n] ")
    local input = read()
    if input:lower() == "n" then
        print("error: operation canceled")
        return
    end

    for _, name in ipairs(targets) do
        if not registry.is_installed(name) then
            print("error: target not found: " .. name)
        else
            print("removing " .. name .. "...")

            local info = registry.get_package_info(name)
            local dir = info.directory or name
            local full_path = fs_utils.combine("iDar", dir)

            if fs.exists(full_path) then
                fs.delete(full_path)
                print("  -> deleted " .. full_path)
            end

            registry.set_uninstalled(name)
        end
    end
    print(":: Processing package changes...")
    print("(1/1) purging core cache...")
end

function pacman.search(query)
    local db = registry.get_all_packages()
    local found = false

    for name, info in pairs(db) do
        if name:find(query) then
            local status = info.installed and " [installed]" or ""
            local version = info.version or "latest"

            print("core/" .. name .. " " .. version .. status)
            found = true
        end
    end

    if not found then
        print("error: no targets found: " .. query)
    end
end

function pacman.info()
    local db = registry.get_all_packages()
    for name, info in pairs(db) do
        if info.installed then
            print(name .. " " .. (info.installed_version or "unknown"))
        end
    end
end

return pacman
