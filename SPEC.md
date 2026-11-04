# Aether Language Specification

**Version:** 0.1.0 (Draft, refined)
**Extensions:** `.ae`, `.aeth`
**Compiler:** Written directly in native assembly (no bootstrapping, no host-language dependency)
**Target:** Direct native execution on physical CPUs (x86-64, ARM64, RISC-V 64)
**License:** MIT
**Author:** Nguyên Games

---

## 1. Overview

**Aether** is a statically typed, compiled, general-purpose programming language. It is designed
for algorithms, embedded systems, applications, software engineering, AI, and data science, while
remaining easy to learn. The compiler is implemented directly in hand-written native assembly and
emits native machine code. Programs run directly on the CPU through the operating system loader
or, in freestanding mode, through a target-specific startup routine.

### 1.1 Goals

- A single self-contained compiler binary produced from assembly sources.
- No bootstrapping: the compiler is not written in Aether and is not built by a previous Aether
  compiler.
- Direct CPU execution: generated code is native machine code.
- Strong, expressive type system with inference for local bindings.
- First-class support for numeric, tensor, and SIMD workloads.
- Deterministic memory model suitable for embedded and real-time systems.
- Small, regular syntax learnable in a weekend.

### 1.2 Non-Goals

- No mandatory garbage-collected runtime. Optional arena and region allocators are libraries.
- No JIT compiler.
- No language-level runtime reflection beyond compile-time macros and attributes.

---

## 2. Design Principles

1. One obvious way to express each construct.
2. Explicit behavior at module and ABI boundaries; inference inside function bodies.
3. Values by default; references are opt-in through `&` and `&mut`.
4. No hidden allocations in the core language. Libraries may allocate explicitly.
5. Errors are values (`Result[T, E]`). Panics are reserved for unrecoverable invariants.
6. Embedded-first: freestanding targets are supported without an operating system or libc.
7. Learnability: keywords are ordinary English words; the grammar fits on a few pages.

---

## 3. Lexical Structure

### 3.1 Source Encoding

UTF-8. Source files use extension `.ae` or `.aeth`. The two extensions are semantically identical.

### 3.2 Whitespace and Comments

```text
// line comment
/* block comment, nestable */
```

A newline is a statement separator inside blocks. Semicolons (`;`) are optional in most positions
and are never required after a closing brace. A semicolon may be used to place multiple statements
on one line or to terminate an empty statement.

### 3.3 Identifiers

```text
ident      := [A-Za-z_][A-Za-z0-9_]*
type_ident := [A-Z][A-Za-z0-9_]*
lifetime   := "'" [A-Za-z_][A-Za-z0-9_]*
```

Identifiers are case-sensitive. The single underscore `_` is a wildcard binding and may appear
where a binding name is expected.

### 3.4 Literals

| Kind | Examples | Notes |
|------|----------|-------|
| Integer | `0`, `42`, `1_000`, `0xFF`, `0b1010`, `0o77`, `42u8`, `100i64` | Underscores are ignored. Suffix selects type. |
| Float | `3.14`, `1e-9`, `2.0f32`, `1.0f64` | Default float type is `f64`. |
| Bool | `true`, `false` | Type `bool`. |
| Char | `'a'`, `'\n'`, `'\u{1F600}'` | Type `char` (Unicode scalar value). |
| String | `"hello"`, `r"raw\n"`, `f"value={x}"` | UTF-8. `f""` is interpolated. |
| Bytes | `b"\x00\x01"` | Type `[u8; N]`. |

Escape sequences: `\\`, `\"`, `\'`, `\n`, `\r`, `\t`, `\0`, `\xNN`, `\u{...}`.

### 3.5 Keywords

```text
fn let mut const type struct enum trait impl match if else for while
loop break continue return use mod module pub priv as
true false nil unsafe extern inline defer async await spawn
macro
```

Contextual keywords (only keywords in specific syntactic positions; may be used as
identifiers elsewhere): `where`, `move`, `dyn`, `crate`, `super`, `self`, `Self`,
`const`, `mut`, `ref`, `in`, `if` (in match guards). `import` is accepted as an alias for
`use` at module scope.


`mod` declares a module. `use` imports items. `pub` and `priv` control visibility.

### 3.6 Operators

Arithmetic: `+ - * / % **`
Comparison: `== != < <= > >=`
Logical: `&& || !`
Bitwise: `& | ^ ~ << >>`
Assignment: `= += -= *= /= %= &= |= ^= <<= >>=`
Range: `.. ..=`
Other: `-> => ? . :: , : ; ( ) [ ] { } @ #`

---

## 3.7 Lexical Grammar (Non-terminals)

```ebnf
letter        := "A".."Z" | "a".."z" | "_"
digit         := "0".."9"
hex_digit     := digit | "A".."F" | "a".."f"
bin_digit     := "0" | "1"
oct_digit     := "0".."7"
ident         := letter (letter | digit)*
type_ident    := [A-Z] (letter | digit)*
lifetime      := "'" ident
int_lit       := digit (digit | "_")* int_suffix?
int_suffix    := "i8"|"i16"|"i32"|"i64"|"i128"|"isize"
                | "u8"|"u16"|"u32"|"u64"|"u128"|"usize"
hex_lit       := "0x" hex_digit (hex_digit | "_")* int_suffix?
bin_lit       := "0b" bin_digit (bin_digit | "_")* int_suffix?
oct_lit       := "0o" oct_digit (oct_digit | "_")* int_suffix?
integer       := int_lit | hex_lit | bin_lit | oct_lit
float_lit     := digit (digit | "_")* "." digit (digit | "_")* float_suffix?
                | digit (digit | "_")* ("." digit (digit | "_")*)? ("e" | "E") ("+" | "-")? digit (digit | "_")* float_suffix?
float_suffix  := "f32" | "f64"
number        := integer | float_lit
bool_lit      := "true" | "false"
char_lit      := "'" (char_char | escape) "'"
string        := """ (string_char | escape | interp)* """
raw_string    := "r" """ raw_chars """
interp_string := "f" """ (string_char | escape | "{" expr "}")* """
bytes_lit     := "b" """ (byte_escape | byte_char)* """
nil_lit       := "nil"
char_char     := <any Unicode scalar except quote or newline>
string_char   := <any UTF-8 byte except quote, backslash, or newline>
byte_char     := <any byte except quote or backslash>
raw_chars     := <any characters until the closing quote>
escape        := "\\" ("n"|"r"|"t"|"0"|"\""|"'"|"\\"|"x" hex_digit hex_digit
                | "u{" hex_digit+ "}")
byte_escape   := "\\" ("n"|"r"|"t"|"0"|"\""|"'"|"\\"|"x" hex_digit hex_digit)
interp        := "{" expr "}"
group         := "(" expr ")" | "[" expr "]" | "{" block "}"
```

`string` denotes a string literal token. `integer` denotes an integer literal token. `group`
denotes a parenthesized, bracketed, or braced expression group used by macro invocation.

