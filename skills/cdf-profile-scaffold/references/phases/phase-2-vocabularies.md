---
phase: 2
title: Extract Vocabularies
requires: []  # synthesizes from phase-1-output.yaml in-place; no direct shared-doc reads
read_at: n/a
---

# Phase 2 · Extract Vocabularies

**Goal:** Aggregate variant-axes across all components into system-level
vocabularies. Detect clashes, compound-value folding, and property-name
drifts. Propose decompositions — User confirms.

**Predecessor:** Phase 1 completed; `phase_1_output` in-hand (component
inventory + `componentPropertyDefinitions` per COMPONENT_SET).

**Successor:** Phase 3 (Grammars).

**Subagent-fit:** ✗ — this phase is a User-loop. Rule E demands dialog
("which name wins? is this one concept or two?"). Subagents cannot pause.

**Shape authority.** The canonical shape reference for this phase is
the `Vocabularies` fragment of CDF-PROFILE-SPEC — load via
`cdf_get_spec_fragment({ fragment: "Vocabularies" })`. It covers §5
(schema + isolation rule §5.5 + token-key-vs-semantic-API naming §5.6).
Do not read the full monolith when only vocabulary shape is needed.

**Finding-prose contract (Lever 5).** Every cluster A/B/C/D finding this
phase seeds MUST carry three fields beyond `observation`:

- `plain_language` (≤50 words, jargon-free) — what the User would see
  in their DS today, no CDF-spec terminology.
- `concrete_example` — real values from the User's `ds_inventory.*`,
  cited verbatim. Not hypothetical.
- `default_if_unsure: { decision, rationale }` — safe default so the
  User isn't forced to `block` out of uncertainty.

Schema reference: [`templates/seeded-findings.schema.yaml`](templates/seeded-findings.schema.yaml).
Bad/good for this phase:

> **Bad** (CDF-format-speak): *"state-axis folds Validation × hasValue
> × Interaction × Extras into one axis."*
>
> **Good** (DS-architect-speak): *"Dein Text Field zeigt 9 verschiedene
> state-Werte (enabled, hover, pressed, disabled, error, filled,
> filled-hover, filled-disabled, error-placeholder). Das sind eigentlich
> vier Konzepte zusammengeworfen: Interaction, hasValue, Validation,
> Disabled."* + concrete_example pulled from `ds_inventory` for the
> Text Field's actual `propertyDefinitions.state.variantOptions`.

User's session language wins (German if conversation is German).
Decision-quality of Phase 6 depends directly on prose comprehension here.

**No spec citations in `plain_language` (Lever 5.I).** Forbidden:
`§…` references, bare CDF terms (`Profile`, `vocabulary isolation`,
`axis-value collision`, `system-vocabulary`). For *meta* findings
(one cross-referencing another, or one explaining a format
constraint), restate the symptom in DS terms — *what does the User
see in their variants or values?* — and keep mechanism prose in
`observation` / `sot_recommendation`. Phase-2's commonest leak is
"`§5.5` vocabulary isolation" inside the user-facing prose; rewrite
around the duplicate-value the User sees instead.

**No new tool-calls.** If Phase 1 captured `propertyDefinitions` per
COMPONENT_SET (= axis names + VARIANT `variantOptions` + BOOLEAN/TEXT
metadata), Phase 2 is pure synthesis. If Phase 1 only captured axis
*names* (the common mistake — `Object.keys()` on the property definitions),
**go back and run Phase 1 Pass-1.5** before continuing. Optionally
`cdf_vocab_diverge` for machine-assisted overlap matrix.

---

## 1 · Methodology

### Step 2.0 — Locate the Phase-1 input (tier-aware)

Phase-1 leaves a structured artefact Phase 2 iterates over. The file and
the access path differ by tier; both expose the same underlying
component-set entries.

| Tier | Phase-1 artefact | Access path for `entries[*]` |
|---|---|---|
| T1 / T2 | `<cwd>/.cdf-cache/phase-1-output.yaml` (version-tagged) | `.ds_inventory.component_sets.entries` |
| T0 | in-LLM-context `phase_1_output` object | `.ds_inventory.component_sets.entries` |

**On T1/T2: assert the schema version BEFORE reading anything else.**

```bash
yq '.schema_version' <cwd>/.cdf-cache/phase-1-output.yaml
# Expected: phase-1-output-v1
```

If the value does NOT equal `phase-1-output-v1`, **hard-fail** — do not
attempt to interpret the file. Ask the User to re-run Phase 1 with the
current skill version (old YAMLs can carry fields whose meaning has
shifted silently; guessing here produces silent drift). `extract-to-yaml.sh`
stamps the version deterministically — a mismatch means the artefact
pre-dates the current schema.

