# Phase 5 · Interaction Patterns + A11y Defaults

**Goal:** Classify each component by the interaction pattern(s) it
implements; derive the DS's focus-strategy, A11y defaults, and
keyboard-binding conventions. This is where the utility-component
classification from Phase 1 pays off — without Rule F, focus design is
routinely mis-called "absent."

**Predecessor:** Phase 4 (`theming_modifiers` + `component_layer_gaps`
in-hand). Phase 1 `standalone_components` classification (Utility /
Documentation / Widget / Asset) is load-bearing for this phase.

**Successor:** Phase 6 (Findings + Classify).

**Subagent-fit:** ✗ — this is a User-dialog phase. The Focus-Ring
correction (a standalone utility-component invisible from variant-axis
analysis) was the field observation that made Rule F exist; without
User confirmation, a scaffold will silently declare "no focus design"
for an entire class of DSes. Stay in main session.

**Shape authority.** Two fragments cover this phase:

- `cdf_get_spec_fragment({ fragment: "InteractionPatterns" })` — §10
  (patterns + reserved-validation §10.8).
- `cdf_get_spec_fragment({ fragment: "AccessibilityDefaults" })` — §11
  (focus_ring, min_target_size, contrast_requirements, keyboard_defaults,
  category_defaults).

Do not read the full monolith when only one sub-concept applies.

**Finding-prose contract (Lever 5).** Every cluster A/B/C/D finding this
phase seeds MUST carry `plain_language` (≤50 words, jargon-free),
`concrete_example` (real component / interaction names from the User's
DS, cited verbatim), and `default_if_unsure: { decision, rationale }`.
Schema: [`templates/seeded-findings.schema.yaml`](templates/seeded-findings.schema.yaml).

> **Bad** (CDF-format-speak): *"Focus-strategy classifies as utility-
> component composition (Rule F) rather than interaction-pattern variant;
> token_layer.focus_ring shows non-uniform binding across categories."*
>
> **Good** (DS-architect-speak): *"Statt eine Focus-Variante in jedem
> Component zu definieren, hat dein DS einen separaten 'Focus Ring'
> Component der per Composition über andere gelegt wird (wie Buttons,
> Inputs, Tabs). Das ist ein gültiges Pattern (Material 3 macht es
> ähnlich), aber CDF empfiehlt es explizit zu deklarieren statt
> implizit zu lassen."* + concrete_example citing the actual Focus
> Ring component name from `phase_1_output.standalone_components.utility`.

User's session language wins. Decision-quality of Phase 6 depends
directly on prose comprehension here.

**No spec citations in `plain_language` (Lever 5.I).** Forbidden:
`§…` references, bare CDF terms (`interaction pattern`, `utility-
component composition`, `token_layer.<X>`, `pattern-with-no-grammar`,
Rule-letter callouts like "Rule F"). Phase-5's commonest leak is
"focus-strategy classified as utility-component composition (Rule F)"
inside the user-facing prose; rewrite around the standalone Focus
Ring component the User can see in their library, and keep the
classification rationale in `observation` / `sot_recommendation`.

---

## 1 · Methodology

### Step 5.0 — Locate Phase-4 input (tier-aware)

Phase 4 leaves a structured artefact Phase 5 iterates over. Path differs by tier.

| Tier | Phase-4 artefact | Access path |
|---|---|---|
| T1 / T2 | `<cwd>/.cdf-cache/phase-4-output.yaml` (version-tagged) | `.phase_5_inputs.theming_axes_snapshot` |
| T0 | `<cwd>/<ds>.phase-4-notes.md` (markdown) | inline theming_modifiers block |

**On T1/T2: assert the schema version BEFORE reading anything else.**

```bash
yq '.schema_version' <cwd>/.cdf-cache/phase-4-output.yaml
# Expected: phase-4-output-v1
```

If the value does NOT equal `phase-4-output-v1`, **hard-fail** — do not
attempt to interpret the file. Ask the User to re-run Phase 4. Phase 4's
emit step (`phase-4-theming.md` §Step 4.last) stamps the version
deterministically.

### Step 5.1 — Ingest documentation-surfaces FIRST (Rule G)

**Before inferring anything** from variant-axes, consume what the DS
author already documented. From Phase 1 §1.6:

