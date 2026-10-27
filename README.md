# LazyVim (Neovim) config

Based on [LazyVim](https://www.lazyvim.org/). Personal bits live under `lua/` and `after/ftplugin/`.

Reload after changes: restart Neovim, or `:Lazy reload`.

---

## Installation on a New Machine

1. **Backup existing config (if any):**
   ```bash
   mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null
   mv ~/.local/share/nvim ~/.local/share/nvim.bak 2>/dev/null
   mv ~/.local/state/nvim ~/.local/state/nvim.bak 2>/dev/null
   mv ~/.cache/nvim ~/.cache/nvim.bak 2>/dev/null
   ```

2. **Clone this repository:**
   ```bash
   git clone https://github.com/thyronix/nvim.git ~/.config/nvim
   ```

3. **Start Neovim:**
   ```bash
   nvim
   ```
   `lazy.nvim` will automatically bootstrap and install all configured plugins, extras, and treesitter parsers on first launch.

---

## Project run / debug (`px`)

Same CLI as the shell — see [`~/Programming/README.md`](../../Programming/README.md).

| Key | Action |
|-----|--------|
| `<leader>r` | Save → `px run` (or single-file compile) |
| `<leader>d` | Save → `px debug` (project only) |

Mapped for: **c**, **cpp**, **go**, **python**, **rust**, **typescript**.

### Behavior

1. If a project root exists (`CMakeLists.txt`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `package.json`, `Makefile`) → `px run` / `px debug`
2. Else if current file is `.c` → `cgcc` from `~/.config/zsh/compile_run.zsh`
3. Else if `.cpp` / `.cc` / `.cxx` → `g++ -std=c++20`

Opens a split terminal and enters insert mode.

---

## Layout

```text
~/.config/nvim/
├── init.lua
├── lazyvim.json          # extras (clangd, go, rust, python, ts, dap, …)
├── lua/config/
│   ├── options.lua
│   ├── keymaps.lua
│   ├── autocmds.lua
│   ├── lazy.lua
│   └── c_compile_run.lua # <leader>r / <leader>d helper
├── lua/plugins/
│   ├── colorscheme.lua   # tokyonight night
│   └── mason.lua
└── after/ftplugin/
    ├── c.lua
    ├── cpp.lua
    ├── go.lua
    ├── python.lua
    ├── rust.lua
    └── typescript.lua
```

---

## Enabled LazyVim extras

From `lazyvim.json`:

- Coding: `mini-surround`
- DAP: `dap.core`
- Lang: `clangd`, `go`, `json`, `python`, `rust`, `sql`, `tailwind`, `typescript`, `yaml`
- Lint / format: `eslint`, `prettier`

---

## Colors & options

- Theme: **tokyonight** (`night`)
- Project root: LazyVim default (LSP → markers → cwd) — good for CMake / `compile_commands.json`

---

## Useful LazyVim defaults

| Key | Action |
|-----|--------|
| `<leader>space` | Find files |
| `<leader>/` | Grep |
| `<leader>e` | Explorer |
| `<leader>gg` | Lazygit |
| `gd` / `gr` / `K` | LSP definition / refs / hover |

Leader is typically **space**.
