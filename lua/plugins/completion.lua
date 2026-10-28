return {
  "saghen/blink.cmp",
  opts = {
    -- No snippets in assembly buffers (keeps LSP, path and buffer words).
    -- Keyed by filetype: there is no filetype "s".
    sources = {
      per_filetype = {
        asm = { "lsp", "path", "buffer" },
        nasm = { "lsp", "path", "buffer" },
        fasm = { "lsp", "path", "buffer" },
        objdump = { "path", "buffer" },
      },
    },
    -- Turn off grey ghost text preview
    completion = {
      ghost_text = { enabled = false },
    },
  },
}