- Doc-frames (`_doc-content` / `_component-docu` / similar) — if present,
  extract their content per COMPONENT_SET. Look specifically for:
  - "Focus Style" / "Focus Strategy" sections
  - "Accessibility" / "A11y" notes
  - "Keyboard" / "Interaction" tables
  - "Best Practices" callouts (often carry ARIA-role guidance)
- Figma Component Descriptions — check each COMPONENT_SET's `description`
  field. Authors often name the ARIA-role, focus behaviour, or
  interaction-pattern here in one or two sentences.
- External docs (User-pointed in Phase 1) — if provided, skim for
  interaction-pattern vocabulary and ARIA-role conventions.

**Rule G in one sentence: author intent beats inferred intent.** If a
doc-frame says "this component uses the Focus Ring utility," record it
as fact. If variant-analysis alone would have inferred "no focus," the
doc-frame wins.

Stash the ingested documentation under `<ds>.phase-5-notes.md` in a
`documentation_ingest:` block. Phase 5's analysis cites back to it.

### Step 5.2 — Utility-component inventory review (Rule F)

Phase 1 §1.3 classified standalones by role. Before Phase 5 classifies
components, validate the Utility-bucket explicitly with the User:

```
"Phase 1 classified these standalone components as Utility:
  • Focus Ring
  • Divider
  • Tooltip Backdrop
  • Scrim / Overlay Layer

Before I analyze interaction patterns, can you confirm:
  (a) Which of these participate in cross-cutting A11y concerns?
      (Focus Ring almost certainly does.)
  (b) Are any of them invoked compositionally from doc-frames rather
      than variant-axes?
  (c) Are there other utility-role components not caught by the name-
      pattern scan?"
```

Any utility-component that participates in interaction patterns must be
cited later when the pattern is recorded. Skipping this step is the
canonical path to the "no focus design" false-negative.

See `references/utility-patterns.md` for recognition-heuristics and known
families (focus rings, dividers, tooltip backdrops, selection indicators,
scrims/overlays).

### Step 5.3 — Pattern classification per COMPONENT_SET

For each COMPONENT_SET in Phase 1's inventory, assign one or more
interaction patterns. The canonical set is:

| Pattern | Signals | Typical states |
|---|---|---|
| **pressable** | click/tap target; has `hover` + `pressed` in state axis; often a Button | enabled, hover, pressed, disabled |
| **focusable** | receives + holds keyboard focus; often a Text input, Select | enabled, hover, focused, disabled |
| **selectable** | binary selection; has `selected` / `checked` / `active` axis | selected, unselected |
| **tristate** | selectable + a third "indeterminate" value | selected, unselected, indeterminate |
| **expandable** | open / closed state controls content visibility | open, closed |
| **validation** | exposes error / success / warning states; often Inputs | none, error, success |
| **progress** | has async-lifecycle states | idle, pending, loading, completed |
| **hasValue** | exposes empty / filled distinction (Inputs) | empty, filled |
| **focus_visible** | standalone focus-indicator utility (Rule F) | (utility-component, not a COMPONENT_SET pattern) |

**Multiple patterns per component is normal.** A Checkbox is
`pressable + selectable + tristate`. A Text Field is `focusable +
validation + hasValue`. Record every pattern that applies.

**Propose `orthogonal_to` relationships.** Patterns that can combine
freely (selectable × pressable, validation × focusable) should be
declared as orthogonal; patterns that are mutually exclusive (tristate
subsumes selectable) inherit.

### Step 5.4 — Focus-strategy classification (the headline Rule F moment)

Every DS has a focus-strategy; most don't make it explicit. Identify
which of the four shapes this DS uses:

| Strategy | Signature | Example |
|---|---|---|
| **variant-boolean** | `focused: [false, true]` as a variant on each focusable component | Focus lives in the component graph; high Figma fidelity, heavy variant-cost |
| **utility-component** | Standalone `Focus Ring` used compositionally (doc-frame reference, instance swap) | Focus is a single source-of-truth; low variant-cost, needs Rule-F + Rule-G to discover |
| **CSS-delegated** | No Figma representation; focus lives entirely in CSS (`:focus-visible`, outline, etc.) | Pure code convention; Figma is silent |
| **implicit-via-stroke** | Hover-stroke + focus-stroke share a token; the component never distinguishes the two in Figma | Dual-purpose token; works visually but not semantically distinct |

**Detection heuristic:**

