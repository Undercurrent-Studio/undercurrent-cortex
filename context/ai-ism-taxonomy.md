# AI-ism Detection Taxonomy (87 Patterns + 8 Anti-Patterns)

> Loaded when Gate 43 (AI-ism Smell Test) fires on customer-facing or significant code plans.
> Do NOT register in `context/_index.md` — referenced directly via `@context/ai-ism-taxonomy.md`.

---

## The Bright Line Test

**"Would a senior engineer under deadline pressure make this choice?"**

- A senior engineer writes `// HACK` comments, not ADRs for rounding functions.
- A senior engineer uses `any` with a comment, not a 15-line generic type.
- A senior engineer writes `if/else`, not the strategy pattern.
- A senior engineer hardcodes the batch size, not creates `BatchConfig`.
- A senior engineer has opinions: "This is the approach. Here's why."

AI doesn't have deadlines, doesn't have opinions, and doesn't make pragmatic shortcuts. That's what makes it detectable.

---

## Good Engineering vs AI-ism

**It's Good Engineering When:**
- Structure serves the specific problem being solved
- Abstraction reduces cognitive load for the next developer
- Consistency is *within a module* (local coherence)
- Tests cover known failure modes and regressions
- Documentation explains *decisions* and *gotchas*
- Comments explain *why*, not *what*
- Error handling is proportional to the risk

**It's an AI-ism When:**
- Structure serves a *pattern* regardless of the problem
- Abstraction exists "in case we need it later"
- Consistency is *global and perfect* (no file-to-file variation)
- Tests cover every possible input instead of likely failures
- Documentation explains things already obvious from the code
- Comments narrate the code line by line
- Error handling is uniform regardless of the risk
- Everything has the same weight and depth
- There are no opinions, no shortcuts, no personality

---

## Category 1: Language and Copy (Customer-Facing)

### 1.1 Forbidden Words (27 words)

| Word/Phrase | Why It's an AI-ism | Severity |
|---|---|---|
| comprehensive | AI's favorite adjective. Real products say "full" or "complete" | P0 |
| robust | Meaningless filler. What product describes itself as "fragile"? | P0 |
| leverage | Corporate AI-speak. Humans say "use" | P1 |
| utilize | Nobody says this in conversation. "Use" is always better | P1 |
| facilitate | "Enable" or "let" or "allow" | P1 |
| seamless | Nothing is seamless. Name the specific quality instead | P0 |
| cutting-edge / state-of-the-art | Self-congratulatory filler | P0 |
| delve / delve into | The #1 AI tell word. Usage increased 25x in academic papers post-ChatGPT | P0 |
| landscape (non-literal) | "In the competitive landscape" — pure AI opener | P1 |
| tapestry / rich tapestry | No human writes this about software | P0 |
| harness / harnessing | "Harnessing the power of" — AI loves this | P1 |
| streamlined | Vague. What specifically is faster/simpler? | P1 |
| empower / empowering | Corporate AI-speak. Say what the user can actually do | P1 |
| elevate | "Elevate your workflow" — meaningless | P1 |
| innovative | Self-awarded. Let users decide | P0 |
| holistic | AI's way of saying "we considered more than one thing" | P1 |
| paradigm | Unless discussing Kuhn, this is filler | P1 |
| synergy | The original corporate AI-ism | P1 |
| transformative | Almost never accurate. "Useful" is more honest | P1 |
| actionable insights | Redundant. Insights should be actionable by definition | P1 |
| unlock (metaphorical) | "Unlock the power of your data" — pure AI | P0 |
| deep dive (in UI copy) | Acceptable in research contexts; AI-ism in product copy | P1 |
| best-in-class | Who determined the class? Who judged the contest? | P0 |
| future-proof | Nothing is future-proof | P1 |
| at scale | Often used where scale isn't relevant | P1 |

### 1.2 Forbidden Sentence Patterns (9 patterns)

