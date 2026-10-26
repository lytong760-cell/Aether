# Aether Language Specification — V1 (SPEC_V1)

Aether (extensions `.ae`, `.aeth`) is a systems programming language whose V1 compiles
to x86-64 assembly. Syntax is **modern** (Rust/Go-like) but semantics stay close to the
machine. V1 compiler is **external** (Perl); bootstrapping (a compiler written in Aether)
begins at **V2**. All compiler source lives in `.ae`/`.aeth` from V2 onward.

---

## 1. Goals / Non-Goals

- Goals: modern readable syntax, deterministic lowering to assembly, multi-file modules,
  clear diagnostics, self-hosting path (V2).
- Non-goals (V1): optimization, generics, closures, runtime/stdlib, non-x86-64.

## 2. File Structure

| Ext | Role |
|-----|------|
| `.ae`   | Module/application source (may contain `main`). |
| `.aeth` | Library source (no `main`; exports symbols). |

Layout:
```
project/
  aether.toml
  src/main.ae
  src/lexer.ae        # V2 compiler modules (Aether source)
  lib/math.aeth
  build/
```
Encoding UTF-8, LF, one statement per line (braces may span lines). Files end with newline.

Manifest `aether.toml`:
```
name = "aetherc"
version = "2.0.0"
entry = "src/main.ae"
modules = ["src/lexer.ae", "src/parser.ae"]
```

## 3. Lexical Grammar

- Comments: `//` line, `/* */` block (non-nesting).
- Identifiers: `[A-Za-z_][A-Za-z0-9_]*`. Case-sensitive.
- Numbers: `42`, `0x2A`, `0b1010`, `0o52`. Suffix `_u8/_u64/_i32` optional.
- Char: `'a'`, `'\n'`. String: `"..."` with escapes.
- Keywords (reserved):
  `module use pub fn let var const struct enum if else while for in return
   break continue asm extern import export unsafe sizeof typeof`
- Operators: `+ - * / % & | ^ ~ << >> == != < > <= >= && || ! = += -= *= /=`
  `-> :: . , ; : ( ) { } [ ]`
- Attributes: `#[...]` (e.g. `#[no_mangle]`, `#[entry]`).

## 4. Syntax (EBNF)

```
file        := module_decl? use* item*
module_decl := "module" path
use         := "use" path ("as" IDENT)? ("{" ident_list "}")?
path        := IDENT ("::" IDENT)*

item        := fn | struct | enum | const | extern_fn | asm_block | global

fn          := ("pub")? "fn" IDENT "(" params ")" ("->" type)? block
params      := (IDENT ":" type ("," IDENT ":" type)*)?
struct      := "struct" IDENT "{" (IDENT ":" type (",")?)* "}"
enum        := "enum" IDENT "{" (IDENT ("=" expr)? (",")?)* "}"
const       := "const" IDENT ":" type "=" expr
extern_fn   := "extern" "fn" IDENT "(" params ")" ("->" type)?
global      := "global" IDENT ":" type ("=" expr)?

block       := "{" stmt* "}"
stmt        := let_stmt | var_stmt | assign | if_stmt | while_stmt | for_stmt
            | return_stmt | break | continue | expr_stmt | asm_block

let_stmt    := "let" IDENT (":" type)? "=" expr
var_stmt    := "var" IDENT (":" type)? ("=" expr)?
assign      := lvalue ("=" | "+=" | "-=" | "*=" | "/=") expr
if_stmt     := "if" expr block ("else" (if_stmt | block))?
while_stmt  := "while" expr block
for_stmt    := "for" IDENT "in" expr ".." expr block
return_stmt := "return" expr?
expr_stmt   := expr

asm_block   := "asm" "{" asm_stmt* "}"
asm_stmt    := raw assembly line (mnemonic + operands)   # passthrough to codegen

type        := "u8"|"u16"|"u32"|"u64"|"i8"|"i16"|"i32"|"i64"
            | "bool"|"void"|"ptr" type? | IDENT (struct/enum) | "[" type ";" NUMBER "]"

expr        := literals | IDENT | path | call | unary | binary | field | index | addr | cast
call        := expr "(" (expr ("," expr)*)? ")"
field       := expr "." IDENT
index       := expr "[" expr "]"
addr        := "&" expr
cast        := expr "as" type
```

