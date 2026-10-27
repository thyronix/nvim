return {
  -- Ensure Tree-sitter asm parser is installed
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "asm" })
      end
    end,
  },

  -- Assembly language server (asm-lsp)
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.asm_lsp = {
        mason = false,
        filetypes = { "asm", "nasm", "s", "S" },
        handlers = {
          -- Suppress bogus diagnostics from asm-lsp:
          -- asm-lsp executes a single static external compiler (like nasm) across all files,
          -- which generates false syntax errors whenever GAS or other assembly syntaxes are used.
          -- Suppressing publishDiagnostics prevents these false alarms while preserving full
          -- LSP functionality: hover documentation, completions, signature help, and goto-definition.
          ["textDocument/publishDiagnostics"] = function(...) end,
        },
      }
    end,
  },

  -- Syntax-aware Assembly Linting via nvim-lint
  -- Accurately verifies GAS using `as` and NASM using `nasm` without false positives
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters = opts.linters or {}

      local af = require("config.assembly_flavor")

      opts.linters.assembly_lint = function()
        local flavor = af.detect_flavor(0)
        if flavor == "gas" then
          return {
            name = "as",
            cmd = "as",
            stdin = false,
            append_fname = true,
            args = { "-g", "-o", "/dev/null" },
            stream = "stderr",
            ignore_exitcode = true,
            parser = require("lint.parser").from_errorformat("%f:%l: %t%*[^:]: %m,%f:%l: %m", {
              source = "as",
            }),
          }
        elseif flavor == "nasm" then
          return {
            name = "nasm",
            cmd = "nasm",
            stdin = false,
            append_fname = true,
            args = { "-f", "elf64", "-X", "gnu", "-o", "/dev/null" },
            stream = "stderr",
            ignore_exitcode = true,
            parser = require("lint.parser").from_errorformat("%f:%l: %t%*[^:]: %m,%f:%l: %m", {
              source = "nasm",
            }),
          }
        end

        -- For FASM, MASM, etc., avoid false alarms
        return {
          name = "assembly_noop",
          cmd = "true",
          stdin = false,
          append_fname = false,
          args = {},
          stream = "stderr",
          ignore_exitcode = true,
          parser = function()
            return {}
          end,
        }
      end

      opts.linters_by_ft.asm = opts.linters_by_ft.asm or {}
      vim.list_extend(opts.linters_by_ft.asm, { "assembly_lint" })

      opts.linters_by_ft.nasm = opts.linters_by_ft.nasm or {}
      vim.list_extend(opts.linters_by_ft.nasm, { "assembly_lint" })
    end,
  },

  -- Debug adapter protocol (DAP)
  {
    "mfussenegger/nvim-dap",
    opts = function()
      pcall(require, "config.dap")
    end,
  },
}
