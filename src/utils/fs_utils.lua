local fs_utils = {}

function fs_utils.read_file(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    return content
end

function fs_utils.write_file(path, content)
    local f = fs.open(path, "w")
    f.write(content)
    f.close()
end

function fs_utils.combine(base_path, local_path)
    return fs.combine(base_path, local_path)
end

return fs_utils