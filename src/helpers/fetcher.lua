local text_utils = require("Pacman.utils.text_utils")

local fetcher = {}

local function get_checked_response(url)
    local response = http.get(url)

    if not response then error("Error: no response from the server") end

    local code = response.getResponseCode()

    if code ~= 200 then
        local status_text = response.getStatusText() or "Unknown lol"
        response.close()
        error("Error: server returned HTTP " .. code .. " (" .. status_text .. ").")
    end

    return response
end

function fetcher.download_raw_progress(name, url)
    local response = get_checked_response(url)

    local content = {}
    local total = tonumber(response.getResponseHeaders()["content-length"])
    local downloaded = 0
    local start_time = os.clock()

    while true do
        local chunk = response.read(2048)
        if not chunk then break end

        downloaded = downloaded + #chunk
        table.insert(content, chunk)

        text_utils.render_progress(name, downloaded, total, start_time)
        os.sleep(0.1 + math.random() * 0.3)
    end
    local x, y = term.getCursorPos()
    term.setCursorPos(1, y + 1)

    response.close()

    return table.concat(content)
end

function fetcher.download_raw(url)
    local response = get_checked_response(url)

    local content = response.readAll()
    response.close()

    if not content or content == "" then error("Error: empty response from server.") end

    return content
end

function fetcher.download_packages(url, file_list)
    local raw_files = {}

    for index, file in ipairs(file_list) do
        raw_files[index] = fetcher.download_raw_progress(file, url .. file)
    end

    return raw_files
end

return fetcher