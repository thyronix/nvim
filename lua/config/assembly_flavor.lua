local M = {}

---Detect assembly syntax flavor for the current buffer or given bufnr.
---Returns one of: "gas", "nasm", "fasm", "masm"
---@param bufnr? integer
---@return "gas"|"nasm"|"fasm"|"masm"
function M.detect_flavor(bufnr)
  bufnr = bufnr or 0
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local ext = vim.fn.fnamemodify(filename, ":e"):lower()

  -- Strong extension hints
  if ext == "s" then
    return "gas"
  elseif ext == "nasm" then
    return "nasm"
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local max_lines = math.min(150, line_count)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_lines, false)
  local content = table.concat(lines, "\n")

  -- Check for FASM markers
  if content:match("format%s+ELF") or content:match("format%s+PE") or content:match("format%s+binary") then
    return "fasm"
  end

  -- Check for MASM markers
  if content:match("%.model%s+") or content:match("%s+PROC%f[%s]") or content:match("%s+ENDP%f[%s]")
     or content:match("INVOKE%s+") then
    return "masm"
  end

  -- Check for GAS (GNU Assembler) markers:
  -- Directives: .globl, .global, .intel_syntax, .att_syntax, .text, .data, .section, .ascii, .asciz, .type, .size, .cfi_
  -- AT&T register syntax: %rax, %rbx, %eax, %edi, %rsi, %rsp, %rbp, %cl, etc.
  -- Immediate values with $: $1, $60, $0x...
  -- Assembler comments: # ... (not #include or #define)
  if content:match("%.globl%s+")
     or content:match("%.global%s+")
     or content:match("%.intel_syntax")
     or content:match("%.att_syntax")
     or content:match("%.type%s+")
     or content:match("%.size%s+")
     or content:match("%.cfi_")
     or content:match("%.section%s+")
     or content:match("%.ascii")
     or content:match("%.asciz")
     or content:match("%.byte%s+")
     or content:match("%.short%s+")
     or content:match("%.long%s+")
     or content:match("%.quad%s+")
     or content:match("%%%a+")
     or content:match("%$%d+")
     or content:match("%$0x%x+")
     or content:match("^%s*#%s*[^i#%s]")
     or content:match("\n%s*#%s*[^i#%s]") then
    return "gas"
  end

  -- Check for NASM markers:
  -- global, default rel, section .text, extern, [rel ...], resb/resw/resd/resq
  if content:match("default%s+rel")
     or content:match("section%s+%.")
     or content:match("global%s+[%a_]")
     or content:match("extern%s+[%a_]")
     or content:match("%[rel%s+")
     or content:match("%bres[bwdq]%b") then
    return "nasm"
  end

  -- Fallback based on extension or leading directives
  if ext == "asm" then
    if content:match("^%s*%.") or content:match("\n%s*%.") then
      return "gas"
    end
    return "nasm"
  end

  return "gas"
end

---Setup buffer options, comments, and keymaps for any assembly buffer.
---@param bufnr? integer
function M.setup_buffer(bufnr)
  bufnr = bufnr or 0
  if vim.b[bufnr].did_assembly_setup then
    return
  end
  vim.b[bufnr].did_assembly_setup = true

  local flavor = M.detect_flavor(bufnr)

  vim.bo[bufnr].expandtab = true
  vim.bo[bufnr].shiftwidth = 4
  vim.bo[bufnr].tabstop = 4
  vim.bo[bufnr].softtabstop = 4

  -- Configure commenting character based on syntax flavor
  if flavor == "gas" then
    vim.bo[bufnr].commentstring = "# %s"
  else
    vim.bo[bufnr].commentstring = "; %s"
  end

  -- Compile & run with <leader>r
  vim.keymap.set("n", "<leader>r", function()
    require("config.c_compile_run").run()
  end, { buffer = bufnr, desc = "Assembly: Compile & Run" })

  -- Quick debug with <leader>d
  vim.keymap.set("n", "<leader>d", function()
    require("config.c_compile_run").debug()
  end, { buffer = bufnr, desc = "Assembly: Debug" })

  -- Assembly instruction-level stepping shortcuts
  vim.keymap.set("n", "<leader>dsi", function()
    require("dap").step_into({ steppingGranularity = "instruction" })
  end, { buffer = bufnr, desc = "DAP: Step Instruction Into" })

  vim.keymap.set("n", "<leader>dso", function()
    require("dap").step_over({ steppingGranularity = "instruction" })
  end, { buffer = bufnr, desc = "DAP: Step Instruction Over" })
end

return M
