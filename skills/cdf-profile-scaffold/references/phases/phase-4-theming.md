# Phase 4 · Theming Modifiers

**Goal:** Derive the DS's theming-axes (semantic, device, shape, brand, …)
from token sources + Figma Variable modes; verify they line up across
representations; surface component-layer gaps; record mode-sparsity per
collection. This is the phase that tests whether the DS's *stated*
multi-dimensional theming actually holds at the token-leaf level.

**Predecessor:** Phase 3 (`grammars` + `standalone_tokens` + `aliases`
in-hand). The theming-matrix was pre-recorded in Phase 1 §1.5 — Phase 4
verifies it and adds depth.

**Successor:** Phase 5 (Interaction Patterns + A11y Defaults).

**Subagent-fit:** △ hybrid — the cross-check is research-heavy (one call
per mode × collection), but the SoT-decisions around brand-drift and
tablet-orphans require User dialog (Rule E). Dispatch subagents only for
the pure enumeration legs; keep reasoning in main session.

**Shape authority.** Load `cdf_get_spec_fragment({ fragment: "Theming" })`
— §8 (modifiers + set_mapping). This is the sole Profile-spec fragment
Phase 4 needs; do not read the full monolith.

**Finding-prose contract (Lever 5).** Every cluster A/B/C/D finding this
phase seeds MUST carry `plain_language` (≤50 words, jargon-free),
`concrete_example` (real values from `compare_themes` / `list_themes`
output, cited verbatim), and `default_if_unsure: { decision, rationale }`.
Schema: [`templates/seeded-findings.schema.yaml`](templates/seeded-findings.schema.yaml).

> **Bad** (CDF-format-speak): *"Mode-sparsity at the Semantic axis
> exhibits N=45 unmirrored token-leaves between Light/Dark with
> set_mapping orphan-mode coverage gap."*
>
> **Good** (DS-architect-speak): *"Im Vergleich zwischen Light- und
> Dark-Mode haben 45 Tokens nur einen der beiden Werte definiert (z.B.
> `color.surface.elevated` ist nur in Light gesetzt). Das heißt im
> Dark-Mode greift der Default-Wert. Vermutlich gewollt für neutrale
> Tokens — solltest Du pro Token bestätigen."* + concrete_example
> citing 3-5 of the unmirrored token paths from `compare_themes`.

User's session language wins. Decision-quality of Phase 6 depends
directly on prose comprehension here.

**No spec citations in `plain_language` (Lever 5.I).** Forbidden:
`§…` references, bare CDF terms (`mode-sparsity`, `orphan modes`,
`set_mapping coverage gap`, `theming modifier axis`). Phase-4's
commonest leak is "Semantic-axis mode-sparsity" inside the
user-facing prose; rewrite around the unmirrored Light/Dark token
count the User can see when they switch modes, and keep the
modifier/coverage mechanics in `observation` / `sot_recommendation`.

---

## 1 · Methodology

### Step 4.0 — Locate Phase-3 input (tier-aware)

Phase 3 leaves a structured artefact Phase 4 iterates over. Path differs by tier.

| Tier | Phase-3 artefact | Access path |
|---|---|---|
| T1 / T2 | `<cwd>/.cdf-cache/phase-3-output.yaml` (version-tagged) | `.phase_4_inputs.grammars_snapshot` + `.phase_4_inputs.token_layers_snapshot` |
| T0 | `<cwd>/<ds>.phase-3-notes.md` (markdown) | inline grammars + token_layers sections |

**On T1/T2: assert the schema version BEFORE reading anything else.**

```bash
yq '.schema_version' <cwd>/.cdf-cache/phase-3-output.yaml
# Expected: phase-3-output-v1
```

If the value does NOT equal `phase-3-output-v1`, **hard-fail** — do not
attempt to interpret the file. Ask the User to re-run Phase 3. Phase 3's
emit step (`phase-3-grammars.md` §Step 3.last) stamps the version
deterministically.

### Step 4.1 — Enumerate theming axes (Rule A — whichever tool is canonical)

The theming matrix lives in one of three places depending on regime:

