local fetcher = require("Pacman.helpers.fetcher")
local registry = require("Pacman.helpers.registry")
local manifest = require("Pacman.helpers.manifest")
local text_utils = require("Pacman.utils.text_utils")
local fs_utils = require("Pacman.utils.fs_utils")
local solver = require("Pacman.helpers.solver")
local fake_root = require("Pacman.helpers.fake_root")
local installer = require("Pacman.helpers.installer")

local pacman = {}

local function fetch_manifest_deps(name, version)
    local url = registry.get_manifest_url(name, version)
    local success, raw_manifest = text_utils.run_safe(fetcher.download_raw, "Error: can't download manifest of package '" .. name .. "'.", url)

    if not success then return false end

    success, _ = text_utils.run_safe(manifest.load, "Error: can't load manifest of package '" .. name .. "'.", name, raw_manifest)

    if not success then return false end

    if registry.is_installed(name) and registry.get_installed_version(name) == version then
        print("warning: " .. name .. " is up to date -- reinstalling")
        os.sleep(0.1)
    end

    return manifest.get_dependencies(name)
end

function pacman.update()
    local sources = dofile("/iDar/etc/sources.lua")

    if not fs.exists("/iDar/var/sync") then fs.makeDir("/iDar/var/sync") end

    local sync_ok = true

    for _, source in ipairs(sources) do
        local db_path = fs_utils.combine("/iDar/var/sync", source.name .. ".lua")
        local sum_path = fs_utils.combine("/iDar/var/sync", source.name .. ".sum")
        local success, remote_sum = text_utils.run_safe(fetcher.download_raw, "Error: can't fetch database checksum.", source.checksum)

        if not success or not remote_sum then 
            sync_ok = false
            goto continue_loop
        end

        remote_sum = remote_sum:gsub("%s+", "")
        local local_sum = fs_utils.read_file(sum_path)

        if local_sum then local_sum = local_sum:gsub("%s+", "") end
        if local_sum == remote_sum and fs.exists(db_path) then
            print(" " .. source.name .." is up to date ")
            goto continue_loop
        end

        local success, content = text_utils.run_safe(fetcher.download_raw_progress, "Error fetching " .. source.name, source.name, source.url)

        if success then
            fs_utils.write_file(db_path, content)
            fs_utils.write_file(sum_path, remote_sum)
        else
            sync_ok = false
        end

        ::continue_loop::
    end

    registry.reload()
    return sync_ok
end

