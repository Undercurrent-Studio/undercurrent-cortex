keywords: python,pyproject.toml,venv,pytest,django,flask,fastapi,poetry,ruff,mypy,pydantic

# Python Patterns

Context for Python projects. Injected when Python-related keywords are detected.

## Project Structure

- `pyproject.toml` is the modern standard (PEP 621). `setup.py`/`setup.cfg` are legacy.
- `src/` layout (recommended) vs flat layout. `src/` prevents accidental imports of uninstalled packages.
- Keep `__init__.py` files minimal — avoid heavy imports that slow startup.

## Dependency Management

- **uv** (fast, Rust-based) or **poetry** for lock-file-based dependency management.
- Always pin dependencies in production. Use lock files (`uv.lock`, `poetry.lock`).
- Virtual environments: always isolate. Never `pip install` globally.
- Separate dev/test/prod dependency groups in `pyproject.toml`.

## Type Safety

- `mypy --strict` or `pyright` for static type checking. Enable incrementally if retrofitting.
- `pydantic` for runtime validation at system boundaries (API inputs, config, external data).
- `typing.Protocol` for structural subtyping (duck typing with type safety).
- Annotate public function signatures. Internal helpers can rely on inference.

## Testing

- **pytest** conventions: `conftest.py` for shared fixtures, `@pytest.mark.parametrize` for combinatorial cases.
- `pytest-cov` for coverage. `pytest-asyncio` for async tests (use `auto` mode).
- Prefer dependency injection over `unittest.mock.patch`. Patching is brittle — inject collaborators instead.
- Test files mirror source structure: `src/foo/bar.py` → `tests/foo/test_bar.py`.

## Common Pitfalls

- **Mutable default arguments**: `def f(items=[])` shares the list across calls. Use `items=None` + `items = items or []`.
- **Late binding closures in loops**: `lambda: i` captures the variable, not the value. Use `lambda i=i: i`.
- **Bare `except`**: Catches `KeyboardInterrupt` and `SystemExit`. Always use `except Exception`.
- **`is` vs `==`**: `is` for singletons only (`None`, `True`, `False`). `==` for value comparison.
- **f-strings over `.format()`**: Prefer f-strings for readability. Use `.format()` only for deferred formatting.
- **`__all__` in modules**: Define explicitly to control public API and avoid leaking internals.

## Async

- `asyncio` event loop: one per thread. Don't nest `asyncio.run()`.
- `async with` for async context managers (DB connections, HTTP sessions).
- `asyncio.TaskGroup` (3.11+) over `asyncio.gather` — better error handling, automatic cancellation.
- Never mix sync and async DB calls in the same codebase without clear boundaries.

## Linting & Formatting

- **ruff** replaces flake8 + isort + pyupgrade + autoflake. Single tool, Rust-speed.
- `ruff format` or `black` for formatting. Configure in `pyproject.toml`, not separate config files.
- Enable `ruff check --fix` in CI for auto-fixable issues.
