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
    sandbox_env.sys = {
        list = function(path) return sys.list(sys.combine(temp_dir, path)) end,
        exists = function(path) return sys.exists(sys.combine(temp_dir, path)) end,
        isDir = function(path) return sys.is_dir(sys.combine(temp_dir, path)) end,
        makeDir = function(path) return sys.mkdir(sys.combine(temp_dir, path)) end,
        delete = function(path) return sys.delete(sys.combine(temp_dir, path)) end,
        open = function(path, mode)
            local safe_path = sys.combine(temp_dir, path)
            return sys.open(safe_path, mode)
        end,
        combine = sys.combine,
        getName = sys.getName
    }

    return sandbox_env
end

function fakeroot.run_hook(script_content, session_id)
    local temp_base = "/tmp/" .. session_id
    if not sys.exists(temp_base) then sys.mkdir(temp_base) end

    local tmp_file = "/tmp/hook_" .. session_id .. ".lua"
    local fd = sys.open(tmp_file, "w")

    if not fd then error("Error: cannot load file descriptor") end

    sys.write(fd, script_content)
    sys.close(fd)

    local pid = sys.spawn(tmp_file)

    local died_naturally, reason = sys.wait(pid, 5)
    sys.delete(tmp_file)

    if not died_naturally and reason == "timeout" then
        sys.kill(pid)
        error("Error: Hook took too long without yielding (possible malicious loop).")
    end

    local env = create_sandbox_env(temp_base)
    local func, err = load(script_content, "post_install", "t", env)

    if not func then return false, "Syntax Error: " .. err end

    local ok, res = pcall(func)

    if not ok then
        return false, res
    end

    return true
end

function fakeroot.commit(session_id, install_dir, bin)
    local source_path = "/tmp/" .. session_id .. "/root/" .. install_dir
    local dest_path = (#bin > 0 and "/opt/" or "/lib/") .. install_dir

    if sys.exists(dest_path) then
        sys.delete(dest_path)
    end

    if sys.exists(source_path) then
         sys.move(source_path, dest_path)
    end

    local session_root = "/tmp/" .. session_id
    sys.delete(session_root)
end

function fakeroot.rollback(session_id)
    local temp_path = "/tmp/" .. session_id
    if sys.exists(temp_path) then
        sys.delete(temp_path)
    end
end

return fakeroot