function pacman.install(initial_targets)
    local explicit_map = {}
    for _, t in ipairs(initial_targets) do
        explicit_map[t.name] = true
    end
    local dependency_map = {}
    local to_scan = {}

    for _, t in ipairs(initial_targets) do
        table.insert(to_scan, t)
    end

    print(":: Resolving dependencies...")
    local i = 1

    while i <= #to_scan do
        local pkg = to_scan[i]
        local name = pkg.name

        if not dependency_map[name] then
            local deps = fetch_manifest_deps(name, pkg.version)

            if not deps then return false end

            dependency_map[name] = {
                name = name,
                version = pkg.version,
                deps = {}
            }

            for _, dep in ipairs(deps) do
                table.insert(dependency_map[name].deps, dep.name)
                table.insert(to_scan, {name = dep.name, version = dep.version})
            end
        end
        i = i + 1
    end

    local graph_input = {}

    for _, data in pairs(dependency_map) do
        table.insert(graph_input, data)
    end

    local packages_sorted, err = solver.solve_dependencies(graph_input)

    if not packages_sorted then
        print("Error: " .. err)
        return false
    end

    local pkg_list = {}

    for _, pkg in ipairs(packages_sorted) do
        table.insert(pkg_list, pkg.name .. "-" .. (pkg.version or "latest"))
    end

    print("\nPackages (" .. #packages_sorted .. ") " .. table.concat(pkg_list, "  "))
    term.write("\n:: Proceed with installation? [Y/n] ")
    local input = read()

    if input:lower() == "n" then
        print("\nError: operation canceled")
        return false
    end

    local session_id = tostring(math.random(1000000))

    print("\n:: Getting the packages...")

    for _, package in ipairs(packages_sorted) do
        local name = package.name
        local version = package.version
        local url = registry.get_package_url(name, version)
        local manifest_files = manifest.get_files(name)

        local success, raw_files = text_utils.run_safe(fetcher.download_packages, "Error: can't download files of package '" .. package.name .. "'.", url, manifest_files)

        if not success or not raw_files then
            fake_root.rollback(session_id)
            return false
        end

        local is_explicit = explicit_map[package.name] ~= nil
        success, err = text_utils.run_safe(installer.install_package, "Error installing package '" .. name .. "'.", package, raw_files, session_id, is_explicit)

        if not success then
            fake_root.rollback(session_id)
            return false
        end
    end

    fake_root.rollback(session_id)

    return true
end

function pacman.upgrade()
    local to_update = {}

    local db = registry.get_all_packages()

    for name, info in pairs(db) do
        local current = info.installed_version
        local latest = registry.get_package_info(name).latest

        if current ~= latest then
            print("Update available for " .. name .. ": " .. current .. " -> " .. latest)
            table.insert(to_update, {name = name, version = latest})
        end
    end

    if #to_update > 0 then
        pacman.install(to_update)
    else
        print("Nothing to do.")
    end
end

function pacman.remove(targets, keep_deps)
    print(":: checking dependencies...")
    local to_remove = {}
    local to_remove_set = {}
    local dep_candidates = {}

    for _, pkg_name in ipairs(targets) do
        if registry.is_installed(pkg_name) then
            table.insert(to_remove, pkg_name)
            to_remove_set[pkg_name] = true

            local info = registry.get_package_info(pkg_name)
            local deps = info.dependencies or {}

            for _, dep in ipairs(deps) do
                dep_candidates[dep.name] = true
            end
        end
    end

    if not keep_deps then
        for dep_name, _ in pairs(dep_candidates) do
            local is_used = false

            for other_pkg, other_info in pairs(registry.get_all_packages()) do
                if not to_remove_set[other_pkg] then
                    local other_deps = other_info.dependencies or {}
                    for _, other_dep in ipairs(other_deps) do
                        if other_dep.name == dep_name then
                            is_used = true
                            break
                        end
                    end
                end
                if is_used then break end
            end

            if not is_used then
                if not to_remove_set[dep_name] then
                    table.insert(to_remove, dep_name)
                    to_remove_set[dep_name] = true
                end
            end
        end
    end

    return installer.remove_package(to_remove)
end

function pacman.search(query)
    local db = registry.get_all_packages()
    local found = false

    for name, info in pairs(db) do
        if name:find(query) then
            local status = info.installed and " [installed]" or ""
            local version = info[info.installed_version] or info.installed_version or info.latest

            print("core/" .. name .. " " .. version .. status)
            found = true
        end
    end

    if not found then
        print("Error: no targets found: " .. query)
    end
end

function pacman.list()
    local db = registry.get_all_packages()
    for name, info in pairs(db) do
        print(name .. " " .. (info.installed_version or "unknown"))
    end
end

function pacman.list_orphans()
    local orphans = {}
    local all_packages = registry.get_all_packages()

    for pkg_name, info in pairs(all_packages) do
        if info.package_type == "implicit" then
            local is_orphan = true

            for _, other_info in pairs(all_packages) do
                local deps = other_info.dependencies or {}
                    for _, dep in ipairs(deps) do
                        if dep.name == pkg_name then
                            is_orphan = false
                            break
                        end
                    end
                if not is_orphan then break end
            end

            if is_orphan then
                table.insert(orphans, pkg_name)
            end
        end
    end

    for _, name in pairs(orphans) do
        print(name .. " " .. (all_packages[name][registry.get_installed_version(name)] or registry.get_installed_version(name)))
    end
end

return pacman