Inline assembly example:
```
asm {
    mov rax, 1
    syscall
}
```

## 5. Semantics / Execution Model

- Target: x86-64 System V AMD64 ABI, Linux. Freestanding by default (`_start`).
- Types map to sizes; `ptr` = u64. No implicit conversions except integer widening in
  `as`.
- Calling convention per §5 of V0 (args rdi rsi rdx rcx r8 r9, ret rax).
- `main`/`_start`: if `fn main()` present and `#[entry]`, compiler generates `_start`
  calling `main()` then `exit`.
- Memory: arrays are value types stored inline; `&` takes address; indexing bounds are
  NOT checked (V1).
- `asm` blocks are verbatim inserted; compiler does not validate registers inside.

## 6. Algorithms (Compiler Pipeline, V1 external)

1. CLI parse args (`aetherc <inputs> -o out [--emit-asm|--emit-obj] -I path -v`).
2. Preprocess: resolve `use`/`import` graph, include textual `include` if any (V1 keeps `use`).
3. Lex -> tokens with positions.
4. Parse -> AST.
5. Semantic:
   - Symbol table (functions, structs, consts, globals).
   - Type check expressions (minimal: size + signedness).
   - Resolve modules; detect cycles (E020).
   - Monomorphization: none (V1).
6. Lowering: AST -> Aether-IR (simple three-address) -> x86-64 instructions.
7. Codegen: emit NASM `.asm` (or object via nasm).
8. Assemble & link: `nasm -f elf64`, `ld`.
9. Report diagnostics; atomic output write.

Two passes over AST: symbols then codegen. V1 compiler is Perl (`aetherc.pl`).

## 7. Multi-File / Splitting

- Each file is a module. `module a::b` sets path; file path is hint only.
- `use a::b` / `use a::b::{x, y}` imports.
- `pub` controls export. Non-pub items are module-private.
- Build starts at entry module, collects reachable modules, compiles each to `.o`,
  links.
- Circular module deps -> E020.

## 8. Compiler Responsibilities (V1, external)

- Implement §6 in Perl (or any host language) producing NASM.
- Toolchain invocation and error propagation.
- Diagnostics format §9.
- Exit codes: 0 ok, 1 compile error, 2 usage, 3 toolchain/internal.

## 9. Error Handling & Messages

Format:
```
src/lexer.ae:42:7: error[E003]: unknown identifier `tokn`
  hint: did you mean `token`?
  note: declared in src/token.ae:10
```
Codes:
- E001 unexpected token
- E002 unterminated string/char
- E003 unknown identifier
- E004 type mismatch
- E005 undefined symbol
- E006 duplicate symbol
- E007 invalid module path / cycle (E020 for cycle specifically)
- E008 bad number literal
- E009 arity mismatch
- E010 module not found
- E020 circular dependency
- E030 toolchain failure
- E099 internal compiler error

Recovery: skip to next statement on error; skip to next item on item error; never
emit partial output (temp + rename).

## 10. Bootstrapping (starts at V2)

- **V1**: compiler is external (Perl `aetherc.pl`). Source tree may already use `.ae`
  for examples, but the compiler itself is NOT Aether.
- **V2**: compiler is rewritten in Aether (`.ae`/`.aeth` under `src/`). Bootstrapping
  begins here: V1 compiles V2 compiler source -> `aetherc` binary; then V2 compiles
  itself (self-host). V1 must support all features used by the V2 compiler source.
- Requirement: V1 feature set must be sufficient to express a lexer/parser/codegen.
  This constrains V1 to include: modules, structs, enums, arrays, pointers, inline asm,
  file I/O via syscalls.

## 11. Minimal Example

`hello.ae`:
```
module hello

fn main() -> i32 {
    // write syscall
    unsafe {
        asm {
            mov rax, 1
            mov rdi, 1
            lea rsi, [msg]
            mov rdx, 14
            syscall
        }
    }
    return 0
}

// data in asm block at module top is not allowed; use global + addr instead
global msg: [u8; 14] = "Hello, Aether!"
```
Build: `aetherc hello.ae -o hello && ./hello`

---

End of SPEC_V1.
