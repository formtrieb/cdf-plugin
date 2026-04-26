# Phase 1 · Orient

**Goal:** Build a map of the DS — what components, what libraries, what
theming-axes, what documentation-surfaces, what token-source regime. Produce
the inputs every later phase depends on.

**Predecessor:** Pre-Phase-0 checklist in SKILL.md §7 passed
(🔴 ds_name + figma.file_url known, 🟡 token regime identified,
**tier detected** per SKILL.md §1.4).

**Successor:** Phase 2 (Vocabularies) — synthesis only, no new tool-calls if
Phase 1 enumerated `componentPropertyDefinitions`.

**Subagent-fit:** ★★★ — enumeration is research-heavy and parallelizable
(T0 only). See §7 below for dispatch template. T1/T2 does not need
subagents — the walker is already single-pass.

**Tier branch:** If `scaffold.tier == "T1"` or `"T2"`, skip §1.2–§1.6
methodology and follow **§8 T1 Local-File Path** instead. The Plugin-JS
enumeration described in §1.2 is only needed for T0. The T1 path produces
the same `phase_1_output` schema (§2) mechanically in ~2 s.

**Source authority (T1/T2 — walker output is authoritative).** On the
T1/T2 path the walker artefact (`phase-1-output.json` or equivalent)
IS the Phase-1 source of truth. **Do NOT re-validate, plausibility-
check, or cross-reference against `use_figma` / live Figma reads** to
"confirm" what the walker produced. Interpret and transcribe — don't
re-derive. At max-effort every self-directed confirmation loop burns
minutes with no correctness gain: the walker is mechanical and
deterministic; a second Figma read cannot out-vote it. If the walker
output genuinely looks wrong (e.g. zero component sets on a known
non-empty file), that's a tier-detection or fixture-path issue — stop
the phase and surface it, do not patch by re-reading Figma. On T0 this
constraint does not apply; live Figma IS the source.

---

## 1 · Methodology (Survey First — Rule A everywhere)

### Step 1.1 — Confirm token-source regime (🟡 input)

Canonical content in `../../../../shared/cdf-source-discovery/source-discovery.md` §3
— **`Read` that file** for the regime table (tokens-studio / dtcg-folder /
figma-variables / figma-styles / none). Phase 3/4 are the main downstream
surfaces that branch on the regime value.

### Step 1.1.1 — Parent Profile inheritance (🟡 input)

Canonical content in `../../../../shared/cdf-source-discovery/source-discovery.md` §4
— **`Read` that file** for the User-prompt text, the `extends:` recording shape,
the spec constraints (single-level / cdf_version range / circular / parent
file exists), and merge semantics (§15.1 per-key REPLACE).

Phase-2 through Phase-5 outputs build as *differences from parent* when
`extends:` is set, not as absolute characterizations. This keeps Phase-7's
emit cycle trivial.

### Step 1.1.2 — DS identifier short-code (🟢 input)

Canonical content in `../../../../shared/cdf-source-discovery/source-discovery.md` §5
— **`Read` that file** for the User-prompt text, defaulting rule (first 3
chars of ds_name), examples (Formtrieb→ft / Primer→pr / Material 3→m3 /
Acme→acme), and the inherited-unchanged emit rule.

### Step 1.2 — Enumerate Figma structure (one call, Plugin-JS)

Use `figma:figma-use` as prerequisite, then `use_figma`. **Don't start with
`figma-mcp.get_libraries` or `get_metadata(0:1)`** — those have near-zero
leverage here (see §6 Pitfalls).

**Step 1.2.0 — Page-count precheck (one cheap call, under 1 kB payload).**
Before choosing a Pass-1 strategy, run a minimal enumeration to get the
file's page count and a per-page component summary:

```js
const pages = figma.root.children.map((p) => ({
  name: p.name,
  childCount: p.children.length,
}));
return { pageCount: pages.length, pages };
```