## 4. Grammar (EBNF)

The following grammar is the normative syntax. All examples in this specification are intended to
be parseable by this grammar.

```ebnf
program       := module_attr* module_decl? item*

module_attr   := inner_attr
item          := outer_attr* (fn_decl | type_decl | struct_decl | enum_decl
                | trait_decl | impl_decl | const_decl | extern_decl
                | macro_decl | mod_decl | use_decl)

inner_attr    := "#![" attr_body "]"
outer_attr    := "#[" attr_body "]"
attr_body     := ident ("(" attr_args ")")?
attr_args     := attr_arg ("," attr_arg)* ","?
attr_arg      := ident ("=" literal)? | literal | path

mod_decl      := "mod" ident (";" | block)
use_decl      := "use" use_path ";"
use_path      := path ("as" ident)?
                | path "::" "{" use_list "}"
                | path "::" "*"
use_list      := use_item ("," use_item)* ","?
use_item      := ident ("as" ident)? | path

module_decl   := "module" path ";"

vis           := "pub" | "priv"

fn_decl       := vis? "async"? "fn" ident generics? params ("->" type)? where_clause? block
params        := "(" (param ("," param)*)? ","? ")"
param         := "mut"? ident ":" type
                | "self"
                | "&" "mut"? "self"
                | "&" lifetime "mut"? "self"

type_decl     := vis? "type" ident generics? "=" type ";"
struct_decl   := vis? "struct" ident generics? where_clause? ("{" field_decl* "}"
                | "(" tuple_field* ")" ";"
                | ";")
field_decl    := vis? (ident ":" type | "mut"? ident ":" type) ("," | ";")?
tuple_field   := vis? type ("," | ";")?

enum_decl     := vis? "enum" ident generics? where_clause? "{" variant* "}"
variant       := ident
                | ident "(" type ("," type)* ","? ")"
                | ident "{" field_decl* "}"

trait_decl    := vis? "trait" ident generics? (":" trait_bounds)? where_clause? "{" trait_item* "}"
trait_item    := fn_sig ";" | fn_sig block | type_decl | const_decl
fn_sig        := vis? "async"? "fn" ident generics? params ("->" type)? where_clause?

impl_decl     := "impl" generics? type ("for" type)? where_clause? "{" impl_item* "}"
impl_item     := fn_decl | type_decl | const_decl

const_decl    := vis? "const" ident ":" type "=" expr ";"
extern_decl   := "extern" (string)? "fn" ident params ("->" type)? ";"
macro_decl    := "macro" ident "(" macro_params ")" block
macro_params  := (ident ("," ident)*)?

generics      := "<" gen_param ("," gen_param)* ","? ">"
gen_param     := lifetime_param | type_param | const_param
lifetime_param:= lifetime (":" lifetime_bounds)?
type_param    := ident (":" trait_bounds)? ("=" type)?
const_param   := "const" ident ":" type
trait_bounds  := bound ("+" bound)*
lifetime_bounds:= lifetime ("+" lifetime)*
bound         := type_path | lifetime
where_clause  := "where" where_pred ("," where_pred)* ","?
where_pred    := type ":" trait_bounds | lifetime ":" lifetime_bounds

type          := fn_type | ref_type | ptr_type | array_type | slice_type
                | tuple_type | path_type | trait_object_type | never_type
                | unit_type | inferred_type
trait_object_type := "dyn" trait_bounds
fn_type       := "fn" "(" (type ("," type)*)? ","? ")" ("->" type)?
ref_type      := "&" lifetime? "mut"? type
ptr_type      := "*" ("const" | "mut")? type
array_type    := "[" type ";" expr "]"
slice_type    := "[" type "]"
tuple_type    := "(" (type ("," type)* ","?)? ")"
path_type     := type_path generics?
never_type    := "!"
unit_type     := "(" ")"
inferred_type := "_"
type_path     := path (generics)?

literal       := number | bool_lit | char_lit | string | raw_string
                | interp_string | bytes_lit | nil_lit

block         := "{" stmt* expr? "}"
stmt          := let_stmt | assign_stmt | if_stmt | for_stmt | while_stmt
                | loop_stmt | match_stmt | return_stmt | break_stmt
                | continue_stmt | defer_stmt | expr_stmt | item
let_stmt      := "let" "mut"? pattern (":" type)? ("=" expr)? ";"
assign_stmt   := place assign_op expr ";"
if_stmt       := "if" expr block ("else" (if_stmt | block))?
for_stmt      := "for" pattern "in" expr block
while_stmt    := "while" expr block
loop_stmt     := "loop" block
match_stmt    := "match" expr "{" arm* "}"
arm           := pattern ("if" expr)? "=>" (expr | block) ","?
return_stmt   := "return" expr? ";"
break_stmt    := "break" (lifetime | expr)? ";"
continue_stmt := "continue" (lifetime)? ";"
defer_stmt    := "defer" expr ";"
expr_stmt     := expr ";"

place         := postfix

expr          := assign_expr
assign_expr   := range_expr (assign_op assign_expr)?
range_expr    := or_expr (range_op or_expr)?
range_op      := ".." | "..="
or_expr       := and_expr ("||" and_expr)*
and_expr      := cmp_expr ("&&" cmp_expr)*
cmp_expr      := bitor_expr (cmp_op bitor_expr)*
bitor_expr    := bitxor_expr ("|" bitxor_expr)*
bitxor_expr   := bitand_expr ("^" bitand_expr)*
bitand_expr   := shift_expr ("&" shift_expr)*
shift_expr    := add_expr (("<<" | ">>") add_expr)*
add_expr      := mul_expr (("+" | "-") mul_expr)*
mul_expr      := pow_expr (("*" | "/" | "%") pow_expr)*
pow_expr      := unary ("**" pow_expr)?
unary         := ("!" | "-" | "~" | "&" | "&" "mut" | "*") unary
                | postfix
postfix       := primary (call | index | field | try_op | cast)*
call          := "(" (expr ("," expr)*)? ","? ")"
index         := "[" expr "]"
field         := "." (ident | integer)
try_op        := "?"
cast          := "as" type
primary       := literal | ident | path | "(" expr ")" | tuple | array
                | struct_lit | block | closure | if_expr | match_expr
                | macro_invoc | spawn_expr | async_block
spawn_expr    := "spawn" (closure | primary)
async_block   := "async" block

tuple         := "(" (expr ("," expr)* ","?)? ")"
array         := "[" (expr (";" expr)? | expr ("," expr)* ","?)? "]"
struct_lit    := path "{" (field_init ("," field_init)* ","?)? "}"
                | path "(" (expr ("," expr)*)? ","? ")"
field_init    := ident (":" expr)? | ".." expr
closure       := ("move"? "|" closure_params? "|" ("->" type)? (block | expr))
closure_params:= closure_param ("," closure_param)* ","?
closure_param := "mut"? ident (":" type)?
if_expr       := "if" expr block ("else" (if_expr | block))?
match_expr    := "match" expr "{" arm* "}"
macro_invoc   := path "!" (group | ident | literal)

pattern       := or_pat
or_pat        := alt_pat ("|" alt_pat)*
alt_pat       := range_pat | atom_pat
range_pat     := atom_pat (".." "="? atom_pat)?
atom_pat      := "_" | literal | binding | ref_pat | tuple_pat | struct_pat
                | enum_pat | slice_pat | "(" pattern ")"
binding       := ident ("@" pattern)?
ref_pat       := "&" "mut"? pattern
tuple_pat     := "(" (pattern ("," pattern)* ","?)? ")"
struct_pat    := path "{" (field_pat ("," field_pat)* ","?)? "}" (".." )?
field_pat     := ident (":" pattern)?
enum_pat      := path ("(" (pattern ("," pattern)*)? ","? ")")?
                | path "{" (field_pat ("," field_pat)* ","?)? "}"
slice_pat     := "[" (pattern ("," pattern)* ","?)? (".." pattern?)? "]"

path          := ("::")? path_seg ("::" path_seg)*
path_seg      := ident | "super" | "self" | "crate" | type_ident

literal       := int_lit | float_lit | bool_lit | char_lit | string_lit
                | bytes_lit | nil_lit
nil_lit       := "nil"

assign_op     := "=" | "+=" | "-=" | "*=" | "/=" | "%=" | "&=" | "|=" | "^=" | "<<=" | ">>="
cmp_op        := "==" | "!=" | "<" | "<=" | ">" | ">="
bit_op        := "&" | "|" | "^" | "<<" | ">>"
```