**Fallback (tier detection):** if `phase-1-output.yaml` is absent but
`phase-1-notes.md` is present, you are on the T0 path — continue from the
in-context `phase_1_output` object as before. Do not synthesize a YAML
from the notes; T0 and T1 carry-forward artefacts are first-class
alternatives, not equivalents.

### Step 2.0-bis — Mechanical aggregation (T1/T2 only)

On the T1/T2 path, a handful of detections are deterministic over
`phase-1-output.yaml.ds_inventory.component_sets.entries[]` — running
them via inline `jq` saves the LLM from re-deriving them via prose
synthesis (and seeds `phase-2-output.yaml` directly).

**T0 path:** skip this step. T0 has no structured carry-forward; jump
to §2.1 and continue with prose-aggregation.

Set the input path once:

```bash
P1=<cwd>/.cdf-cache/phase-1-output.yaml
```

The blocks below each return JSON. Capture the output as you go; the
final `Step 2.last` emits everything into a single `phase-2-output.yaml`.

#### 2.0-bis.1 — `axis_inventory` (every axis, every component)

```bash
yq -o=json '.ds_inventory.component_sets.entries' "$P1" | jq -s '
  .[0] |
  [ .[] | .name as $c |
    (.propertyDefinitions // {} | to_entries) |
    map({component: $c, axis: .key, type: .value.type,
         options: (.value.variantOptions // [])}) |
    .[]
  ] |
  group_by(.axis) |
  map({
    axis: .[0].axis,
    type: .[0].type,
    components_using: length,
    all_options: ([.[] | .options[]] | unique),
    per_component: map({component, options})
  })
'
```

Returns the array that goes into `axis_inventory` verbatim. **LLM
MUST NOT edit individual entries** — this is the contract (see emit
step below).

#### 2.0-bis.2 — `§Z-compound-value-fold` candidates

```bash
yq -o=json '.ds_inventory.component_sets.entries' "$P1" | jq -s '
  .[0] |
  [ .[] | .name as $c |
    (.propertyDefinitions // {} | to_entries) |
    map(select(.value.type == "VARIANT")) |
    map({component: $c, axis: .key,
         compounds: ((.value.variantOptions // []) | map(select(test("[-+]"))))}) |
    map(select(.compounds | length > 0)) |
    .[]
  ] |
  group_by(.axis) |
  map({axis: .[0].axis,
       components_with_compounds: length,
       sample_compounds: ([.[] | .compounds[]] | unique | .[0:8])})
'
```

If non-empty: seed `§Z-compound-value-fold` finding (cluster `Z`) per
the schema. `instances` = result above; `observation` = "<N> axes
contain compound values across <M> components".

#### 2.0-bis.3 — `§Z-casing-drift` candidates

```bash
yq -o=json '.ds_inventory.component_sets.entries' "$P1" | jq -s '
  .[0] |
  [ .[] | (.propertyDefinitions // {} | keys[]) ] |
  group_by(ascii_downcase) |
  map(select((unique | length) > 1)) |
  map({lower: (.[0] | ascii_downcase), variants: unique})
'
```

If non-empty: seed `§Z-casing-drift` (cluster `Z`).

#### 2.0-bis.4 — `§Z-generic-name` candidates

```bash
yq -o=json '.ds_inventory.component_sets.entries' "$P1" | jq -s '
  .[0] |
  [ .[] | .name as $c |
    (.propertyDefinitions // {} | keys[]) |
    select(test("^Property [0-9]+$")) |
    {component: $c, axis: .}
  ]
'
```

If non-empty: seed `§Z-generic-name` (cluster `Z`).

#### 2.0-bis.5 — `§B1` state-axis overload candidates

```bash
yq -o=json '.ds_inventory.component_sets.entries' "$P1" | jq -s '
  .[0] |
  [ .[] |
    select(.propertyDefinitions.state? and .propertyDefinitions.interaction?) |
    {component: .name,
     state_values: (.propertyDefinitions.state.variantOptions // []),
     interaction_values: (.propertyDefinitions.interaction.variantOptions // [])}
  ]
'
```

If non-empty: seed `§B1` (cluster `C` — Component-Axis Consistency)
with `kind: state-axis-decomp` decomposition_proposal.

#### 2.0-bis.6 — `§B2` property-name drift candidates

Heuristic: pairs of axes whose option-sets overlap with ≥ 2 shared
non-boolean options AND > 50% overlap ratio (Jaccard). Pure boolean
axes (`{false, true}`) are excluded — every boolean axis would
otherwise pair-match every other boolean axis, swamping the signal
with noise.