Branch strategy on the result. **Count content-pages, not raw pages**
— a `content_page_count` is `pages.filter(p => p.childCount > 0).length`.
Many DSes use empty separator-pages (`---`, `↓ Section Header`, etc.)
to organize the file outline; counting those inflates the volume
estimate and falsely triggers Pass-1-lite. Use both counts in the
branch decision, with content-pages as the primary signal:

| content_page_count | Strategy |
|---|---|
| ≤ 20 | Run full Pass-1 directly |
| 20–50 | Run full Pass-1; expect occasional truncation, fall back to Pass-1b batch |
| > 50 | **Skip straight to Pass-1-lite + batched Pass-1.5.** Full-first Pass-1 is pure waste — truncation is near-certain. |

When `pageCount` is much larger than `content_page_count` (e.g. raw
81 / content 49 — real-run baseline on a mid-size DS), record both in
the phase-1-notes; that ratio is itself a §Z housekeeping signal
(file organization vs. content density).

This one extra call pays for itself the first time you avoid a wasted
truncated Pass-1 against a 100+ page file.

**Pass-1 template (hardened enumeration with property-definitions).** Phase 2
needs axis **values** (not just names) to aggregate vocabularies, so Pass-1
captures `componentPropertyDefinitions` in full — this yields
`{ type: "VARIANT", variantOptions: [...] }` per VARIANT axis plus
`defaultValue` metadata for BOOLEAN/TEXT properties. Two common failures the
plain-child-iteration template misses: (a) DSes that use "one component per
page" layouts nest COMPONENT_SETs inside framing containers so
`page.children` returns zero sets; (b) a single broken COMPONENT_SET
anywhere in the file throws on `componentPropertyDefinitions` and kills the
whole enumeration. Use `findAllWithCriteria` + wrap the property read:

```js
// Enumerate all pages + component structures. Robust to nested layouts
// and broken COMPONENT_SETs (either would otherwise abort the script).
// Captures propertyDefinitions so Phase 2 can aggregate axis VALUES,
// not just names.
const summary = [];
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  const nodes = page.findAllWithCriteria({
    types: ["COMPONENT_SET", "COMPONENT"],
  });

  const sets = [];
  const standalones = [];
  for (const node of nodes) {
    if (node.type === "COMPONENT_SET") {
      let propertyDefinitions = {};
      let propsError = null;
      try {
        // propertyDefinitions[name] = { type, variantOptions?, defaultValue? }
        propertyDefinitions = node.componentPropertyDefinitions ?? {};
      } catch (e) {
        // Broken COMPONENT_SET — record and keep going.
        propsError = String(e.message).slice(0, 120);
      }
      sets.push({
        id: node.id,
        name: node.name,
        propertyDefinitions,
        variantCount: node.children.length,
        ...(propsError ? { propsError } : {}),
      });
    } else if (node.type === "COMPONENT") {
      // Filter out variant children — they surface as COMPONENT inside
      // a COMPONENT_SET, but we already counted them via variantCount.
      if (node.parent && node.parent.type !== "COMPONENT_SET") {
        standalones.push({ id: node.id, name: node.name });
      }
    }
  }

  if (sets.length || standalones.length) {
    summary.push({ page: page.name, sets, standalones });
  }
}
return summary;
```

**Payload sizing note:** the 20 kB cap is **payload-density-limited, not
count-limited**. Field-observed truncation hit at page-index 47 on a
110-page file — well below the "> 50 sets" heuristic — because one
COMPONENT_SET with a rich INSTANCE_SWAP `preferredValues` array burned
the remaining budget in a single entry. Other high-cost fields that
commonly blow Pass-1:

- `componentPropertyDefinitions[*].preferredValues` (INSTANCE_SWAP props)
- long VARIANT `variantOptions` arrays (10+ values × multiple axes)
- unusually long component/variant names (e.g. auto-generated IDs baked in)

**Default stance:** Pass-1 drops `preferredValues` from `propertyDefinitions`
payload (keep `type` + `variantOptions` + `defaultValue` only) and refetches
only when Phase 5 needs INSTANCE-swap wiring. Strip with:

```js
// In the Pass-1 template, after `propertyDefinitions = node.componentPropertyDefinitions ?? {}`:
for (const key of Object.keys(propertyDefinitions)) {
  const def = propertyDefinitions[key];
  if (def && "preferredValues" in def) delete def.preferredValues;
}
```

**When to split (Pass-1-lite + Pass-1.5) anyway:** if Pass-1 still truncates
after `preferredValues` stripping — or if any single set has
`variantOptions` arrays summing > ~2 kB.

**Pass-1b (batch) — when Pass-1 hits the 20 kB response cap mid-array and
truncates:**

```js
// Re-run Pass-1 starting from a page index. SKIP_BEFORE is substituted
// by the Master between batches.
const SKIP_BEFORE = __SKIP_BEFORE__; // e.g. 50 — resumes after first batch
const summary = [];
const pages = figma.root.children;
for (let i = SKIP_BEFORE; i < pages.length; i++) {
  // …same inner loop as Pass-1…
}
return summary;
```

**Pass-1-lite + Pass-1.5 (for DSes that truncate even under batch).**
Pass-1-lite captures structure only (drop `propertyDefinitions`, keep
`id`, `name`, `variantCount`); then Pass-1.5 fetches property-definitions
in smaller batches using recorded ids.

**Batch-size heuristic (load-bearing — skip it, and Pass-1.5 re-truncates):**

| DS character | Target IDs per batch |
|---|---|
| Typical DS (BEM naming, standard variant-axes, no INSTANCE_SWAP heavy) | ≤ 40 IDs |
| INSTANCE_SWAP-heavy DS (Avatar / Combo Box / Media Card with slot-primitives) | ≤ 20 IDs |
| Uncertain | Start at 40; halve on truncation |

**INSTANCE_SWAP recognition:** Phase 1's `propertyDefinitions` output
includes `type: "INSTANCE_SWAP"` entries. If Pass-1-lite records any
COMPONENT_SETs with > 3 INSTANCE_SWAP axes OR variantOptions-arrays
summing > 2 kB per set, halve batch size preemptively.

**On truncation: split the CURRENT batch, don't shrink the batch-list.**
Prior successful batches (pages 0-30 already fetched) stay. The
truncated batch (say pages 30-70, 40 IDs) gets split to pages 30-50
(20 IDs) + pages 50-70 (20 IDs). Do NOT restart from batch 1 — that
wastes successful work.

**Do NOT issue a batch without a descriptive `description` param** on
the `use_figma` call — `"Pass-1.5 Batch B — IDs 30-70 (INSTANCE_SWAP-heavy)"`
makes the tool-call log self-auditing for later Rule-B reviews. If
Batch B truncates and you need to split, the log shows the ID range
already covered.

Pass-1.5 code template:

```js
// Pass-1.5 — run per page-range or per batch of IDs returned by Pass-1-lite.
const IDS = __IDS__; // e.g. ["123:456", "123:457", …]
const out = [];
for (const id of IDS) {
  const node = await figma.getNodeByIdAsync(id);
  if (!node || node.type !== "COMPONENT_SET") continue;
  let propertyDefinitions = {};
  let propsError = null;
  try { propertyDefinitions = node.componentPropertyDefinitions ?? {}; }
  catch (e) { propsError = String(e.message).slice(0, 120); }
  out.push({ id, propertyDefinitions, ...(propsError ? { propsError } : {}) });
}
return out;
```

By Phase-1 completion, every COMPONENT_SET must have its
`propertyDefinitions` merged into its summary entry — Phase 2 depends on it.

**Pass-2 (detail) — only for specific components needing full
`propertyDefinitions`:**

```js
// Example: detail one COMPONENT_SET's variantOptions + text props.
const node = await figma.getNodeByIdAsync("__NODE_ID__");
return {
  id: node.id,
  name: node.name,
  properties: node.componentPropertyDefinitions,
  variants: node.children.map((v) => ({ id: v.id, name: v.name })),
};
```

**Rule B (Truncation-Awareness) applies.** Truncation probability correlates
with payload-density, not just set-count — one INSTANCE_SWAP-heavy set can
burn the 20 kB budget alone. Strategies (in recovery order):