### 4.2 Newline and Semicolon Insertion

Algorithm (applied by the lexer):

1. The lexer emits a `NEWLINE` token at each source newline.
2. The parser treats `NEWLINE` as whitespace unless it appears between two tokens that cannot
   be joined into a single expression/statement.
3. A newline terminates a statement if the token before the newline can end a statement
   (identifier, literal, `)`, `]`, `}`, `break`, `continue`, `return`) and the token after the
   newline can start a statement (keyword, identifier, literal, `(`, `[`, `{`, `if`, `match`,
   etc.) and is not a binary operator or field access.
4. Semicolons are optional. A semicolon always terminates a statement.
5. Newlines inside parentheses, brackets, braces, or after a binary operator are ignored.

Exceptions:
- A line ending with `+`, `-`, `*`, `/`, `&&`, `||`, `.`, `::`, `,`, or an opening delimiter
  continues on the next line.
- A line ending with `}` always terminates, except a newline between `}` and `else` is
  treated as whitespace.
- In closure-primary position, `||` is tokenized as two `|` delimiters for empty closure
  parameters; otherwise `||` is logical OR.

Verification examples:

```ae
let x = 1 +
        2;          // continued: x = 3

let y = foo
        .bar();     // continued: method call

let z = 1;          // terminated
let w = 2
```

```ae
if cond {
    work()
}                   // terminated by }
else { ... }        // separate statement
```
### 4.1 Grammar Notes

- `mod foo;` declares a submodule in file `foo.ae`. `mod foo { ... }` defines it inline.
- Inner attributes apply to the enclosing module or crate. Outer attributes apply to the following item.
- Range expressions are non-associative.
- A block's final expression, if present, is the block's value. Otherwise the block has type `()`.
- Semicolon insertion: if a line ends with an expression and the next line starts with an operator
  or opening delimiter that can continue it, the newline is treated as whitespace. Otherwise the
  newline terminates the statement. This rule is deterministic and is specified fully in the
  lexer.

---

## 5. Type System

### 5.1 Primitive Types

| Type | Description | Size (bytes) |
|------|-------------|--------------|
| `i8` | Signed integer | 1 |
| `i16` | Signed integer | 2 |
| `i32` | Signed integer | 4 |
| `i64` | Signed integer | 8 |
| `i128` | Signed integer | 16 |
| `isize` | Signed pointer-sized integer | target pointer size |
| `u8` | Unsigned integer | 1 |
| `u16` | Unsigned integer | 2 |
| `u32` | Unsigned integer | 4 |
| `u64` | Unsigned integer | 8 |
| `u128` | Unsigned integer | 16 |
| `usize` | Unsigned pointer-sized integer | target pointer size |
| `f32` | IEEE-754 binary32 | 4 |
| `f64` | IEEE-754 binary64 | 8 |
| `bool` | Boolean | 1 |
| `char` | Unicode scalar value | 4 |
| `()` | Unit | 0 |
| `!` | Never | 0 |

`usize` and `isize` are `u64`/`i64` on 64-bit targets and `u32`/`i32` on 32-bit targets.
Aether v0.1 targets 64-bit architectures only; 32-bit support is reserved.

### 5.2 Composite Types

- Tuples: `(T1, T2, ...)`. The one-element tuple is `(T,)`.
- Arrays: `[T; N]`, where `N` is a compile-time constant. Arrays are values.
- Slices: `[T]`, a fat pointer `(ptr, len)`.
- Structs, enums, traits.
- Function pointers: `fn(T1, T2, ...) -> R`.
- Pointers: `*const T` (immutable raw pointer), `*mut T` (mutable raw pointer). `*T` is a
  shorthand for `*const T`. Raw pointers may be null.
- References: `&T` and `&mut T`.

### 5.3 Generics and Lifetimes

All generic parameters and lifetime parameters use angle brackets:

```ae
fn max<T: Ord>(a: T, b: T) -> T { if a > b { a } else { b } }

struct Pair<T, U> { first: T, second: U }

fn longest<'a>(x: &'a str, y: &'a str) -> &'a str { ... }
```

This resolves the syntactic conflict: there is only one delimiter family for type parameters
and lifetime parameters. Lifetimes are not written with square brackets anywhere in Aether.

Generic parameters may be:

- Type parameters: `T`, optionally with bounds `T: Trait` and default `T = DefaultType`.
- Lifetime parameters: `'a`, optionally with bounds `'a: 'b`.
- Const parameters: `const N: usize`.

### 5.4 Type Inference

Aether uses Hindley-Milner inference extended with trait constraints. Local `let` bindings
infer their type. Function parameters and return types must be annotated explicitly, except for
closures, whose parameter and return types may be inferred from context.

Integer literals are polymorphic until constrained; they default to `i32` if unconstrained.
Float literals default to `f64`.

### 5.5 Type Coercion and Conversion

There are no implicit numeric conversions. Values must be converted explicitly with `as`:

```ae
let x: i64 = 42i32 as i64;
let y: f64 = 3 as f64;
```

The following coercions are implicit:

- `&mut T` to `&T`.
- `&T` to `*const T` and `&mut T` to `*mut T` (and to `*const T`) inside `unsafe`.
- Array `[T; N]` to slice `[T]` at function boundaries and assignments.
- Closure to matching function pointer type if it does not capture.
- Unsizing of `Box<T>` to `Box<dyn Trait>` when `T: Trait`.