| Regime | Primary source | Tool |
|---|---|---|
| tokens-studio | `$themes.json` (group × mode × sets) | DS-specific tokens MCP `list_themes` |
| dtcg-folder | convention varies — ask the User how themes are declared | MCP if available; else `Read` |
| figma-variables | `VariableCollection.modes` | `use_figma` Plugin-JS enumeration |
| figma-styles | none — styles have no modes | Skip Phase 4 mode-cross-check; record as Finding |

**Always cross-check at least two representations** when both exist. A DS
that claims `semantic: [Light, Dark]` in DTCG but whose Figma file has no
Light/Dark variable collection has a sync gap — that is a Finding, not a
detail.

**Tokens-Studio-regime exception (sync wraps both sides).** When the DS
uses `tokens-studio` AND its DS-specific tokens MCP wraps the same
underlying source, the MCP IS the cross-check — it normalizes
`$themes.json` and the Figma-Variables sync state into one view. An
explicit `use_figma` VariableCollection enumeration is unnecessary unless
there's drift evidence (e.g. one mode shows a noticeably different value
count). Reduces friction for LLM-authors without weakening Rule A.

**Rule-B-for-theming (carried forward from phase-3 §8).** When a DS-specific
tokens MCP exposes a zod/schema enum for mode-selection (e.g.
`Semantic: "Light" | "Dark"`), treat that enum as the tool's **schema-baked
view**, not as the file's truth. An MCP lineage-adapted from a smaller
DS to a larger one will silently drop modes beyond the original enum.

- **Trust `list_themes` output** (file-derived, always complete) over any
  enum that appears in `resolve_token` / `compose_theme` / `compare_themes`
  schemas.
- If a mode is listed by `list_themes` but not selectable via the
  enum-gated tools, fall back to `browse_tokens(set="<Collection>/<Mode>",
  …)` — set-name strings are not enum-restricted and resolve against the
  same Resolver state.
- Record the mismatch as a Phase-4 finding (Cluster B — Theming &
  Coverage) for the DS-tools maintainer to fix. Do not block scaffolding
  on it.

### Step 4.1-bis — Mechanical mode-sparsity seeding (T1/T2 only)

When the regime is `tokens-studio` (and the DS-tokens MCP exposes
`compare_themes` + `browse_tokens(set=...)`), `mode_sparsity[]` and
`orphan_modes[]` can be populated mechanically. T0 path: skip — emit
prose to `<ds>.phase-4-notes.md` instead.

**4.1-bis.1 — Per-axis leaf counts** (the `mode_sparsity` block):

For each multi-mode collection in Phase-3's `token_layers`, count
leaves per mode. The simplest pattern is one `browse_tokens(set=...)`
per (collection × mode) returning the leaf list — then `jq | length`.

```bash
# Pseudocode — substitute the actual MCP invocation per Rule A.
COLLECTION="color.semantic"
for MODE in Light Dark Brand-B; do
  COUNT=$(<ds>-tokens.browse_tokens "$COLLECTION/$MODE" | jq '. | length')
  echo "$MODE: $COUNT"
done
```

When `compare_themes` is available and faster, prefer it — the diff
shape exposes which leaves exist on one side and not the other.

Aggregate into the schema slot:

```yaml
mode_sparsity:
  - collection: color.semantic
    modes: [Light, Dark, Brand-B]
    leaf_counts: { Light: 387, Dark: 387, Brand-B: 384 }
    delta_pattern: <LLM-authored — "Brand-B −3 leaves vs Light/Dark">
```

**4.1-bis.2 — Orphan-mode threshold seeding** (the `orphan_modes`
block + `§B-orphan-mode-*` findings):

For each entry in `mode_sparsity`, emit `orphan_modes[]` when
`max(leaf_counts) − this_mode > 0`. Pure jq:

```bash
echo "$MODE_SPARSITY_JSON" | jq '
  [ .[] |
    .collection as $c |
    .modes as $modes |
    .leaf_counts as $counts |
    ($counts | to_entries | map(.value) | max) as $max |
    .modes[] |
    . as $mode |
    ($counts[$mode]) as $actual |
    select($max > $actual) |
    {axis: $c, mode: $mode,
     expected_count: $max, actual_count: $actual,
     delta: ($max - $actual)}
  ]
'
```

