# Aether SPEC Review Report

## Fixed in latest audit (verified by inspection)

- JSON diagnostics specified as NDJSON on stderr; progress suppressed in JSON mode.
- `aetherc run` stream separation and exit code propagation specified.
- stdout behavior for generated files, assembly, object output clarified.
- Error code registry added with legacy aliases and canonical codes.
- JSON diagnostic schema v1 added with required/optional fields and examples.
- Exit status includes runtime panic, signals, traps, ICE.
- Lexical non-terminals expanded; `async fn` added; closure/`||` maximal-munch exception added;
  newline before `else` exception added.
- Embedded attributes `#[entry]`, `#[interrupt]`, `#[start]` defined.

## Remaining Undetermined Items

1. Procedural macros unspecified.
2. Executor scheduling/cancellation semantics need deeper specification.
3. GPU backend ABI and transfer semantics not fully defined.
4. 32-bit targets reserved.
5. `import` keyword compatibility decision.
6. Full inline assembly constraint language.
7. Panic unwinding strategy (abort-only in v0.1).

## Tool Verification

No EBNF parser or test suite was run. All checks were manual inspection.