`as` may truncate, wrap, or reinterpret according to target type. Lossy conversions are allowed
but should produce compiler warnings when detectable.

### 5.6 Ownership and Borrowing

Aether uses single ownership without a garbage collector.

- A value has exactly one owner.
- Assignment of a non-`Copy` type moves the value; the source becomes uninitialized.
- Types implementing `Copy` are copied instead of moved. `Copy` requires `Clone`.
- `&T` is a shared, immutable borrow.
- `&mut T` is an exclusive, mutable borrow.
- The borrow checker enforces that mutable borrows do not alias any other borrow.
- Lifetimes are inferred; explicit lifetime parameters use `'a`.
- Non-lexical lifetimes (NLL) are supported: a borrow ends at its last use, not at scope end.

Drop semantics:

- A value is dropped when its owner goes out of scope, unless it was moved.
- Types may implement `Drop` to define destructors.
- Drop order for struct fields and tuple elements is declaration order.
- Drop order for local variables is reverse declaration order.
- `mem::forget` prevents dropping; it is `unsafe`.

### 5.7 Traits

Traits define shared behavior:

```ae
trait Display {
    fn fmt(&self, f: &mut Formatter) -> Result<(), FmtError>;
}
```

Trait resolution is static (monomorphization). Dynamic dispatch uses `dyn Trait` fat pointers.

### 5.8 Type Aliases

```ae
type Kilograms = f64;
type Result<T> = std::result::Result<T, Error>;
```

### 5.9 Standard Result and Option

```ae
enum Option<T> { Some(T), None }
enum Result<T, E> { Ok(T), Err(E) }
```

Both are defined in `core::option` and `core::result`. They are ordinary enums, not built-in
magic types, except that `?` and `match` have special support.

### 5.10 Never Type

`!` is the type of expressions that never return (e.g. `panic!`, `loop {}`). It coerces to
every type.

---

### 5.11 `nil`, `Option`, `str`, and Strings

- `nil` is the null pointer literal. Its type is inferred as `*const T` or `*mut T` from
  context. It has no other type.
- `Option<T>` is an ordinary enum (`Some(T)` / `None`). `None` is not `nil`.
- `str` is a built-in unsized UTF-8 string slice type (conceptually `[u8]` with UTF-8
  validity). It is normally used as `&str`.
- String literals have type `&'static str`.
- Interpolated strings `f"..."` desugar to formatting calls and have type `String`.
- Raw strings `r"..."` do not process escapes.
- Numeric casts with `as` follow target type range: out-of-range integer casts wrap modulo
  2^N; float-to-int truncates toward zero; int-to-float may round. Lossy conversions produce a
  warning in debug builds.

## 6. Operator and Expression Semantics

### 6.1 Precedence and Associativity

Highest to lowest:

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 14 | postfix `. [] () ? as` | left |
| 13 | unary `! - ~ & &mut *` | right |
| 12 | `**` | right |
| 11 | `* / %` | left |
| 10 | `+ -` | left |
| 9 | `<< >>` | left |
| 8 | `&` (bitwise) | left |
| 7 | `^` | left |
| 6 | `|` (bitwise) | left |
| 5 | `== != < <= > >=` | left |
| 4 | `&&` | left |
| 3 | `||` | left |
| 2 | `.. ..=` | non-associative |
| 1 | `= += -= *= /= %= &= |= ^= <<= >>=` | right |

### 6.2 Semantics

- `&&` and `||` short-circuit.
- Assignment evaluates the right-hand side, then stores into the place. Compound assignment
  `x += y` is equivalent to `x = x + y` but evaluates `x`'s place once.
- `**` is exponentiation for numeric types.
- `as` casts between types according to §5.5.
- `?` unwraps `Result`/`Option`, returning early from the enclosing function on `Err`/`None`.
- Range `a..b` excludes `b`; `a..=b` includes `b`. Either bound may be omitted.

### 6.3 Precedence Example

```ae
let v = a + b * c == d && e || f;
// parsed as: (((a + (b * c)) == d) && e) || f

let r = 1..5;          // range over or_expr
let x = foo.bar[0]();  // call result of indexing field
let y = -a ** 2;       // -(a ** 2)
```

---

## 7. Statements and Control Flow

### 7.1 `if`

`if` is an expression:

```ae
let sign = if x > 0 { 1 } else if x < 0 { -1 } else { 0 };
```

### 7.2 `match`

`match` is exhaustive. Patterns may include guards:

```ae
match value {
    0 => "zero",
    n if n < 0 => "negative",
    _ => "positive",
}
```

Exhaustiveness is checked using the pattern matrix algorithm.

### 7.3 Loops

```ae
for x in 0..10 { ... }
while cond { ... }
loop { ... }
```

`break` may carry a value: `break 42;`. `continue` skips to next iteration. Labeled loops:
`'outer: loop { break 'outer; }`.

### 7.4 `defer`

`defer expr;` evaluates `expr` when the enclosing scope exits, in reverse order of deferral.
Deferred expressions are not allowed to diverge.

### 7.5 Closures

```ae
let f = |x: i32| x * 2;
let g = move |x| x + captured;
```

Closures capture by reference by default; `move` captures by value. Closure types are anonymous
structs implementing `Fn`, `FnMut`, or `FnOnce`.

---

## 8. Modules and Visibility

- `mod name;` loads `name.ae` or `name/mod.ae`.
- `mod name { ... }` defines an inline module.
- `use path;` brings items into scope.
- `pub` makes an item visible outside its module. Default visibility is private.
- Paths: `crate::`, `super::`, `self::`.

---

## 9. Memory Model and Ownership (Detailed)

### 9.1 Allocation

- Stack allocation is the default for local variables and fixed-size aggregates.
- Heap allocation uses `Box<T>`, `Vec<T>`, and other containers in `std`. These call the
  global allocator.
- Arena/region allocation is available via `std::alloc::Arena`.
- Embedded targets may disable the global allocator (`#![no_std]`); only stack and static
  storage are available unless a custom allocator is provided.

### 9.2 Move and Copy

- Non-`Copy` values move on assignment, function argument passing, and return.
- After a move, the source location is uninitialized and cannot be used.
- `Copy` types are bitwise-copied. `Copy` implies `Clone`.

### 9.3 Borrowing Rules

- A shared borrow `&T` allows read access.
- A mutable borrow `&mut T` allows read/write access and is exclusive.
- Borrows cannot outlive the borrowed value (lifetime checking).
- NLL: borrow scope ends at last use.

### 9.4 Dangling Reference Prevention

The compiler rejects any borrow whose lifetime exceeds the lifetime of the referent. This
includes returns of references to local variables.

### 9.5 Drop and Destructors