```bash
yq -o=json '.ds_inventory.component_sets.entries' "$P1" | jq -s '
  .[0] |
  [ .[] | (.propertyDefinitions // {} | to_entries) |
    map(select(.value.type == "VARIANT")) |
    map({axis: .key, opts: (.value.variantOptions // [] | map(ascii_downcase) | unique)}) |
    .[]
  ] |
  group_by(.axis) |
  map({axis: .[0].axis, all_opts: ([.[] | .opts[]] | unique)}) |
  map(select((.all_opts | sort) != ["false", "true"])) |    # skip pure-boolean axes
  . as $axes |
  [ range(0; $axes | length) as $i |
    range($i+1; $axes | length) as $j |
    ($axes[$i].all_opts) as $a |
    ($axes[$j].all_opts) as $b |
    ([$a[], $b[]] | group_by(.) | map(select(length > 1)) | length) as $shared |
    ($a + $b | unique | length) as $union |
    select($shared >= 2 and ($shared / $union) > 0.5) |
    {axis_a: $axes[$i].axis, axis_b: $axes[$j].axis,
     overlap_ratio: ($shared / $union),
     shared_options: ([$a[], $b[]] | group_by(.) | map(select(length > 1)) | map(.[0]))}
  ]
'
```

If non-empty: seed `§B2` (cluster `C`) per pair, with
`kind: property-name-drift` decomposition_proposal.

**Note:** drift candidates that are also picked up by §Z-casing-drift
(e.g. `Icon`/`icon`) will appear in both — that's expected. Keep both
findings: housekeeping (rename) ≠ architectural (consolidate).

#### 2.0-bis.7 — `§Z-typo` (optional / LLM fallback)

`jq` has no native edit-distance operator. If you want a mechanical
typo-detector, port the heuristic to `python -c '...'` or skip and
let §2.4 catch typos during prose review (the `fillled-error` /
`_verficiation-` patterns surface naturally to the LLM eye). The
schema reserves `§Z-typo` either way.

### Step 2.1 — Collect axes across all components

From the component-set entries resolved in Step 2.0
(`entries[*].propertyDefinitions`), build a master table. For each
VARIANT-type property, `variantOptions` is the raw value set; for
BOOLEAN/TEXT properties, record the `type` + `defaultValue`.

| Axis name (raw) | Component | Values |
|---|---|---|
| `type` | Button | primary, brand, secondary, tertiary, tertiaryWithoutPadding |
| `appearance` | Warning Button | primary, secondary, tertiary |
| `hierarchy` | Segmented Control | primary, secondary |
| `state` | Button | enabled, hover, pressed, disabled, pending |
| `state` | Text Field | enabled, hover, pressed, disabled, error, filled, filled-hover, … |
| `size` | Button | default, compact, dense |
| `selected` | Radio Button | false, true |
| `type` | Checkbox | unselected, selected, indeterminate |

Do this comprehensively — even 30-component DSes usually surface 3–5
property-name drifts.

### Step 2.2 — Axis-aggregation heuristics

**Group raw axis-names by concept, not by string-match.** Concept-signals:

| Concept | Raw names commonly used | Semantic test |
|---|---|---|
| **hierarchy** (visual emphasis) | `type`, `appearance`, `hierarchy`, `variant`, `emphasis`, `style` | Values look like `primary` / `secondary` / `tertiary` — ranked by emphasis |
| **intent** (semantic meaning) | sometimes mixed INTO hierarchy; sometimes `intent`, `tone`, `severity` | Values look like `info` / `success` / `warning` / `danger` / `negative` |
| **size** | `size`, `density`, `scale` | Values `small` / `default` / `large` OR `compact` / `default` / `spacious` |
| **state** (runtime) | `state`, `status` | Values `enabled` / `hover` / `pressed` / `disabled` / `focused` |
| **selected** | `selected`, `checked`, `active`, `on` | Boolean semantics regardless of name |
| **expanded** | `expanded`, `open`, `collapsed` | Boolean-ish; may include `opening` / `closing` transitional |
| **hasValue** / filledness | `empty` / `filled` in state-axis; `hasValue`; `populated` | Is there user-entered content? |
| **progress** | `idle` / `pending` / `loading` / `completed` | Async-op lifecycle |

After grouping, the **system-level vocabularies** fall out of Step 2.2.

### Step 2.3 — Property-name drift detection (Rule E opportunity)

When the same concept appears under multiple raw names, propose unification:

```markdown
## §N · Property-name drift: hierarchy

**Observation:**
- Button uses `type` with values [primary, brand, secondary, tertiary, …]
- Warning Button uses `appearance` with [primary, secondary, tertiary]
- Segmented Control uses `hierarchy` with [primary, secondary]

**Discrepancy:** Same concept (visual emphasis), three names.

**Source-of-Truth-Recommendation:** Unify to `hierarchy`. Rationale:
(a) the name matches the CDF conventional term; (b) it's already used by
one component; (c) `type` is dangerously overloaded in most DSes.

**User-Decision:** _filled in Phase 6_
```

