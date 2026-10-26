# Aether Language Specification — V1 (SPEC_V1)

Aether (extensions `.ae`, `.aeth`) is a low-level programming language built directly on
x86-64 assembly concepts. V1 is a **bootstrap compiler**: it is implemented outside of
Aether (in Perl) and lowers Aether source to NASM assembly, then invokes `nasm` + `ld`.

---

## 1. Goals and Non-Goals

- **Goals**: readable assembly-level syntax, multi-file projects, modules, macros, clear
  diagnostics, deterministic builds.
- **Non-goals (V1)**: optimization, type system, high-level control flow beyond macros,
  cross-architecture (x86-64 Linux only), debugger integration.

## 2. File Structure

| Extension | Role |
|-----------|------|
| `.ae`     | Application/module source. May define an entry point (`_start` or `main`). |
| `.aeth`   | Library/module source. No entry point; exports symbols. |

Project layout (recommended):
```
project/
  aether.toml          # manifest (optional in V1)
  src/
    main.ae
  lib/
    math.aeth
  build/
    *.asm *.o a.out
```

Encoding: UTF-8. Line endings: LF (CRLF accepted, normalized). One statement per line.
Indentation is cosmetic (spaces/tabs). Files must end with a newline.

Manifest `aether.toml` (optional):
```
name = "demo"
entry = "src/main.ae"
modules = ["lib/math.aeth"]
```

## 3. Lexical Grammar

- Comments: `;` to end of line. Block comments `/* ... */` (may not nest).
- Identifiers: `[A-Za-z_][A-Za-z0-9_]*`. Case-sensitive.
- Labels: identifier followed by `:` at statement start (or `name:` anywhere a label is valid).
- Numbers: `42` (dec), `0x2A`, `0b101010`, `0o52`. Suffixes: `h`/`b`/`o`/`d` optional.
- Chars: `'a'`, `'\n'`, `'\0'`.
- Strings: `"..."` with escapes `\n \t \r \\ \" \0 \xHH`.
- Registers: `rax rbx rcx rdx rsi rdi rbp rsp r8..r15` and 32/16/8-bit aliases.
- Keywords/directives are case-insensitive for directives, case-sensitive for identifiers? V1: directives case-insensitive.

Operators: `+ - * / % & | ^ ~ << >> = == != < > <= >=` (used in `equ`/macro exprs).

## 4. Syntax (EBNF-ish)

```
file        := (module_decl)? (import)* (section)*
module_decl := "module" IDENT
import      := "import" IDENT ("as" IDENT)? "from" STRING
            | "include" STRING

section     := "section" SECTION_NAME stmt_list
SECTION_NAME:= ".text" | ".data" | ".bss" | ".rodata"

stmt        := label | directive | instruction | proc_block | macro_block | data_decl

directive   := "global" IDENT
            | "extern" IDENT
            | "equ" IDENT "," expr          # IDENT equ expr  (also IDENT equ expr)
            | "align" NUMBER

proc_block  := "proc" IDENT (":" params?) stmt_list "endp"
macro_block := "macro" IDENT params? stmt_list "endm"

data_decl   := IDENT? ("db"|"dw"|"dd"|"dq"|"resb"|"resw"|"resd"|"resq") (expr ("," expr)*)?

instruction := MNEMONIC (operand ("," operand)*)?
operand     := register | identifier | number | char | string
            | "[" expr ("," scale?) "]"     # memory reference
            | "rel" operand

expr        := standard arithmetic/precedence expression over numbers, idents, $, $$
```

Notes:
- `proc name:` and `proc name` both accepted; colon optional after name.
- Labels may be local (`.name`) scoped to nearest global label.
- `$$` = current section base, `$` = current offset.

## 5. Semantics / Execution Model

