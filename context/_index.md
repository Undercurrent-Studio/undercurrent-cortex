# Context Files — Auto-Injection Index

> **Parent:** [../docs/context-flow.md](../docs/context-flow.md)

Context files auto-inject when user prompts match their keywords. First match wins.

| File | Keywords | Triggers When |
|------|----------|---------------|
| [typescript-discipline.md](typescript-discipline.md) | typescript, type error, tsc, nouncheckedindexedaccess, type guard, as never, use client | TypeScript/React project work |
| [python-patterns.md](python-patterns.md) | python, pyproject.toml, venv, pytest, django, flask, fastapi, poetry, ruff, mypy, pydantic | Python project detected |
| [go-patterns.md](go-patterns.md) | golang, go.mod, goroutine, go.sum, cobra, fiber | Go project detected |
| [rust-patterns.md](rust-patterns.md) | rustc, cargo.toml, lifetime, tokio, async-std, serde, clippy, rust-lang | Rust project detected |
| [testing-conventions.md](testing-conventions.md) | vitest, test suite, write test, add test, run test, fix test, coverage | Testing-related tasks |
| [math-review.md](math-review.md) | formula, statistics, probability, monte carlo, sigmoid, logarithm, exponential decay, half-life, normalization, regression, interpolation, z-score, zscore, standard deviation, stddev, variance, distribution, likelihood, ou, gbm | Mathematical/statistical code |
| [deploy-readiness.md](deploy-readiness.md) | deploy, vercel, go live, push to prod, production, ship it | Deployment tasks |
| [synthesis-memory.md](synthesis-memory.md) | collaboration pattern, workflow pattern, synthesis, curate memory, how we work, reusable workflow, memory tier, collaboration file | Synthesis memory operations |

## How Context Injection Works

1. User submits a prompt
2. `context-flow.sh` (UserPromptSubmit hook) scans all `.md` files in this directory
3. Reads `keywords:` from first line of each file
4. First keyword match against prompt content wins
5. Matched file's content injected as additional context

## Adding a New Context File

1. Create `context/your-domain.md`
2. First line: `keywords: keyword1, keyword2, keyword3`
3. Content below keywords = what gets injected
4. Update this index
5. Test: mention a keyword in a prompt and verify injection
