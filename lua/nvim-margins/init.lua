require('nvim-margins.utils.result')

vim.keymap.set("n", "<leader>m", ":messages<CR>")

local function create_array(length, value)
    local output = {}
    for i = 1, length do
        output[i] = value
    end
    return output
end

local function create_string(length)
    local output = ""
    for _ = 1, length do
        output = output .. " "
    end
    return output
end

local function get_draw_padding(side)
    return function(buffer_id)
        vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {}) -- clear buffer

        local width = vim.api.nvim_win_get_width(0)
        local height = vim.api.nvim_win_get_height(0)

        local display = side .. ", width: " .. width .. ", height: " .. height

        local text_height = math.floor(height / 2)
        local start = math.floor(width / 2) - math.floor(#display / 2)

        vim.api.nvim_buf_set_lines(buffer_id, 0, 0, false, create_array(text_height - 1, ""))
        vim.api.nvim_buf_set_lines(buffer_id, text_height, text_height, false, {
            create_string(start) .. display
        })
    end
end

local M = {
    options = {
        max_width = 150,
        draw_left_padding = get_draw_padding("left"),
        draw_right_padding = get_draw_padding("right"),
    }
}

local function get_tab_state()
    return {
        left_buffer = nil,
        left_window = nil,
        right_buffer = nil,
        right_window = nil,
    }
end

local state = get_tab_state()

local function get_window_options(side)
    return {
        width = 10,
        focusable = false,
        style = "minimal",
        vertical = true,
        split = side,
        noautocmd = true,
        win = -1,
    }
end

--- @return Result
local function create_sidebars()
    -- escape if this setup is done already
    if state.left_window ~= nil and state.right_window ~= nil then
        return Ok("Nothing to create")
    end

    local current_window_result = Wrap(vim.api.nvim_get_current_win)
    if current_window_result.is_error then return current_window_result end

    -- create buffers

    if state.left_buffer == nil then
        local buf_result = Wrap(vim.api.nvim_create_buf, false, true)
        buf_result:match(
            function(value)
                state.left_buffer = value
            end,
            function(error)
                state.left_buffer = nil
                print(error)
            end
        )
    end

    if state.right_buffer == nil then
        local buf_result = Wrap(vim.api.nvim_create_buf, false, true)
        buf_result:match(
            function(value)
                state.right_buffer = value
            end,
            function(error)
                state.right_buffer = nil
                print(error)
            end
        )
    end

    -- create windows

    if state.left_window == nil then
        local window_result = Wrap(vim.api.nvim_open_win, state.left_buffer, false, get_window_options("left"))
        if window_result.is_error then return window_result end
        state.left_window = window_result.value
    end

    if state.right_window == nil then
        local window_result = Wrap(vim.api.nvim_open_win, state.right_buffer, false, get_window_options("right"))
        if window_result.is_error then return window_result end
        state.right_window = window_result.value
    end

    -- don't select windows just created
    current_window_result:match_ok(function(value)
        local success = Wrap(vim.api.nvim_set_current_win, value)
        if success.is_error then return success end
    end)

    return Ok("Success")
end

--- close the windows if the last user window was closed
local function close_sidebars()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    local other_window = false
    for _, win in ipairs(windows) do
        if win ~= state.left_window and win ~= state.right_window then
            other_window = true
            break
        end
    end
    if other_window == false then
        vim.api.nvim_win_close(state.left_window, true)
        vim.api.nvim_win_close(state.right_window, true)
        return
    end
end

local function get_first_row(layout)
    if type(layout) ~= "table" then return nil end

    if layout[1] == "row" then
        -- remove window paddings
        local temp_layout = {}

        for _, window in ipairs(layout[2]) do
            if window[2] ~= state.left_window and
                window[2] ~= state.right_window
            then
                table.insert(temp_layout, window)
            end
        end

        if #temp_layout == 1 then
            layout = get_first_row(temp_layout)
        else
            layout[2] = temp_layout
        end

        return layout
    end

    if type(layout[1]) == "string" then
        return get_first_row(layout[2])
    end

    for _, window in ipairs(layout) do
        local row = get_first_row(window)
        if row ~= nil then return row end
    end

    return nil
end

local function get_editor_width()
    local layout = vim.fn.winlayout()

    local row = get_first_row(layout)

    -- get the number of splits
    local splits = 1
    if row ~= nil and row[1] == "row" then
        splits = #row[2]
    end

    return M.options.max_width * splits
end

local function set_window_width()
    -- create sidebars if they don't exist
    if state.left_window == nil or state.right_window == nil then
        local error = create_sidebars()
        if error ~= nil then return "error creating sidebars: " .. error end
    end

    -- TODO: this does not work
    -- close_sidebars()

    -- calc the widths
    local columns = vim.o.columns
    local window_columns = math.floor((columns - get_editor_width()) / 2)
    if window_columns < 0 then window_columns = 0 end

    -- set the size of the sidebars

    local error = nil
    error = vim.api.nvim_win_set_width(state.left_window, window_columns)
    if error ~= nil then return "error: could not set left window width" end
    vim.api.nvim_win_call(state.left_window, function()
        M.options.draw_left_padding(state.left_buffer)
    end)

    error = vim.api.nvim_win_set_width(state.right_window, window_columns)
    if error ~= nil then return "error: could not set right window width" end
    vim.api.nvim_win_call(state.right_window, function()
        M.options.draw_right_padding(state.right_buffer)
    end)
end

local function on_window_closed(window_id)
    if window_id == state.right_window then
        state.right_window = nil
        state.right_buffer = nil
    end

    if window_id == state.left_window then
        state.left_window = nil
        state.left_buffer = nil
    end
end

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.options, opts or {})

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        callback = function(event)
            on_window_closed(tonumber(event.file))
        end
    })

    -- setup autocmd for when window is resized
    vim.api.nvim_create_autocmd({ "VimEnter", "VimResized", "WinEnter", "WinResized", "WinClosed" }, {
        callback = function()
            xpcall(function()
                local create_sidebars_result = create_sidebars()
                if create_sidebars_result.is_error then print("error creating sidebars:", create_sidebars_result.message) end

                local set_window_result = set_window_width()
                if set_window_result ~= nil then print("error setting window width\n", set_window_result) end
            end, function(error) print(error) end)
        end
    })
end

return M