**Seed as finding immediately** — don't defer to Phase 6 just because it's
premature. Phase 6 is classification, not collection.

### Step 2.4 — State-axis decomposition (the headline Advisor moment)

The `state` axis almost always folds multiple orthogonal concepts. From the
v1.4.0 walkthrough, ~8 independent dimensions commonly hide inside `state`:

| # | Dimension | Typical values | Classification |
|---|---|---|---|
| 1 | **Interaction** (base) | hover, pressed, (focused — but see Rule F) | runtime-transient |
| 2 | **Base-idle-label** | enabled OR active OR default (pick one) | naming |
| 3 | **Disabled** | disabled | boolean, orthogonal |
| 4 | **Validation** | error, error-placeholder, error-visible, error-filled-*, fillled-error (typo) | orthogonal or state-overlay |
| 5 | **hasValue** | empty, filled (often folded as filled-hover, filled-disabled) | boolean, orthogonal |
| 6 | **Expansion** | closed, open, open-hover, open-pressed | boolean × interaction |
| 7 | **Progress** | idle, pending, loading, completed, success | async lifecycle |
| 8 | **Selection** (as state!) | active = selected | boolean — but often named `active` |

**Decomposition proposal template:**

```markdown
## §N · State-axis decomposition

**Observation:** Across 27 components inspected, 21+ distinct state-vocabs
observed. Representative examples:
- Button: [enabled, hover, pressed, disabled, pending]
- Text Field: [enabled, hover, pressed, disabled, error, filled,
  filled-hover, filled-disabled, error-placeholder]
- Combo Box: [enabled, hover, pressed, disabled, open, open-hover,
  open-pressed, error, filled-error, fillled-error]  ← typo

**Discrepancy:** The single `state` axis folds at least 5 orthogonal
dimensions: Interaction, hasValue, Validation, Expansion, Progress.
Compound values (filled-hover, error-filled-*) are the fold's symptom.

**Source-of-Truth-Recommendation:** Decompose into orthogonal axes:
- `state: [enabled, hover, pressed, disabled]` (Interaction + Disabled)
- `hasValue: boolean` (was compound `filled-*`)
- `validation: [none, error, success]` (was compound `error-*`)
- `expanded: boolean` (was compound `open-*`)
- `progress: [idle, pending, loading, completed]` (where applicable)

This reduces Text Field state-matrix from 9 compound values to 4 × 2 × 3 =
24 orthogonal combinations — most empty (good, sparsity is information),
a few actually rendered.

**User-Decision:** _filled in Phase 6 — likely a DS-level refactor decision_
```

**Reference pattern:** Formtrieb DS models this correctly by default —
`hasValue` as boolean, `state` as pure runtime. The DS-specific Profile YAML
serves as a worked example once one exists; until then, foreign-DS profiles
in `cdf/examples/` (e.g. `shadcn`, `primer`, `material3`) also exhibit the
orthogonal pattern.

### Step 2.5 — Type-overloading detection

The axis name `type` often carries **multiple semantic loads** across
different components:

- hierarchy (Button: type = primary/secondary)
- selection modeling (Checkbox: type = selected/unselected/indeterminate)
- content-slot mode (TabItem: type = withIcon/withoutIcon)

**Propose rename per component** — don't touch `type` globally (it's too
entrenched). Finding seeds the User's decision.

### Step 2.6 — Selection-modeling inconsistency

When two components model the same selection concept differently:

- Checkbox: `type: [unselected, selected, indeterminate]` (variant-based, 3 values)
- Radio Button: `selected: [false, true]` (boolean, 2 values)

…that's a finding. Recommend: `selected: boolean` base + orthogonal
`indeterminate: boolean` (tristate pattern). Seed finding with SoT rationale.

### Step 2.7 — `active` ambiguity (common anti-pattern)

When `active` means **two different things** across DS:

- Base-idle-label: Destructive Button state = active (alt-name for enabled)
- Selection: Breadcrumb-item state = active (alt-name for selected)

Recommend: rename selection-`active` → `selected: true`; (preferably) also
rename base-`active` → `enabled` DS-wide. Seed finding — this is a
rename-wave and non-trivial.

### Step 2.8 — Property-explosion detection

When a property value encodes a second orthogonal property:

- `type: [primary, brand, secondary, tertiary, tertiaryWithoutPadding]`

…the last value = `type: tertiary` + `padding: false`. Recommend
decomposition into `type: tertiary` + boolean `padding: [default, none]`.
Seed finding.

