keywords: rustc,cargo.toml,lifetime,tokio,async-std,serde,clippy,rust-lang

# Rust Patterns

Context for Rust projects. Injected when Rust-related keywords are detected.

## Project Structure

- `Cargo.toml` at repo root. `src/main.rs` (binary) or `src/lib.rs` (library).
- Workspace (`Cargo.toml` with `[workspace]`) for multi-crate projects.
- Feature flags (`[features]` in Cargo.toml) for optional functionality — prefer over conditional compilation.
- `build.rs` for build scripts (code generation, native library linking).

## Ownership & Borrowing

- The borrow checker is your ally, not your enemy. Fight it less, design with it more.
- Prefer `&T` (immutable borrow) by default. `&mut T` only when mutation is needed.
- `Clone` is acceptable for prototyping but audit for production — it hides performance costs.
- Let the compiler infer lifetimes when possible. Annotate only when required (struct fields, trait objects).
- When fighting the borrow checker: consider restructuring data ownership, not adding lifetimes.
- `Rc<T>` / `Arc<T>` for shared ownership. `RefCell<T>` / `Mutex<T>` for interior mutability.

## Error Handling

- `Result<T, E>` for recoverable errors. `panic!` only for unrecoverable programmer errors.
- **Libraries**: `thiserror` for defining error types with `#[derive(Error)]`.
- **Applications**: `anyhow` for flexible error handling with context.
- `?` operator for error propagation. Chain context with `.context("what failed")?` (anyhow).
- Never `unwrap()` in production code. Use `expect("reason")` if you must, or handle the error.
- `From` trait implementations for error type conversions.

## Async

- `tokio` is the de facto async runtime. Pin runtime version in Cargo.toml.
- `async`/`.await` syntax. Functions are lazy — nothing happens until awaited.
- `tokio::spawn` for concurrent tasks. `tokio::select!` for racing futures.
- `Send + Sync` bounds required for sharing state across tasks.
- Use `tokio::sync::Mutex` in async code, not `std::sync::Mutex` (which blocks the executor).
- `tokio::join!` for concurrent execution of independent futures.

## Testing

- `#[cfg(test)] mod tests { ... }` for unit tests (same file as implementation).
- Integration tests in `tests/` directory (separate compilation, only access public API).
- `#[test]` attribute. `assert_eq!`, `assert_ne!`, `assert!` macros.
- `#[should_panic(expected = "message")]` for expected panic tests.
- `#[tokio::test]` for async tests. `mockall` crate for mocking traits.
- Doc tests (`///` comments with code blocks) run as tests automatically.

## Common Pitfalls

- **`String` vs `&str`**: `String` is owned (heap-allocated), `&str` is borrowed (a view). Accept `&str` in function params, return `String` when ownership transfer is needed.
- **`Vec<T>` vs `&[T]`**: Same pattern — accept slices, return owned vectors.
- **Iterator adaptors are lazy**: `.map()`, `.filter()`, etc. do nothing until consumed (`.collect()`, `.for_each()`, `.count()`).
- **Deadlocks with `Mutex`**: Holding a lock across an `.await` point with `std::sync::Mutex` blocks the async executor. Use `tokio::sync::Mutex`.
- **Orphan rule**: Can't implement external traits on external types. Use newtype pattern as workaround.
- **Integer overflow**: Debug builds panic, release builds wrap. Use `checked_*`, `saturating_*`, or `wrapping_*` methods for explicit behavior.
- **Move semantics**: Values are moved by default (not copied). Implement `Copy` for small value types, `Clone` for explicit duplication.

## Tooling

- `cargo clippy` for lints — treat warnings as errors in CI (`-D warnings`).
- `cargo fmt` (rustfmt) for formatting. Configure in `rustfmt.toml`.
- `cargo doc --open` for generated documentation. Write doc comments on all public items.
- `cargo bench` for benchmarks (use `criterion` crate for statistical benchmarking).
- `cargo audit` for dependency vulnerability scanning.
- `cargo tree` to inspect dependency graph.
