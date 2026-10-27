-- Shared multi-lang compile/run via `px` for <leader>r
-- CMake/Make/Go/Rust/Python/Web → `px run`
-- Lone .c / .cpp file (no project markers) → cgcc / g++

local M = {}

local function has_px_project()
  local root = vim.fs.root(0, {
    "CMakeLists.txt",
    "go.mod",
    "Cargo.toml",
    "pyproject.toml",
    "package.json",
    "Makefile",
  })
  if root then
    return root
  end
  return vim.fs.root(0, function(name)
    return name:match("%.sln$") ~= nil or name:match("%.csproj$") ~= nil
  end)
end

function M.run()
  vim.cmd("write")

  local dir = vim.fn.expand("%:p:h")
  local name = vim.fn.expand("%:t:r")
  local ext = vim.fn.expand("%:e")
  local root = has_px_project()

  local full_cmd
  if root then
    full_cmd = string.format("cd %s && px run", vim.fn.shellescape(root))
  elseif ext == "c" then
    full_cmd = string.format(
      "source %s && cd %s && cgcc %s && ./%s",
      vim.fn.shellescape(vim.fn.expand("~/.config/zsh/compile_run.zsh")),
      vim.fn.shellescape(dir),
      vim.fn.shellescape(name),
      vim.fn.shellescape(name)
    )
  elseif ext == "cpp" or ext == "cc" or ext == "cxx" then
    full_cmd = string.format(
      "cd %s && g++ -Wall -Wextra -Wpedantic -std=c++20 -g %s -o %s && ./%s",
      vim.fn.shellescape(dir),
      vim.fn.shellescape(name .. "." .. ext),
      vim.fn.shellescape(name),
      vim.fn.shellescape(name)
    )
  elseif ext == "cs" then
    full_cmd = string.format("cd %s && dotnet run", vim.fn.shellescape(dir))
  elseif ext == "rs" then
    full_cmd = string.format("cd %s && rustc %s.rs && ./%s", vim.fn.shellescape(dir), vim.fn.shellescape(name), vim.fn.shellescape(name))
  elseif ext == "asm" or ext == "nasm" or ext == "s" or ext == "S" then
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    local flavor = require("config.assembly_flavor").detect_flavor(0)

    if flavor == "gas" then
      if content:match("%.globl%s+_start") or content:match("%.global%s+_start")
         or content:match("global%s+_start") or content:match("_start:") then
        full_cmd = string.format(
          "cd %s && as -g %s -o %s.o && ld %s.o -o %s && ./%s",
          vim.fn.shellescape(dir),
          vim.fn.shellescape(name .. "." .. ext),
          vim.fn.shellescape(name),
          vim.fn.shellescape(name),
          vim.fn.shellescape(name),
          vim.fn.shellescape(name)
        )
      else
        full_cmd = string.format(
          "cd %s && gcc -g -no-pie %s -o %s && ./%s",
          vim.fn.shellescape(dir),
          vim.fn.shellescape(name .. "." .. ext),
          vim.fn.shellescape(name),
          vim.fn.shellescape(name)
        )
      end
    elseif flavor == "fasm" then
      full_cmd = string.format(
        "cd %s && fasm %s %s && chmod +x %s && ./%s",
        vim.fn.shellescape(dir),
        vim.fn.shellescape(name .. "." .. ext),
        vim.fn.shellescape(name),
        vim.fn.shellescape(name),
        vim.fn.shellescape(name)
      )
    else
      -- NASM / default
      local linker = "ld"
      if content:match("global%s+main") or (content:match("main:") and not content:match("_start:")) then
        linker = "gcc -g -no-pie"
      end
      full_cmd = string.format(
        "cd %s && nasm -f elf64 -g -F dwarf %s -o %s.o && %s %s.o -o %s && ./%s",
        vim.fn.shellescape(dir),
        vim.fn.shellescape(name .. "." .. ext),
        vim.fn.shellescape(name),
        linker,
        vim.fn.shellescape(name),
        vim.fn.shellescape(name),
        vim.fn.shellescape(name)
      )
    end
  else
    vim.notify("No project root and unsupported single file type", vim.log.levels.WARN)
    return
  end

  vim.cmd("split | terminal zsh -c " .. vim.fn.shellescape(full_cmd))
  vim.cmd("startinsert")
end

function M.debug()
  vim.cmd("write")
  local root = has_px_project()
  if root then
    local full_cmd = string.format("cd %s && px debug", vim.fn.shellescape(root))
    vim.cmd("split | terminal zsh -c " .. vim.fn.shellescape(full_cmd))
    vim.cmd("startinsert")
    return
  end

  local ext = vim.fn.expand("%:e")
  if ext == "asm" or ext == "nasm" or ext == "s" or ext == "S" or ext == "c" or ext == "cpp" then
    require("dap").continue()
    return
  end

  vim.notify("px debug needs a project root", vim.log.levels.WARN)
end

return M
