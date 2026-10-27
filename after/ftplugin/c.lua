-- after/ftplugin/c.lua
vim.keymap.set("n", "<leader>r", function()
  require("config.c_compile_run").run()
end, { buffer = true, desc = "px run / compile & run" })

vim.keymap.set("n", "<leader>d", function()
  require("config.c_compile_run").debug()
end, { buffer = true, desc = "px debug" })
