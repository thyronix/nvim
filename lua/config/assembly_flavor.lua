-- Assembly dialect detection, per-buffer setup and build commands.
--
-- `classify()` is a pure function (no Neovim API) so it can be unit-tested with
--   nvim -l tests/asm_flavor_spec.lua

local M = {}

-- Neovim may pick any of these filetypes for a *.asm file, so handle them all.
M.FILETYPES = { "asm", "nasm", "fasm", "masm" }

-- Words after "#" that are C-preprocessor directives, not GAS comments.
local CPP_WORDS = {
  include = true, define = true, undef = true, ["if"] = true, ifdef = true, ifndef = true,
  ["else"] = true, elif = true, endif = true, pragma = true, error = true, line = true,
}

-- GAS directives that other dialects (almost) never use at the start of a line.
local GAS_DIRECTIVES = {
  "globl", "global", "intel_syntax", "att_syntax", "text", "data", "bss", "section",
  "type", "size", "ascii", "asciz", "string", "byte", "short", "long", "quad",
  "align", "p2align", "balign", "cfi_[%w_]+",
}

-- AT&T register operands: %rax %esi %r8d %al %xmm0 %rip ...
local ATT_REGISTERS = {
  "%%[er]?[abcd]x", "%%[er]?[sd]i", "%%[er]?[sb]p", "%%r%d+[dwb]?",
  "%%[abcd][lh]", "%%xmm%d", "%%rip",
}

---Classify assembly source text.
---Order matters: NASM's preprocessor (`%define`, `%macro`, `%include`) looks like
---AT&T registers (`%rax`) to a naive matcher, so NASM-only markers are tested
---*before* any GAS heuristic, and every marker is anchored to the start of a line
---so comments and strings can't trigger it.
---@param content string first N lines of the buffer
---@param ext string file extension, any case ("asm", "s", "S", ...)
---@return "gas"|"nasm"|"fasm"|"masm"
function M.classify(content, ext)
  ext = (ext or ""):lower()
  if ext == "s" then
    return "gas" -- .s and .S are always GNU as
  elseif ext == "nasm" then
    return "nasm"
  end

  content = content .. "\n" -- so a directive on the last line still has trailing whitespace

  ---True when some line starts (after blanks) with `pat`.
  local function line(pat)
    return content:find("^%s*" .. pat) ~= nil or content:find("\n%s*" .. pat) ~= nil
  end

  -- FASM
  if line("format%s+ELF") or line("format%s+PE") or line("format%s+MZ") or line("format%s+binary") then
    return "fasm"
  end

  -- MASM
  if
    line("%.model%s")
    or line("INVOKE%s")
    or content:find("[%w_]%s+PROC%f[%W]")
    or content:find("[%w_]%s+ENDP%f[%W]")
  then
    return "masm"
  end

  -- NASM (before GAS, see above)
  if
    line("%%%a") -- %define / %macro / %include / %if ... at the start of a line
    or line("bits%s+%d")
    or line("default%s+rel")
    or line("default%s+abs")
    or line("section%s+%.")
    or line("segment%s+%.")
    or line("global%s+[%a_]")
    or line("extern%s+[%a_]")
    or content:find("%[rel%s")
    or content:find("%[abs%s")
    or content:find("%f[%w_]res[bwdqt]%f[%W]")
  then
    return "nasm"
  end

  -- GAS
  for _, d in ipairs(GAS_DIRECTIVES) do
    if line("%." .. d .. "%s") then
      return "gas"
    end
  end
  for _, reg in ipairs(ATT_REGISTERS) do
    if content:find(reg .. "%f[%W]") then
      return "gas"
    end
  end
  if content:find("[%s,]%$%d") then -- AT&T immediates: $1, $0x10
    return "gas"
  end
  for l in content:gmatch("[^\n]+") do
    local word = l:match("^%s*#%s*(%a*)")
    if word and not CPP_WORDS[word] then
      return "gas" -- "# comment"
    end
  end
  if line("%.%a[%w_]*%s") then -- some other ".directive args" (local labels end in ":")
    return "gas"
  end

  return "nasm"