If non-empty: also seed one `§B-orphan-mode-<axis>-<mode>` finding
per entry (cluster `B` — Theming & Coverage). Per-leaf "what's
missing" requires a second compare_themes call to populate
`sample_missing_paths`; if the surface is ambiguous, leave that
empty and let §4.5 LLM synthesis fill from the prose review.

**4.1-bis.3 — Theming-axes carry-forward**:

`theming_axes[]` is partially mechanical: `name` and `contexts` come
from `phase-1-output.yaml.theming_matrix.collections` (resolver-
filled). LLM fills `description`, `required`, `data_attribute`, and
`affects[]` based on Phase-3 grammar cross-reference.

```bash
yq -o=json '.theming_matrix.collections' "$P1" | jq '
  [ .[] | {name: .name, contexts: (.modes // [])} ]
'
```

### Step 4.2 — Cross-check modes between representations

For each axis identified in Step 4.1:

```
for each theming axis (e.g. Semantic):
  modes_from_dtcg  = $themes.json groups with that axis name
  modes_from_figma = VariableCollections[axis].modes
  if modes_from_dtcg != modes_from_figma:
    → Finding (mode-set drift): which side wins?
```

Common drifts:

| Observed | Example | Likely cause |
|---|---|---|
| DTCG has mode, Figma doesn't | `$themes.json` has `Brand-B`, Figma collections don't | Migration incomplete, or DTCG ahead of Figma |
| Figma has mode, DTCG doesn't | Figma Shape → `[Round, Sharp, Squared]`, DTCG only `[Round, Sharp]` | Designer added mode in Figma pre-sync |
| Name casing drift | DTCG `light`, Figma `Light` | Cosmetic; pin casing rule in Profile |

**For each drift:** seed a Finding with Cluster B · Theming & Coverage.
Observation + Discrepancy filled here; SoT-Recommendation sketched;
User-Decision deferred to Phase 6.

### Step 4.3 — Mode-sparsity per collection (does every leaf have every mode?)

For each multi-mode collection, count leaves per mode. Any gap is a
finding:

| Collection | Modes | Leaves in mode A | Leaves in mode B | Leaves in mode C | Delta |
|---|---|---|---|---|---|
| `color.semantic` | Light, Dark, Brand-B | 387 | 387 | 384 | **3 missing in Brand-B** |
| `typography` | Desktop, Tablet, Mobile | 68 | 68 | 68 | dense |
| `color.controls` | Light, Dark | 192 | 192 | — | dense |

**Two shapes of sparsity:**

1. **Count-delta** — one mode has fewer leaves than siblings. Almost always
   **brand-drift**: a secondary brand or tertiary mode didn't get every
   token assigned. SoT-Recommendation: either canonize the delta's absence
   ("these 3 tokens are intentionally missing in Brand-B") or canonize
   the full set ("all brands get all tokens"). The User decides in Phase 6.
2. **Per-leaf gap** — individual leaves resolve to `undefined` in one
   mode but not others. Usually an authoring miss; canonize full coverage
   unless the DS has a documented "intentionally inherit from parent"
   convention.

**The numerical delta is the leverage.** "Brand-B has 3 fewer tokens than
Light/Dark" is far more actionable in a DS-meeting than "brand coverage
looks incomplete."

### Step 4.4 — Component-layer gap detection (the tablet-orphan pattern)

**The headline Rule-E moment in Phase 4.** Phase 1 recorded every
COMPONENT_SET's `propertyDefinitions`; Phase 4 now cross-checks:

```
for each theming axis with a component-layer analogue (typically `device`,
rarely `shape`):
  tokens_modes   = Phase-4.1 output (e.g. [Desktop, Tablet, Mobile])
  component_vars = Phase-1 variant-axes with same semantic
                   (e.g. COMPONENT_SETs with `device: [...]` variant)
  if tokens_modes is a proper superset of component_vars values:
    → Finding (tablet-orphan): tokens cover Tablet but no component
      exposes a Tablet variant.
```

