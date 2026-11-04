# Aether SPEC Change Log (v0.1.0 refinement)

## Summary

Refined the draft specification into a more consistent and implementable document. No compiler
implementation was added.

## Major Decisions

1. Generic and lifetime syntax unified to angle brackets.
2. Range operators `..` and `..=` added.
3. Attributes `#[...]` and `#![...]` defined.
4. Module syntax clarified; `import` retained as alias for `use`.
5. Type coercion rules defined.
6. Ownership semantics expanded.
7. Compiler output modes reconciled (object writer vs linker).
8. `aetherc run` clarified as AOT-to-memory with relocation/permissions.
9. Host/target and cross-compilation documented.
10. Optimization profiles retained.
11. Safety defaults clarified.

## Second Audit Changes

- Added lexical grammar non-terminals.
- Synchronized keyword list and contextual keywords.
- Split bitwise operator precedence layers in grammar.
- Defined pointer shorthand and coercion.
- Scoped variadic const generics to Tensor.
- Documented `std::embedded`.
- Defined `nil`, `str`, `Option`, casts.
- Added newline/semicolon insertion algorithm.
- Detailed `aetherc run` mechanism.
- Clarified object writer vs linker.

## Diagnostics Addendum

- Added chapter 21: Compiler Diagnostics and Error Reporting.
- Defined diagnostic structure, categories, source locations, human/JSON output, stdout/stderr rules, exit statuses, CLI options, recovery, ICE.

## Unresolved Items

See `SPEC_REVIEW.md`.

## Final Audit Addendum

- Added error code registry and legacy mappings.
- Added JSON diagnostic schema v1 and stream rules.
- Clarified exit statuses including runtime traps and ICE.
- Clarified stdout/stderr and redirect behavior.
- Completed lexical non-terminals and async fn grammar.
- Added closure/`||` and newline-before-`else` exceptions.
- Defined embedded attributes.
