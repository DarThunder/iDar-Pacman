local text_utils = {}

function text_utils.run_safe(func_to_run, error_message_base, ...)
    local success, result = pcall(func_to_run, ...)

    if not success then
        print("Error: " .. error_message_base)
        print("Datails: " .. tostring(result))
        return false
    end

    return true, result
end

function text_utils.render_progress(name, downloaded, total, start_time)
    name = name:match("([^/]+)$") or name
    name = name:gsub("%.lua$", "")
    local elapsed = os.clock() - start_time
    local speed = downloaded / math.max(elapsed, 0.001)
    local max_name_len = 12

    if #name > max_name_len then
        name = string.sub(name, 1, max_name_len - 3) .. "..."
    end

    local output_str = ""

    if total and total > 0 then
        local bar_length = 20
        local ratio = downloaded / total

        if ratio > 1 then ratio = 1 end

        local filled = math.floor(ratio * bar_length)
        local empty = bar_length - filled
        local bar = string.rep("#", filled) .. string.rep("-", empty)
        local percent = math.floor(ratio * 100)
        output_str = string.format(
            "%-12s [%s] %3d%% %6.1fKB/s",
            name, bar, percent, speed / 1024
        )
    else
        output_str = string.format(
            "%-12s [ <=> ] %5dKB %6.1fKB/s",
            name, math.floor(downloaded / 1024), speed / 1024
        )
    end

    local x, y = term.getCursorPos()
    term.setCursorPos(1, y)
    term.clearLine()
    term.write(output_str)
end

return text_utils