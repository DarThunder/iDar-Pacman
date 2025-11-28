local fakeroot = {}

local TIMEOUT = 5

local function create_sandbox_env(temp_dir)
    local sandbox_env = {}

    sandbox_env.print = print
    sandbox_env.table = table
    sandbox_env.string = string
    sandbox_env.math = math
    sandbox_env.pairs = pairs
    sandbox_env.ipairs = ipairs
    sandbox_env.type = type
    sandbox_env.tostring = tostring
    sandbox_env.fs = {
        list = function(path) return fs.list(fs.combine(temp_dir, path)) end,
        exists = function(path) return fs.exists(fs.combine(temp_dir, path)) end,
        isDir = function(path) return fs.isDir(fs.combine(temp_dir, path)) end,
        makeDir = function(path) return fs.makeDir(fs.combine(temp_dir, path)) end,
        delete = function(path) return fs.delete(fs.combine(temp_dir, path)) end,
        open = function(path, mode)
            local safe_path = fs.combine(temp_dir, path)
            return fs.open(safe_path, mode)
        end,
        combine = fs.combine,
        getName = fs.getName
    }

    return sandbox_env
end

function fakeroot.run_hook(script_content, session_id)
    local temp_base = "/iDar/tmp/" .. session_id
    if not fs.exists(temp_base) then fs.makeDir(temp_base) end

    local env = create_sandbox_env(temp_base)
    local func, err = load(script_content, "post_install", "t", env)

    if not func then return false, "Syntax Error: " .. err end

    local start_time = os.clock()
    local function watchdog()
        if os.clock() - start_time > TIMEOUT then
            error("Error: Hook timed out (" .. TIMEOUT .. "s limit)")
        end
    end

    debug.sethook(watchdog, "", 10000)
    local ok, res = pcall(func)
    debug.sethook()

    if not ok then
        return false, res
    end

    return true
end

function fakeroot.commit(session_id, install_dir)
    local source_path = "/iDar/tmp/" .. session_id .. "/root/iDar/" .. install_dir
    local dest_path = "/iDar/" .. install_dir

    if fs.exists(dest_path) then
        fs.delete(dest_path)
    end

    if fs.exists(source_path) then
         fs.move(source_path, dest_path)
    end

    local session_root = "/iDar/tmp/" .. session_id
    fs.delete(session_root)
end

function fakeroot.rollback(session_id)
    local temp_path = "/iDar/tmp/" .. session_id
    if fs.exists(temp_path) then
        fs.delete(temp_path)
    end
end

return fakeroot