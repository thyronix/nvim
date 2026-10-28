-- Run from ~/.config/nvim:   nvim -l tests/asm_flavor_spec.lua
package.path = "lua/?.lua;" .. package.path
local F = require("config.assembly_flavor")

local cases = {
  {
    name = "NASM: %define + section",
    ext = "asm", want = "nasm",
    src = "%define SYS_exit 60\nsection .text\nglobal _start\n_start:\n  mov rax, SYS_exit\n  syscall\n",
  },
  {
    name = "NASM: %include (used to be 'gas')",
    ext = "asm", want = "nasm",
    src = '%include "macros.inc"\nsection .data\nmsg db "hi", 10\nlen equ $ - msg\n',
  },
  {
    name = "NASM: only resb (used to crash)",
    ext = "asm", want = "nasm",
    src = "buffer: resb 64\n",
  },
  {
    name = "NASM: bare fragment, no markers",
    ext = "asm", want = "nasm",
    src = "_start:\n  mov rax, 60\n  xor rdi, rdi\n  syscall\n",
  },
  {
    name = "NASM: comment mentions 'format ELF'",
    ext = "asm", want = "nasm",
    src = "; output format ELF64\nsection .text\nglobal _start\n",
  },
  {
    name = "NASM: .nasm extension",
    ext = "nasm", want = "nasm",
    src = "anything\n",
  },
  {
    name = "GAS: AT&T with .globl",
    ext = "asm", want = "gas",
    src = ".globl _start\n.text\n_start:\n  movq $60, %rax\n  xorq %rdi, %rdi\n  syscall\n",
  },
  {
    name = "GAS: intel_syntax noprefix",
    ext = "asm", want = "gas",
    src = ".intel_syntax noprefix\n.global _start\n_start:\n  mov rax, 60\n",
  },
  {
    name = "GAS: AT&T registers only",
    ext = "",    want = "gas",
    src = "_start:\n  movq %rsp, %rbp\n",
  },
  {
    name = "GAS: # comment",
    ext = "asm", want = "gas",
    src = "# hello\n_start:\n  nop\n",
  },
  {
    name = "GAS: .s extension",
    ext = "s",   want = "gas",
    src = "nothing recognisable\n",
  },
  {
    name = "GAS: .S extension",
    ext = "S",   want = "gas",
    src = "#include <asm/unistd.h>\n",
  },
  {
    name = "FASM: format ELF64",
    ext = "asm", want = "fasm",
    src = "format ELF64 executable 3\nentry start\nsegment readable executable\nstart:\n  mov eax, 60\n",
  },
  {
    name = "MASM: .model / PROC",
    ext = "asm", want = "masm",
    src = ".model flat, stdcall\n.code\nmain PROC\n  ret\nmain ENDP\nEND main\n",
  },
  {
    name = "Objdump: AT&T output with header",
    ext = "s", want = "objdump",
    src = "a.out:     file format elf64-x86-64\n\nDisassembly of section .text:\n0000000000001000 <_start>:\n    1000:\tf3 0f 1e fa          \tendbr64\n",
  },
  {
    name = "Objdump: Intel disassembly without header",
    ext = "asm", want = "objdump",
    src = "0000000000001000 <_start>:\n    1000:\tf3 0f 1e fa          \tendbr64\n    1004:\t48 83 ec 08          \tsub    rsp,0x8\n",
  },
  {
    name = "Objdump: .objdump extension",
    ext = "objdump", want = "objdump",
    src = "anything\n",
  },
  {
    name = "Objdump: .dis extension",
    ext = "dis", want = "objdump",
    src = "anything\n",
  },
}

local failed = 0
for _, c in ipairs(cases) do
  local ok, got = pcall(F.classify, c.src, c.ext)
  if not ok or got ~= c.want then
    failed = failed + 1
    print(("FAIL  %-42s want=%s got=%s"):format(c.name, c.want, tostring(got)))
  end
end

print(failed == 0 and ("all %d flavor tests passed"):format(#cases) or (failed .. " test(s) failed"))
os.exit(failed == 0 and 0 or 1)