1. **Strip `preferredValues`** from `propertyDefinitions` before return (see
   sizing-note above). Usually enough for DSes up to ~100 COMPONENT_SETs.
2. **Per-page batch enumeration** — use Pass-1b with `SKIP_BEFORE`; merge
   batches in the Master.
3. **Split Pass-1-lite + Pass-1.5** — structure-only first pass, then
   per-ID property-definitions batches.
4. **Subagent parallelism** — dispatch N subagents, each covering a
   page-range (see §7). Preferred for DSes > 100 components.

### Step 1.3 — Classify standalone COMPONENTs (Rule F)

Not every COMPONENT is a widget. After enumeration, classify by name pattern +
User confirmation:

| Role | Name patterns | Examples |
|---|---|---|
| **Utility** | `focus`, `ring`, `divider`, `backdrop`, `scrim`, `overlay`, `surface` | Focus Ring, Divider, Tooltip Backdrop |
| **Documentation** | `_doc`, `doc-`, `docu`, `description`, `guide` | `_doc-content` frames |
| **Widget** | plain component names | Label, Helper Text |
| **Asset** | `icon`, `illustration`, `logo`, `badge` | Icon-Check, Logo-Mark |

**Ask the User if any utility roles are non-obvious from the name.** A
standalone focus-ring component can be invisible via name-pattern alone
without User correction — Rule F exists because of observations like this.

### Step 1.4 — Enumerate tokens (per regime, via Rule A)

Always ask *"which tool do you have available?"* before reaching for `Read`.

| Regime | Preferred inspection |
|---|---|
| tokens-studio | DS-specific MCP (e.g. `formtrieb-tokens.list_token_sets` + `browse_tokens`) — then cross-check `$themes.json` |
| dtcg-folder | DS-specific MCP if present; fall back to `Read` on the DTCG files |
| figma-variables | `use_figma` Plugin-JS: `figma.variables.getLocalVariableCollectionsAsync()` — **wrap any `collection.hiddenFromPublishing` read in `try/catch`**; local collections can throw `Node with id "VariableCollectionId:<id>" not found` on that property alone while other fields (`name`, `modes`, `variableIds`) work. Record the failure as a file-health finding and continue. |
| figma-styles | `use_figma`: `figma.getLocalPaintStylesAsync()` + `getLocalTextStylesAsync()` + `getLocalEffectStylesAsync()` |
| none | Skip; seed Finding #1 in `findings.md`. |

**Always enumerate Figma Styles alongside Variables, regardless of regime.**
Typography frequently lives as TextStyles even when Paint is in Variables.
Shadows lives almost exclusively in EffectStyles. Skipping Styles = systematic
representation-gap finding missed.

### Step 1.5 — Theming Axes (pre-record, confirmed in Phase 4)

From Variable Mode enumeration and/or DTCG `$themes.json`, record:

- collection-name → modes list (e.g. `Semantic` → `[Light, Dark]`, `Device`
  → `[Desktop, Tablet, Mobile]`, `Shape` → `[Round, Sharp]`).
- cross-axis matrix (e.g. 2 semantic × 3 device × 2 shape = 12 combinations).

Do **not** attempt to classify sparsity yet — that is Phase 4. Just record.

### Step 1.6 — Documentation-Surfaces Survey (Rule H)

For each surface, record presence + sample:

| Surface | Detection | What to record |
|---|---|---|
| DTCG `$description` on tokens | parse DTCG, grep `$description` | count + 1-2 samples |
| Figma Component Description | `node.description` field | "present on N of M COMPONENT_SETs" |
| Figma Annotations (sticky-notes) | **Not reliably reachable from `use_figma` Plugin-JS** — `figma.annotations.*` methods have thrown `not a function` in recent runtime checks. Treat as unavailable unless a Figma plugin UI exposes them; leave as `null` in inventory, note in findings. | `unavailable` sentinel + note |
| Doc-frames | **Two-stage detection.** (1) name pattern match (`_doc*`, `doc-*`, `docu*`, `description`); (2) **composition-fallback if (1) yields nothing**: find top-level FRAMEs whose children include INSTANCEs of a standalone `_doc*` / `_component-docu*` COMPONENT. The frame-name can be literally `" "` (single space) or duplicate page name — author-intent lives in what's *inside*, not what's *named*. | frame-IDs list + 1 sample content |
| External docs | ask User | URL list |