| Pattern | Example | Better Alternative | Severity |
|---|---|---|---|
| "In today's [adjective] [noun]..." | "In today's fast-paced market..." | Just start with the point | P0 |
| "It's important to note that..." | Filler transition | Delete; say the thing directly | P1 |
| "Whether you're a [X] or a [Y]..." | "Whether you're a beginner or expert..." | Pick your audience; don't hedge | P1 |
| "[Noun] is more than just [obvious thing]" | "Data is more than just numbers" | Delete the whole sentence | P0 |
| "From [X] to [Y], we've got you covered" | Marketing formula | Be specific about what you actually do | P1 |
| "Take your [X] to the next level" | "Take your analysis to the next level" | Describe the specific improvement | P0 |
| "[X] that [Y] so you can [Z]" | "Signals that alert you so you can act" | Fine once; AI repeats this structure 5x | P1 |
| "Here's the thing:" / "Here's why:" | Conversational filler AI uses to sound human | Just say the thing | P2 |
| Rhetorical question as section opener | "Wondering how to...?" | State the problem directly | P1 |

### 1.3 Structural Copy Tells (5 patterns)

| Pattern | The Tell | Severity |
|---|---|---|
| Every feature has same description length | AI balances word count across items | P1 |
| Three-adjective lists | "Fast, reliable, and intuitive" | P1 |
| Benefit + "so you can" + outcome | Repeated formula | P1 |
| Mirror structure in paired elements | Pros/cons have same # of bullets | P1 |
| Every section has an intro paragraph | AI can't start without a preamble | P2 |

---

## Category 2: Code Comments and Documentation

### 2.1 Comment Anti-Patterns (7 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| What-comments (narrating code) | `// Loop through the array and filter items` | No comment needed; or `// Exclude delisted tickers (zombie check)` | P1 |
| JSDoc on trivial functions | Full JSDoc on `isPositive(value)` | No JSDoc; function name is sufficient | P2 |
| Section banner comments | `// ============= HELPER FUNCTIONS =============` | File structure should be self-evident | P2 |
| Explaining the obvious | `const MAX_RETRIES = 3; // Maximum number of retries` | `const MAX_RETRIES = 3;` | P1 |
| Apologetic comments | `// Note: This is a simplified version for now` | Either complete or TODO with ticket | P2 |
| Changelog comments | `// Updated 2024-01-15: Added error handling` | That's what git blame is for | P2 |
| "This function" opener | `// This function calculates the weighted average` | `// Weighted average with null-excluded renormalization` | P1 |

### 2.2 Documentation Patterns (5 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Over-documented constants | 3-paragraph explanation of `MS_PER_DAY = 86400000` | Self-documenting name | P2 |
| README that restates file structure | "The `src/` directory contains source code" | Document what's non-obvious | P1 |
| Every function has same-format doc | `@param`, `@returns`, `@throws`, `@example` on everything | Doc only what's surprising | P2 |
| ADRs for trivial decisions | "ADR-007: We chose `Math.round()` for rounding" | ADRs for real tradeoffs only | P1 |
| Answering questions nobody asked | "FAQ: Why TypeScript?" | Only document decisions people question | P1 |

---

## Category 3: Code Architecture and Design

### 3.1 Over-Abstraction (6 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Utility for one-time use | `createDateFormatter()` used in 1 file | Inline the call | P1 |
| Wrapper around a single function | `export function fetchData(url) { return fetch(url)... }` | Use `fetch` directly | P1 |
| Abstract base class with one impl | `abstract class DataProcessor` + 1 impl | Just write the impl | P1 |
| Config object for 2 options | `{ retries: 3, timeout: 5000 }` through 4 layers | Inline the values | P2 |
| Generic type parameter used once | `function process<T>(input: T): T` only with `string` | `function process(input: string): string` | P2 |
| Factory function for simple construction | `createLogger()` that just returns `new Logger()` | `new Logger()` | P1 |