**Classic pattern:** tokens model `device: [Desktop, Tablet, Mobile]` via a
collection + mode. Components expose only a 2-value `device: [Desktop,
Mobile]` variant. The Tablet mode is an orphan — tokens flow through the
CSS cascade at the `data-device="Tablet"` scope but no Figma variant
renders against them.

This is **not** necessarily a bug. Three legitimate shapes:

| Shape | Meaning |
|---|---|
| CSS-only adaptation | Tablet is handled entirely via CSS/media-queries; Figma variants skip it to keep the component-graph lean. Profile documents the arrangement; no change needed. |
| Migration in flight | Component-layer is behind token-layer. Token-layer is ahead. Component-layer catches up. Recommend: schedule component-variant expansion. |
| Genuinely orphaned | Tablet was an aspirational value; nobody uses it. Recommend: drop from token-layer OR document intent explicitly. |

Seed a Finding per orphan with the three options; User chooses in Phase 6.

### Step 4.5 — Brand-drift detection (multi-brand DSes)

When a DS has multiple brand-modes (Brand-A, Brand-B, white-label-X), run
Step 4.3's count-delta analysis specifically for that axis. Brand-drift
has a distinctive signature:

- **Count difference across modes** is the headline.
- **Per-leaf absences concentrate in one area** (e.g. all 3 missing
  `color.controls.accent.*` tokens in Brand-B) — diagnostic for whether
  the drift is systematic (feature omitted) or incidental (3 typos).
- **Brand-drift often pairs with alias-collapse** — the missing brand's
  tokens may secretly alias the primary brand's tokens. If the DS tokens
  MCP exposes resolved values, scan for aliases pointing from the
  short-mode back to the long-mode.

### Step 4.6 — Typography & Shadow representation-gap (regime-specific)

If Phase 1 recorded "DTCG has N typography tokens, Figma Variables has M ≪ N"
**or** "DTCG has shadow tokens, Figma Variables has 0 in that family,"
Phase 4 is where it lands as a finding.

Typography usually lives as **Figma TextStyles** (not Variables); shadows
as **EffectStyles**. Both are legitimate — *but* theming-axis applicability
is unclear without explicit cross-check:

| Question | Answer shapes |
|---|---|
| Does Typography vary by `device` mode? | TextStyles have no modes; DTCG has per-device sets → recommend canonize DTCG, use Plugin-JS to generate per-mode TextStyle overrides on build |
| Does Shadow vary by `semantic` mode? | EffectStyles have no modes; same shape of recommendation |
| Can Figma render the DTCG view? | Typically requires build-time export to TextStyle/EffectStyle variants |

Record as Findings Cluster B, not as a blocker.

### Step 4.7 — Always-on collections (Foundation / Helpers)

Most DSes have collections that are not theming-axes but always-enabled:
`Foundation`, `Helpers`, `Base`, `Primitives`. Record them in the
`theming.set_mapping` output as `always_enabled: true` — not as axes.

**Heuristic:** a collection with exactly one mode is either a
single-mode-axis-candidate (rare — usually means the axis hasn't been
built out yet, seed Finding) OR an always-on collection. Ask the User if
unclear.

---

## 2 · Output (carry-forward to Phase 5)

**T1/T2 path:** `<ds-test-dir>/.cdf-cache/phase-4-output.yaml`, shape per
`references/phases/templates/phase-4-output.schema.yaml`. Phase 5
asserts `schema_version: phase-4-output-v1`.

**T0 path (legacy):** `<ds-test-dir>/<ds>.phase-4-notes.md`. Phase 6's
markdown-fallback consumer handles it.

### Step 4.last — Emit `phase-4-output.yaml` (T1/T2 only)

Build via `jq`, round-trip through `yq -P`:

```bash
OUT=<ds-test-dir>/.cdf-cache/phase-4-output.yaml
mkdir -p "$(dirname "$OUT")"
jq -n \
  --argjson axes        '<from Step 4.1-bis.3 + LLM enrichment>' \
  --argjson sparsity    '<from Step 4.1-bis.1>' \
  --argjson orphans     '<from Step 4.1-bis.2>' \
  --argjson gaps        '<from Step 4.4>' \
  --argjson set_map     '<from Step 4.7>' \
  --argjson findings    '<seeded_findings — mechanical B + LLM B>' \
  --arg     phase3_path 'phase-3-output.yaml' \
  '{
    schema_version: "phase-4-output-v1",
    generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    generated_by: { source_phase_3: $phase3_path, tier: "T1" },
    theming_axes: $axes,
    mode_sparsity: $sparsity,
    orphan_modes: $orphans,
    component_layer_gaps: $gaps,
    set_mapping: $set_map,
    seeded_findings: $findings,
    interpretation: [],
    phase_5_inputs: { theming_axes_snapshot: $axes }
  }' | yq -P -o=yaml > "$OUT"

yq '.schema_version' "$OUT"   # Expected: phase-4-output-v1
```

**LLM review contract (mirrors Phase-2 / Phase-3):**

1. Walker-owned (do NOT edit): `schema_version`, `generated_at`,
   `generated_by`, `mode_sparsity[].leaf_counts`,
   `orphan_modes[]` (counts + delta), and `theming_axes[].contexts`
   (resolver-derived).
2. Mechanical seeds (`§B-orphan-mode-*`) stay as emitted; LLM only
   fills `user_decision` during Phase 6.
3. LLM-owned: `theming_axes[].description / required / data_attribute
   / affects`, `component_layer_gaps[]`, `set_mapping`, additional
   `seeded_findings` entries (mode-set-drift, tablet-orphan,
   typography rep-gap, etc.), `interpretation[]`.
4. Phase 6 hard-asserts `schema_version: phase-4-output-v1`.

Update `.cdf.config.yaml` `scaffold:` block's
`last_scaffold.phases_completed` to extend `[…, 4]`.

---

## 3 · Tool-leverage Map (Phase-4 specific)

