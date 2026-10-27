local function map_px()
  vim.keymap.set("n", "<leader>r", function()
    require("config.c_compile_run").run()
  end, { buffer = true, desc = "px run" })
end

map_px()