### 3.2 Symmetry and Completionism (5 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Module A mirrors Module B | CRUD for every entity even when some only need read | Design to the use case | P1 |
| Every error type gets its own class | 5+ error classes | 2-3 max; the rest are strings | P1 |
| Every API route has identical middleware | Auth -> validate -> rate-limit on every route | Apply what's needed | P1 |
| Parallel test structure | Tests mirror source tree 1:1 | Test what has logic | P2 |
| Same number of items in every list | 5 pros, 5 cons, 5 recs | Real analysis is asymmetric | P1 |

### 3.3 Naming (5 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| DataProcessor / ResultHandler / ConfigManager | Abstract, tells nothing about domain | `ScoreEngine`, `TickerBatcher`, `PipelineLock` | P1 |
| `handleX` for everything | `handleClick`, `handleSubmit`, `handleChange` | `submitOrder`, `resetFilters`, `retryFetch` | P2 |
| Overly descriptive variable names | `const filteredAndSortedStocksList` | `const stocks` (context is clear) | P2 |
| `utils.ts` / `helpers.ts` as junk drawer | Everything in utils | Name by function: `batch-upsert.ts` | P1 |
| Redundant type suffixes | `StockType`, `ScoreInterface`, `UserModel` | `Stock`, `Score`, `User` | P2 |

### 3.4 Over-Engineering (5 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Try/catch wrapping every call | Every `await` individually wrapped | Catch at boundary | P1 |
| Making everything configurable | DEFAULT_BATCH_SIZE that's never changed | Hardcode unless demonstrated need | P2 |
| Event emitter for 2 listeners | Pub/sub for 2 functions | Direct function calls | P1 |
| Strategy pattern for 2 strategies | Interface + 2 impls | `if/else` or function parameter | P1 |
| Interface for every type | `interface IUser` used in one place | Inline the type | P2 |

---

## Category 4: Plan and Process Patterns

### 4.1 Plan Structure Tells (7 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Perfectly balanced phases | Phase 1: 3 tasks. Phase 2: 3 tasks. Phase 3: 3 tasks. | Phase 1: 1. Phase 2: 7. Phase 3: 2. | P1 |
| Every phase ends with "Verify" | "4.3: Verify changes work correctly" | Verify at meaningful checkpoints | P1 |
| Round time estimates | "Phase 1: ~2 hours. Phase 2: ~2 hours." | "Phase 1: 20 min. Phase 2: half a day." | P2 |
| Risk list covers everything equally | 4 risks of equal weight | "Main risk: X. Minor: Y." | P1 |
| Decimal precision nesting | "2.3.1: Create helper function" | Real plans don't nest past 2 levels | P2 |
| "Phase 0: Setup" as distinct phase | Setting up branch as a phase | That's just starting work | P2 |
| Every task has acceptance criteria | AC for "update a constant" | AC for features with user-facing behavior | P2 |

### 4.2 Communication Tells (5 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Third-person self-reference | "The implementation will..." | "I'll..." or imperative: "Add batch size constant" | P2 |
| Restating the requirement | Plan starts restating what was asked | Jump to the approach | P1 |
| "Considerations" section | "things to keep in mind" paragraph | Integrate concerns into plan steps | P2 |
| Diplomatic hedging | "We might want to consider..." | "Do X" or "Skip Y because Z" | P1 |
| Equal treatment of all options | Same depth for every option | "Option A. Option B exists but is worse because X." | P1 |

---

## Category 5: UX and Visual Design

### 5.1 Layout and Visual Tells (6 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Perfectly equal column widths | 3 cards at exactly 33.33% | Most important one is wider | P1 |
| Uniform spacing everywhere | 24px gap on everything | Tighter within groups, more between | P1 |
| Safe color palette | Blue primary, gray secondary | Palette with personality | P1 |
| Tooltip text as documentation | 2-sentence explanation | "Higher is better. 68+ is Strong." | P0 |
| Same skeleton shape for everything | Same gray bars | Skeletons matching content shape | P1 |
| Icons for decoration | Sparkle icon next to "AI Brief" | Icons that communicate function | P1 |