| Tool | Leverage | Notes |
|---|---|---|
| DS-tokens MCP `list_themes` | ★★★ | Rule A primary — file-derived, always complete. Trust this over enum-gated tools (Rule-B-for-theming) |
| DS-tokens MCP `compare_themes` | ★★ | Diff two modes explicitly — useful for brand-drift drill-downs. Watch for enum-gating |
| DS-tokens MCP `browse_tokens(set="Collection/Mode")` | ★★ | Fallback enumeration when enum-gated tools can't reach a mode. Set-name strings bypass enum restrictions |
| `use_figma` Plugin-JS mode enumeration | ★★ | `figma.variables.getLocalVariableCollectionsAsync()` → `.modes` per collection. Primary source when regime = figma-variables |
| `figma-mcp.get_variable_defs(nodeId)` | ★ | Sample one component to verify which modes actually bind |
| `cdf-mcp.cdf_vocab_diverge` | ✗ | Out of scope — vocab-axis divergence, not theming-mode divergence |
| `Read` on DTCG `$themes.json` | ★★ | Direct parse when no MCP is available; fine as canonical (it's the file) |

---

## 4 · Completion Gates

- [ ] Every theming axis (from Phase 1 §1.5) enumerated with modes list.
- [ ] At least two representations cross-checked where both exist
  (DTCG `$themes.json` + Figma Variable modes). Drift recorded.
- [ ] Rule-B-for-theming applied: `list_themes` trusted over schema
  enums if the DS MCP shows signs of enum-gating.
- [ ] Mode-sparsity computed per multi-mode collection — leaf counts
  per mode in-hand.
- [ ] Component-layer gap check done for every axis with a plausible
  component-layer analogue (typically `device`).
- [ ] Always-on collections distinguished from single-mode axes; User
  consulted when unclear.
- [ ] Typography / Shadow representation-gap recorded if Phase 1 flagged
  the DTCG-vs-Variables count delta.
- [ ] Brand-drift findings seeded with (a) count-delta, (b) per-leaf
  concentration, (c) alias-collapse scan (if aliases were classified
  in Phase 3).
- [ ] `.cdf.config.yaml` `scaffold:` block updated.

---

## 5 · Findings-Seed Candidates

1. **Mode-set drift (DTCG vs Figma)** — e.g. "DTCG `$themes.json`
   declares `Shape: [Round, Sharp, Squared]`; Figma Shape collection
   has only `[Round, Sharp]`." Cluster B.
2. **Brand-drift** — e.g. "Brand-B mode has 384 leaves; Light/Dark
   modes have 387. 3-leaf gap in `color.controls.accent.*`." Cluster B.
3. **Tablet-orphan** — e.g. "Device-axis has 3 modes at token-layer;
   components expose 2." Cluster B.
4. **Typography representation-gap** — e.g. "68 DTCG typography tokens;
   2 Figma Variables. Typography lives as TextStyles." Cluster B.
5. **Shadow representation-gap** — e.g. "14 DTCG shadow tokens;
   0 Figma Variables. Shadow lives as EffectStyles." Cluster B.
6. **Mode-naming casing drift** — e.g. "DTCG `light`, Figma `Light`."
   Cluster B or Cluster Z (housekeeping depending on whether a
   casing-rule is pinned).
7. **DS-tools enum-gating** — e.g. "Tokens MCP `resolve_token` enum
   excludes Brand-B; `browse_tokens(set=...)` works. MCP maintainer
   ticket." Cluster B.
8. **Always-on collection ambiguity** — e.g. "`Typography` has one mode;
   user confirmed always-on." Cluster B — often just a housekeeping
   note, but worth recording to prevent re-litigation.

---

## 6 · Typical Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Trusting schema enums as file truth | "The MCP says 2 semantic modes, but the file has 3" | Rule-B-for-theming — prefer `list_themes` / set-name strings |
| Taking mode-count as mode-sparsity | "Both modes exist, therefore dense" | Count leaves per mode, not just mode presence |
| Conflating always-on with single-mode-axis | `Foundation` listed as a theming axis with one context | Ask User; treat as always-on unless axis is aspirational |
| Skipping TextStyles/EffectStyles | Typography/Shadow coverage looks near-zero | Phase 1 §1.4 should have enumerated both — if it didn't, go back |
| Missing tablet-orphan | Profile declares 3-device support; no component implements it | Step 4.4 cross-check against Phase-1 variant-axes |
| Adding axes based on collection-names alone | `Helpers` promoted to a theming axis because it's a distinct collection | Helpers / Base / Primitives are almost always always-on |
| Not recording mode-name casing | DTCG `light` / Figma `Light` drift goes unflagged | Seed housekeeping finding (§Z) with a casing-rule proposal |

---

## 7 · Subagent Dispatch Template (△ hybrid)

Phase 4 is a hybrid — enumeration is parallelizable, but SoT-decisions
around brand-drift and tablet-orphans need User dialog. The safe pattern:

**Dispatch for the cross-check enumeration:**

```
Agent 1: For each multi-mode collection, browse_tokens(set="Coll/Mode")
         per mode; return leaf-count matrix.
Agent 2: use_figma Plugin-JS: enumerate every VariableCollection + modes;
         sample 3 leaves per mode to verify binding.
Agent 3: Parse DTCG $themes.json; return groups × modes × set-refs.
```

Each agent returns structured YAML. The Master merges and **then** runs
Steps 4.4 (component-layer gap) and 4.5 (brand-drift interpretation) in
main session — those steps generate Findings the User will classify, so
the dialog must stay with the Master.

**Do not dispatch** Steps 4.4, 4.5, 4.7 — they are Rule-E advisor steps.

**Per-agent context budget:** Phase-4 goal + Phase-1 theming-matrix +
output-YAML template only. No full SKILL.md. No writes to
`.cdf.config.yaml`.

---

## 8 · Cross-Reference to Phase 5

The `theming_modifiers` + `component_layer_gaps` flow into Phase 5 two
ways:

- **Focus-strategy identification** — some DSes encode focus as a shape
  mode (`Shape: [Round, Sharp, Focused]`). That's unusual but real;
  Phase 5 needs to know the mode-list to spot it.
- **A11y-defaults `min_target_size`** — if `device` is an axis, the
  size scales per mode. The Profile's `accessibility_defaults` binds a
  token path (e.g. `controls.height.base`) — Phase 5 just needs the
  axis registered here.

Do **not** attempt focus-strategy analysis in Phase 4. Mode-inspection
stays with tokens; focus lives at component + utility-component layer
(Phase 5's Rules F + G territory).
