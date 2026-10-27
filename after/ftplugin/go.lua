-- after/ftplugin for go / python / rust / typescript → px run/debug

local function map_px()
  vim.keymap.set("n", "<leader>r", function()
    require("config.c_compile_run").run()
  end, { buffer = true, desc = "px run" })

  vim.keymap.set("n", "<leader>d", function()
    require("config.c_compile_run").debug()
  end, { buffer = true, desc = "px debug" })
end

map_px()
