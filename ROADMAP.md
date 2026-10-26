# Aether Roadmap

Aether is a systems language with modern syntax and assembly-level control. Roadmap
below tracks milestones from bootstrap to a full modern, powerful language.

---

## V1 — Bootstrap Compiler (written in x86-64 assembly)
Goal: a working compiler that can compile Aether source to native binaries.

- Compiler implemented in NASM (`src/main.asm`), built with `nasm` + `ld`.
- Frontend:
  - Lexer with positions (file:line:col), comments, literals, identifiers.
  - Parser for modules, `fn`, `let`/`var`, `const`, `struct`, `enum`, control flow.
  - Inline `asm { ... }` passthrough.
- Backend:
  - Lowering to x86-64 instructions, ELF64 object emission via NASM.
  - Syscall-based I/O, freestanding `_start`.
- Tooling:
  - Multi-file modules (`use`/`import`), include paths (`-I`).
  - Diagnostics with error codes (E001..), hints, notes.
  - Flags: `-o`, `--emit-asm`, `--emit-obj`, `-v`.
- Target: x86-64 Linux only.

## V2 — Self-Hosted Compiler (written in Aether)
Goal: compiler is itself an Aether program; bootstrapping succeeds.

- Rewrite lexer/parser/semantic/codegen in `.ae`/`.aeth` under `src/v2/`.
- V1 compiles V2 -> `aetherc`; V2 compiles itself (self-host check).
- Type system V1:
  - Primitive types (u8..u64, i8..i64, bool, ptr, void, arrays).
  - Structs and enums, field access, indexing.
  - Basic type checking and inference for `let`.
- Modules and visibility (`pub`, private), cycle detection.
- Standard library seed: raw syscalls, pointer utils, basic strings.
- Build system: project manifest `aether.toml`, dependency collection.

## V3 — Modern Language Core (powerful + ergonomic)
Goal: Aether becomes a genuinely modern systems language.

- Object-Oriented Programming:
  - `class`/`struct` methods, associated functions.
  - Inheritance (single) and composition, `virtual`/`override`.
  - Interfaces/traits with dynamic dispatch (vtables) and static dispatch (monomorphization).
  - Encapsulation: `pub`/`priv`/`protected`, getters/setters.
  - Constructors/destructors, `new`, RAII, `Drop`.
  - Operator overloading for user types.
- Generics and polymorphism:
  - Generic functions/types, constraints/traits bounds.
  - Monomorphization + optional dynamic dispatch.
- Advanced type system:
  - Sum types (enums with payloads), pattern matching (`match`).
  - Option/Result types, null-safety via Option.
  - Lifetime/ownership (borrow checker) for memory safety.
  - Const generics, type aliases, newtypes.
- Control flow & concurrency:
  - `if`/`else`, `while`, `for`, `loop`, `match`, `?` propagation.
  - Coroutines/async-await, threads, channels, atomics.
  - `unsafe` blocks for raw operations.
- Memory model:
  - Ownership + borrowing, move semantics.
  - Smart pointers (`Box`, `Rc`, `Arc`), slices, strings (UTF-8).
  - Custom allocators, arenas.
- Error handling:
  - `Result<T,E>`, `?`, `try`/`catch` for FFI.
  - Panic/unwind with backtraces.
- Metaprogramming:
  - Macros (declarative + procedural), compile-time eval (`comptime`).
  - Conditional compilation (`#[cfg]`).
- Tooling:
  - Formatter (`aetherfmt`), linter, LSP, debugger (DWARF).
  - Package manager and registry.
  - Incremental compilation, caching, parallel builds.

## V4 — Production-Ready & Ecosystem
Goal: stable, optimized, widely usable.

- Optimizations:
  - SSA IR, optimization passes (inlining, vectorization, LICM, DCE).
  - Register allocation (graph coloring), instruction selection.
  - LTO, PGO, profile-guided opts.
- Targets and platforms:
  - Linux/macOS/Windows, x86-64 + ARM64 + RISC-V.
  - WebAssembly backend.
- FFI and interop:
  - C ABI, call C/Rust/Go libs, export C symbols.
  - Python/Node bindings (optional).
- Runtime and stdlib:
  - Full standard library (fs, net, time, crypto, json, regex).
  - Async runtime (epoll/io_uring), GC-free allocator.
- Safety and security:
  - Sandboxed execution, capability-based permissions.
  - Formal-ish checks for unsafe boundaries.
- Ecosystem:
  - Docs generator, test framework, benchmarks.
  - Stable language spec + versioning, compatibility guarantees.

---

"Fully complete, the language is now modern and powerful; everything after is optimization, bug fixes, and optional new features"