### 5.2 Interaction Tells (5 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Same toast for every action | "Operation completed successfully" | "Watchlist updated" / nothing if obvious | P0 |
| Same error for every failure | "Something went wrong. Please try again." | "Couldn't load insider data. SEC may be down." | P0 |
| Confirmation dialogs for everything | "Are you sure you want to sort?" | Confirm destructive only; everything else immediate with undo | P1 |
| Empty states that explain the concept | "Watchlists let you track stocks..." | "No stocks yet." with add button | P1 |
| Uniform animation timing | Everything 300ms ease-in-out | Fast for micro (150ms), slower for layout (400ms) | P1 |

---

## Category 6: Error Handling and Edge Cases (5 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Generic catch-all errors | `catch (error) { console.error('Error:', error); return null; }` | Catch specific; let unexpected propagate | P1 |
| Over-validating inputs | Checking number is number after TypeScript typed it | Validate at boundary, trust internal types | P1 |
| Null-coalescing everything | `value ?? defaultValue ?? fallbackValue ?? ''` | Decide: null valid? Handle or throw early | P2 |
| Defensive returns | 4 nested null checks | One check at the right level | P1 |
| Retry logic everywhere | `withRetry()` on every API call | Retry at orchestration layer | P1 |

---

## Category 7: Testing Patterns (6 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Test names as specifications | `it('should return null when input is undefined and...')` | `it('rejects unauthorized users')` | P2 |
| Testing implementation details | Testing internal helper call count | Testing output correctness | P1 |
| One assertion per test (always) | 20 tests each assert one property | 3 tests each assert meaningful behavior | P2 |
| Exhaustive happy-path coverage | Tests for every valid combination | Critical paths + edge cases that caused bugs | P1 |
| Mock everything | Mocking `Date.now()`, `Math.random()`, `console.log` | Mock external deps; real for pure logic | P1 |
| `describe` nesting 4+ deep | `describe > describe > describe > it` | 2 levels max | P2 |

---

## Category 8: Git and Process Artifacts (4 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| Every commit same format/length | `feat: add X flow` / `feat: add Y flow` | `feat: auth` / `fix: stripe webhook race condition` | P2 |
| PR description restates the diff | "Changed fetchData to accept options" | "Pipeline timed out. Reduced batch size." (the WHY) | P1 |
| No WIP/fixup commits | Every commit clean | Real developers commit messy, then squash | P2 |
| Rigid branch naming | `feature/UC-123-add-scoring-module` | `fix-scoring` or `wip-insider-stuff` | P2 |

---

## Category 9: The Uncanny Valley (7 patterns)

| Pattern | AI Example | Human Example | Severity |
|---|---|---|---|
| No tech debt markers | Zero TODO/HACK/FIXME | Occasional `// TODO(will):` and `// HACK:` | P1 |
| Uniform code quality across time | Code from 6 months ago identical to yesterday | Early code rougher, recent reflects lessons | P1 |
| No opinions in comments | Factual only | `// This API is garbage but it's the only free option` | P2 |
| Perfect import ordering | Alphabetical, grouped, every file | Mostly ordered, occasional drift | P2 |
| No dead experiments | No commented-out alternatives | `// Tried WebSocket, switched to polling` | P2 |
| Consistent error message tone | Every message sounds like docs | Some terse, some detailed — natural variation | P1 |
| No variable name drift | `score` always `score` | `score` / `s` in loop / `pillarScore` | P2 |

---

## The 8 AI-Specific Anti-Patterns

These patterns *only* happen when AI writes code. They're not general code smells — they're artifacts of the AI development process.

### 1. The Import-Wrap-Export Pattern