**Rule G applies from here.** If doc-frames are present, **ingest them before
inferring anything** in Phase 5. Author intent beats inferred intent.

---

## 2 · Output (carry-forward to Phase 2)

After Phase 1, the following must be in-hand for Phase 2 and beyond:

```yaml
phase_1_output:
  ds_inventory:
    pages: <count>
    component_sets:
      count: <N>
      entries:                   # MUST include propertyDefinitions per entry —
        - id: "123:456"          # Phase 2 aggregates axis VALUES, not just names
          name: Button
          page: Components
          variantCount: 24
          propertyDefinitions:
            type:
              type: VARIANT
              variantOptions: [primary, secondary, tertiary]
            state:
              type: VARIANT
              variantOptions: [enabled, hover, pressed, disabled]
            size:
              type: VARIANT
              variantOptions: [default, compact]
            hasIcon:
              type: BOOLEAN
              defaultValue: false
            label:
              type: TEXT
              defaultValue: Button
        # …one entry per COMPONENT_SET
    standalone_components:
      utility: [Focus Ring, Divider, ...]
      documentation: [_doc-content, ...]
      widget: [Label, Helper Text, ...]
      asset: [Icon-Check, ...]
  theming_matrix:
    collections:
      - name: Semantic
        modes: [Light, Dark]
      - name: Device
        modes: [Desktop, Tablet, Mobile]
      - name: Shape
        modes: [Round, Sharp]
  token_source:
    regime: tokens-studio|dtcg-folder|figma-variables|figma-styles|none
    paths: [./tokens/]
    quality_rating: 0-3
  documentation_surfaces:
    dtcg_descriptions: <count | null>
    figma_component_descriptions: "<N of M>"
    figma_annotations: <count | 0>
    doc_frames: { convention: "_doc-content", count: N }
    external_docs: [URLs]
  findings_seeded:
    - "§1 · Token-source regime methodology note" (if regime in [figma-styles, none])
    - "§N · Potential DTCG↔Figma drift" (if Variable count ≠ DTCG count)
```

**Carry-forward artefact by tier:**

| Tier | File | Producer | Phase 2 reads |
|---|---|---|---|
| T1 / T2 | `<cwd>/.cdf-cache/phase-1-output.yaml` | `cdf_extract_figma_file({source:"rest"})` MCP tool (walker + emit; deprecated bash twin: `scripts/extract-to-yaml.sh`) | YAML, version-tagged `phase-1-output-v1` |
| T0 | `<cwd>/phase-1-notes.md` | LLM during Phase-1 synthesis | Markdown prose (legacy path) |

On T1/T2 the YAML **is** the carry-forward — Phase 2 consumes it directly
via `yq` / `yq -o=json … | jq …`. Don't also write a `phase-1-notes.md`:
it would drift from the structured source and invite cross-reference
confusion (violates the walker-authoritative discipline above). LLM
review may append non-mechanical observations to the YAML's
`interpretation:` zone (see `../../../../shared/cdf-source-discovery/walker-invocation.md` §2 LLM-review-contract step 4) — that is the sanctioned
free-form surface.

The `scaffold:` block in `.cdf.config.yaml` is updated with
`last_scaffold.phases_completed: [1]` in both tiers.

---

## 3 · Tool-leverage Map (Phase-1 specific)

Canonical content in `../../../../shared/cdf-source-discovery/tool-leverage.md` §3
— **`Read` that file** for the full leverage table (`use_figma` ★★★,
`get_variable_defs` ★★, DS-specific tokens MCP ★★★, `get_design_context` ★,
`get_metadata` ✗, `get_libraries` ✗, `whoami` ✗, `Read` on DTCG ★). The
new §2 (Rule-A Enforcement: Tool-Survey Before Resolver-Gap) is also
load-bearing for Phase-3 token-grammar work — see `phase-3-grammars.md`
for the cross-reference.