- `Drop::drop(&mut self)` is called automatically.
- Manual drop: `drop(value)`.
- Types containing non-`Copy` fields are not `Copy`.
- Panic during drop: aborts (no unwinding through drop in v0.1).

### 9.6 Ownership in Calls and Returns

- Arguments are moved or copied according to their type.
- Return values are moved to the caller.
- References may be returned only if their lifetime is tied to an input reference.

### 9.7 Closure Capture

- By default, closures capture by reference.
- `move` forces capture by value (move or copy).
- Captured references must satisfy lifetime constraints.

### 9.8 Async Ownership

- Futures are state machines generated by the compiler.
- Captured variables in async blocks are moved into the future.
- Async functions require captured types to be `Send` if the future is sent across threads.

---

## 10. Concurrency and Async

### 10.1 Threads

`spawn` creates an OS thread. `join` waits for completion. Shared state uses atomics and locks
in `std::sync`.

### 10.1.1 Thread Spawn vs Task Spawn

- `spawn` as a keyword/expression creates an OS thread and returns a `JoinHandle<T>`.
  Example: `let h = spawn || work();`
- Asynchronous tasks are created by `std::async::spawn(future)`, which submits a future to an
  executor and returns a `Task<T>`.
- The two mechanisms are distinct: OS threads are preemptively scheduled by the OS; async
  tasks are cooperatively scheduled by the executor.
- `Send` and `Sync` apply to both, but async tasks additionally require futures to be
  `Send` when moved across threads.

### 10.2 Async/Await

```ae
async fn fetch(url: &str) -> Result<String, Error> { ... }
let result = fetch(url).await;
```

- `async fn` returns an anonymous future implementing `Future<Output = T>`.
- `.await` suspends the current task until the future completes.
- An executor in `std::async` drives tasks.
- `spawn` on an executor creates a task.

### 10.3 Send and Sync

- `Send`: safe to transfer between threads.
- `Sync`: safe to share references between threads.
- The compiler checks these bounds for thread spawning and async tasks.

### 10.4 Distinctions

- Concurrency: multiple tasks making progress (may be interleaved).
- Parallelism: multiple tasks executing simultaneously on multiple cores.
- Asynchronous execution: tasks suspend without blocking threads.

---

## 11. Standard Library

### 11.1 Core (`core`)

Available in `#![no_std]`. Provides primitive operations, traits (`Copy`, `Clone`, `Drop`,
`Sized`, `Send`, `Sync`), `Option`, `Result`, iterators, and memory primitives.

### 11.2 Modules

| Module | Purpose |
|--------|---------|
| `std::io` | Readers, writers, stdin/stdout/stderr |
| `std::fs` | Filesystem operations |
| `std::net` | TCP, UDP, DNS |
| `std::collections` | `Vec`, `HashMap`, `BTreeMap`, `HashSet`, `Deque` |
| `std::string` | `String`, `str`, formatting |
| `std::math` | Math functions (§15) |
| `std::tensor` | Tensors, matmul, activations |
| `std::simd` | SIMD vector types and intrinsics |
| `std::thread` | OS threads |
| `std::sync` | Mutex, RwLock, atomics, channels |
| `std::async` | Executor and tasks |
| `std::time` | `Instant`, `Duration` |
| `std::ffi` | C ABI interop |
| `std::mem` | Allocation, layout, transmute |
| `std::fmt` | Formatting traits |
| `std::iter` | Iterator traits |
| `std::rand` | RNG and distributions |
| `std::crypto` | Hashing, ciphers |
| `std::json` | JSON parsing/serialization |
| `std::csv` | CSV parsing/serialization |
| `std::embedded` | GPIO, delay, peripherals (embedded profile) |

### 11.3 Embedded Profile

`#![no_std]` removes OS-dependent modules (`io`, `fs`, `net`, `thread`, `async`, `time`
wall-clock). `core` and `alloc` (if an allocator is provided) remain. `#![no_main]` removes the
default entry point; the user provides `#[entry]` or `#[start]`.

---

## 12. Embedded Programming

Defined embedded attributes:

- `#[entry]`: marks the program entry point in `#![no_main]` programs.
- `#[interrupt]`: marks an interrupt handler.
- `#[start]`: marks a custom runtime start function.


Embedded APIs (provided by `std::embedded`):

- `gpio::pin(n) -> Pin`
- `Pin::output(&mut self)`, `Pin::toggle(&mut self)`, `Pin::set(&mut self, bool)`
- `delay_ms(ms: u32)`, `delay_us(us: u32)`
- These APIs are only available when `#![no_std]` targeting an embedded profile.


- Volatile MMIO: `volatile_read<T>(addr: usize) -> T` and `volatile_write<T>(addr, val)`.
- Interrupt handlers: `#[interrupt] fn handler()`.
- Inline assembly:

```ae
unsafe {
    asm!("mov {0}, {1}", in(reg) x, out(reg) y);
}
```

- Memory-mapped peripherals are modeled as `#[repr(C)]` structs with volatile fields.
- Static allocation only unless an allocator is linked.
- Targets: Cortex-M, RISC-V embedded, AVR (experimental).

---

## 13. AI, Tensor, and SIMD

### 13.1 Tensor Types

```ae
// Compile-time shape: variadic const generics are supported only for Tensor.
type Tensor<T, const ...Dims: usize>

// Dynamic shape:
type DynTensor<T, const RANK: usize>

type Matrix<T> = DynTensor<T, 2>
type Vector<T> = DynTensor<T, 1>
```

Variadic const generics (`const ...Dims: usize`) are defined only for `Tensor`. They expand to a
fixed arity during monomorphization. General variadic generics are not part of v0.1.

`Tensor<T, 2, 3>` has shape `[2, 3]` known at compile time. `DynTensor<T, 2>` stores its shape
at runtime.


Tensor memory layout defaults to row-major (C order). Column-major is available via
`Tensor::col_major`.

### 13.2 SIMD

SIMD vector types: `v4f32`, `v8f32`, `v2f64`, `v4i32`, etc. These map to CPU SIMD registers.
The available set depends on the target and enabled features (SSE, AVX, NEON, RVV).

### 13.3 Autograd and NN

- Autograd via `#[derive(Grad)]` on functions; reverse-mode automatic differentiation.
- NN primitives in `std::tensor::nn`: `matmul`, `conv2d`, `relu`, `sigmoid`, `softmax`,
  `layernorm`, `attention`.
- Optimizers: SGD, Adam, AdamW.
- GPU offload is optional and explicit via `#[gpu]` targeting SPIR-V or PTX. It requires an
  external GPU toolchain and is not enabled by default.

These features are library and backend features, not core language semantics, except for the
`#[derive]` and `#[gpu]` attribute mechanisms.

---

## 14. Compiler Architecture

### 14.1 Host and Target

- **Host architecture**: the machine running the compiler.
- **Target architecture**: the machine running the compiled program.
- The compiler binary is host-specific. A host binary contains code generators for all
  supported targets.
