-- One place that loads lua/config/dap.lua (it used to be required, wrapped in pcall,
-- from both assembly.lua and cpp.lua). Needs the dap.core extra from lazyvim.json.
return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      require("config.dap")
    end,
  },
}
