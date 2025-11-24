local fs_utils = require("Pacman.utils.fs_utils")

local installer = {}

function installer.install_package(pkg)
    for path, package in pkg do
        fs_utils.write_file(path, package)
    end
end

return installer