- Cross-compilation is supported: `aetherc build --target aarch64-linux`.
- No bootstrapping: each host binary is built from assembly sources using the system assembler
  and linker.

### 14.2 Output Methods

Aether supports two output modes, selected by `--emit`:

1. **Object mode (default)**: the compiler's built-in object writer emits ELF, Mach-O, or PE
   object files and executables. No external assembler is required. Relocations, symbol tables,
   and section layout are handled by the object writer.
2. **Assembly mode (`--emit=asm`)**: the compiler emits textual assembly for debugging and
   inspection. An external assembler may be used, but this is optional and not required for
   normal builds.

Linking is a separate stage from object writing:
- The **object writer** produces binary object files/executables from machine code.
- The **linker** combines objects, resolves symbols, applies relocations, and produces the final
  executable. The built-in linker supports freestanding and simple hosted executables. For
  complex hosted targets, `--use-system-linker` invokes the system linker.

### 14.1.1 Host-Specific Compiler Build

The compiler is built per host architecture. The build compiles the host entry point plus all
shared compiler modules (lexer, parser, types, codegen for every supported target) into a single
host-native binary. Thus one host binary can compile for multiple targets. Cross-compilation does
not require a separate compiler binary, only `--target`.

### 14.3 AOT and `aetherc run`

Aether is an ahead-of-time (AOT) compiler. `aetherc run file.ae` performs the full pipeline
through code generation, then:

1. Creates an anonymous executable memory mapping.
2. Writes the generated machine code and data into the mapping.
3. Applies all relocations and resolves external symbols against the host process / system
   libraries.
4. Sets memory permissions: code pages read-execute, data pages read-write (W^X).
5. Transfers control to the entry point (`_start` or `main` according to target ABI) with
   standard `argc`, `argv`, `envp` layout.
6. Waits for the entry point to return, captures the exit status, unmaps memory, and exits.

This is not JIT compilation: all code generation completes before execution; no code is generated
or recompiled during execution; no profiling or runtime optimization occurs. `aetherc run` is
supported only for hosted targets.

### 14.4 Pipeline

```text
Source (.ae/.aeth)
  -> Lexer          (characters -> tokens)
  ->Parser         (tokens -> AST)
  ->Name Resolution (AST -> resolved AST, symbols)
  ->Type Checker   (resolved AST -> typed AST, constraints)
  ->HIR Lowering    (typed AST -> HIR)
  ->MIR Lowering    (HIR -> MIR, SSA CFG)
  ->Borrow Check    (MIR -> validated MIR)
  ->Optimizer       (MIR -> optimized MIR)
  ->LIR Lowering    (MIR -> LIR)
  ->RegAlloc        (LIR -> LIR with physical regs)
  ->Codegen         (LIR -> machine code / assembly)
  ->Object Writer   (machine code -> object/executable)
  ->Linker          (objects -> executable)
```

Responsibilities:

- Lexer: tokenization, keyword classification, error recovery.
- Parser: syntax, AST construction, panic-mode recovery.
- Name Resolution: scope, imports, visibility.
- Type Checker: inference, trait resolution, exhaustiveness.
- HIR: desugaring (closures, for, ?, methods).
- MIR: SSA CFG, borrow checking, optimization input.
- Optimizer: semantics-preserving transforms.
- LIR: machine-level representation, ABI lowering.
- Codegen: instruction selection, target-specific emission.
- Object Writer/Linker: binary format, relocation, executable.

### 14.5 Directory Layout

```text
aether/
├── README.md
├── LICENSE
├── SPEC.md
├── compiler/
│   ├── asm/
│   │   ├── bootstrap/
│   │   │   ├── entry_x86_64.s
│   │   │   ├── entry_arm64.s
│   │   │   └── entry_riscv64.s
│   │   ├── common/
│   │   ├── lexer/
│   │   ├── parser/
│   │   ├── ast/
│   │   ├── resolve/
│   │   ├── types/
│   │   ├── hir/
│   │   ├── mir/
│   │   ├── opt/
│   │   ├── codegen/
│   │   └── driver/
│   ├── include/
│   └── build.sh
├── runtime/
├── std/
├── tests/
├── examples/
└── docs/
```

### 14.6 No Bootstrapping Policy

The compiler is written entirely in assembly. Build:

```sh
as compiler/asm/bootstrap/entry_x86_64.s ... -o aetherc.o
ld aetherc.o -o aetherc
```

No C, Rust, Go, or other high-level compiler is required beyond the system assembler and
linker. These are OS toolchain components, not a language bootstrap.

---

## 15. Math Functions (`std::math`)

Constants: `PI`, `E`, `TAU`, `INF`, `NAN`, `EPSILON`.

Elementary: `abs`, `sign`, `floor`, `ceil`, `round`, `trunc`, `sqrt`, `cbrt`, `pow`, `exp`,
`exp2`, `log`, `log2`, `log10`, `log1p`, `expm1`.

Trigonometry: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`,
`asinh`, `acosh`, `atanh`.

Special: `hypot`, `erf`, `erfc`, `gamma`, `lgamma`, `tgamma`.

Linear algebra (`std::linalg`): `dot`, `cross`, `norm`, `normalize`, `matmul`, `transpose`,
`det`, `inv`, `solve`.

Vectorized SIMD (`std::simd::math`): `vabs`, `vsqrt`, `vsin`, `vcos`, `vexp`, `vlog`, `vpow`.

Random (`std::rand`): PCG and xoshiro generators; distributions uniform, normal, bernoulli.

---

## 16. Optimization

### 16.1 Passes

1. SimplifyCfg
2. Inline
3. SCCP (sparse conditional constant propagation)
4. ConstFold + StrengthReduce
5. GVN (global value numbering)
6. SROA (scalar replacement of aggregates)
7. Mem2Reg
8. LICM (loop invariant code motion)
9. LoopUnroll
10. Vectorize (SLP + loop vectorization)
11. DCE (dead code elimination)
12. TailCallOpt
13. RegAlloc
14. Peephole

### 16.2 Algorithms

- Dominator tree: Lengauer-Tarjan.
- Loop detection: back edges and natural loops.
- Alias analysis: basic type-based alias analysis (TBAA).
- Inlining heuristic: benefit = call overhead saved - code size growth.
- Register allocation: graph coloring with spilling; linear scan available for compile speed.

### 16.3 Profiles

| Flag | Behavior |
|------|----------|
| `-O0` | No optimization; debug info retained. |
| `-O1` | Basic optimizations. |
| `-O2` | Default; includes inlining and LICM. |
| `-O3` | Aggressive; enables vectorization. |
| `-Os` | Optimize for size. |
| `-Oz` | Minimize size. |

Optimizations must preserve program semantics. Floating-point reassociation requires
`-ffast-math`-equivalent flag `--fast-math`, which is off by default.

---

## 17. Security and Safety

- Integer overflow: checked (trap) in debug builds; wrapping in release builds unless
  `-C overflow-checks` is enabled. Explicit `checked_*`, `wrapping_*`, `saturating_*`
  operations are always available.
- Bounds checking: always performed for slice/array indexing. `get_unchecked` is unsafe.
- Null/invalid pointers: dereferencing requires `unsafe`.
- Undefined behavior: minimized. Only `unsafe` blocks, FFI, and inline asm may introduce UB.
- Stack overflow: guard pages in hosted mode; embedded mode has no guard pages.
- Stack canaries: enabled in debug builds.
- Memory layout: `#[repr(C)]`, `#[repr(packed)]`, `#[repr(align(N))]`.
- FFI safety: `extern "C"` functions use C ABI; types crossing FFI must be `#[repr(C)]`.