```
if any COMPONENT_SET has a focused-variant in its propertyDefinitions → variant-boolean
else if any standalone Utility-component named /focus|ring/ exists
     AND any doc-frame references it (via INSTANCE or by name in prose) → utility-component
else if a CSS convention is documented externally (User points at it) → CSS-delegated
else if hover and focus both resolve to the same token in sampled bindings → implicit-via-stroke
else → unknown — ask User; seed finding; do NOT declare "no focus design"
```

**This is where "no focus design" false-negatives used to happen.**
Without Rule F + Rule G, a variant-only scan misses the utility-component
strategy entirely. The fallback "ask User" is load-bearing — don't skip.

### Step 5.5 — Anti-pattern detection (carry-forward from Phase 2)

Phase 2 should already have seeded these findings; Phase 5 confirms they
show up at the interaction-pattern level too:

| Anti-pattern | Phase-5 symptom |
|---|---|
| compound-state folding | Component's state-axis has values like `filled-hover` or `open-pressed` — interaction-patterns overlap compound dimensions |
| active-ambiguity | `active` means both "base-idle-label" (enabled-alias) and "selected" depending on component |
| property-explosion | A variant value encodes a second axis (`tertiaryWithoutPadding` = `type: tertiary` + `padding: false`) |
| modeling-inconsistency | Selection modeled as 3-variant for Checkbox, boolean for Radio |

For each, confirm the interaction-pattern lens and cross-reference the
Phase-2 finding. Don't re-open the SoT-Recommendation — that's Phase 6's
job. Just mark the finding as "interaction-confirmed" so Phase 6's
classification has a full trail.

### Step 5.6 — Accessibility defaults derivation

From the DS's conventions + doc-frame content + User input, derive:

```yaml
accessibility_defaults:
  focus_ring:
    description: "<pattern summary — e.g. single-ring outline, double-ring, inset>"
    pattern: <variant-boolean | utility-component | css-delegated | implicit-via-stroke>
    token_group: <path or "external">
  min_target_size:
    token: <e.g. controls.height.base>
    wcag_level: AA | AAA
    description: "<scaling note if device-modifier applies>"
  contrast_requirements:
    description: "<DS's stated policy — per-context, per-pair, etc.>"
    wcag_level: AA | AAA
  keyboard_defaults:
    # per interaction-pattern
    pressable: { activate: [Enter, Space] }
    focusable: { activate: [Enter], escape: [Escape] }
    selectable: { toggle: [Space] }
    expandable: { toggle: [Enter, Space], close: [Escape] }
  category_defaults:
    # per category, with ARIA-roles
    Buttons: { role: button, tabindex: 0 }
    Inputs:  { role: textbox, tabindex: 0 }
    Menus:   { role: menu, tabindex: -1, focus_strategy: roving }
```

**Most DSes have never written this down.** The Phase 5 output is often
the first formal artefact of their A11y-conventions. That makes two
things true:

1. Get User sign-off on every block — the LLM is proposing, not
   canonizing.
2. Cite the source for every claim (doc-frame §, external-docs URL, or
   "inferred from variant-pattern; needs User confirmation").

### Step 5.7 — Pattern-token mapping

For each interaction-pattern declared, propose a `token_mapping` from
pattern-state → grammar-state:

```yaml
pressable:
  token_layer: <layer-name from Phase-3 token_layers[] — typically "Controls">
  token_mapping:
    enabled: enabled
    hover: hover
    pressed: pressed
    disabled: disabled
    pending: enabled   # if no dedicated token, fallback
```

**`token_layer`** points at a **layer name** from Phase-3
`token_layers[]` (e.g. `Controls`, `Interaction`, `Foundation`) — NOT
a grammar key (e.g. `color.controls`). The validator's L4 cross-field
check rejects a grammar key here. If the DS has no Phase-3 layer that
covers this pattern (e.g. a `progress` pattern with no progress-
tokens at all), seed a Finding — Cluster A (Token-Layer Architecture)
or Cluster D (Accessibility Patterns) depending on where the gap is
more actionable. If a layer exists but the grammar inside it is
missing for this pattern, that is a sparsity finding for Cluster A,
not a `token_layer` mis-binding.

**`promoted`** lists states that the Profile flags for strong
generator-emit (e.g. `disabled` is universally important; generators
should always scaffold its styles even if sparse).