end

---Detect the dialect of a buffer (first 200 lines + file extension).
---@param bufnr? integer
---@return "gas"|"nasm"|"fasm"|"masm"
function M.detect_flavor(bufnr)
  bufnr = bufnr or 0
  local ext = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":e")
  local n = math.min(200, vim.api.nvim_buf_line_count(bufnr))
  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, n, false), "\n")
  return M.classify(content, ext)
end

---Build (and optionally run) the assembly file in `bufnr`.
---@param bufnr? integer
---@param run? boolean append `&& ./<binary>`
---@return string? cmd shell command (run with `sh -c`)
---@return string? err
function M.build_cmd(bufnr, run)
  bufnr = bufnr or 0
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return nil, "Save the buffer first"
  end

  local dir = vim.fs.dirname(file)
  local src = vim.fs.basename(file)
  local name = vim.fn.fnamemodify(file, ":t:r")
  local ext = vim.fn.fnamemodify(file, ":e")
  local flavor = M.detect_flavor(bufnr)
  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

  local q = vim.fn.shellescape
  local obj = name .. ".o"

  local function defines(sym)
    return content:find("%f[%w_]" .. sym .. "%s*:") ~= nil -- label
      or content:find("%.?globa?l%s+" .. sym .. "%f[%W]") ~= nil -- global / globl
  end
  -- `_start` => bare ld. `main` without `_start` => needs libc startup => gcc.
  local use_gcc = defines("main") and not defines("_start")
  local link
  if use_gcc then
    link = ("gcc -g -no-pie %s -o %s"):format(q(obj), q(name))
  else
    link = ("ld %s -o %s"):format(q(obj), q(name))
  end

  local steps
  if flavor == "gas" then
    local assemble
    if ext == "S" then -- needs the C preprocessor
      assemble = ("gcc -g -c %s -o %s"):format(q(src), q(obj))
    else
      assemble = ("as -g %s -o %s"):format(q(src), q(obj))
    end
    steps = { assemble, link }
  elseif flavor == "fasm" then
    steps = { ("fasm %s %s"):format(q(src), q(name)), ("chmod +x %s"):format(q(name)) }
  elseif flavor == "nasm" then
    steps = { ("nasm -f elf64 -g -F dwarf %s -o %s"):format(q(src), q(obj)), link }
  else
    return nil, "MASM source can't be built with the Linux toolchain"
  end

  local cmd = ("cd %s && %s"):format(q(dir), table.concat(steps, " && "))
  if run then
    cmd = cmd .. " && ./" .. q(name)
  end
  return cmd
end

---Options, comment string and instruction-stepping keymaps for an assembly buffer.
---(<leader>r / <leader>dd are mapped by config.c_compile_run.attach.)
---@param bufnr? integer
function M.setup_buffer(bufnr)
  bufnr = bufnr or 0
  local flavor = M.detect_flavor(bufnr)

  vim.bo[bufnr].expandtab = true
  vim.bo[bufnr].shiftwidth = 4
  vim.bo[bufnr].tabstop = 4
  vim.bo[bufnr].softtabstop = 4
  vim.bo[bufnr].commentstring = (flavor == "gas") and "# %s" or "; %s"

  -- The DAP field is `granularity` (not `steppingGranularity`).
  -- <leader>ds is LazyVim's "Session" key, so <leader>dsi / <leader>dso made it
  -- a prefix and delayed it; capital I / N are separate keys.
  local function step(fn)
    return function()
      require("dap")[fn]({ granularity = "instruction" })
    end
  end
  vim.keymap.set("n", "<leader>dI", step("step_into"), { buffer = bufnr, desc = "DAP: Step Into (instruction)" })
  vim.keymap.set("n", "<leader>dN", step("step_over"), { buffer = bufnr, desc = "DAP: Step Over (instruction)" })
end

return M