Safe vs unsafe boundary:

- Safe code cannot cause memory unsafety or UB.
- `unsafe` blocks/functions may dereference raw pointers, call unsafe functions, access
  mutable statics, implement unsafe traits, and use inline asm.

---

## 18. Tooling

- `aetherc build`: compile project using `Aether.toml`.
- `aetherc run`: compile and execute (AOT to memory).
- `aetherc check`: typecheck only.
- `aetherc fmt`: format source.
- `aetherc test`: run `#[test]` functions.
- `aetherc doc`: generate documentation.
- REPL: compiled, assembly-based, in-memory.
- LSP: `aether-lsp`.

### 18.1 Manifest (Aether.toml)

```toml
[package]
name = "myapp"
version = "0.1.0"
edition = "2026"

[dependencies]
std = "0.1"

[profile.release]
opt-level = 3
lto = true
```

---

## 19. Examples

### Hello World

```ae
fn main() {
    println!("Hello, Aether!");
}
```

### Fibonacci

```ae
fn fib(n: u64) -> u64 {
    if n < 2 { n } else { fib(n - 1) + fib(n - 2) }
}
```

### Embedded Blink

```ae
#![no_std]
#![no_main]

use std::embedded::gpio;

#[entry]
fn main() -> ! {
    gpio::pin(13).output();
    loop {
        gpio::pin(13).toggle();
        delay_ms(500);
    }
}
```

### Matrix Multiply

```ae
fn matmul(a: &Matrix<f32>, b: &Matrix<f32>) -> Matrix<f32> {
    let (m, k) = a.shape();
    let (_, n) = b.shape();
    let mut c = Matrix::zeros(m, n);
    for i in 0..m {
        for j in 0..n {
            let mut s = 0.0f32;
            for l in 0..k {
                s += a[(i, l)] * b[(l, j)];
            }
            c[(i, j)] = s;
        }
    }
    c
}
```

---

## 20. Testing and Conformance

- Unit tests: `#[test] fn ...()`.
- Property tests: `#[property]`.
- Conformance suite: lexer, parser, typecheck, codegen, runtime golden tests.
- Differential testing against a reference interpreter included in the test harness
  (assembly-based, not a bootstrap compiler).

---

## 21. Compiler Diagnostics and Error Reporting

### 21.1 Diagnostic Structure

A Diagnostic is a structured record with the following fields:

- `severity`: `error`, `warning`, `note`, `help`, or `ice`.
- `code`: stable diagnostic code (e.g. `E0003`).
- `message`: short human-readable summary.
- `phase`: compiler phase where it was produced.
- `primary_span`: main source span.
- `secondary_spans`: additional labeled spans.
- `notes`: explanatory notes.
- `help`: actionable guidance.
- `suggestions`: machine-applicable code edits.
- `related`: related diagnostics (e.g. previous definition).
- `children`: nested diagnostics.

Severity semantics:

- `error`: compilation fails.
- `warning`: compilation succeeds unless `--deny-warnings`.
- `note`: informational context attached to another diagnostic.
- `help`: suggested fix or next step.
- `ice`: internal compiler error; always fails.

### 21.2 Diagnostic Categories

Error code families (stable ranges):

- `E00xx`: lexical errors.
- `E01xx`: parsing errors.
- `E02xx`: name resolution.
- `E03xx`: module/import.
- `E04xx`: type checking.
- `E05xx`: generics/traits.
- `E06xx`: ownership/borrow.
- `E07xx`: lifetimes.
- `E08xx`: macros.
- `E09xx`: const evaluation.
- `E10xx`: code generation.
- `E11xx`: linking.
- `E12xx`: runtime traps.
- `E9xxx`: internal compiler errors.

Existing codes retained: `E0001`..`E0010`. New codes are appended without reusing old numbers. Codes are stable across versions; deprecated codes are retained as aliases.

Compile-time diagnostics are distinct from runtime errors (`E12xx`) and ICEs (`E9xxx`).

### 21.2.1 Error Code Registry and Legacy Mapping

Canonical codes (selected):

| Code | Category | Meaning |
|------|----------|---------|
| E0001 (legacy) | parsing | unexpected token (alias of E0101) |
| E0002 (legacy) | type | type mismatch (alias of E0401) |
| E0003 (legacy) | resolution | undefined name (alias of E0201) |
| E0004 (legacy) | ownership | borrow checker violation (alias of E0602) |
| E0005 (legacy) | type | non-exhaustive match (alias of E0402) |
| E0006 (legacy) | const eval | integer overflow in checked context (alias of E0901) |
| E0007 (legacy) | codegen/runtime | out of bounds (alias of E1202) |
| E0008 (legacy) | ownership | use of moved value (alias of E0603) |
| E0009 (legacy) | lifetime | lifetime error (alias of E0701) |
| E0010 (legacy) | generics | trait bound not satisfied (alias of E0502) |
| E0101 | parsing | unexpected token |
| E0102 | parsing | missing semicolon |
| E0201 | resolution | undefined name |
| E0301 | module | module not found |
| E0302 | import | import resolution failure |
| E0401 | type | type mismatch |
| E0402 | type | non-exhaustive match |
| E0501 | generics | invalid generic constraint |
| E0502 | traits | trait bound not satisfied |
| E0601 | ownership | ownership violation |
| E0602 | borrow | borrow checker violation |
| E0603 | ownership | use of moved value |
| E0701 | lifetime | lifetime error |
| E0801 | macro | macro expansion error |
| E0901 | const eval | const evaluation failure |
| E1001 | codegen | code generation failure |
| E1101 | linking | linker failure |
| E1201 | runtime | integer overflow trap |
| E1202 | runtime | bounds check trap |
| E9001 | ice | internal compiler error |
| W0001 | warning | unreachable code |
| W0002 | warning | deprecated API |

Legacy codes remain accepted by `--explain` and in diagnostic output for compatibility. New code
should use canonical codes. Codes are never reused; deprecated codes map to canonical ones.

### 21.3 Source Location

A source location consists of:

- `file`: path.
- `byte_start`, `byte_end`: UTF-8 byte offsets (half-open).
- `line_start`, `line_end`: 1-based line numbers.
- `col_start`, `col_end`: 1-based display columns.

