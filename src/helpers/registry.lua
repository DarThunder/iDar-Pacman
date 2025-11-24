local fs_utils = require("Pacman.utils.fs_utils")

local registry = {}
local db = nil

local REGISTRY_PATH = "/iDar/var/registry.lua"

local function load_registry_db()
    local content = fs_utils.read_file(REGISTRY_PATH)

    if not content or content == "" then error("Error: can't read registries db.") end

    db = load(content)()

    if not db or db == "" then error("Error: can't load registries db.") end
end

local function ensure_db()
    if not db then
        load_registry_db()
        if not db then error("Error: Database not found. Run 'pacman -Syy' first.") end
    end
end

local function dump()
    if not db then return end
    local content = textutils.serialize(db)
    fs_utils.write_file(REGISTRY_PATH, "return " .. content)
end

function registry.update(new_registry_raw)
    if not new_registry_raw or new_registry_raw == "" then error("New registry DB is empty") end

    local func = load(new_registry_raw, "new_registry", "t", {})

    if not func then error("Error: Invalid registry format from server.") end

    local new_db = func()
    ensure_db()

    if db then
        for pkg_name, old_data in pairs(db) do
            if old_data.installed then
                if new_db[pkg_name] then
                    new_db[pkg_name].installed = true
                    new_db[pkg_name].installed_version = old_data.installed_version
                end
            end
        end
    end

    db = new_db
    dump()
end

function registry.get_manifest_url(package_name, version)
    ensure_db()
    local info = db[package_name]
    if not info then error("Error: package not found") end

    local v = (info[version] or version)
    return string.format("https://raw.githubusercontent.com/%s/%s/refs/tags/%s/manifest.lua", info.dev, info.package_name, v)
end

function registry.get_package_url(package_name, version)
    ensure_db()
    local info = db[package_name]
    if not info then error("Error: package not found") end

    local v = (info[version] or version)
    return string.format("https://raw.githubusercontent.com/%s/%s/refs/tags/%s/", info.dev, info.package_name, v)
end

function registry.get_installed_version(package_name)
    ensure_db()
    if not db[package_name] then return nil end
    return db[package_name].installed_version
end

function registry.get_all_packages()
    ensure_db()
    return db
end

function registry.get_package_info(name)
    ensure_db()
    return db[name]
end

function registry.set_installed(package_name, version_installed)
    ensure_db()
    if not db[package_name] then error("Error: package not found") end

    db[package_name].installed = true
    db[package_name].installed_version = version_installed
    dump()
end

function registry.set_uninstalled(package_name)
    ensure_db()
    if db[package_name] then
        db[package_name].installed = nil
        db[package_name].installed_version = nil
        dump()
    end
end

function registry.is_installed(package_name)
    ensure_db()
    if not db[package_name] then error("Error: package not found") end
    return db[package_name].installed
end

return registry