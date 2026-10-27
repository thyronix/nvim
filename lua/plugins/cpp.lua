return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.clangd = {
        cmd = { "clangd", "--background-index", "--compile-commands-dir=." },
      }
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = { "jay-babu/mason-nvim-dap.nvim" },
    opts = function()
      pcall(require, "config.dap")
    end,
  },
}
