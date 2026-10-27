-- after/ftplugin/cs.lua - C# compile & run / debug integration

local function map_px()
  vim.keymap.set("n", "<leader>r", function()
    require("config.c_compile_run").run()
  end, { buffer = true, desc = "dotnet / px run" })

  vim.keymap.set("n", "<leader>d", function()
    require("config.c_compile_run").debug()
  end, { buffer = true, desc = "dotnet / px debug" })
end

map_px()