---

## 2 · Output (carry-forward to Phase 6)

**T1/T2 path:** `<ds-test-dir>/.cdf-cache/phase-5-output.yaml`, shape per
`references/phases/templates/phase-5-output.schema.yaml`. Phase 6
asserts `schema_version: phase-5-output-v1`.

**T0 path (legacy):** `<ds-test-dir>/<ds>.phase-5-notes.md`. Phase 6's
markdown-fallback consumer handles it.

Phase 5 has **no inline-jq seeders** — it is ~100% LLM synthesis off
the upstream phase outputs + ingested doc-frames + Rule-F utility-
component review. The schema captures the synthesis output in named
slots so Phase 6 can iterate `seeded_findings[]` uniformly across
phases.

### Step 5.last — Emit `phase-5-output.yaml` (T1/T2 only)

```bash
OUT=<ds-test-dir>/.cdf-cache/phase-5-output.yaml
mkdir -p "$(dirname "$OUT")"
jq -n \
  --argjson focus      '<focus_strategy block from Step 5.4>' \
  --argjson utilities  '<utility_components from Step 5.2>' \
  --argjson patterns   '<interaction_patterns from Step 5.3>' \
  --argjson cmap       '<component_pattern_map from Step 5.3>' \
  --argjson a11y       '<accessibility_defaults from Step 5.6>' \
  --argjson findings   '<seeded_findings — LLM-authored>' \
  --arg     phase4_path 'phase-4-output.yaml' \
  '{
    schema_version: "phase-5-output-v1",
    generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    generated_by: { source_phase_4: $phase4_path, tier: "T1" },
    focus_strategy: $focus,
    utility_components: $utilities,
    interaction_patterns: $patterns,
    component_pattern_map: $cmap,
    accessibility_defaults: $a11y,
    seeded_findings: $findings,
    interpretation: [],
    phase_6_inputs: {}
  }' | yq -P -o=yaml > "$OUT"

yq '.schema_version' "$OUT"   # Expected: phase-5-output-v1
```

**LLM review contract (Phase 5 is the all-LLM phase):**

1. Walker-owned (do NOT edit): `schema_version`, `generated_at`,
   `generated_by`. Re-emit must produce identical metadata for the
   same content (modulo timestamp).
2. Everything else is LLM-authored. There are no mechanical seeds
   to preserve; the Phase-6 consumer treats every `seeded_findings[]`
   entry uniformly.
3. Phase 6 hard-asserts `schema_version: phase-5-output-v1`.

Update `.cdf.config.yaml` `scaffold:` block's
`last_scaffold.phases_completed` to extend `[…, 5]`.

---

## 3 · Tool-leverage Map (Phase-5 specific)

| Tool | Leverage | Notes |
|---|---|---|
| LLM synthesis (reading Phase 1–4 notes) | ★★★ | Primary activity. No new tool-calls required for most DSes |
| Doc-frame content (read via `get_design_context`) | ★★ | Rule G — author-intent ingestion. Sample per COMPONENT_SET; batch if > 30 |
| Figma Component Description | ★ | Often carries ARIA-role or pattern hint in 1–2 sentences |
| Figma Annotations | ✗ | Not reliably reachable from `use_figma` Plugin-JS (Phase-1 pitfall). Don't rely on these |
| `figma-mcp.get_variable_defs(nodeId)` | ★ | Verify token-layer binding when `token_mapping` is ambiguous |
| External docs (User-pointed) | ★★ | When available, often contains explicit A11y conventions |
| `cdf_show_pattern_examples` | ✗ | Deferred to v1.5.0. For now: `references/foreign-ds-corpus/*.profile.yaml` as example library |

---

## 4 · Completion Gates

- [ ] Documentation-surfaces ingested **first** (Rule G) — at least
  doc-frames + Component Descriptions scanned before pattern inference.
- [ ] Utility-component review done with User; Focus-Ring-class
  components confirmed in or out (Rule F).
- [ ] Every COMPONENT_SET assigned one or more interaction-patterns.
- [ ] Focus-strategy classified (one of the 4 shapes, or `unknown` with
  a pending User-question).
- [ ] Phase-2 anti-patterns re-confirmed at the interaction lens.
- [ ] `accessibility_defaults` drafted in full — focus-ring,
  min-target-size, contrast, keyboard, category-defaults.
