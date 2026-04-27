local manifest = {}
local manifests = {}

function manifest.load(package, raw_manifest)
    local tmp_file = "/tmp/manifest_" .. package .. ".lua"
    local fd = sys.open(tmp_file, "w")

    if not fd then error("Error: cannot load file descriptor") end

    sys.write(fd, raw_manifest)
    sys.close(fd)

    local pid = sys.spawn(tmp_file)

    local died_naturally, reason = sys.wait(pid, 0.05)
    sys.delete(tmp_file)

    if not died_naturally and reason == "timeout" then
        sys.kill(pid)
        error("Error: Manifest took too long without yielding (possible malicious loop).")
    end

    local sandbox = {}
    local func, err = load(raw_manifest, nil, "t", sandbox)

    if not func then error("Error: invalid manifest syntax: " .. tostring(err)) end

    local ok, res = pcall(func)

    if not ok then error("Error: runtime error in manifest: " .. tostring(res)) end
    if type(res) ~= "table" then error("Error: manifest must return a table") end

    manifests[package] = res

    if not manifests[package] or manifests[package] == "" then error("Error: can't load manifest") return end
end

function manifest.get_directory(package_name)
    return manifests[package_name].directory or ""
end

function manifest.get_files(package_name)
    return manifests[package_name].files or {}
end

function manifest.get_dependencies(package_name)
    return manifests[package_name].dependencies or {}
end

function manifest.get_hooks(package_name)
    return manifests[package_name].hooks or {}
end

function manifest.has_hook(package_name)
    local hooks = manifests[package_name].hooks
    return hooks and #hooks > 0
end

function manifest.get_bin(package_name)
    return manifests[package_name].bin or {}
end

return manifest