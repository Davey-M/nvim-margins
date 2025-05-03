vim.keymap.set("n", "<leader>m", ":messages<CR>")

local M = {}

local default_options = {
    max_width = 1000,
}

local function set_padding()
    local layout = vim.fn.winlayout()
    print(vim.inspect(layout))
    local split_type = layout[1]
    if split_type == "row" then
        print("multi pane width")
        local panes = layout[2]
    else
        print("single pane width")
    end
end

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", default_options, opts or {})

    -- setup autocmd for when window is resized
    vim.api.nvim_create_autocmd({"VimResized" , "WinNew", "WinClosed"}, {
        callback = function(event)
            print("resize event:\n"..vim.inspect(event))
            set_padding()
        end
    })

    -- add initial padding
    set_padding()
end

return M