- Target: x86-64 System V AMD64 ABI, Linux syscalls.
- Calling convention: args in `rdi rsi rdx rcx r8 r9`, return in `rax`, caller-saved
  `rax rcx rdx rsi rdi r8-r11`, callee-saved `rbx rbp r12-r15`.
- Stack: 16-byte aligned before `call`.
- No runtime; programs are freestanding. Entry symbol `_start` (or `main` if using libc,
  V1 default freestanding `_start`).
- Memory sections map to ELF sections via NASM.

## 6. Algorithms (Compiler Pipeline)

1. **CLI parse**: validate args, determine input files, output path.
2. **Preprocess** (per file):
   - Resolve `include` (textual, with include-guard via `#pragma once`-like `once`).
   - Expand `macro` definitions (textual substitution with parameters).
   - Remove comments.
3. **Lex**: produce token stream with positions (file, line, col).
4. **Parse**: build AST (list of sections/statements).
5. **Semantic analysis**:
   - Build global symbol table (labels, procs, data, equ).
   - Resolve `import`/`extern` against exported symbols of other modules.
   - Validate instruction mnemonics against allowed table (subset of x86-64).
   - Check label uniqueness within scope; section placement rules.
   - Compute `equ` expressions (constant folding, V1: only constants and `$`).
6. **Codegen**: emit NASM source (`.asm`) preserving sections, labels, instructions.
   - Imports become `extern`; exports become `global`.
7. **Assemble & link**: `nasm -f elf64` then `ld` (or `gcc` if libc requested).
8. **Report**: diagnostics, timing, output path.

Single-pass where possible; semantic pass requires two passes (symbols then codegen).

## 7. Multi-File / Splitting

- Each `.ae`/`.aeth` is one module. Module name = file basename unless `module` declared.
- `import foo from "path.aeth"` brings exported symbol `foo` into current scope.
- `include "path"` performs textual inclusion (no new scope).
- Build collects all reachable modules starting from entry; compiles each to `.o`;
  links together.
- A `.aeth` without `global`/exported symbols is allowed (internal helpers) but
  warns `W001 unused module`.
- Circular imports are an error `E020`.

## 8. Compiler Responsibilities (V1)

- Parse & validate syntax.
- Manage symbol tables across modules.
- Emit valid NASM.
- Invoke toolchain (`nasm`, `ld`) and propagate failures.
- Produce diagnostics in the format in §9.
- Support `--emit-asm`, `--emit-obj`, `-o`, `-I includepath`, `-v`.
- Exit codes: `0` ok, `1` compile error, `2` usage/args, `3` toolchain/internal.

## 9. Error Handling & Messages

Format (one line, machine-parseable):
```
file.ae:12:5: error[E003]: unknown mnemonic 'movv'
  hint: did you mean 'mov'?
```
Warnings: `warning[W001]: ...`. Notes: `note: ...`.

Error codes:
- `E001` unexpected token
- `E002` unterminated string/char
- `E003` unknown mnemonic
- `E004` invalid operand for mnemonic
- `E005` undefined symbol
- `E006` duplicate symbol
- `E007` invalid section
- `E008` bad number literal
- `E009` macro arity mismatch
- `E010` include not found
- `E020` circular import
- `E030` toolchain failure (nasm/ld)
- `E099` internal compiler error

Recovery: on a statement error, skip to next newline; on a section error, skip to next
section; never emit partial output file (atomic write to temp then rename).

## 10. Bootstrapping

- V1 compiler is implemented in Perl (see `aetherc.pl`) and depends on `nasm`+`ld`.
- V1's job is to be correct enough to compile a V2 compiler written in Aether.
- V2 (future) is self-hosted; out of scope for SPEC_V1.

## 11. Minimal Example

`hello.ae`:
```
section .data
    msg db "Hello, Aether!", 10
    len equ $ - msg

section .text
    global _start

_start:
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg]
    mov rdx, len
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall
```
Build: `aetherc hello.ae -o hello && ./hello`

---

End of SPEC_V1.