AI imports a module, wraps one function in a "utility," and re-exports it:

```typescript
// AI-ism: src/lib/utils/date-utils.ts
import { format } from 'date-fns'
export function formatDate(date: Date): string {
  return format(date, 'yyyy-MM-dd')
}

// Human: just use format() directly where needed
import { format } from 'date-fns'
const dateStr = format(date, 'yyyy-MM-dd')
```

### 2. The Defensive Pyramid

AI wraps every operation in guards because it can't reason about control flow:

```typescript
// AI-ism
async function getScore(ticker: string) {
  if (!ticker) return null
  try {
    const data = await fetchData(ticker)
    if (!data) return null
    if (!data.score) return null
    if (typeof data.score !== 'number') return null
    return data.score
  } catch (error) {
    console.error('Error getting score:', error)
    return null
  }
}

// Human
async function getScore(ticker: string) {
  const data = await fetchData(ticker)
  return data?.score ?? null  // Let errors propagate to boundary
}
```

### 3. The Mirror Module

AI creates a new module that mirrors the structure of an existing one:

```
// AI-ism: every entity gets the same file structure
src/lib/stocks/  -> index.ts, types.ts, utils.ts, constants.ts
src/lib/scores/  -> index.ts, types.ts, utils.ts, constants.ts
src/lib/signals/ -> index.ts, types.ts, utils.ts, constants.ts

// Human: each module is shaped by its actual needs
src/lib/scoring/  -> v10-engine.ts, v10-helpers.ts, percentile.ts, transfer-functions.ts
src/lib/signals/  -> bayesian.ts, decay.ts, event-logger.ts, regime-detection.ts
src/lib/pipeline/ -> circuit-breaker.ts, batch-upsert.ts
```

### 4. The Config Object Creep

AI creates configuration objects for things that will never be configured:

```typescript
// AI-ism
interface PipelineConfig {
  batchSize: number
  concurrency: number
  retryCount: number
  timeout: number
  enableLogging: boolean
  logLevel: 'debug' | 'info' | 'warn' | 'error'
}

const DEFAULT_CONFIG: PipelineConfig = {
  batchSize: 300,
  concurrency: 4,
  retryCount: 3,
  timeout: 30000,
  enableLogging: true,
  logLevel: 'info',
}

// Human
const BATCH_SIZE = 300
const CONCURRENCY = 4
```

### 5. The Premature Interface

AI creates interfaces before there's a second implementation:

```typescript
// AI-ism
interface IScoreCalculator {
  calculate(ticker: string): Promise<Score>
}

class V10ScoreCalculator implements IScoreCalculator {
  async calculate(ticker: string) { /* ... */ }
}

// Human (when there's only V10)
async function calculateScore(ticker: string): Promise<Score> { /* ... */ }
// Extract interface IF V11 needs different behavior
```

### 6. The Exhaustive Enum Handler

AI creates switch/case for every enum value, even when most cases are identical:

```typescript
// AI-ism
switch (status) {
  case 'active': return renderActive()
  case 'pending': return renderPending()
  case 'expired': return renderExpired()
  case 'cancelled': return renderCancelled()
  case 'suspended': return renderSuspended()
  default: return renderDefault()
}
// ...where renderPending, renderExpired, renderCancelled, renderSuspended
// all return the same gray badge

// Human
if (status === 'active') return renderActive()
return renderInactive(status)  // One function handles all non-active states
```

### 7. The Ghost Dependency

AI imports a library to use one small feature, when a 3-line implementation exists:

```typescript
// AI-ism
import { chunk } from 'lodash'
const batches = chunk(tickers, 300)

// Human
function chunk<T>(arr: T[], size: number): T[][] {
  const result: T[][] = []
  for (let i = 0; i < arr.length; i += size) result.push(arr.slice(i, i + size))
  return result
}
```

### 8. The Parallel Test Suite

AI generates tests that mirror the source file structure exactly, including tests for trivial re-exports and type definitions:

```typescript
// AI-ism
describe('constants.ts', () => {
  it('should export BATCH_SIZE as 300', () => {
    expect(BATCH_SIZE).toBe(300)
  })
  it('should export MAX_RETRIES as 3', () => {
    expect(MAX_RETRIES).toBe(3)
  })
})

// Human: don't test constants. Test behavior.
```

---

## Detection Heuristics

### Automated (grep-able)

```bash
# Forbidden words in user-facing files
grep -riE '\b(comprehensive|robust|leverage[ds]?|utilize[ds]?|facilitate[ds]?|seamless(ly)?|cutting-edge|state-of-the-art|delve[ds]?|tapestry|harness(ing)?|streamlined|empower(ing|s)?|elevate[ds]?|innovative|holistic|paradigm|synergy|transformative|actionable insights?|best-in-class|future-proof)\b' \
  src/components/ src/app/ --include='*.tsx' --include='*.ts'

# "This function" comment pattern
grep -rn '// This function' src/

# Section banner comments
grep -rn '// ====\|// ----\|// \*\*\*\*' src/

# What-comments (narrating loops/conditions)
grep -rnE '// (Loop|Iterate|Check|Get|Set|Return|Create|Initialize|Calculate) (through|over|if|the|a|an) ' src/

# Generic handler names
grep -rn 'handleData\|handleResult\|handleResponse\|DataProcessor\|ResultHandler\|ConfigManager' src/
```

### Semi-Automated (flag for review)

1. **Symmetry check**: Count items in parallel structures. Identical counts = flag.
2. **Comment density**: >1 comment per 5 LOC = flag.
3. **Abstraction depth**: Function called from only 1 location = flag.
4. **Type complexity**: Generic param instantiated once = flag.
5. **Error handling depth**: try/catch >1 per function = flag.

### Manual (requires taste)

1. **The squint test**: Blur eyes, look at plan/code. Everything same size/shape? Real work is lumpy.
2. **The opinion test**: Can you identify a strong opinion?
3. **The deadline test**: Would someone with 2 hours left write this?
4. **The surprise test**: Anything unexpected or unconventional?
5. **The personality test**: Does it sound like a specific person wrote it?

---

## Plan-Type Applicability

| Plan Type | Applicable Questions |
|-----------|---------------------|
| Feature plans | All 23 questions (LC, CQ, AR, UX, PP, ST) |
| Bug fix plans | CQ-1 through CQ-5, AR-5 only |
| Refactoring plans | CQ and AR questions |
| Copy/design tasks | LC and UX questions |
| All plans | PP and ST questions (always) |

## Pattern Count Summary

| Category | Subcategory | Count |
|----------|------------|-------|
| 1. Language & Copy | 1.1 Forbidden words | 27 |
| | 1.2 Sentence patterns | 9 |
| | 1.3 Structural tells | 5 |
| 2. Comments & Docs | 2.1 Comment anti-patterns | 7 |
| | 2.2 Documentation patterns | 5 |
| 3. Architecture | 3.1 Over-abstraction | 6 |
| | 3.2 Symmetry | 5 |
| | 3.3 Naming | 5 |
| | 3.4 Over-engineering | 5 |
| 4. Plans & Process | 4.1 Structure tells | 7 |
| | 4.2 Communication tells | 5 |
| 5. UX & Visual | 5.1 Layout tells | 6 |
| | 5.2 Interaction tells | 5 |
| 6. Error Handling | | 5 |
| 7. Testing | | 6 |
| 8. Git/Process | | 4 |
| 9. Uncanny Valley | | 7 |
| **Total patterns** | | **122** |
| **AI-specific anti-patterns** | | **8** |

> Note: The research reports cited 87 patterns. The full enumeration yields 122 individual patterns across 9 categories. The "87" figure from the original reports counted some subcategories as single items. All patterns are included here regardless of count — completeness over labeling.
