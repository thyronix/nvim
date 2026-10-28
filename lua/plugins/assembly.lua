return {
  -- Tree-sitter asm parser
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "asm" })
    end,
  },

  -- Assembly language server (asm-lsp)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        asm_lsp = {
          -- Install it yourself (`cargo install asm-lsp`, your package manager, or look
          -- for it in :Mason); mason = false means LazyVim won't try.
          mason = false,
          filetypes = { "asm", "vmasm", "nasm" },
          handlers = {
            -- asm-lsp runs one fixed assembler over every file, so it reports false
            -- syntax errors whenever the dialect differs. nvim-lint (below) does the
            -- dialect-aware diagnostics; hover, completion and goto-definition stay.
            ["textDocument/publishDiagnostics"] = function() end,
          },
        },
      },
    },
  },

  -- Dialect-aware diagnostics: `as` for GAS, `nasm` for NASM, nothing for the rest
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      local af = require("config.assembly_flavor")
      local efm = "%f:%l: %t%*[^:]: %m,%f:%l: %m"

      local function linter(cmd, args)
        return {
          name = cmd,
          cmd = cmd,
          args = args,
          stdin = false,
          append_fname = true,
          stream = "stderr",
          ignore_exitcode = true,
          parser = require("lint.parser").from_errorformat(efm, { source = cmd }),
        }
      end

      opts.linters = opts.linters or {}
      opts.linters.assembly_lint = function()
        local flavor = af.detect_flavor(0)
        if flavor == "gas" then
          if vim.fn.expand("%:e") == "S" then -- needs the C preprocessor
            return linter("gcc", { "-x", "assembler-with-cpp", "-c", "-o", "/dev/null" })
          end
          return linter("as", { "-g", "-o", "/dev/null" })
        elseif flavor == "nasm" then
          return linter("nasm", { "-f", "elf64", "-X", "gnu", "-o", "/dev/null" })
        end
        -- FASM / MASM: no linter, no false alarms
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

      opts.linters_by_ft = opts.linters_by_ft or {}
      for _, ft in ipairs({ "asm", "nasm" }) do
        opts.linters_by_ft[ft] = opts.linters_by_ft[ft] or {}
        vim.list_extend(opts.linters_by_ft[ft], { "assembly_lint" })
      end
    end,
  },
}
