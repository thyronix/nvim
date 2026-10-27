return {
  "saghen/blink.cmp",
  opts = {
    -- Remove snippets for assembly files (keeps LSP, path, and buffer words)
    sources = {
      per_filetype = {
        asm = { "lsp", "path", "buffer" },
        nasm = { "lsp", "path", "buffer" },
        s = { "lsp", "path", "buffer" },
      },
    },
    -- Turn off grey ghost text preview
    completion = {
      ghost_text = { enabled = false },
    },
  },
}
