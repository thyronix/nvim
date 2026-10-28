-- Extra DAP adapters/configurations. Loaded from lua/plugins/dap.lua (plain
-- `require`, no pcall, so a typo here shows up instead of silently disabling DAP).
local dap = require("dap")

-- 1. CodeLLDB: Mason puts its bin dir on PATH; fall back to the explicit path.
local codelldb = vim.fn.exepath("codelldb")
if codelldb == "" then
  local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
  if vim.uv.fs_stat(mason_bin) then
    codelldb = mason_bin
  end
end
if codelldb ~= "" and not dap.adapters.codelldb then
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = { command = codelldb, args = { "--port", "${port}" } },
  }
end

-- 2. GDB's native DAP server (needs GDB 14 or newer).
if vim.fn.executable("gdb") == 1 and not dap.adapters.gdb then
  dap.adapters.gdb = {
    type = "executable",
    command = "gdb",
    args = { "--quiet", "--interpreter=dap" },
  }
end

-- 3. Build the current assembly buffer with debug info; return the binary path.
local function asm_program()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
  end
  vim.cmd("silent update")

  local cmd, err = require("config.assembly_flavor").build_cmd(0, false)
  if not cmd then
    vim.notify(err or "Can't build this file", vim.log.levels.ERROR)
    return dap.ABORT
  end
  local out = vim.fn.system({ "sh", "-c", cmd })
  if vim.v.shell_error ~= 0 then
    vim.notify("Assembly build failed:\n" .. out, vim.log.levels.ERROR)
    return dap.ABORT
  end
  return vim.fs.dirname(file) .. "/" .. vim.fn.fnamemodify(file, ":t:r")
end

local function pick_executable()
  return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
end

-- 4. Assembly configurations. Keyed by *filetype*; there is no filetype "s" or "S"
--    (those are extensions, and Neovim reports asm/nasm/fasm for them).
local asm_configs = {
  { name = "Assembly (CodeLLDB, stop at entry)", type = "codelldb", request = "launch", program = asm_program, cwd = "${workspaceFolder}", stopOnEntry = true },
  { name = "Assembly (GDB)", type = "gdb", request = "launch", program = asm_program, cwd = "${workspaceFolder}" },
  { name = "Assembly (CodeLLDB, run to breakpoint)", type = "codelldb", request = "launch", program = asm_program, cwd = "${workspaceFolder}", stopOnEntry = false },
  { name = "Assembly (pick executable)", type = "codelldb", request = "launch", program = pick_executable, cwd = "${workspaceFolder}", stopOnEntry = true },
}
for _, ft in ipairs({ "asm", "nasm", "fasm" }) do
  dap.configurations[ft] = asm_configs
end

-- 5. Machine-specific Godot entry: only registered when the paths exist.
--    (No more `dap.configurations.c = dap.configurations.cpp` aliasing: the
--    LazyVim clangd extra already defines separate c and cpp lists.)
local godot = vim.fn.expand("~/.local/bin/godot")
local godot_project = vim.fn.expand("~/projects/godot-cpp-project")
if vim.uv.fs_stat(godot) and vim.uv.fs_stat(godot_project) then
  dap.configurations.cpp = dap.configurations.cpp or {}
  table.insert(dap.configurations.cpp, {
    name = "Debug Godot (GDExtension)",
    type = "codelldb",
    request = "launch",
    program = godot,
    args = { "--path", godot_project .. "/demo" },
    cwd = godot_project,
    stopOnEntry = false,
  })
end
