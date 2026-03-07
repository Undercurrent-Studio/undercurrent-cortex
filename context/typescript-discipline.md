# TypeScript Discipline — Undercurrent

**`noUncheckedIndexedAccess: true`** is enabled. All array/object indexed access returns `T | undefined`.
- Use `!` post-fix assertion only when access is provably safe (e.g., after `.length` check or `.find()` guard).
- Use `?? fallback` for optional chain results.
- Never suppress with `as T` — use type narrowing instead.

**`Promise.allSettled` type predicates**: Results are `PromiseSettledResult<T>[]`. Filter fulfilled:
```ts
const fulfilled = results.filter((r): r is PromiseFulfilledResult<T> => r.status === 'fulfilled').map(r => r.value);
```

**`as never` casts**: Required for yahoo-finance2 `quoteSummary` modules param. Acceptable narrow exception.

**`"use client"` data export gotcha**: Never export data constants (arrays, objects) from `"use client"` files — server components importing them get bundled as client. Extract shared data to a plain `.ts` file with no directive.

**Server/client import boundaries**: `server-only` package enforces build-time errors. Types can cross the boundary; runtime code cannot. Shared types go in `src/types/`.
