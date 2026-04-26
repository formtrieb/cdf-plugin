# Phase 3 · Infer Grammars

**Goal:** Identify token-grammar patterns (`color.{axis}.{axis}.{state}`),
classify sparsity + aliases, map component bindings onto grammars, detect
DTCG↔Figma drift. This is the phase where the LLM-vs-MCP leverage is
highest — the LLM sees a path-shape and pattern-matches in one read.

**Predecessor:** Phase 2 (`system_vocabularies` in-hand).

**Successor:** Phase 4 (Theming Modifiers).

**Subagent-fit:** ★★★ — token-tree scan + pattern-match is parallelizable.
See §7 below for dispatch shapes.

**Shape authority.** Spec shape for this phase is split across five
fragments — load only what the current sub-step needs:

- `cdf_get_spec_fragment({ fragment: "TokenGrammar" })` — §6.1–§6.9
  (grammar shape + axis-order + state-name mapping). Primary reference.
- `cdf_get_spec_fragment({ fragment: "TokenLayers" })` — §6.10 reference
  cascade (ordered list + DAG rules).
- `cdf_get_spec_fragment({ fragment: "StandaloneTokens" })` — §6.11
  singletons + flat enumerations.
- `cdf_get_spec_fragment({ fragment: "Resolution" })` — §6.12 axis
  collapse + precedence.
- `cdf_get_spec_fragment({ fragment: "TokenSources" })` — §7 directory,
  format, sets.

Do not read the full monolith when only one of these sub-concepts
applies.

**Finding-prose contract (Lever 5).** Every cluster A/B/C/D finding this
phase seeds MUST carry `plain_language` (≤50 words, jargon-free),
`concrete_example` (real values from token-MCP / DTCG output, cited
verbatim), and `default_if_unsure: { decision, rationale }`. Schema:
[`templates/seeded-findings.schema.yaml`](templates/seeded-findings.schema.yaml).