---

## 4 · Completion Gates

Before advancing to Phase 2, verify:

- [ ] Full file inventory (COMPONENT_SETs, standalones) — no truncation residue.
- [ ] Every COMPONENT_SET entry has `propertyDefinitions` populated (not just
  `axes: [names]`). Phase 2 reads axis VALUES from this field — missing it
  means Phase 2 cannot aggregate without re-fetching.
- [ ] Standalone components classified (Utility / Documentation / Widget / Asset).
- [ ] Token-source regime confirmed (★-rating recorded).
- [ ] **Parent Profile check done** (Step 1.1.1) — `extends.path` recorded
  or explicitly set to `null`. If set: parent file exists, single-level
  confirmed, cdf_version range fits.
- [ ] **DS identifier short-code recorded** (Step 1.1.2) — User-chosen or
  default-accepted (first 3 chars of ds_name).
- [ ] Tokens enumerated (via MCP if available; `Read` only as fallback).
- [ ] Figma Styles enumerated (Paint + Text + Effect) — regardless of regime.
- [ ] Theming-axes matrix recorded.
- [ ] Documentation surfaces surveyed; doc-frames ingested if present.
- [ ] Initial findings seeded (any drift, orphan, sparsity already visible).
- [ ] `.cdf.config.yaml` `scaffold:` block updated.

If any gate fails, do **not** advance — the later phases amplify Phase-1 gaps.

---

## 5 · Findings-Seed Candidates

These commonly surface in Phase 1 and should go into `findings.md` immediately
with **Observation** filled (Discrepancy/SoT/User-Decision come in Phase 6):

1. **Token-count drift between DTCG and Figma Variables** — e.g., "DTCG has
   192 `color.controls.*` tokens; Figma Variables show 195. 3-token delta."
2. **Typography representation-gap** — e.g., "68 DTCG typography tokens;
   only 2 Figma Variables. Typography appears to live as TextStyles
   primarily."
3. **Brand-mode drift** — e.g., "Brand-B mode has N−3 values; Brand-A
   modes have N. 3-value gap."
4. **Tablet-orphan** — e.g., "Device collection has Tablet mode; no
   component variant exposes tablet."
5. **Empty placeholder collections** — e.g., "Figma `Components` collection
   has 0 variables. DTCG `Components/TextFields.json = {}`. Drop candidate."
6. **Focus-pattern not visible via variants** — seed note: "Focus-strategy
   not present in variant-axes; check utility-components + doc-frames in
   Phase 5."

---

