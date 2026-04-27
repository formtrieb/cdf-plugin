# CDF Walker Invocation — Shared Reference

**Purpose:** How to invoke the mechanical Phase-1 extractor (`jq` walker
+ resolver), what its output looks like, and the contract for treating
walker output as authoritative. Used by both Production-scaffold and
Snapshot-style skills on the T1/T2 path.

**When this applies:** `scaffold.tier == "T1"` (REST file cached on disk)
or `"T2"` (Enterprise REST with Variables sidecar). T0 (live `figma_execute`
enumeration) does NOT use the walker — see consuming skill's own T0
methodology.

**Skill-agnosticism contract:** this file talks about the walker, its
output schema, and downstream consumption rules. It does NOT prescribe
synthesis flow, classification, or User-dialog cadence — those are
per-skill.

---

## 1 · Source-of-Truth Contract (T1/T2)

On the T1/T2 path the walker artefact (`phase-1-output.yaml`) IS the
inventory source of truth. **Do NOT re-validate, plausibility-check, or
cross-reference against `use_figma` / live Figma reads** to "confirm" what
the walker produced. Interpret and transcribe — don't re-derive. At
max-effort every self-directed confirmation loop burns minutes with no
correctness gain: the walker is mechanical and deterministic; a second
Figma read cannot out-vote it. If walker output genuinely looks wrong
(e.g. zero component sets on a known non-empty file), that's a
tier-detection or fixture-path issue — stop and surface it, do not patch
by re-reading Figma. On T0 this constraint does not apply; live Figma IS
the source.

---

## 2 · Run the Walker

**Tier selection happens upstream.** This section assumes T1 or T2 was selected
by the probe-first algorithm in `source-discovery.md` §2. If you skipped that
step and arrived here directly because no on-disk cache was visible, **stop**
and run the upstream algorithm — you may be falling to T0 unnecessarily. The
Rule B "Capability-Probe Before Default-Fallback" discipline in
`tool-leverage.md` §3 codifies this: legacy cache absence is not equivalent to
T1-unreachability, and `cdf_fetch_figma_file({file_key})` is the canonical
T1-modern probe.

**Canonical path — `cdf-mcp` (≥ v1.7.0):**

```text
1. cdf_fetch_figma_file({ file_key: "<your-file-key>" })
   → caches the REST payload at <ds-root>/.cdf-cache/figma/<file_key>.json
   → also serves as T1-modern probe (see source-discovery.md §2 step 3)
2. cdf_extract_figma_file({ source: "rest", file_key: "<your-file-key>" })
   → walks + emits <ds-root>/.cdf-cache/phase-1-output.yaml
```

`cdf_fetch_figma_file` resolves the Figma PAT in this order:
`pat` arg > `FIGMA_PAT` env var > actionable error with MCP-config snippet.

`cdf_extract_figma_file` wraps `walkFigmaFile` + `emitPhase1Yaml` from
`formtrieb-cdf-core` and emits a version-tagged YAML artefact
(`schema_version: phase-1-output-v1`) ready for downstream consumption.
Walker + emit runs in ~3 s total. Schema reference:
`../../skills/cdf-profile-scaffold/references/phases/templates/phase-1-output.schema.yaml`.

**Deprecated bash fallback** — if cdf-mcp v1.7.0+ is unavailable, the
identical pipeline lives at `scripts/extract-to-yaml.sh
<path-to-library.file.json> --output <ds-test-dir>/.cdf-cache/phase-1-output.yaml`
(wrapping `scripts/figma-phase1-extract.sh`). The bash scripts produce
byte-identical output for the 5 golden fixtures; they are scheduled for
removal in cdf-mcp v1.8.0 once the regression-baseline (Plan §N1.6)
confirms parity in the wild.

The walker is a single-pass `jq` extractor. It collects in one
tree-traversal:

- `ds_inventory.pages` — total + content-page counts, page list
- `ds_inventory.component_sets.entries[]` — every COMPONENT_SET with full
  `propertyDefinitions` (inc. `variantOptions`), deduplicated by id,
  page-attributed
- `ds_inventory.component_sets` counts — `tree_unique_count`,
  `indexed_count` (from `.componentSets` metadata map),
  `remote_only_count` (indexed − tree = remote-library refs)
- `ds_inventory.standalone_components` — COMPONENTs not inside a
  COMPONENT_SET, pre-classified by name pattern (utility / documentation /
  widget / asset). **Author-confirmation still required downstream** —
  the classification is a starting point, not truth.
- `documentation_surfaces.figma_component_descriptions` — count + samples
- `documentation_surfaces.doc_frames` — stage-1 name-pattern matches

**Walker-output field-name drift (v1.7.x).** The walker emits
`ds_inventory.component_sets.total` for the indexed count, but the
snapshot schema expects `indexed_count`. Both refer to the same metric
(union of tree-resolved + remote-only sets, currently 195 for MoPla).
When mapping walker → snapshot, alias `total` → `indexed_count`. Walker
field rename queued for v1.8.0; until then the alias-mapping is
authoritative.

