local fs_utils = {}

function fs_utils.read_file(path)
    if not sys.exists(path) then return nil end
    local fd = sys.open(path, "r")

    if not fd then return end

    local content = sys.read(fd)
    sys.close(fd)
    return content
end

function fs_utils.write_file(path, content)
    local fd = sys.open(path, "w")

    if not fd then return end

    sys.write(fd, content)
    sys.close(fd)
end

function fs_utils.combine(base_path, local_path)
    return sys.combine(base_path, local_path)
end

return fs_utils