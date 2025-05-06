vim.keymap.set("n", "<leader>m", ":messages<CR>")

local M = {}

local function draw_buffer(side, buffer_id)
    vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {}) -- clear the whole buffer

    local width = vim.api.nvim_win_get_width(0)
    local height = vim.api.nvim_win_get_height(0)
    local text_height = math.floor(height / 2)
    vim.api.nvim_buf_set_lines(buffer_id, text_height, text_height, false, { side, "width: "..width })
    -- vim.api.nvim_buf_set_text(buffer_id, 5, left_side, 5, left_side, { side })
end

local default_options = {
    max_width = 1000,
    sidebar_width_percent = 25,
    draw_buffer = draw_buffer,
}

local state = {
    left_buffer = nil,
    left_window = nil,
    right_buffer = nil,
    right_window = nil,
}

local function get_window_options(side)
    return {
        width = 10,
        focusable = false,
        style = "minimal",
        vertical = true,
        split = side,
        noautocmd = true
    }
end

local function create_sidebars()
    -- escape if this setup is done already
    if state.left_window ~= nil and state.right_window ~= nil then
        return nil
    end

    local current_window = vim.api.nvim_get_current_win()
    if current_window == nil then return "error: could not get the current window" end
    -- print("current_window "..current_window)

    -- create buffers

    if state.left_buffer == nil then
        local buf = vim.api.nvim_create_buf(false, true)
        if buf == 0 then return "error: could not create left buffer" end
        state.left_buffer = buf
    end

    if state.right_buffer == nil then
        local buf = vim.api.nvim_create_buf(false, true)
        if buf == 0 then return "error: could not create right buffer" end
        state.right_buffer = buf
    end

    -- create windows

    if state.left_window == nil then
        local window = vim.api.nvim_open_win(state.left_buffer, false, get_window_options("left"))
        if window == 0 then return "error: could not create left window" end
        state.left_window = window
    end

    if state.right_window == nil then
        local window = vim.api.nvim_open_win(state.right_buffer, false, get_window_options("right"))
        if window == 0 then return "error: could not create right window" end
        state.right_window = window
    end

    -- don't select windows just created
    local success = vim.api.nvim_set_current_win(current_window)
    if success == false then return "error: could not navigate to window: "..current_window end
end

--- close the windows if the last user window was closed
local function close_sidebars()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    local other_window = false
    for _, win in ipairs(windows) do
        -- print(win)
        if win ~= state.left_window and win ~= state.right_window then
            other_window = true
            break
        end
    end
    if other_window == false then
        -- print("closing windows")
        vim.api.nvim_win_close(state.left_window, true)
        vim.api.nvim_win_close(state.right_window, true)
        return
    end
    -- print("not closing windows")
end

local function set_window_width()
    -- create sidebars if they don't exist
    if state.left_window == nil or state.right_window == nil then
        local error = create_sidebars()
        if error ~= nil then return "error creating sidebars: "..error end
    end

    close_sidebars()

    -- get the percent
    local percent = M.options.sidebar_width_percent;
    if type(percent) ~= "number" then return "error: sidebar_width_percent must be a number between 0 and 50" end
    if percent > 50 or percent < 0 then return "error: sidebars can't be more than 50% or less than 0% of the screen" end
    local factor = percent * 0.01

    -- calc the widths
    local columns = vim.o.columns
    local window_columns = math.floor(columns * factor)

    local error = nil
    error = vim.api.nvim_win_set_width(state.left_window, window_columns)
    if error ~= nil then return "error: could not set left window width" end
    vim.api.nvim_win_call(state.left_window, function()
        M.options.draw_buffer("left", state.left_buffer, window_columns)
    end)

    error = vim.api.nvim_win_set_width(state.right_window, window_columns)
    if error ~= nil then return "error: could not set right window width" end
    vim.api.nvim_win_call(state.right_window, function()
        M.options.draw_buffer("right", state.right_buffer, window_columns)
    end)
end

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", default_options, opts or {})

    -- setup autocmd for when window is resized
    vim.api.nvim_create_autocmd({"VimEnter", "VimResized" , "WinEnter", "WinClosed"}, {
        callback = function(event)
            -- print(vim.inspect(event))
            local error = create_sidebars()
            if error ~= nil then print("error creating sidebars\n"..error) end

            -- print(vim.inspect(state))

            error = set_window_width()
            if error ~= nil then print("error setting window width\n"..error) end
        end
    })
end

return M

