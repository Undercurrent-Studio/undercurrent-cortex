keywords: golang,go.mod,goroutine,go.sum,cobra,fiber

# Go Patterns

Context for Go projects. Injected when Go-related keywords are detected.

## Project Structure

- `go.mod` at repo root. Module path matches repo URL.
- `cmd/` for entrypoints (`cmd/server/main.go`), `internal/` for private packages, `pkg/` for public (often unnecessary).
- No `src/` directory — Go convention is flat package layout at repo root.
- One package per directory. Package name matches directory name (lowercase, no underscores).

## Error Handling

- Always check returned errors. Never `_ = someFunc()` unless you've verified it's safe.
- Wrap errors with context: `fmt.Errorf("fetching user %d: %w", id, err)` — use `%w` for unwrappable chains.
- `errors.Is()` for sentinel errors, `errors.As()` for typed errors. Never compare error strings.
- Return errors up the stack. Only log at the top-level handler — don't log-and-return (double logging).
- Custom error types implement `Error() string`. Add context fields, not just messages.

## Concurrency

- Goroutines are cheap but not free. Always have a plan for how they terminate.
- **Always use `context.Context`** for cancellation and timeouts. Pass as first parameter.
- Channels for communication between goroutines. Mutexes (`sync.Mutex`) for protecting shared state.
- `errgroup.Group` for fan-out with error propagation. `sync.WaitGroup` for fire-and-forget.
- Watch for goroutine leaks: unbuffered channels with no reader, blocked selects, forgotten cancellation.
- `select` with `ctx.Done()` in every long-running goroutine.

## Testing

- `go test ./...` runs all tests. Table-driven tests are idiomatic Go.
- Use `testify/assert` or stdlib `if got != want` comparisons.
- `httptest.NewServer` for HTTP handler testing. `httptest.NewRecorder` for unit tests.
- `t.Parallel()` for concurrent tests — but be careful with shared test fixtures.
- `t.Helper()` in test helper functions for correct line reporting.
- Benchmarks with `testing.B`. Profile before optimizing.

## Common Pitfalls

- **Loop variable capture** (pre-Go 1.22): Goroutines in loops capture the loop variable by reference. Fixed in Go 1.22+ but be aware for older codebases.
- **Nil map writes panic**: Always `make(map[K]V)` before writing. Reading from nil map is safe (returns zero value).
- **Interface satisfaction is implicit**: Compile-time check with `var _ Interface = (*Struct)(nil)`.
- **`defer` runs at function exit, not block exit**: Deferred calls in a loop accumulate until the function returns.
- **Slice gotchas**: Slicing creates a view, not a copy. Appending to a slice may modify the original's backing array.
- **Exported = public**: Capitalized names are exported. Keep your public API surface small.

## Performance

- `sync.Pool` for high-allocation paths (reusable buffers, temporary objects).
- `strings.Builder` over `+` concatenation for building strings in loops.
- Profile with `pprof` before optimizing. `go tool pprof` for CPU and memory profiles.
- `sync.Once` for expensive one-time initialization.

## Dependency Management

- `go mod tidy` to clean unused dependencies. Run in CI to catch drift.
- Minimal external dependencies is idiomatic Go. Prefer stdlib where reasonable.
- `go mod vendor` optional — useful for reproducible builds and air-gapped environments.