Columns are display columns after tab expansion (tab = 4 spaces) and Unicode width handling. Byte offsets are authoritative; columns are derived for display.

Multi-line spans are allowed. Multiple labels may attach to one diagnostic if they refer to the
same underlying issue.

### 21.4 Human-readable Output

Terminal format (default):

```text
error[E0003]: cannot find value `foo` in this scope
 --> src/main.ae:3:5
  |
3 |     let x = foo + 1;
  |             ^^^ not found
  |
  = note: `foo` may be misspelled
  = help: did you mean `for`?
```

Examples required (abbreviated):

- Undefined variable: `E0003`.
- Unexpected token: `E0101`.
- Missing semicolon: `E0102`.
- Type mismatch: `E0401`.
- Invalid generic constraint: `E0501`.
- Ownership violation: `E0601`.
- Borrow checker violation: `E0602`.
- Lifetime error: `E0701`.
- Unreachable code: `W0001` (warning).
- Deprecated API: `W0002`.
- Linker failure: `E1101`.

The compiler reports as many independent diagnostics as possible in one run, subject to recovery
limits (§21.9).

### 21.5 Machine-readable Diagnostics (JSON)

`--error-format=json` emits one JSON object per diagnostic to stdout? No: diagnostics always go
to stderr; JSON diagnostics go to stderr as newline-delimited JSON (NDJSON). Each line is a
valid JSON object:

```json
{"severity":"error","code":"E0003","message":"cannot find value `foo`","phase":"resolve",
 "file":"src/main.ae","byte_start":42,"byte_end":45,"line_start":3,"line_end":3,
 "col_start":5,"col_end":8,"labels":[{"span":[42,45],"text":"not found"}],
 "notes":["..."],"help":"...","suggestions":[]}
```

No progress or log text is mixed with JSON diagnostic lines. Non-diagnostic informational
messages are suppressed or routed separately when JSON format is active.

### 21.5.1 JSON Diagnostic Schema (v1)

```json
{
  "schema_version": "1",
  "severity": "error",
  "code": "E0401",
  "message": "mismatched types",
  "phase": "typecheck",
  "file": "src/main.ae",
  "byte_start": 42,
  "byte_end": 46,
  "line_start": 3,
  "line_end": 3,
  "col_start": 14,
  "col_end": 18,
  "labels": [{"span": [42, 46], "text": "expected `i32`, found `f64`"}],
  "secondary_labels": [{"file": "src/lib.ae", "span": [10, 12], "text": "defined here"}],
  "notes": ["..."],
  "help": "convert with `as`",
  "related": [{"code": "E0401", "message": "..."}],
  "children": [],
  "suggestions": [{"span": [42, 46], "replacement": "x as i32", "applicability": "machine-applicable"}]
}
```

Required fields: `schema_version`, `severity`, `code`, `message`, `phase`, `file`, `byte_start`,
`byte_end`, `line_start`, `line_end`, `col_start`, `col_end`. All others optional.

Examples:
- Lexical: `E0001`/`E0101` unexpected token.
- Parser: `E0102` missing semicolon.
- Type: `E0401` mismatch.
- Ownership: `E0601` ownership violation.
- Linker: `E1101` linker failure.

### 21.5.2 Stream Rules for JSON

When `--error-format=json`, stderr contains only NDJSON diagnostic objects. No progress text,
color, or human-formatted diagnostics are emitted to stderr. stdout is unaffected.

### 21.6 stdout and stderr

- Compiler diagnostics (human or JSON) go to stderr.
- Warnings go to stderr.
- Informational/build progress goes to stderr unless `--quiet`.
- Generated artifact paths and requested data go to stdout.
- `--emit=asm` writes assembly to the output file by default; `--print-asm` writes assembly to
  stdout.
- `--emit=obj` writes object code to the output file; no object bytes go to stdout unless
  `--print-obj` is given.
- Program stdout/stderr when using `aetherc run` are forwarded unchanged to the process's
  stdout/stderr.
- Compiler diagnostics are never written to stdout.
- JSON diagnostics are never mixed with human text on the same stream.

Redirect behavior: if stdout or stderr is not a TTY, color is disabled by default (`--color=auto`).
Redirecting program output via `aetherc run` preserves exit code and stream separation.

### 21.7 Exit Status

Compiler exit codes:

- `0`: success.
- `1`: compilation failure (errors).
- `2`: invalid command-line arguments.
- `3`: input/output error.
- `4`: code generation failure.
- `5`: linker failure.
- `6`: internal compiler error.

`aetherc run`: if compilation succeeds, the process exits with the executed program's exit
status. Runtime panic prints a panic message to the program's stderr and exits with status 101.
Signals terminate with 128 + signal number. Runtime traps (overflow, bounds) exit with status 101.
If compilation fails, exits with compiler code above. ICE always exits 6.

Stream behavior when redirected/piped: diagnostics remain on stderr; program output on stdout/stderr
of the child is forwarded. Exit codes propagate as above.

### 21.8 Command-line Diagnostic Options

- `--error-format=human|json`: select output format.
- `--color=auto|always|never`: color control.
- `--deny-warnings`: treat warnings as errors.
- `--allow-warnings`: default; warnings do not fail build.
- `--explain`: print extended explanation for an error code (e.g. `--explain E0003`).
- `--verbose`: include phase timing and ICE details.
- `--quiet`: suppress progress; keep diagnostics.

Interactions: `--deny-warnings` implies warnings affect exit status. `--quiet` does not suppress
diagnostics. `--error-format=json` disables color.

### 21.9 Error Recovery

- Lexer: on invalid character, emit diagnostic and skip one UTF-8 scalar; continue.
- Parser: panic-mode recovery synchronizes on `;`, `}`, `fn`, `struct`, etc.; inserts error
  nodes; continues.
- Type checker: on type mismatch, record error and continue with an error type to avoid cascades.
- Borrow checker: report all violations in a function before stopping.
- Maximum diagnostics per run: 100 (configurable via `--max-diagnostics`).
- Duplicate suppression: identical diagnostics at same span are collapsed.
- Cascading prevention: errors in dependent items suppress downstream errors where possible.

Compiler stops a phase early if the input is too damaged to proceed safely (e.g. parser produced
no AST).

### 21.10 Internal Compiler Errors

ICEs are reported with code `E9xxx`, compiler version, phase, and a minimal reproduction hint.
They are distinct from user errors. `--verbose` includes stack trace and internal identifiers.
No source file contents beyond the relevant span are printed by default.

## Appendix A: Error Codes

- `E0001` unexpected token
- `E0002` type mismatch
- `E0003` undefined name
- `E0004` borrow checker violation
- `E0005` non-exhaustive match
- `E0006` integer overflow (checked context)
- `E0007` out of bounds (checked context)
- `E0008` use of moved value
- `E0009` lifetime error
- `E0010` trait bound not satisfied

---

*End of Specification v0.1.0*
