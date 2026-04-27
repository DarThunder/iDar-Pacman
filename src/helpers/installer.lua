local fs_utils = require("opt.Pacman.utils.fs_utils")
local manifest = require("opt.Pacman.helpers.manifest")
local fake_root = require("opt.Pacman.helpers.fake_root")
local registry = require("opt.Pacman.helpers.registry")

local installer = {}

function installer.install_package(package, raw_files, session_id, is_explicit)
    local name = package.name
    local version = package.version
    local bin = manifest.get_bin(name)

    local staging_dir = "/tmp/" .. session_id .. "/root"

    for local_path, file_content in pairs(raw_files) do
        local real_rel_path = manifest.get_directory(name) .. "/" .. local_path
        local temp_path = fs_utils.combine(staging_dir, real_rel_path)
        
        local folder = sys.get_dir(temp_path)
        if not sys.exists(folder) then sys.mkdir(folder) end
        
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

    fake_root.commit(session_id, manifest.get_directory(name), bin)

    for cmd, rel_path in pairs(bin) do
        local ptr_path = "/bin/" .. cmd .. ".ptr"
        local full_path = "/opt/" .. manifest.get_directory(name) .. "/" .. rel_path
        local fd = sys.open(ptr_path, "w")
        if fd then
            sys.write(fd, full_path)
            sys.close(fd)
        end
    end

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
        (#bin > 0 and "/opt/" or "/lib/") .. manifest.get_directory(name),
        bin
    )

    return true
end

function installer.remove_package(targets)
    if #targets == 0 then return end

    print(":: Packages to remove (" .. #targets .. "): " .. table.concat(targets, " "))

    local input = read(":: Do you want to remove these packages? [Y/n] ", colors.white, {})
    if input:lower() == "n" then
        print("Error: operation canceled")
        return
    end

    for _, name in ipairs(targets) do
            print("removing " .. name .. "...")

            local dir = registry.get_installed_dir(name)

            if sys.exists(dir) then
                sys.delete(dir)
                print("  -> deleted " .. dir)
            end

            local bin = registry.get_installed_bin(name)
            for cmd, _ in pairs(bin) do
                local ptr_path = "/bin/" .. cmd .. ".ptr"
                if sys.exists(ptr_path) then
                    sys.delete(ptr_path)
                end
            end

            registry.set_uninstalled(name)
    end
    print(":: Processing package changes...")
    print("(1/1) purging core cache...")
end

return installer