## 6 · Typical Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| 6-component-sample gambling | Inferring vocab from a handful of components | Rule B; enumerate **all** pages first |
| Using `get_libraries` as DS-specific evidence | Listing team-global libraries | Rule D — that tool is global, not DS-scoped |
| Using `get_metadata(0:1)` as file-structure | Reporting "Welcome page = DS taxonomy" | Switch to `use_figma` Plugin-JS enumeration |
| Missing standalone utilities | Phase-5 "no focus design" false-negative | Rule F classification pass in Step 1.3 |
| Assuming DTCG ↔ Figma 1:1 link | Drift goes unnoticed until generators break | Record both counts; compare in Phase 3/4 |
| Skipping Figma Styles when Variables present | Typography / Shadow gap missed | Always enumerate Paint/Text/Effect Styles |
| Reading DTCG raw when MCP exists | Bypasses resolved/validated view | Rule A — ask for DS-specific MCP first |
| Searching for token **values** via `search_tokens` and getting 0 hits | `search_tokens` semantically matches dot-paths, not `$value` payloads | Use a domain scan tool if available (e.g. `find_placeholders` for magenta-stub detection); else `browse_tokens` enumeration + value-grep on the returned tree |
| `page.children` returns empty despite many components | "1 component per page" layout wraps sets in framing containers | Use `page.findAllWithCriteria({types:["COMPONENT_SET","COMPONENT"]})`; filter standalones by `parent.type !== "COMPONENT_SET"` |
| Single broken COMPONENT_SET kills the whole enum | `Component set has existing errors` thrown from `componentPropertyDefinitions` | Wrap the property read in `try/catch`; record as `propsError` field on the set |
| `hiddenFromPublishing` throws on every VariableCollection | `Node with id "VariableCollectionId:<id>" not found` when reading that one property | Wrap publishing-state read in `try/catch`; Profile doesn't depend on it, non-blocking |
| 20 kB response cap truncates mid-array | `// truncated to 20kb` marker at end of payload; later data lost | Pass-1b batch via `SKIP_BEFORE`; OR split into Pass-1-lite (structure) + Pass-1.5 (property-definitions) |
| Pass-1.5 batch truncates on INSTANCE_SWAP-heavy DS | Batch of 40+ IDs against a DS with Avatar/Combo-Box-style INSTANCE_SWAP slots → mid-batch truncation | Target ≤ 40 IDs per batch (≤ 20 for INSTANCE_SWAP-heavy); split truncated batch in half, keep prior successful batches |
| Capturing axis names but not values | Phase 2 can't aggregate vocabs; "Phase 2 needs variant values" blocker | Pass-1 must capture full `componentPropertyDefinitions` (includes `variantOptions`), not just `Object.keys(...)` |
| Calling `figma.annotations.getAllAsync()` | `{ error: "not a function" }` at runtime | Annotations API is not reliably available from `use_figma`. Mark unavailable, continue — Component Descriptions + doc-frames carry Rule-H |

---

## 7 · Subagent Dispatch Template (★★★ research-heavy)

Phase 1 is the primary candidate for subagent parallelism. Use
`superpowers:dispatching-parallel-agents` patterns.

**When to dispatch:**

- DS has > 50 COMPONENT_SETs **AND** > 20 pages (Pass-1 likely truncates).
- Token source has > 500 tokens across > 3 files.
- User has pointed at external docs that need summarization.

**Do not dispatch when:**

- User has not yet confirmed the token-source regime (Rule A — dialog first).
- DS is small (< 20 components) — sequential is faster than coordination.

**Parallel task shapes (safe, non-overlapping):**

```
Agent 1: Enumerate pages [0..N/2] via use_figma Pass-1
Agent 2: Enumerate pages [N/2..N] via use_figma Pass-1
Agent 3: Enumerate DTCG token tree (browse_tokens depth-traversal)
Agent 4: Summarize doc-frames content (get_design_context on sample IDs)
```

All agents return structured YAML that the Master merges. No agent is allowed
to write to `.cdf.config.yaml` — the Master owns persistence.

**Context limit:** dispatch agents with the Phase-1 goal + inventory template
(§2) only; do not pass the full SKILL.md. The phase-doc itself stays in
Master's context.

---

## 8 · T1 Local-File Path (replaces §1.2–§1.6 when tier=T1/T2)

Canonical content lives in
`../../../../shared/cdf-source-discovery/walker-invocation.md`. **`Read` that
file** when `scaffold.tier == "T1"` or `"T2"`. Covers:

- §1 Source-of-Truth contract (walker output is authoritative; no
  re-Figma cross-checks)
- §2 Walker run (`cdf_fetch_figma_file` + `cdf_extract_figma_file`
  MCP tools, with deprecated `scripts/extract-to-yaml.sh` fallback;
  output schema, LLM review contract)
- §3 Resolver invocation (`tokens-mcp` / `plugin-cache` / `enterprise-rest`)
- §4 Mechanical seeded findings (§A description-gap, §C remote-drift,
  §Z-frame-named, §Z-page-ratio thresholds)
- §5 What the walker cannot derive (regime, extends, identifier,
  external_docs, dtcg_descriptions)
- §6 Completion gates (tier-aware)
- §7 Pitfalls specific to T1/T2

Phase-2 hard-asserts `phase-1-output.yaml` schema_version
`phase-1-output-v1`. Anything Phase-1 emits goes through the shared
walker-invocation contract.
