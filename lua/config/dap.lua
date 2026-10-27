local dap = require("dap")

-- 1. CodeLLDB adapter (Mason or system)
local codelldb_bin = "codelldb"
if vim.fn.executable("codelldb") == 0 then
  local mason_bin = vim.fn.expand("~/.local/share/nvim/mason/bin/codelldb")
  if vim.fn.filereadable(mason_bin) == 1 then
    codelldb_bin = mason_bin
  end
end

if not dap.adapters.codelldb then
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = codelldb_bin,
      args = { "--port", "${port}" },
    },
  }
end

-- 2. GDB adapter (native DAP via --interpreter=dap)
if not dap.adapters.gdb and vim.fn.executable("gdb") == 1 then
  dap.adapters.gdb = {
    type = "executable",
    command = "gdb",
    args = { "--quiet", "--interpreter=dap" },
  }
end

-- 3. Auto-compile helper for Assembly binaries with DWARF debug info
local function get_asm_binary()
  local ext = vim.fn.expand("%:e")
  local dir = vim.fn.expand("%:p:h")
  local name = vim.fn.expand("%:t:r")
  local bin = dir .. "/" .. name

  if ext == "asm" or ext == "nasm" or ext == "s" or ext == "S" then
    vim.cmd("write")
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    local flavor = require("config.assembly_flavor").detect_flavor(0)
    local cmd

    if flavor == "gas" then
      if content:match("%.globl%s+_start") or content:match("%.global%s+_start")
         or content:match("global%s+_start") or content:match("_start:") then
        cmd = string.format(
          "cd %s && as -g %s -o %s.o && ld %s.o -o %s",
          vim.fn.shellescape(dir),
          vim.fn.shellescape(vim.fn.expand("%:t")),
          vim.fn.shellescape(name),
          vim.fn.shellescape(name),
          vim.fn.shellescape(name)
        )
      else
        cmd = string.format(
          "cd %s && gcc -g -no-pie %s -o %s",
          vim.fn.shellescape(dir),
          vim.fn.shellescape(vim.fn.expand("%:t")),
          vim.fn.shellescape(name)
        )
      end
    elseif flavor == "fasm" then
      cmd = string.format(
        "cd %s && fasm %s %s && chmod +x %s",
        vim.fn.shellescape(dir),
        vim.fn.shellescape(vim.fn.expand("%:t")),
        vim.fn.shellescape(name),
        vim.fn.shellescape(name)
      )
    else
      -- NASM / default
      local linker = "ld"
      if content:match("global%s+main") or (content:match("main:") and not content:match("_start:")) then
        linker = "gcc -g -no-pie"
      end
      cmd = string.format(
        "cd %s && nasm -f elf64 -g -F dwarf %s -o %s.o && %s %s.o -o %s",
        vim.fn.shellescape(dir),
        vim.fn.shellescape(vim.fn.expand("%:t")),
        vim.fn.shellescape(name),
        linker,
        vim.fn.shellescape(name),
        vim.fn.shellescape(name)
      )
    end

    local out = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
      vim.notify("Assembly compilation failed:\n" .. out, vim.log.levels.ERROR)
      return dap.ABORT
    end
    return bin
  else
    if vim.fn.filereadable(bin) == 1 then
      return bin
    end
    return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
  end
end

-- 4. Assembly DAP configurations
dap.configurations.asm = {
  {
    name = "Debug Assembly (CodeLLDB - stop at entry)",
    type = "codelldb",
    request = "launch",
    program = get_asm_binary,
    cwd = "${workspaceFolder}",
    stopOnEntry = true,
  },
  {
    name = "Debug Assembly (GDB - stop at entry)",
    type = "gdb",
    request = "launch",
    program = get_asm_binary,
    cwd = "${workspaceFolder}",
    stopOnEntry = true,
  },
  {
    name = "Debug Assembly (CodeLLDB - continue to breakpoint)",
    type = "codelldb",
    request = "launch",
    program = get_asm_binary,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  },
  {
    name = "Debug Assembly (Pick executable)",
    type = "codelldb",
    request = "launch",
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = true,
  },
}

dap.configurations.nasm = dap.configurations.asm
dap.configurations.s = dap.configurations.asm

-- 5. C / C++ DAP configurations
dap.configurations.cpp = dap.configurations.cpp or {}

table.insert(dap.configurations.cpp, {
  name = "Debug Godot (GDExtension)",
  type = "codelldb",
  request = "launch",
  program = vim.fn.expand("~/.local/bin/godot"),
  args = { "--path", vim.fn.expand("~/projects/godot-cpp-project/demo") },
  cwd = vim.fn.expand("~/projects/godot-cpp-project"),
  stopOnEntry = false,
})

dap.configurations.c = dap.configurations.cpp
