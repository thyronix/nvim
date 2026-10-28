-- <leader>r (run) and <leader>dd (debug) for every supported language.
--
--   * assembly files            -> built directly (see config.assembly_flavor)
--   * a project root is found   -> `px run` / `px debug`
--   * a lone source file        -> compiled / interpreted directly
--
-- Mapped per buffer by M.attach(), called from the FileType autocmd in
-- lua/config/autocmds.lua (replaces the old after/ftplugin/*.lua copies).

local M = {}

local ASM_EXT = { asm = true, nasm = true, s = true, S = true }
local PROJECT_MARKERS = { "CMakeLists.txt", "go.mod", "Cargo.toml", "pyproject.toml", "package.json", "Makefile" }

local function sq(s)
  return vim.fn.shellescape(s)
end

local function warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

---Nearest project root for `px`. The search stops at $HOME so a stray
---~/Makefile or ~/package.json can't hijack every file below it.
---@return string?
local function project_root()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return nil
  end
  local opts = { upward = true, path = vim.fs.dirname(file), stop = vim.env.HOME, limit = 1 }
  local found = vim.fs.find(PROJECT_MARKERS, opts)[1]
  if not found then
    found = vim.fs.find(function(name)
      return name:match("%.sln$") ~= nil or name:match("%.csproj$") ~= nil
    end, opts)[1]
  end
  return found and vim.fs.dirname(found) or nil
end

---Command for a file that is not inside a project.
---@return {cmd: string, shell?: string}?, string?
local function single_file(ext, dir, base, name)
  local cd = "cd " .. sq(dir) .. " && "
  local b, n = sq(base), sq(name)

  if ext == "c" then
    -- Keep using the `cgcc` helper when it exists; otherwise plain gcc.
    local helper = vim.fn.expand("~/.config/zsh/compile_run.zsh")
    if vim.fn.executable("zsh") == 1 and vim.fn.filereadable(helper) == 1 then
      return { shell = "zsh", cmd = ("source %s && %scgcc %s && ./%s"):format(sq(helper), cd, n, n) }
    end
    return { cmd = ("%sgcc -Wall -Wextra -g %s -o %s && ./%s"):format(cd, b, n, n) }
  elseif ext == "cpp" or ext == "cc" or ext == "cxx" then
    return { cmd = ("%sg++ -Wall -Wextra -Wpedantic -std=c++20 -g %s -o %s && ./%s"):format(cd, b, n, n) }
  elseif ext == "rs" then
    return { cmd = ("%srustc -g %s -o %s && ./%s"):format(cd, b, n, n) }
  elseif ext == "go" then
    return { cmd = ("%sgo run %s"):format(cd, b) }
  elseif ext == "py" then
    return { cmd = ("%spython3 %s"):format(cd, b) }
  elseif ext == "js" then
    return { cmd = ("%snode %s"):format(cd, b) }
  elseif ext == "ts" then
    for _, r in ipairs({ { "bun", "bun run" }, { "tsx", "tsx" }, { "deno", "deno run" } }) do
      if vim.fn.executable(r[1]) == 1 then
        return { cmd = ("%s%s %s"):format(cd, r[2], b) }
      end
    end
    return nil, "No TypeScript runner found (install bun, tsx or deno)"
  elseif ext == "cs" then
    return { cmd = cd .. "dotnet run" }
  end
  return nil, "No project root and no single-file runner for ." .. ext
end

---Run `job.cmd` in a terminal split.
---`:botright new` first: jobstart({term = true}) turns the *current buffer* into
---the terminal, so it must be a fresh scratch buffer, never the source file.
local function open_terminal(job)
  vim.cmd("botright 15new")
  vim.fn.jobstart({ job.shell or "sh", "-c", job.cmd }, { term = true })
  vim.cmd("startinsert")
end

function M.run()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return warn("Save the buffer first")
  end
  vim.cmd("silent update")

  local ext = vim.fn.fnamemodify(file, ":e")
  local job, err

  if ASM_EXT[ext] then
    -- Assembly is always built directly: a Makefile/package.json somewhere above
    -- the file must not turn <leader>r into `px run`.
    local cmd, e = require("config.assembly_flavor").build_cmd(0, true)
    job, err = cmd and { cmd = cmd } or nil, e
  else
    local root = project_root()
    if root then
      if vim.fn.executable("px") == 0 then
        return warn("`px` not found in PATH")
      end
      job = { cmd = "cd " .. sq(root) .. " && px run" }
    else
      job, err = single_file(ext, vim.fs.dirname(file), vim.fs.basename(file), vim.fn.fnamemodify(file, ":t:r"))
    end
  end

  if not job then
    return warn(err or "Nothing to run")
  end
  open_terminal(job)
end

function M.debug()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return warn("Save the buffer first")
  end
  vim.cmd("silent update")

  local ext = vim.fn.fnamemodify(file, ":e")
  if ASM_EXT[ext] then
    return require("dap").continue()
  end

  local root = project_root()
  if root then
    if vim.fn.executable("px") == 0 then
      return warn("`px` not found in PATH")
    end
    return open_terminal({ cmd = "cd " .. sq(root) .. " && px debug" })
  end

  if ext == "c" or ext == "cpp" then
    return require("dap").continue()
  end
  warn("px debug needs a project root")
end

---Buffer-local keymaps. <leader>dd lives inside LazyVim's debug group, so it
---doesn't turn <leader>d into an ambiguous prefix like the old <leader>d did.
---@param bufnr integer
function M.attach(bufnr)
  vim.keymap.set("n", "<leader>r", M.run, { buffer = bufnr, desc = "Run (px / single file)" })
  vim.keymap.set("n", "<leader>dd", M.debug, { buffer = bufnr, desc = "Debug (px / DAP)" })
end

return M