> **Bad** (CDF-format-speak): *"Token-grammar `color.controls.{hierarchy}.
> {state}` exhibits axis-pattern sparsity at depth-2 with cross-cell
> placeholder leakage."*
>
> **Good** (DS-architect-speak): *"Du hast 240 mögliche Button-Farben
> nach der Token-Struktur (`color.controls.{4 hierarchies}.{6
> states}.{10 modifiers}`), aber nur 87 sind tatsächlich definiert.
> Die fehlenden 153 fallen auf Default-Werte zurück. Das ist normal —
> nicht jede Kombination muss gefüllt sein."* + concrete_example
> citing 2-3 placeholder paths from `find_placeholders` output.

User's session language wins. Decision-quality of Phase 6 depends
directly on prose comprehension here.

**No spec citations in `plain_language` (Lever 5.I).** Forbidden:
`§…` references, bare CDF terms (`token-grammar`, `placeholder
leakage`, `axis-pattern sparsity`, `token-layer architecture`).
Phase-3's commonest leak is "the `{state}` axis of `color.controls.…`"
inside the user-facing prose; rewrite around the actual count of
unfilled paths the User can see in their token tree, and keep the
grammar-shape mechanics in `observation` / `sot_recommendation`.

**Source authority (tokens-MCP is authoritative when present).** When
the DS has a dedicated tokens MCP (`tokens-studio` regime with a
per-DS adapter such as `formtrieb-tokens` / `<ds>-tokens`, or
`dtcg-folder` regime with a similar adapter), that MCP's output IS
the Phase-3
source of truth. **Do NOT cross-check against raw `Read` DTCG files**
to "validate" grammar inferences — the MCP already parses, resolves
aliases, and filters the tree. A raw DTCG re-read gives the same data
with extra parsing cost and no new information. Only drop to raw
DTCG reads when (a) the inference is genuinely ambiguous (two
plausible grammar shapes the MCP surface can't disambiguate), or (b)
the MCP returns an error / partial result. For `figma-variables` and
`figma-styles` regimes without a dedicated MCP, the authority
hierarchy in Step 3.1 applies instead.

---

## 1 · Methodology

### Step 3.0 — Locate Phase-2 input (tier-aware)

Phase 2 leaves a structured artefact Phase 3 iterates over. Path differs by tier.

| Tier | Phase-2 artefact | Access path for vocabularies |
|---|---|---|
| T1 / T2 | `<cwd>/.cdf-cache/phase-2-output.yaml` (version-tagged) | `.phase_3_inputs.system_vocabularies_snapshot` |
| T0 | `<cwd>/<ds>.phase-2-notes.md` (markdown) | inline `system_vocabularies` block |

**On T1/T2: assert the schema version BEFORE reading anything else.**

```bash
yq '.schema_version' <cwd>/.cdf-cache/phase-2-output.yaml
# Expected: phase-2-output-v1
```

If the value does NOT equal `phase-2-output-v1`, **hard-fail** — do not
attempt to interpret the file. Ask the User to re-run Phase 2 with the
current skill version. Phase 2's emit step (`phase-2-vocabularies.md`
§Step 2.last) stamps the version deterministically — a mismatch means
the artefact pre-dates the current schema.

**Fallback (tier detection):** if `phase-2-output.yaml` is absent but
`<ds>.phase-2-notes.md` is present, you are on the T0 path — continue
from the in-context vocabularies as before. Do not synthesize a YAML
from the notes.

### Step 3.1.0 — Tool-survey BEFORE gap-declaration (Rule-A enforcement)

**Hard requirement.** Before declaring any token-source gap of the
shape *"X NOT enumerable / NOT visible / NOT accessible / NOT available"*
in this phase, the LLM MUST execute a tool-survey-and-probe. This rule
applies to ALL runs but is especially load-bearing for **auto-mode**
(no Phase-6 dialog brake) and on the **T1 path** (REST cache file
visibly does NOT contain Variables — the trap is to extrapolate "REST
gap = capability gap"; the right move is "REST gap → probe Plugin-API
resolver next").

Canonical content in
`../../../../shared/cdf-source-discovery/tool-leverage.md` §2 (Rule A
Enforcement: Tool-Survey BEFORE Resolver-Gap). **`Read` that file**
before running this step.

**Three-step contract per gap-claim:**

1. **List loaded `mcp__*` tools** that conceivably address the missing
   resource type. For color tokens: at minimum `mcp__figma__get_variable_defs`,
   any DS-specific tokens MCP (`mcp__<ds>-tokens__browse_tokens`),
   `mcp__figma-console__figma_get_variables`, and
   `mcp__figma-console__figma_execute` (Plugin-API JS shell).
2. **Probe at least ONE representative target.** The probe must be
   real, not theoretical. For figma-variables regime against a Figma
   file, the canonical probe is `mcp__figma__get_variable_defs(fileKey,
   nodeId)` against any COMPONENT_SET node — pick a representative
   like a primary action button. ONE call returns the variables
   consumed by that node and refutes the gap.
3. **Record the probe outcome** in the resulting claim. The
   gap-declaration either qualifies itself with the probe result
   ("Variables NOT visible to non-Enterprise REST [probed
   `get_variable_defs` on Button → 17 paths returned]") or vanishes
   entirely (gap was false; proceed with grammar enumeration).

**`.cdf.config.yaml.resolver` is NOT a substitute for probing.** A
fresh-DS auto-run has no User-filled resolver block; speculative
defaults must not gate "can I see variables?" decisions. Probe.

**For auto-mode runs the probe MUST be made.** Auto-mode skips
User-dialog but does NOT skip resolver-invocation; the SKILL.md §1.5
auto-mode contract is silent on this exact step, so this phase-doc
section IS the contract authority. Skipping the probe in auto-mode is
a Rule-A violation.

#### Probe budget

- **Auto-mode minimum:** 3 representative nodes (e.g. one button-family,
  one input-family, one feedback-family). 5 is comfortable for a DS
  with ≥3 component categories. Each call is ~5s wall-time.
- **Snapshot mode:** see `cdf-profile-snapshot/references/synthesis.md`
  Contract 3 — Snapshot's blind_spots claims also require a probe (one
  per claim) but Snapshot is single-pass + flag-only, so the budget is
  tighter (1 probe per gap-claim is the floor).
- **Interactive scaffold:** still apply this rule; the User-dialog in
  Phase 6 is NOT the place to retrofit. Resolve gap-vs-not-gap in
  Phase 3, surface the result.

#### Worked example — QL.E.1 Primer (2026-04-26)

Phase-3 of the auto-mode scaffold against the Primer REST cache
(`<ds-root>/.cdf-cache/figma/<file_key>.json`) declared:

> *"Color tokens NOT enumerable (Figma Variables not visible in
> non-Enterprise REST)."*

The claim was technically true for the static REST file but
operationally false: `mcp__figma__get_variable_defs` was loaded the
entire run. The corrective probe (5 nodes, ~30s total wall-time):

```
get_variable_defs(fileKey=k4eLYQOFsumGUW3v8CM2kt, nodeId=28860:52225)  # Primary Button
get_variable_defs(…, nodeId=34303:2712)    # Banner
get_variable_defs(…, nodeId=18959:65008)   # Label
get_variable_defs(…, nodeId=15341:46504)   # TextInput
get_variable_defs(…, nodeId=18959:64987)   # IssueLabel
```

…surfaced `button.{hierarchy}.{element}.{state}`,
`fgColor.{tone}` × 9 tones, `bgColor.{tone}.{prominence}`,
`space.{step}`, `control.{size}.{property}[.{density}]`,
`text.body.{property}.{size}`, `shadow.{context}.{size}`,
`focus.outlineColor` — full grammar visible, plus a Code↔Figma drift
finding (`secondary` vs `default` button hierarchy) that the false
gap-declaration would have silently swallowed.

The corrective `phase-3.5-output.yaml` retrofitted the survey results
into the existing scaffold output (full grammar fields above, plus the
Code↔Figma drift finding) before Phase-6 classification fired.

This is exactly the failure mode this rule prevents.

### Step 3.1 — Enumerate full token tree (Rule B — no truncation)

Preferred sources by regime (Rule A):

| Regime | Tool | Strategy |
|---|---|---|
| tokens-studio | DS-specific MCP `browse_tokens(path_prefix="", depth=N)` | Full depth-traversal; paginate by path_prefix if > 500 tokens |
| dtcg-folder | DS-specific MCP if present; else `Read` DTCG files | Parse DTCG tree; combine across files |
| figma-variables (with Plugin-API access) | `use_figma` Plugin-JS: `figma.variables.getLocalVariableCollectionsAsync()` + per-collection iteration | Mind ~20 kB cap; paginate per collection |
| figma-variables (without Plugin-API, T1 REST path) | `mcp__figma__get_variable_defs(fileKey, nodeId)` per representative node — see Step 3.1.0 probe protocol | 3-5 representative nodes covers 90%+ of grammar surface; ~5s/call |
| figma-styles | Style names (PaintStyle.name etc.) **are** paths (`Color/Controls/Brand/Background/Default`) | Parse by `/` separator |

**Do not use `search_tokens` as enumeration.** It caps at 100 results. It
is a lookup, not an enumeration tool. Rule B.

### Step 3.1-bis — Mechanical seeding (T1/T2 only)

Two MCP outputs feed `phase-3-output.yaml` directly without LLM
synthesis: token-layer enumeration and placeholder detection. T0 path:
skip — emit prose to `<ds>.phase-3-notes.md` instead.

**3.1-bis.1 — Token layers** (the `token_layers` block):

Call the DS tokens MCP `list_token_sets` (e.g.
`formtrieb-tokens.list_token_sets` for Formtrieb, or whatever the
DS-specific MCP is per Rule A — `<ds>-tokens.list_token_sets`).
Pipe the JSON through jq to shape into the structured slot:

```bash
SETS_JSON=$(<ds>-tokens.list_token_sets)   # invoke via MCP, capture JSON