### Step 2.8.5 — Slot-primitive detection (from INSTANCE_SWAP `defaultValue`)

When many components have INSTANCE_SWAP properties whose `defaultValue`
points at the **same standalone COMPONENT id** (e.g. 20+ components all
default their `footer-slot` / `menu-slot` / `content-slot` / `image-slot`
to `15591:17447`), that target component is a **first-class slot primitive**
— a convention, not an oversight. The DS uses a shared "empty slot" as the
canonical stand-in for user-replaceable content.

**Detection:** scan `phase_1_output.ds_inventory.component_sets.entries[*]
.propertyDefinitions` for entries where `type === "INSTANCE_SWAP"`; group
by `defaultValue`; any id shared by ≥ 3 components is a slot-primitive
candidate.

**Implication for the Profile:**
- The target standalone should be classified as `categories.primitives` in
  the Profile (or whatever the DS's primitive-category is).
- Phase 5 should treat INSTANCE_SWAP slots + their default primitives as
  a single composition pattern, not as individual bindings.
- Record as a Finding with cluster `A · Token-Layer Architecture` or
  `C · Component-Axis Consistency` depending on whether the slot pattern
  carries token-layer weight.

**Do not treat the shared defaultValue as a "duplicate" or "clash".** It
is a named pattern.

### Step 2.9 — Compound-value folding (the textbook Rule E moment)

Any value-name with a separator inside suggests folding:

- `filled-hover` = hasValue × Interaction
- `error-filled-counter` = Validation × hasValue × Extras
- `open-pressed` = Expansion × Interaction

For each, write a finding with:
- the folding axes named explicitly
- the orthogonal decomposition proposed
- the matrix-shrink implication

The mechanical seeder (Step 2.0-bis.2) already produced the
candidate list — review it for false positives (e.g. `top-left`
position values are compound-named but architecturally atomic) and
seed the meaningful cases as `kind: compound-value-folding`
decomposition_proposals.

### Step 2.9.5 — Vocab-isolation pre-check (post-synthesis)

**Why:** Profile §5.5 Vocabulary Isolation Rule warns when the same
value appears in more than one vocabulary (`none` across
`intent`/`validation`/`padding`/`icon`, `base` across `emphasis`/
`size`/`density`, `"false"`/`"true"` across every boolean axis). The
warnings surface at `cdf_validate_profile` time — late, advisory, and
architecturally significant on meaningful-concept collisions. A
mechanical detector here seeds them as Phase-6 findings so the User
decides the convention **once** (accept boolean idiom, rename
colliding concept, or accept-as-divergence) instead of watching 15
pairwise warnings scroll by at emit-time. Real-run baseline
(2026-04-23): 15 Profile warnings collapse to 5 architectural
findings.

**Placement note.** Unlike the §2.0-bis.* jq seeders (which run on
raw `phase-1-output.ds_inventory.component_sets.entries`), this
check operates on the **LLM-synthesized `system_vocabularies`** from
§2.2. Run it AFTER §2.2 grouping is in hand and BEFORE §2.last emit.

**Input shape handling.** `system_vocabularies` in `phase-2-output.yaml`
carries two shapes — bare-list (`hierarchy: [brand, primary, ...]`)
and scalar-boolean-marker (`selected: boolean`, expanded to
`["false", "true"]` at Profile-emit time per §7.1.5 pitfall ★2). The
pipeline handles both; entries whose value is neither array nor the
literal string `"boolean"` are skipped.

```bash
echo '<paste the system_vocabularies block (or pipe from a scratch file)>' | \
  yq -o=json '.' | jq '
    to_entries |
    map(
      if (.value | type) == "array" then
        {vocab: .key, values: .value}
      elif (.value | type) == "string" and .value == "boolean" then
        {vocab: .key, values: ["false", "true"]}
      else
        empty
      end
    ) |
    [ .[] | .vocab as $v | .values[] | {vocab: $v, value: .} ] |
    group_by(.value) |
    map(select(length > 1)) |
    map({value: .[0].value, vocabs: (map(.vocab) | unique | sort)})
  '
```

Each returned element is one collision across 2+ vocabularies. Seed
per element as follows:

| Collision kind | Cluster | Id | Title |
|---|---|---|---|
| value is `"false"` or `"true"` (boolean-axis convention) | `Z` | `§Z-vocab-overlap-<value>` | `"Boolean-axis value '<value>' spans N vocabularies"` |
| any other value (semantic-concept collision) | `C` | `§Z-vocab-overlap-<value>` (id-prefix retained by convention; cluster discriminates) | `"Concept-collision: value '<value>' spans N vocabularies"` |

**SoT-recommendation per case:**

- **Boolean-axis case** (Z): "Accept as DS-wide convention — every
  boolean vocab reuses `"false"`/`"true"` and that is the standard
  idiom. Profile §5.5 isolation is advisory, not normative for
  boolean axes. User-Decision typically `adopt-as-is` or `drop`."
- **Concept collision** (C): "Per Profile §5.5, consider renaming
  one side so axis-bindings stay unambiguous (e.g.
  `validation.none` → `validation.ok`, `intent.none` →
  `intent.default`, `size.base` / `density.base` → `size.medium` /
  `density.medium`). If the collision is architecturally
  meaningful and intentional, `accept-as-divergence`. Otherwise the
  rename closes N future vocab-isolation warnings in one go."

Example finding (from a clean-run on an MVP test DS):

```yaml
- id: §Z-vocab-overlap-none
  cluster: C
  title: "Concept-collision: value 'none' spans 2 vocabularies"
  observation: "'none' appears in: intent, validation."
  threshold_met: value appears in ≥2 system_vocabularies entries
  sot_recommendation: >
    Per Profile §5.5, consider renaming one side — e.g.
    validation.none → validation.ok, or intent.none →
    intent.default — so axis-bindings stay unambiguous. If the
    collision is architecturally meaningful (same 'no signal'
    semantic on both axes), accept-as-divergence.
  instances: [intent, validation]
  user_decision: pending

- id: §Z-vocab-overlap-false
  cluster: Z
  title: "Boolean-axis value 'false' spans 5 vocabularies"
  observation: "'false' appears in: expanded, hasValue, indeterminate, open, selected."
  threshold_met: value appears in ≥2 system_vocabularies entries
  sot_recommendation: >
    Standard boolean-axis idiom — every boolean vocab reuses
    'false'/'true'. Profile §5.5 isolation is advisory, not normative
    for booleans. Typically adopt-as-is.
  instances: [expanded, hasValue, indeterminate, open, selected]
  user_decision: pending
```

Append these to `seeded_findings[]` in the §2.last emit (same list
as `§B1` / `§B2` / `§Z-compound-value-fold` etc.). Don't emit them
separately.

### Step 2.9.6 — Vocab near-miss lint (post-synthesis)

**Why:** §2.9.5 catches the same value across multiple axes
(value-collision). It does NOT catch **different but synonymous**
values across vocabs (`leading` vs `left`), **near-synonym axis names**
(`state` vs `interaction`), or **family-overlap** axes (`type` vs
`hierarchy` vs `emphasis`). The L2A near-miss lint covers those gaps —
empirically validated against a 2026-04-25 real-DS run, with a
7-pattern catalog and a 3-pattern sentinel-suppression whitelist.
Catalog is canonical in
[`phase-7-emit-validate.md` §7.1.6](./phase-7-emit-validate.md#step-716--vocabulary-near-miss-catalog--pre-emit-verification);
this section runs the detector at the right spot in the Phase-2
pipeline.

**Placement note.** Same constraint as §2.9.5 — operates on the
**LLM-synthesized `system_vocabularies`** from §2.2, not raw walker
data. Run AFTER §2.9.5 (vocab-isolation pre-check) so both checks
share the same input snapshot.

**Run the detector.** Pipe the synthesized `system_vocabularies` JSON
to the lint script; it emits a JSON-array of seeded-finding entries:

```bash
# Path-form (reads .system_vocabularies from a phase-2-output.yaml-shape file):
$ROOT/scripts/lint-vocab-near-miss.sh <ds-test-dir>/.cdf-cache/phase-2-output.yaml

# Stream-form (synthesized block as JSON on stdin — preferred during
# the §2.last assembly when phase-2-output.yaml hasn't been written yet):
echo '<system_vocabularies as JSON>' | $ROOT/scripts/lint-vocab-near-miss.sh -
```

Output shape: a JSON array of seeded-finding entries (per
[`templates/seeded-findings.schema.yaml`](./templates/seeded-findings.schema.yaml)).
Each carries `id` of the form `§Z-vocab-near-miss-<pattern>`, the
appropriate `cluster` (`C` for genuine near-misses, `Z` for
boolean-idiom acceptance), `plain_language` per L5.I rules,
`default_if_unsure.{decision,rationale}` for the AskUserQuestion
preselect, and `kind: vocab-near-miss` for the §6.4-ter dialog
matcher.

Empty array on no detections — usually means the DS already resolved
the canonical pairs upstream (e.g. post-rename) or has no axes from
the catalog's coverage. Both are valid; the lint reports what it
sees, not what it expected.

**Sentinel-idiom suppression** — the lint deliberately does NOT
double-emit on `none`/`base`/`error`-`success` cross-vocab patterns;
those are §2.9.5 territory (cluster C concept-collisions). See
§7.1.6's whitelist table for the rationale.

**Append to `seeded_findings[]`.** Like §2.9.5, the near-miss findings
fold into the `seeded_findings[]` array of the `phase-2-output.yaml`
emit. Do NOT emit a separate file.

```bash
# In the §2.last assembly (jq -n --argjson findings ...):
NEAR_MISS=$($ROOT/scripts/lint-vocab-near-miss.sh -)  # JSON array
EXISTING_FINDINGS=$(... §2.9.5 + §B1 + §B2 + ... seeds as JSON ...)
ALL_FINDINGS=$(jq -n \
  --argjson a "$EXISTING_FINDINGS" \
  --argjson b "$NEAR_MISS" \
  '$a + $b')
# Then pass $ALL_FINDINGS into the §2.last `--argjson findings ...` slot.
```

**Test coverage.** The detector ships with a self-test:
`scripts/test/lint-vocab-near-miss.test.sh` (24 assertions across 7
test cases — synthetic 7+3 spec, schema fidelity, L5.I prose rule,
id-uniqueness, real-data integration). Run before relying on the
lint in production.

### Step 2.last — Emit `phase-2-output.yaml` (T1/T2 only)

Assemble the structured artefact and write it. T0 path: skip — emit
`<ds>.phase-2-notes.md` per the legacy convention instead.

Build the file via `jq` (JSON-side, where `--argjson` works) and pipe
through `yq -P -o=yaml` for pretty YAML — `mikefarah/yq` has no
`--argjson` equivalent, so this round-trip is the cleanest emit.

```bash
OUT=<ds-test-dir>/.cdf-cache/phase-2-output.yaml
mkdir -p "$(dirname "$OUT")"
jq -n \
  --argjson axis_inv      '<paste from Step 2.0-bis.1>' \
  --argjson sysvocab      '<system_vocabularies block from §2.2>' \
  --argjson clash         '<clash_matrix from §2.3>' \
  --argjson proposals     '<decomposition_proposals from §2.4–§2.9>' \
  --argjson findings      '<seeded_findings — mechanical seeds + LLM additions>' \
  '{
    schema_version: "phase-2-output-v1",
    generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    generated_by: { source_phase_1: "phase-1-output.yaml", tier: "T1" },
    axis_inventory: $axis_inv,
    system_vocabularies: $sysvocab,
    clash_matrix: $clash,
    decomposition_proposals: $proposals,
    seeded_findings: $findings,
    interpretation: [],
    phase_3_inputs: { system_vocabularies_snapshot: $sysvocab }
  }' | yq -P -o=yaml > "$OUT"
```

Then verify the schema-version round-trip:

```bash
yq '.schema_version' "$OUT"
# Expected: phase-2-output-v1
```

**LLM review contract (what to do AFTER `phase-2-output.yaml` is written):**

1. `Read` the file. Treat the mechanical fields as authoritative.
2. **Walker-owned (do NOT edit):** `schema_version`, `generated_at`,
   `generated_by`, `axis_inventory[]` (every entry, every field).
   Re-running the jq snippet must produce identical output.
3. **Seeded findings rule (mirror of Phase-1 §8.1.3):** Mechanical
   seeds in `seeded_findings[]` (`§Z-compound-value-fold`,
   `§Z-casing-drift`, `§Z-generic-name`, `§B1`, `§B2`) stay as
   emitted; LLM only fills `sot_recommendation` if the heuristic was
   incomplete on its own and only fills `user_decision` during Phase 6.
   Additional findings the LLM spots that the jq pipeline cannot
   detect (selection-inconsistency, active-ambiguity, type-overloading,
   slot-primitive, property-explosion) are appended to
   `seeded_findings[]` as fresh entries with their own ids.
4. **LLM-owned:** `system_vocabularies` (the Step 2.2 grouping),
   `clash_matrix`, `decomposition_proposals[*].rationale` and
   `decomposition_proposals[*].proposed_replacement`,
   `interpretation[]`. These are pure synthesis output.
5. **`interpretation:` is the sanctioned free-form zone.** Anything
   architectural worth surfacing for Phase 6 that doesn't fit a slot
   goes here. Keep tight — restating walker fields is noise.
6. Phase 6 hard-asserts `schema_version: phase-2-output-v1` and walks
   each `seeded_findings[]` entry through AskUserQuestion per Rule-E
   COVERAGE.

---

## 2 · Output (carry-forward to Phase 3)

**T1/T2 path:** the artefact is `<ds-test-dir>/.cdf-cache/phase-2-output.yaml`,
shape per `references/phases/templates/phase-2-output.schema.yaml` and
emitted by Step 2.last. Phase 3 consumes it via the version-tag-asserting
read pattern (see Phase-3 §1 Step 3.0).

The structured artefact replaces the previous two-artefact pattern
(scratch markdown + findings-doc appendix). Findings live in
`seeded_findings[]`; Phase 6 reads the union across phases. The
`system_vocabularies` block — DS-meeting-ready freeze candidate — is
embedded in `phase_3_inputs.system_vocabularies_snapshot`; the
DS-meeting view is rendered from `findings.yaml` by `cdf_render_findings`
(or the deprecated `scripts/render-findings.sh`) in Phase 6 (Lever-2A
Scope-A keystone — see Phase-6 doc §1).

**T0 path (legacy):** emit `<ds-test-dir>/<ds>.phase-2-notes.md` with
`system_vocabularies`, `clash_matrix`, and finding seeds inline as
markdown prose. Phase 6's markdown-fallback consumer handles it. T0
keeps the previous two-artefact pattern; the YAML pivot is T1/T2-only
because T0 has no upstream `phase-1-output.yaml` to seed off.

### 2.1 — System-vocabularies block (proposed)

Whichever path emitted: the vocabulary set follows the same shape.
Frozen only after Phase-6 User decisions; Phase 3 may still add axes
from token-grammar.

```yaml
system_vocabularies:
  hierarchy: [brand, primary, secondary]      # unified from {type, appearance, hierarchy}
  intent: [none, information, warning, danger, success]
  size: [default, compact]
  density: [low, base, large]                  # if distinct from size — row-height semantic
  state: [enabled, hover, pressed, disabled]   # decomposed base-state
  selected: boolean
  indeterminate: boolean                       # Checkbox tristate companion
  expanded: boolean
  validation: [none, error, success]
  hasValue: boolean
  progress: [idle, pending, loading, completed]
  orientation: [horizontal, vertical]
  # …add axes that surfaced in this DS only — don't invent universals
```

---

## 3 · Completion Gates

- [ ] Every COMPONENT_SET's axes accounted for in aggregation table.
- [ ] Each raw axis-name mapped to a concept (hierarchy / intent / size /
  state / selected / expanded / hasValue / progress / other).
- [ ] Property-name drifts surfaced as findings (at least one usually exists).
- [ ] State-axis decomposition proposal drafted (compound values broken
  apart into orthogonal dimensions).
- [ ] `active` ambiguity check done.
- [ ] Selection-modeling consistency check done.
- [ ] Every finding has Observation + Discrepancy + SoT-Recommendation
  filled; User-Decision empty for Phase 6.
- [ ] User has been shown the decomposition proposals and acknowledged
  (even "I'll think about it"); no silent assumptions.

---

## 4 · Typical Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Accepting compound-values as atomic | "state: filled-hover" kept as one concept | Detect separators — decomposition (§2.9) |
| Trusting axis-name as concept | Treating `type` and `hierarchy` as different concepts | Concept-signals (§2.2) over name-matching |
| Silent selection-modeling acceptance | Checkbox 3-variant + Radio 2-bool both adopted as-is | Step 2.6 checks them pairwise |
| Unilaterally renaming without User dialog | Deciding `active → selected` without asking | Rule E — recommend, don't decide |
| Over-decomposing | Splitting every axis into atoms the DS doesn't actually use | Sparsity check at Phase 3 will correct, but try not to over-propose here |
| Missing the typo flag | `fillled-error` accepted into vocab | Scan for typos in axis values + component names — they frequently hide in plain sight (e.g., triple-l `fillled-`, missing-i `_verficiation-`) |

---

## 5 · Anti-Patterns to Name in Findings

Use these exact labels — they make the Findings-Doc scannable:

- **property-name-drift** — same concept, different names across components
- **state-axis folding** — multiple concepts compressed into one axis
- **compound-value folding** — cartesian product of axes encoded as joined strings
- **ambiguous-name** — single name carries ≥ 2 meanings (`active`)
- **property-explosion** — special-case value encodes a second property
- **modeling-inconsistency** — same concept, different cardinality/shape
- **intent-emphasis mixing** — hierarchy vocab containing both emphasis AND intent

---

## 6 · Cross-Reference to Phase 3

The **unified vocabularies** from Phase 2 feed Phase 3's path-shape matching.
Specifically:

- `system_vocabularies.hierarchy` becomes a position-candidate in the
  `color.controls.{hierarchy}.{element}.{state}` grammar.
- `system_vocabularies.state` becomes a position-candidate in the same.
- Cross-check: every vocabulary value in Phase 2 should appear either as a
  token-path segment (Phase 3) or as a variant-only value (annotated as
  such). Orphans are findings.

Do not attempt this cross-check yet — it's Phase 3's job. Just make sure
the vocab-set is complete before advancing.
