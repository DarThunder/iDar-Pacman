local fs_utils = require("Pacman.utils.fs_utils")
local manifest = require("Pacman.helpers.manifest")
local fake_root = require("Pacman.helpers.fake_root")
local registry = require("Pacman.helpers.registry")

local installer = {}

function installer.install_package(package, raw_files, session_id, is_explicit)
    local name = package.name
    local version = package.version

    local staging_dir = "/iDar/tmp/" .. session_id .. "/root"
    local manifest_files = manifest.get_files(name)

    for file_index, file_content in ipairs(raw_files) do
        local real_rel_path = fs_utils.combine("iDar", manifest.get_directory(name) .. "/" .. manifest_files[file_index])
        local temp_path = fs_utils.combine(staging_dir, real_rel_path)
        fs_utils.write_file(temp_path, file_content)
    end

    if manifest.has_hook(name) then
        print(":: Running post-installation hooks...")
        local hooks = manifest.get_hooks(name)

        for i, hook in ipairs(hooks) do
            print(string.format("(%d/%d) %s...", i, #hooks, hook.name))
            local ok, err = fake_root.run_hook(hook.script, session_id)
            if not ok then
                return false, "Hook failed: " .. err
            end
        end
    end

    fake_root.commit(session_id, manifest.get_directory(name))

    local deps = manifest.get_dependencies(name)
    local installed_version = registry.get_package_info(name)[version] or version

    for _, dep in ipairs(deps) do
        dep.version = registry.get_package_info(dep.name).latest or dep.version
    end

    registry.set_installed(
        name,
        installed_version,
        is_explicit,
        deps,
        manifest.get_directory(name)
    )

    return true
end

function installer.remove_package(targets)
    if #targets == 0 then return end

    print(":: Packages to remove (" .. #targets .. "): " .. table.concat(targets, " "))

    term.write(":: Do you want to remove these packages? [Y/n] ")
    local input = read()
    if input:lower() == "n" then
        print("Error: operation canceled")
        return
    end

    for _, name in ipairs(targets) do
            print("removing " .. name .. "...")

            local dir = registry.get_installed_dir(name)
            local full_path = fs_utils.combine("iDar", dir)

            if fs.exists(full_path) then
                fs.delete(full_path)
                print("  -> deleted " .. full_path)
            end

            registry.set_uninstalled(name)
    end
    print(":: Processing package changes...")
    print("(1/1) purging core cache...")
end

return installer