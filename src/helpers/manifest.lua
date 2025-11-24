local manifest = {}
local manifests = {}

function manifest.load(package, raw_manifest)
    local sandbox = {}
    local func, err = load(raw_manifest, nil, "t", sandbox)

    if not func then error("Error: invalid manisfest: " .. err) end

    local start = os.clock()
    local function killer()
        if os.clock() - start > 0.05 then
            error("Error: manifest took too long without yielding")
        end
    end
    debug.sethook(killer, "", 10000)
    local ok, res = pcall(func)
    debug.sethook()

    if not ok then error("Error: can't execute manifest: " .. res) end
    if type(res) ~= "table" then error("Error: manifest it must be a table") end

    manifests[package] = res

    if not manifests[package] or manifests[package] == "" then error("Error: can't load manifest") return end
end

function manifest.get(package_name)
    return manifests[package_name]
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

return manifest