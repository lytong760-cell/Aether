# Aether Roadmap

## V1 — Bootstrap (assembly)
- Compiler written in x86-64 assembly (NASM): `src/main.asm`.
- Lex + parse modern syntax (modules, fn, types, control flow, structs/enums, inline asm).
- Lower to NASM, invoke `nasm`+`ld`.
- Multi-file modules, basic diagnostics, exit codes.
- Target: x86-64 Linux, freestanding.

## V2 — Self-hosted compiler
- Compiler rewritten in Aether (`src/v2/*.ae`), compiled by V1.
- V2 compiles itself (self-host).
- Improved diagnostics, symbol tables, type checking.
- Inline asm passthrough, file I/O via syscalls.

## V3 — Mature language
- Optimization passes (constant folding, dead code, register allocation).
- Standard library (I/O, strings, collections, memory).
- Generics and traits/interfaces.
- Better error recovery and LSP support.
- Cross-platform targets (more OS/arch).

## V4 — Production-ready
- Full standard library and package manager.
- Debug info (DWARF), profiler support.
- Incremental compilation and caching.
- Stable ABI and FFI.
- Security hardening and sandboxing.

"Fully complete, the language is now modern and powerful; everything after is optimization, bug fixes, and optional new features"
