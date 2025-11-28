package.path = "/iDar/?.lua;/iDar/?/init.lua;" .. package.path
local core = require("Pacman.helpers.core")

local args = { ... }
local flag = args[1]

local function printUsage()
    print([[
iDar-Pacman Alpha v1.0
Usage: pacman <operation> [packages]

Operations:
  -S   <packages>  Install specific packages
  -Syy             Synchronize package databases
  -Syu             Perform full system upgrade
  -Ss  <query>     Search for packages
  -R   <packages>  Remove packages
  -Q               List installed packages
]])
end

local function parsePackage(package)
    local name, version = package:match("^([%w%-_]+):([%d%.]+)$")

    return {name = name or package, version = version or "latest"}
end

if not flag then
    printUsage()
    return
end

local targets = {}
for i = 2, #args do
    table.insert(targets, parsePackage(args[i]))
end

if flag == "-S" then
    if #targets == 0 then
        print("Error: Faltan argumentos.")
        print("Uso: pacman -S nombre_paquete")
        return
    end

    core.install(targets)

elseif flag == "-Syy" then
    print(":: Synchronizing package databases...")
    core.update()

elseif flag == "-Syu" then
    print(":: Synchronizing package databases...")
    core.update()
    print(":: Starting full system update...")
    core.upgrade()
    if #targets >= 1 then core.install(targets) end

elseif flag == "-Ss" then
    local query = args[2]
    if not query then
        print("Error: No search query specified.")
        return
    end
    core.search(query)

elseif flag == "-R" then
    local targets_to_remove = {}
    for i = 2, #args do
        table.insert(targets_to_remove, args[i])
    end

    if #targets_to_remove == 0 then
        print("Error: No target specified.")
        return
    end
    core.remove(targets_to_remove, true)

elseif flag == "-Rns" then
    local targets_to_remove = {}
    for i = 2, #args do
        table.insert(targets_to_remove, args[i])
    end

    if #targets_to_remove == 0 then
        print("Error: No target specified.")
        return
    end
    core.remove(targets_to_remove, false)

elseif flag == "-Q" then
    core.list()

elseif flag == "-Qtdq" then
    core.list_orphans()

else
    print("Error: Flag '" .. flag .. "' invalida.")
    printUsage()
end