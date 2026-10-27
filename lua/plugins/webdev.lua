return {
  -- LSP Configuration for Web Development (HTML, CSS, Emmet)
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.html = {
        filetypes = { "html", "templ" },
      }
      opts.servers.cssls = {
        settings = {
          css = {
            validate = true,
            lint = {
              unknownAtRules = "ignore",
            },
          },
          scss = {
            validate = true,
            lint = {
              unknownAtRules = "ignore",
            },
          },
          less = {
            validate = true,
            lint = {
              unknownAtRules = "ignore",
            },
          },
        },
      }
      opts.servers.emmet_language_server = {
        filetypes = {
          "css",
          "eruby",
          "html",
          "javascript",
          "javascriptreact",
          "less",
          "sass",
          "scss",
          "pug",
          "typescriptreact",
        },
      }
    end,
  },

  -- Ensure all Web Development Treesitter grammars are installed
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, {
          "html",
          "css",
          "scss",
          "javascript",
          "typescript",
          "tsx",
          "json",
        })
      end
    end,
  },

  -- Ensure Mason installs HTML, CSS, and Emmet LSPs
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "html-lsp",
        "css-lsp",
        "emmet-language-server",
      })
    end,
  },

  -- Auto-closing and auto-renaming HTML and JSX tags
  {
    "windwp/nvim-ts-autotag",
    event = "LazyFile",
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },
}