- [ ] `token_mapping` proposed per pattern; missing grammar → Finding.
- [ ] User has been shown the `focus_strategy` and `accessibility_
  defaults` and acknowledged (first-write DSes nearly always need a
  "let me check / revise" round).
- [ ] `.cdf.config.yaml` `scaffold:` block updated.

---

## 5 · Findings-Seed Candidates

1. **Focus-strategy is utility-component (not variant-boolean)** — when
   Rule F catches a standalone focus-ring that Phase 1's variant-scan
   missed. Cluster D.
2. **Focus-strategy is unknown** — when none of the 4 shapes fit without
   User input. Cluster D.
3. **Pattern has no token-grammar backing** — e.g. `progress` pattern
   exists in components but no `progress.*` tokens; generators must
   fallback. Cluster A or D.
4. **compound-state interaction-confirmation** — carry-forward from
   Phase 2; tag as "interaction-lens confirms this is a fold, not an
   atom." Cluster C.
5. **A11y-defaults first-write** — seed the full `accessibility_
   defaults` block; flag that this is a Skill-proposed artefact needing
   DS-team sign-off. Cluster D.
6. **Keyboard-binding convention ambiguity** — when doc-frames and
   external docs disagree, or when no source states the bindings.
   Cluster D.
7. **Orphan pattern** — a pattern declared in one source (doc-frame) but
   no component uses it. Cluster C or D.
8. **CDF-Format-gap: utility-component focus pattern** — first-class
   support for utility-component focus-strategy is a known gap in
   Profile Spec v1.0.0. Seed to `docs/specs/cdf-profile-spec-v1.1.0-
   issues.md` (Cluster F, not the DS findings-doc).

---

## 6 · Typical Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Variant-axis-only focus scan | "This DS has no focus design" declared with confidence | Rule F — check utility-components. Rule G — ingest doc-frames |
| Skipping doc-frames | Patterns inferred from variants only; author-intent lost | Step 5.1 FIRST. Author intent beats inferred intent |
| One-pattern-per-component assumption | Checkbox declared as only `selectable`, misses `pressable` + `tristate` | Most components wear 2–3 patterns; classify generously, constrain via `orthogonal_to` |
| Conflating focus with selection | `selected` treated as a focus-state | Selection is persistence; focus is roving attention. Different patterns |
| Declaring focus-strategy without User confirmation | Profile freezes "css-delegated" because nothing found; wrong for DSes with invisible utility conventions | Ask User when unclear; `unknown` is a valid status until they answer |
| Inferring keyboard-bindings from nothing | Block filled in with WCAG defaults and no cite | Label inferences explicitly; cite doc-frames / external-docs where possible |
| Missing pattern-token-grammar gap | `progress` pattern declared, no `progress.*` tokens, generator fails | Step 5.7 maps every pattern-state to a grammar-state or explicit fallback |

---

## 7 · Subagent Dispatch

**Not recommended** for Phase 5. The phase is Rule-E-heavy:

- Utility-component review (Step 5.2) is a User-dialog.
- Focus-strategy identification (Step 5.4) often needs User correction.
- A11y-defaults derivation (Step 5.6) almost always needs User sign-off
  for first-write DSes.

If doc-frame ingestion (Step 5.1) is unusually large (> 50 COMPONENT_SETs
with rich doc-frames), a single subagent can summarize them in parallel
while the Master continues with Rule-F review. Output: per-component
YAML with extracted A11y / focus / keyboard notes; Master merges.

Everything else stays in main session.

---

## 8 · Cross-Reference to Phase 6

The `interaction_patterns` + `focus_strategy` + `accessibility_defaults`
are now **proposed artefacts** in the Profile. Phase 6 is where the User
classifies each Phase-5 Finding:

- Focus-strategy findings often resolve as "adopt" (DS-team confirms
  the classification).
- A11y-defaults findings usually resolve as "adopt, with edits" (first-
  write; User revises specific values).
- Pattern-with-no-grammar findings typically resolve as "backlog for
  token-layer work" (not a blocker for Profile emit).
- CDF-Format-gap findings (Cluster F) go to a **separate artefact**
  (`cdf-profile-spec-v1.1.0-issues.md`), not the DS findings-doc.

Do **not** classify findings in Phase 5. Seeding is enough. Phase 6
owns the decision-tree.
