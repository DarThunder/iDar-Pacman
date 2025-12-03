local fs_utils = require("Pacman.utils.fs_utils")
local registry = {}

local local_db = {}
local sync_dbs = {}
local loaded = false

local LOCAL_DB_PATH = "/iDar/var/local.lua"
local SYNC_DIR = "/iDar/var/sync/"

local function load_local_db()
    if fs.exists(LOCAL_DB_PATH) then
        local content = fs_utils.read_file(LOCAL_DB_PATH)
        local func = load(content, "local_db", "t", {})
        if func then local_db = func() end
    else
        local_db = {}
    end
end

local function load_sync_dbs()
    sync_dbs = {}
    local sources = dofile("/iDar/etc/sources.lua")

    for _, source in ipairs(sources) do
        local path = fs.combine(SYNC_DIR, source.name .. ".lua")
        if fs.exists(path) then
            local content = fs_utils.read_file(path)
            local func = load(content, source.name, "t", {})
            if func then
                table.insert(sync_dbs, { name = source.name, data = func() })
            end
        end
    end
end

local function ensure_loaded()
    if not loaded then
        load_local_db()
        load_sync_dbs()
        loaded = true
    end
end

local function dump_local()
    local content = textutils.serialize(local_db)
    fs_utils.write_file(LOCAL_DB_PATH, "return " .. content)
end

function registry.reload()
    load_local_db()
    load_sync_dbs()
    loaded = true
end

function registry.get_manifest_url(package_name, version)
    ensure_loaded()
    local info = registry.get_package_info(package_name)
    if not info then error("Error: package '" .. package_name .. "' not found in any repository.") end

    local v = (info[version] or version)
    return string.format("https://raw.githubusercontent.com/%s/%s/refs/tags/%s/manifest.lua", info.dev, info.package_name, v)
end

function registry.get_package_url(package_name, version)
    ensure_loaded()
    local info = registry.get_package_info(package_name)
    if not info then error("Error: package '" .. package_name .. "' not found in any repository.") end

    local v = (info[version] or version)
    return string.format("https://raw.githubusercontent.com/%s/%s/refs/tags/%s/", info.dev, info.package_name, v)
end

function registry.get_installed_version(package_name)
    ensure_loaded()
    if not local_db[package_name] then return nil end
    return local_db[package_name].installed_version
end

function registry.get_all_packages()
    ensure_loaded()
    return local_db
end

function registry.get_all_packages_sync()
    ensure_loaded()
    local packages = {}

    for _, db_entry in ipairs(sync_dbs) do
        for name, info in pairs(db_entry.data) do
            packages[name] = info
        end
    end

    return packages
end

function registry.get_package_info(name)
    ensure_loaded()

    for _, db_entry in ipairs(sync_dbs) do
        if db_entry.data[name] then
            local info = db_entry.data[name]
            if local_db[name] then
                info.installed = true
                info.installed_version = local_db[name].version
                info.install_dir = local_db[name].install_dir
                info.dependencies = local_db[name].dependencies
                info.package_type = local_db[name].package_type
            end
            return info
        end
    end

    return local_db[name]
end

function registry.get_dependencies(package_name)
    ensure_loaded()
    if not local_db[package_name] then return {} end
    return local_db[package_name].dependencies or {}
end

function registry.get_installed_dir(package_name)
    ensure_loaded()
    if not local_db[package_name] then return {} end
    return local_db[package_name].install_dir or {}
end

function registry.set_installed(name, version, is_explicit, deps, dir)
    ensure_loaded()
    local_db[name] = {
        installed_version = version,
        package_type = is_explicit and "explicit" or "implicit",
        dependencies = deps,
        install_dir = dir,
        installed_at = os.epoch("utc")
    }
    dump_local()
end

function registry.set_uninstalled(package_name)
    ensure_loaded()
    if local_db[package_name] then
        local_db[package_name].installed = nil
        local_db[package_name].installed_version = nil
        local_db[package_name].package_type = nil
        local_db[package_name].dependencies = nil
        local_db[package_name].install_dir = nil
        dump_local()
    end
end

function registry.is_installed(package_name)
    ensure_loaded()
    return local_db[package_name] and true or false
end

return registry