### Output-Shape Examples (for jq/yq query construction)

The walker emits flat-string arrays (NOT object arrays) for several
fields:

```yaml
standalone_components:
  utility: ["Backdrop"]                      # string[], NOT [{name: ...}]
  documentation: ["docu/component-docu-header"]
  widget: ["_Slot", "ColorCard", "Frame 26"]
  asset: ["asset-pack-A", "asset-pack-B"]

# WRONG query — assumes object-shape:
yq '.standalone_components.utility[].name' phase-1.yaml  # ❌ returns null

# RIGHT query — flat-string-array:
yq '.standalone_components.utility[]' phase-1.yaml       # ✅
```

Other fields with flat-string-array shape: `pages.separators[]`,
`libraries.linked[]` (currently empty — see B5 walker bug pending v1.8.0
investigation), `doc_frames_detected[]`.

The transformer on top:

- Reshapes walker output to the `phase-1-output-v1` schema, keeping the
  canonical `ds_inventory.{pages, component_sets, standalone_components,
  figma_component_descriptions, doc_frames_info}` wrapper and adding
  derived aggregates (`pages.separator_or_meta`, descriptor ratio,
  by-page component-set rollup) inside that wrapper.
- Emits pre-seeded `seeded_findings[]` entries (see §4) with
  `user_decision: pending` for downstream finding-classification.
- Keeps the bulky per-entry detail (propertyDefinitions etc.) inline at
  `ds_inventory.component_sets.entries[]` so the YAML is self-contained.

Output is complete except for two pluggable slots:

- `theming_matrix.collections[]` — filled by the resolver (§3)
- `token_source.regime` — set by caller from `.cdf.config.yaml`

**Direct walker invocation** (JSON-only, skipping YAML transform) lives at
`scripts/figma-phase1-extract.sh <input.json> <output.json>` for the rare
case where the raw walker shape is needed for debugging or tooling outside
the YAML pipeline. Skills always go through `cdf_extract_figma_file` on
T1/T2 (or its bash counterpart `extract-to-yaml.sh` until the v1.8.0
deprecation cleanup).

### LLM Review Contract — what to do AFTER the YAML is emitted

1. `Read` `.cdf-cache/phase-1-output.yaml`. Treat it as authoritative — do
   NOT re-run live Figma reads to "confirm" its counts (§1).
2. **Data fields are walker-owned.** Do not modify any of:
   `schema_version`, `generated_at`, `generated_by`, `figma_file`,
   `ds_inventory.*` (every field — pages, component_sets including
   entries[], standalone_components, figma_component_descriptions,
   doc_frames_info), `libraries`, `token_regime`, `theming_matrix`.
3. **`seeded_findings[]` is walker-owned for threshold-derived entries.**
   The mechanical seeds (`§A`, `§C`, `§Z-frame-named`, `§Z-page-ratio`
   when conditions hold) stay as emitted; downstream synthesis only fills
   `user_decision`. Additional findings spotted during review that the
   walker cannot threshold-detect go into the `interpretation:` zone as
   free-form notes — don't append them to `seeded_findings[]`.
4. **`interpretation:` is the sanctioned free-form zone.** Append items
   here during review (unusual naming patterns, composition oddities,
   anything non-mechanical worth surfacing for downstream
   classification). Keep it tight — if it's just restating a walker field,
   leave it off.
5. Walker phase itself does NOT call AskUserQuestion. Downstream
   finding-classification is per-skill.

---

### Inventory-counting semantic difference (T0 vs T1)

T0 (`figma_execute` runtime, Plugin-API enumeration) and T1 (REST + walker)
emit **different inventory metrics for the same Figma file**. This is
by-design but easy to misread:

| Metric | T0 (runtime) | T1 (REST walker) |
|---|---|---|
| `componentsTotal` | every COMPONENT instance (variants count individually) | not emitted |
| `component_count` | not emitted | unique COMPONENTs by id (variants share parent id) |
| `component_set_count` | every COMPONENT_SET instance | unique COMPONENT_SETs |

Worked example — same Figma file walked under both adapters in a debug
session: T0 reported `componentsTotal: 1615`, T1 reported
`component_count: 191`. The real authored COMPONENT count is ~191; T0's
1615 reflects variant-instance count (each variant inside a
COMPONENT_SET counts as a separate COMPONENT in the runtime tree, while
T1 deduplicates by `id`).

**When emitting Snapshot inventory:** prefer T1's deduped counts. If
both T0 and T1 ran (e.g. probe-then-walker in `source-discovery.md` §2),
emit a one-line note in `inventory:` explaining which metric was used
and the underlying reason for the discrepancy. Snapshot synthesis
(`cdf-profile-snapshot/references/synthesis.md` §2.2) carries the
operational instruction.

