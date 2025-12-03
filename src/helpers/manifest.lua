local manifest = {}
local manifests = {}

local function flatten_paths(tree)
    local result = {}

    local function traverse(node, path)
        for key, value in pairs(node) do
            if type(key) == "string" then
                local current_path = path .. key .. "/"

                if type(value) == "table" then
                    traverse(value, current_path)
                else
                    table.insert(result, current_path .. value)
                end
            end
        end

        if type(node) == "table" then
            for i = 1, #node do
                local item = node[i]
                if type(item) == "string" then
                    table.insert(result, path .. item)
                end
            end
        end
    end

    traverse(tree, "")
    return result
end

function manifest.load(package, raw_manifest)
    local sandbox = {}
    local func, err = load(raw_manifest, nil, "t", sandbox)

    if not func then error("Error: invalid manifest: " .. err) end

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

function manifest.get_directory(package_name)
    return manifests[package_name].directory or ""
end

function manifest.get_files(package_name)
    local files = manifests[package_name].files or {}
    return flatten_paths(files)
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

return manifest