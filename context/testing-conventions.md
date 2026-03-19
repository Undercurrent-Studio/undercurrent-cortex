keywords: vitest,test suite,write test,add test,run test,fix test,coverage
# Testing Conventions Context

**Stack**: vitest + jsdom. `server-only` module stubbed for test imports. comprehensive test suite. CI: `.github/workflows/ci.yml` runs audit -> lint -> type-check -> test -> build.

**Mock patterns**: `vi.mockRejectedValue` + fake timers leaks unhandled rejections. Use `mockImplementation` with `async () => { throw new Error(...) }` instead. Shared helpers: `src/__tests__/helpers/mock-supabase.ts` (chainable builder) + `mock-stripe.ts` (Stripe instance + event factory).

**Dynamic imports**: Use `vi.hoisted(() => ({ mockFn: vi.fn() }))` to create mock references available in both the factory and test code. Module-level `const` variables aren't initialized when `vi.mock()` factory runs.

**TypeScript**: `noUncheckedIndexedAccess: true` — all array/object indexed access returns `T | undefined`. Use `!` for provably safe access (bounded loops), `?? fallback` for optional chains.

**Rules**: Every new utility gets tests. Every bug fix gets a regression test proving the bug is dead. Run the full test suite before marking any task complete.

**Env mocking**: `getServerEnv()` validates ALL env vars. Use `vi.doMock("@/lib/env")` to mock the entire module, not `vi.stubEnv()` for individual vars.