echo "$SETS_JSON" | jq '
  [ . | group_by(.role // "source") |
    map({name: .[0].role, role: .[0].role,
         set_count: length,
         sample_sets: ([.[] | .name] | .[0:5])}) ]
'
```

Returns the array that goes into `token_layers` verbatim. **LLM MUST
NOT edit individual entries** — re-running the call produces identical
output.

**3.1-bis.2 — Placeholders** (the `placeholders_by_context` block):

Call `<ds>-tokens.find_placeholders` (returns the magenta-sentinel
hits across the DS). Group by parent-context for the schema slot:

```bash
PLACEHOLDERS_JSON=$(<ds>-tokens.find_placeholders)

echo "$PLACEHOLDERS_JSON" | jq '
  .all // [] |
  group_by(.path | split(".") | .[:-1] | join(".")) |
  map({key: (.[0].path | split(".") | .[:-1] | join(".")),
       value: {count: length, samples: ([.[] | .path] | .[0:5])}}) |
  from_entries
'
```

If the result is non-empty: **also seed one `§Y-placeholders-<context>`
finding per group** (cluster `Y` — placeholder-family). The
seeded-findings template:

```yaml
- id: "§Y-placeholders-<context-slug>"
  cluster: Y
  title: "Placeholder tokens in <context>"
  observation: "<count> tokens in <context> resolve to placeholder
    sentinel (#f305b7 / #ff00ff). Examples: <samples>"
  threshold_met: "find_placeholders count > 0"
  sot_recommendation: >
    Placeholder tokens mark unfinished references. Either populate
    real values (adopt-DTCG) or document the context as intentionally
    unsupported (accept-as-divergence). Generators surface this as
    visible magenta swatches.
  user_decision: pending
```

**3.1-bis.3 — DTCG↔Figma drift counts** (the `drift_candidates` block):

When the regime supports it (`tokens-studio` with a Figma-aware MCP),
call `compare_themes` (or per-grammar `browse_tokens`) on both sides
and capture count deltas. This stays in §3.6 as the "Field observation"
pattern; the structured slot just collects what §3.6 finds:

```yaml
drift_candidates:
  - grammar: <name>
    dtcg_count: <int>
    figma_count: <int>
    delta: <int>             # figma − dtcg
    example: <token-path>
```

If the regime is `figma-styles` or has no comparable surface: leave
`drift_candidates: []` and rely on §3.6's prose treatment instead.

### Step 3.2 — Detect path-shape patterns (the grammar-candidate test)

A **grammar candidate** = a set of tokens sharing:

1. Identical path-prefix (e.g., everything under `color.controls.*`)
2. Identical path-depth across the group (e.g., all 5 segments deep)
3. Each path-position draws values from a finite, enumerable set

**Algorithm (mentally run, no code needed):**

```
for each top-level token-group (e.g. color.controls, spacing, radius):
  collect all leaf paths under the group
  if all leaves have the same depth D:
    for position p in [prefix+1 .. D-1]:
      enumerate distinct values at position p → axis-candidate
    → grammar: group.{axis1}.{axis2}...{axisN}
  else if depth is mixed:
    either this is multiple grammars co-located,
    or there are depth-outliers (standalone_tokens) polluting the group
    → split: identify consistent-depth sub-groups as grammars,
       depth-outliers as standalone_tokens under the same prefix
       (verify each outlier is a leaf via Step 3.2.bis before promoting)
```

**Worked example — a depth-5 interactive-controls grammar:**

```
color.controls.brand.background.active
color.controls.brand.background.hover
color.controls.brand.background.pressed
...
color.controls.primary.text.error
...
color.controls.negative.icon-on-color.disabled
```

Positions:
- `[2] hierarchy` — emphasis values (e.g. {brand, primary, secondary})
- `[3] element` — {background, stroke, text, text-on-color, icon, icon-on-color}
- `[4] state` — {enabled, hover, pressed, disabled, error, …}

→ Grammar: `color.controls.{hierarchy}.{element}.{state}`

This is the Formtrieb-canonical interactive-controls grammar (see
`formtrieb.profile.yaml`). If a full cartesian would be e.g. 3 × 6 × 8 =
144 tokens but the actual count is lower, that's **sparsity** — Step 3.3.

#### Step 3.2.bis — Leaf-only rule for `standalone_tokens` (mandatory)

**Definition.** A path qualifies as a `standalone_tokens` entry **iff**:

1. It resolves to a **single value** in the DTCG corpus (a leaf — no
   children); **OR**
2. It is the prefix of a **small, flat enumeration** (≤ ~8 entries, all
   string-valued children) whose `values:` are listed inline.

A path is **NOT** a standalone just because the LLM didn't fit it into
a grammar. Unclassified ≠ standalone. If a path has nested objects
underneath, it is a **namespace**, and the right move is either to
write a grammar for it or to record it as an open finding for Phase 6.

**Worked examples (Tokens-Studio-style corpus):**

| Path | Children under it | Verdict |
|---|---|---|
| `colors` | hundreds of nested leaves (entire Tokens-Studio set root) | ✗ namespace — grammar candidate, not standalone |
| `shadow` | multiple `shadow.elevation.*` leaves with their own structure | ✗ namespace — `shadow.elevation.{level}` grammar |
| `Display` | `Display.large`, `Display.medium`, … each with its own typography object | ✗ namespace — `typography.{role}.{property}` grammar |
| `color.brand` | exactly two string-valued children (`primary`, `secondary`) | ✓ standalone with `values: [primary, secondary]` |
| `color.page` | resolves to a single color value | ✓ standalone leaf |
| `focus.outer` | resolves to a single color value | ✓ standalone leaf |

The forcing function: writing `colors:` under `standalone_tokens` in
the Phase-7 map shape requires a single `dtcg_type:` for it. There is
no single DTCG type for an entire namespace — the act of trying to
fill the field reveals the misclassification. (★7 in the Phase-7
template.)

**Self-check (run before promoting a candidate to `standalones[]`):**

For each candidate path `$path` you are about to add to
`standalone_tokens`, call:

```
browse_tokens(path_prefix=$path, depth=1)
```

Apply this decision table to the result:

| `browse_tokens` result | Verdict |
|---|---|
| 0 children (path is itself a leaf) | ✓ keep as standalone, declare `dtcg_type` |
| All children are string-valued (no nested objects) AND count ≤ ~8 | ✓ keep as standalone with inline `values: [...]` |
| Any child is a nested object | ✗ reclassify — this is a namespace, not a leaf |
| Children count > ~8 even if all string-valued | ✗ reclassify — write a grammar instead |

If the verdict is ✗, **do not silently drop the path**. Either:
- Write the grammar (Step 3.2 algorithm above), or
- Emit a finding (`§A-namespace-unclassified` style) so Phase 6 can
  decide. Don't dump the namespace into `standalone_tokens` to make
  the unknown go away — that is exactly the bug this rule prevents.

### Step 3.3 — Sparsity detection per (axis × axis)

For each grammar, enumerate the `(axis1 × axis2)` matrix and record
**which states exist per pair**. Sparsity is structural information, not
noise.

**Illustrative sparsity table (condensed):**

| (hierarchy × element) | States present |
|---|---|
| brand × background | {enabled, hover, pressed, disabled, error, success} |
| brand × text | {enabled, hover, pressed, disabled} |
| secondary × background | {enabled, hover, pressed, disabled} |
| secondary × text | {enabled, disabled} |

Patterns to flag:

- **Fully-dense axis-pair** → document as canonical (grammar handles all states)
- **Sparse axis-pair** → likely intentional; record as grammar's
  `state_subsets` declaration (informs Profile YAML output)
- **Lone state** in an otherwise-empty row → orphan candidate (Finding)
- **"Ghost hierarchy"** (value exists as variant, but no tokens) → Finding
  (e.g., a Button declaring a `tertiary` variant whose visual style is
  simulated via `background.none` rather than a dedicated token set)

### Step 3.4 — Alias classification

When a token value is a reference to another token, classify the link:

| Type | Pattern | Example |
|---|---|---|
| **Self-ref** | alias within same grammar | `controls.secondary.text.hover → controls.secondary.text.active` |
| **Cross-grammar** | alias to a different grammar | `controls.brand.text.disabled → color.text.quaternary` |
| **Semantic-chain** | alias to a semantic path, not a grammar-leaf | `controls.primary.background.error → color.interaction.background.negative.secondary` |

**None of these are anti-patterns.** They are structural: "grammars
cross-reference each other." Document as a Profile-feature in findings.md
Cluster A, not as drift.

### Step 3.5 — Component ↔ grammar binding map

For a representative subset (5–10 components), extract Figma Variable
bindings via `figma-mcp.get_variable_defs(nodeId)` and map each bound
variable to its grammar-path.

Output: per-component binding table. Feeds Phase 5's interaction-pattern
analysis and Phase 6's "which components depend on which grammar" map.

### Step 3.6 — Cross-check DTCG vs Figma counts per family

For each grammar, compare:

- DTCG leaf count under `group.*`
- Figma Variable count in matching collection

**Non-zero diff = DTCG↔Figma drift finding.** Seed into findings.md with
the exact count delta + at least one example token that differs.

**Field observation:** a walkthrough surfaced a DTCG ↔ Figma-Variable
count delta within the same token family (three-token imbalance). Real
drift — neither side alone told the full story. The counts do not match
when bi-directional sync has partial failures.

### Step 3.7 — Intent / emphasis folding (the textbook Rule E moment)

**The most common grammar-level anti-pattern.** A "hierarchy" vocabulary
conflates two semantic axes:

- **Emphasis** (visual weight): brand, primary, secondary, tertiary
- **Intent** (semantic meaning): information, success, warning, danger

When one vocabulary contains both kinds of values (e.g. `hierarchy:
[brand, primary, secondary, accent, warning, negative]`), the grammar is
**folding two orthogonal axes**.

**Test:** try to sort the vocabulary by emphasis. If some values can't be
ranked (warning vs brand — which is "louder"?), the axis is folded.

**Proposal template:**

```markdown
## §N · Intent/Emphasis folding in `hierarchy` vocab

**Observation:** `color.controls.*` grammar position [2] = hierarchy,
values = [brand, primary, secondary, accent, warning, negative]. These
values mix emphasis (brand/primary/secondary) with intent
(warning/negative/accent).

**Discrepancy:** Same anti-pattern often mirrors at component-layer
(e.g. a Warning Button and a Destructive Button carried as separate
type-variants). Token-layer and component-layer conflate together.

**Source-of-Truth-Recommendation:** Separate orthogonally:
- `hierarchy: [brand, primary, secondary]`
- `intent: [none, information, warning, danger, success]`
Token-layer refactor would become:
`color.controls.{hierarchy}.{intent?}.{element}.{state}`
Additive migration (old path deprecates, new path co-exists initially).

**User-Decision:** _filled in Phase 6 — deep refactor decision_
```

---

## 2 · Output (carry-forward to Phase 4)

**T1/T2 path:** `<ds-test-dir>/.cdf-cache/phase-3-output.yaml`, shape per
`references/phases/templates/phase-3-output.schema.yaml`. Phase 4
asserts `schema_version: phase-3-output-v1`.

**T0 path (legacy):** `<ds-test-dir>/<ds>.phase-3-notes.md`. Phase 6's
markdown-fallback consumer handles it.

### Step 3.last — Emit `phase-3-output.yaml` (T1/T2 only)

Build via `jq` and round-trip through `yq -P` for clean YAML
(`mikefarah/yq` has no `--argjson`, so JSON-side assembly is cleanest):

```bash
OUT=<ds-test-dir>/.cdf-cache/phase-3-output.yaml
mkdir -p "$(dirname "$OUT")"
jq -n \
  --argjson layers       '<from Step 3.1-bis.1>' \
  --argjson placeholders '<from Step 3.1-bis.2>' \
  --argjson grammars     '<from Step 3.2 / 3.3>' \
  --argjson standalones  '<from Step 3.2 (depth-outliers)>' \
  --argjson drifts       '<from Step 3.6>' \
  --argjson bindings     '<from Step 3.5>' \
  --argjson findings     '<seeded_findings — mechanical Y + LLM A>' \
  --arg     phase2_path  'phase-2-output.yaml' \
  --arg     regime       '<from .cdf.config.yaml.scaffold.token_source.regime>' \
  '{
    schema_version: "phase-3-output-v1",
    generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    generated_by: { source_phase_2: $phase2_path, tier: "T1", token_regime: $regime },
    token_layers: $layers,
    placeholders_by_context: $placeholders,
    grammars: $grammars,
    standalone_tokens: $standalones,
    drift_candidates: $drifts,
    component_bindings: $bindings,
    seeded_findings: $findings,
    interpretation: [],
    phase_4_inputs: { grammars_snapshot: $grammars, token_layers_snapshot: $layers }
  }' | yq -P -o=yaml > "$OUT"

# Verify round-trip
yq '.schema_version' "$OUT"
# Expected: phase-3-output-v1
```

**LLM review contract (mirrors Phase-2 §2.last):**

1. Walker-owned (do NOT edit): `schema_version`, `generated_at`,
   `generated_by`, `token_layers[]`, `placeholders_by_context`,
   `drift_candidates[]` when MCP-derived.
2. Mechanical seeds (`§Y-placeholders-*`, `§A-token-layer-drift`)
   stay as emitted; LLM only fills `user_decision` during Phase 6.
3. LLM-owned: `grammars[]`, `standalone_tokens[]`, `component_bindings`,
   `interpretation[]`, additional `seeded_findings` entries
   (intent/emphasis folding, ghost-hierarchy, etc.).
4. Phase 6 hard-asserts `schema_version: phase-3-output-v1`.

---

## 3 · Tool-leverage Map (Phase-3 specific)

| Tool | Leverage | Notes |
|---|---|---|
| DS-tokens MCP `browse_tokens(path_prefix, depth)` | ★★★ | Rule A primary. Paginate by prefix. |
| `search_tokens` | ✗ NOT for enumeration | 100-result cap. Use `browse_tokens`. |
| `figma-mcp.get_variable_defs(nodeId)` | ★★ | Per-component binding sampling (Step 3.5) |
| `use_figma` variable-collection enumeration | ★★ | When regime is figma-variables |
| `cdf-mcp.cdf_vocab_diverge` | ★ | Optional — machine-assisted overlap matrix |
| `Read` on DTCG files | ★ | Rule A fallback only |

---

## 4 · Completion Gates

- [ ] Full token tree enumerated — no truncation residue (Rule B verified).
- [ ] Every top-level token-group evaluated as grammar-candidate.
- [ ] Each grammar documented with: pattern, depth, axes, leaf_count,
  cartesian_count, sparsity.
- [ ] Sparsity per (axis × axis) mapped for each grammar (at least the
  headline grammar — smaller grammars can be summarized).
- [ ] Aliases classified into self-ref / cross-grammar / semantic-chain.
- [ ] Component-binding map generated for 5–10 representative components.
- [ ] DTCG vs Figma count-deltas recorded per grammar.
- [ ] Intent/emphasis folding check done on every grammar with a
  hierarchy-like axis.
- [ ] Grammar-level findings seeded in `findings.md` with 4-field template.

---

## 5 · Findings-Seed Candidates

1. **Grammar adoption** — "§N · `color.controls.{hierarchy}.{element}.{state}`:
   192 tokens, clean pattern. Adopt as-is."
2. **Intent/emphasis folding** — §3.7 template.
3. **Ghost hierarchy** — value exists as component variant but has no tokens
   (e.g. a `tertiary` variant rendered via `background.none` substitution).
4. **DTCG↔Figma drift** — count delta per family.
5. **Property-explosion at token-layer** — e.g. a state-segment value like
   `error-filled-counter` folds validation × hasValue × extras into the
   state position. Rare at token-layer, but does occur in DSes that
   propagate component-level compound states into token paths.
6. **Cross-grammar aliases as feature** — document the pattern, not as
   drift.
7. **Orphan standalone tokens** — leaves that don't fit any grammar nor
   have clear standalone purpose.

---

## 6 · Typical Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Using `search_tokens` as enumeration | "Showing 100 of 192" accepted as full set | Rule B — `browse_tokens` with `path_prefix` + `depth` instead |
| Mixed-depth group misclassified as "flat" | One grammar swallowed by root-level scan (v1.3.0 MCP did this) | Split: consistent-depth sub-groups = grammars, depth-outliers = standalone |
| Missing cross-grammar aliases | Declaring grammar "isolated" | Step 3.4 classification |
| Skipping (axis × axis) sparsity | Profile declares full-cartesian; generators emit 96 missing CSS vars | Step 3.3 explicit sparsity table |
| Trusting one-side count | Reporting 192 tokens without Figma cross-check | Step 3.6 DTCG↔Figma delta |
| Accepting folded hierarchy | `hierarchy: [brand, warning, negative]` adopted without question | §3.7 intent/emphasis test |
| Ignoring ghost hierarchy | Button declares `tertiary` variant with no tokens backing it | Flag as Finding — decision: introduce tokens OR document ghost pattern |

---

## 7 · Subagent Dispatch Template (★★★ research-heavy)

Phase 3 is the second major subagent-candidate (after Phase 1). Parallel
shape is natural: token-tree scan is embarrassingly parallel across
top-level groups.

**When to dispatch:**

- Token tree has > 3 top-level groups (one agent per group).
- Each group has > 200 tokens (enumeration benefits from parallelism).
- Component-binding map needs > 10 components sampled.

**Parallel task shapes:**

```
Agent 1: browse_tokens(path_prefix="color.controls", depth=5) — full tree
Agent 2: browse_tokens(path_prefix="color.text", depth=3) — full tree
Agent 3: browse_tokens(path_prefix="spacing", depth=3) — full tree
Agent 4: Sample get_variable_defs on 10 representative component node-IDs

Agent 5 (merge-agent): consolidate grammar-candidates from 1-3,
                        produce sparsity matrices, identify aliases.
```

**Do not dispatch** the intent/emphasis folding analysis (§3.7) — that
involves Rule E advisor reasoning and User dialog is imminent. Stay in
main session.

**Per-agent context budget:** each agent gets the Phase-3 goal + its
specific subtree scope + the output-YAML template (§2). Do not pass full
SKILL.md. Do not let agents write to `.cdf.config.yaml`.

---

## 8 · Cross-Reference to Phase 4

The **grammars + standalone_tokens + aliases** feed Phase 4's theming-
modifier derivation. Specifically:

- Grammar modes (Light/Dark, or whatever the DS's semantic modes are) —
  Phase 4 checks if every grammar-leaf has a value in every mode.
- Standalone tokens may be brand-specific; Phase 4 flags them.
- Aliases that cross brand-modes are recomputed per-mode — Phase 4 tests
  whether this breaks.

**Rule-B-for-theming (forward-note for Phase 4):** when a DS-specific
tokens MCP exposes an enum for mode-selection (e.g. `Semantic: "Light" |
"Dark"`), treat that enum as the tool's **schema-baked view**, not as the
file's truth. An MCP adapted from one DS to another (e.g. a Formtrieb-
lineage MCP pointed at a DS with 3 semantic modes) will silently drop
modes beyond the original enum. **Trust `list_themes` output** (file-
derived, always complete) over the zod/schema enum. If a mode is listed
in `list_themes` but not selectable via `compare_themes` / `resolve_token`
/ `compose_theme`, fall back to `browse_tokens(set="<Collection>/<Mode>",
…)` — set-name strings are not enum-restricted. Record as a Phase-4
finding for the DS-tools maintainer to fix.

Do not start theming cross-check here — Phase 3 is token-shape, Phase 4 is
mode-sparsity.
