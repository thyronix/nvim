-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- <leader>r (run) / <leader>dd (debug) for every supported language, plus assembly
-- buffer setup. One autocmd replaces the ten near-identical after/ftplugin/*.lua files.
local asm_filetypes = { asm = true, nasm = true, fasm = true, masm = true }

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_run_debug", { clear = true }),
  pattern = {
    "c", "cpp", "cs", "go", "python", "rust",
    "javascript", "typescript", "typescriptreact",
    "asm", "nasm", "fasm", "masm",
  },
  callback = function(ev)
    require("config.c_compile_run").attach(ev.buf)
    if asm_filetypes[ev.match] then
      require("config.assembly_flavor").setup_buffer(ev.buf)
    end
  end,
})