This is a **walker-output-semantic** issue, not a discrepancy between
adapters — both adapters faithfully report what they see. The reader
(human or downstream tool) needs the framing to reconcile the numbers.

---

## 3 · Resolver Invocation (Variable-ID → Path Mapping)

Per `scaffold.resolver.kind` in `.cdf.config.yaml`:

| `resolver.kind` | Action |
|---|---|
| `tokens-mcp` | Call `<ds>-tokens.list_themes` (from `resolver.mcp_name`) — returns axes + modes. Merge into `theming_matrix.collections`. Typical: `formtrieb-tokens.list_themes`. |
| `plugin-cache` | Read `resolver.cache_path`. If missing/stale: run one Plugin-API call — `figma.variables.getLocalVariableCollectionsAsync()` — write result to cache_path, then parse. Cache is reused across runs. |
| `enterprise-rest` | `GET /v1/files/{key}/variables` (requires Enterprise). Parse into `theming_matrix.collections`. |

The resolver's output shape is identical across all three — downstream
theming work doesn't know which one filled the slot.

---

## 4 · Mechanical Seeded Findings

`cdf_extract_figma_file` (and its deprecated bash twin `extract-to-yaml.sh`)
pre-seeds four **auto-seedable finding candidates** without inference,
when thresholds are met:

- **§A** — systematic description gap: if
  `figma_component_descriptions.with_description / total_component_sets < 0.1`
  (empirical baseline: 1 / 192 on a mature real-world DS)
- **§C** — remote-library drift: if `remote_only_count > 0`, vocab-source
  ≠ render-source
- **§Z-frame-named** — abandoned-work candidates: any component_set or
  standalone COMPONENT name matching `/^Frame \d+$/`
- **§Z-page-ratio** — file-organisation: if `pages.total / pages.content > 1.5`,
  separator-page-heavy file

Thresholds are hardcoded in `cdf-core/src/extractor/walker.ts`
(and the equivalent bash `extract-to-yaml.sh`) to match this section.
Each entry carries `user_decision: pending` and is consumed by downstream
finding-classification per the consuming skill's own contract. The
auto-seed does NOT classify them — classification is downstream.

---

## 5 · Things the Walker Cannot Mechanically Derive

The following still require User-dialog (or skill-specific defaults):

- `token_source.regime` — from `.cdf.config.yaml`
- `extends.path` + `naming.identifier` — User dialog per
  `source-discovery.md` §4 / §5
- `external_docs[]` — User input
- `dtcg_descriptions` — separate `Read` of DTCG files if regime matches

All other walker outputs are complete after §2 + §3.

---

## 6 · Completion Gates (Tier-Aware)

Adapted from the Phase-1 generic gate-list. T1/T2 replaces the first
three gates:

- [x] Full file inventory → **Walker produced inventory with dedup**
  (`tree_unique_count` matches visual spot-check against Figma).
- [x] Every COMPONENT_SET has `propertyDefinitions` populated → **Walker
  guarantees this** by design (field always included, empty-object when
  Figma returns none).
- [x] Standalone components classified → **Walker did initial pass**;
  User-confirmation for non-obvious names is downstream.
- [ ] Token-source regime confirmed (★-rating recorded in `.cdf.config.yaml`).
- [ ] Parent Profile check done (auto: null if not set).
- [ ] DS identifier short-code recorded.
- [ ] Tokens enumerated via resolver.
- [ ] Theming-axes matrix recorded (from resolver).
- [ ] Documentation surfaces surveyed (Figma-native via walker;
      DTCG separate if regime applies).
- [ ] Initial findings seeded (§4).
- [ ] `.cdf.config.yaml` `scaffold:` block updated with
      `last_scaffold.tier_used` (or analogous skill-specific block).

If any gate fails, do **not** advance — downstream work amplifies any
gaps in the walker output.

---

## 7 · Pitfalls Specific to T1/T2

| Pitfall | Symptom | Fix |
|---|---|---|
| Stale `library.file.json` | Walker output doesn't match the Figma file User sees | Caller responsibility — re-run `specs-cli fetch` (or equivalent). Walker has no way to detect staleness. |
| Non-Enterprise + `token_source.regime: enterprise-rest` | Resolver call returns 404 | Precheck: if regime is enterprise-rest, verify `/variables` endpoint; if 404, fall back to `plugin-cache` OR error with explicit message. |
| Walker classification oversimplifies | Component like `Popover Menu` (composed standalone) shown as "widget" despite its utility role | Treat walker-classes as starting point, surface the classified list to User during downstream classification. |
| Hand-edit of walker-owned fields | LLM "fixes" a count or appends to `seeded_findings[]` post-walker | Walker fields are immutable post-emit (§2 review contract step 2–3). Use `interpretation:` for free-form notes. |
| Re-run walker mid-skill to "double-check" | Wall-clock burned with no correctness gain | §1 source-of-truth contract — walker output is authoritative, not a hypothesis. |
