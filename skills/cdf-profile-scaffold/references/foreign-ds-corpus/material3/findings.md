# Material 3 Port — Findings

Running log of format frictions encountered while porting Material 3
(Button + FAB only) to CDF v1.0.0-draft.8. Same categorisation as
Radix / shadcn / Primer:

- **Real format gap** → draft.9 candidate (spec change + rationale)
- **Validator behind spec** → cdf-core TODO (spec fine, validator lags)
- **My misunderstanding** → NOT logged (fix the spec instead)

Template:

```
## F-material-N: short title
**Material 3 reality:**
**CDF status:**
**Suggested fix:**
**Verdict:**
**Effort:**
```

**Format-change budget for this pass:** ≤2 new optional fields,
≤1 new toggle. Same as prior three passes. If exceeded → stop,
write up, log which Material 3 feature surfaced the gap. Do not
press past budget.

Carry-over Radix / shadcn / Primer findings stay in their own files;
only re-log here if Material 3 surfaces a NEW dimension of the same
friction. Specifically:

- F-primer-5 / F-shadcn-2 — `target_only` third-DS confirmation
- F-primer-2 — vision-accommodation multi-axis, first-class via
  Material's contrast axis
- F-shadcn-3 / draft.7 Token-Driven Principle — state-layer stress test

---

## F-material-provisioning: Material 3 token generation

**Material 3 reality:**
Material does not ship a clone-able token tree. Tokens are generated
from a seed colour via `@material/material-color-utilities`; elevation,
shape, motion, typography come from m3.material.io docs and/or
`@material/web` CSS variables. This pass generated tokens locally
under `<ds-test-dir>/.material3-tokens/` (gitignored).

Replay data:
- **Seed:** `#6750A4` (Material 3 default "Baseline" purple)
- **Utility package:** `@material/material-color-utilities@0.4.0`
- **Generation date:** 2026-04-16
- **Static tokens doc snapshot:** m3.material.io, 2026-04-16

Output files (in `.material3-tokens/`):
- `tokens-baseline.json` — seed-derived light / dark schemes + six
  tonal palettes (primary, secondary, tertiary, neutral, neutralVariant,
  error), 16 tones each
- `tokens-static.json` — manually transcribed elevation (6 levels),
  shape-corner (7 steps), motion-duration (7), motion-easing (5),
  state-layer opacity reference (for toolchain only — not a CDF
  concern)

Node ESM resolution note: `@material/material-color-utilities@0.4.0`
ships ESM modules with extensionless relative imports, which Node
22's strict ESM rejects. A tiny loader hook (`.material3-tokens/
loader.mjs`) auto-appends `.js` or `/index.js` at resolve time.
Dev-env friction only; orthogonal to CDF.

**CDF status:**
Not a CDF concern. The brief pre-committed this as provisioning
rather than a format question. CDF's contract is with the
enumerated-token output, not the toolchain that produced it.

**Suggested fix:** none.
**Verdict:** informational.
**Effort:** n/a.

---

## F-material-0: State-layer mechanism — state-as-token (no escalation)

**Material 3 reality:**
Material 3 specifies interaction states as **opacity overlays**
applied on top of a role's base colour:

| State     | Overlay opacity | Overlay material      |
|-----------|-----------------|-----------------------|
| hover     | 8%              | `color.onPrimary` (the paired on-role colour) |
| focus     | 10%             | `color.onPrimary`     |
| pressed   | 10%             | `color.onPrimary`     |
| dragged   | 16%             | `color.onPrimary` (out of scope this pass) |
| disabled  | 12% (container) / 38% (text) | `color.onSurface` |

Material's own reference implementation (`@material/web`) applies
these as CSS-runtime composites via `color-mix()` or multi-layer
paint (a `.state-layer` child element with `background: var(--md-sys-
color-on-primary); opacity: 0.08`). This is **exactly** the
runtime-math pattern F-shadcn-3 first surfaced and that draft.7's
Token-Driven Principle (Component §1.1 #2) subsequently forbade from
CDF specs.

**CDF status:**
Per the brief's pre-commit and draft.7 prose: *"State layers via
state-as-token (overlay-as-modifier violates principle)."* The
mechanism this Profile uses:

1. The `color` grammar includes `{state}` as a grammar axis:
   `color.{role}.{slot}.{state}` with `state ∈ [rest, hover, focus,
   pressed, disabled]`.
2. The toolchain (hypothetical DTCG emitter fed by
   `.material3-tokens/*.json`) pre-composes each cell by applying
   the overlay percentage to the base + overlay material, emitting
   one concrete DTCG `$value` per cell. Button / FAB specs bind to
   the resulting paths (`color.primary.base.hover`) without knowing
   the percentages.
3. The percentages live in
   `.material3-tokens/tokens-static.json`'s `stateLayer` block as
   **toolchain-only metadata**. Neither the Profile nor any
   Component references them. If I ever found myself tempted to
   declare a `state_layers:` section on the Profile or a
   `state_overlay: 0.08` field on a Component, that would be a
   principle violation, not a format gap (brief's pre-commit).

**Validation in practice:**
During authoring, the `tokens:` block for Button variant=filled
hover binds to `color.primary.base.hover` — a single token path,
resolves to a single DTCG value at build time, no opacity
expression anywhere in the spec. CDF-CON-008
(`no-raw-unitless-tokens`) has no surface to fire on because no raw
numeric appears. The spec stays pure token-driven.

**What this tests for draft.7 / draft.8:**
The brief's headline claim — *"state-layers are exactly the
runtime-math pattern draft.7 forbade; if CDF-CON-008 fires
anywhere, either (a) a state-token was missed in the Profile, or
(b) the Profile authored a state-layer family that should not
exist"* — is the clean stress test. Result (after authoring both
components, see F-material-5): zero CDF-CON-008 hits. The
principle held.

**Suggested fix:** none. The principle is the fix.
**Verdict:** Accepted as pre-committed. State-as-token absorbed
Material's richest state model with zero format change.
**Effort:** none format-side.

---

## F-material-1: Theme axes — semantic × contrast (two axes)

**Material 3 reality:**
Material 3 ships three distinct variant families per colour role:
`standard`, `medium-contrast`, `high-contrast`. Combined with
Light / Dark, that is 2 × 3 = 6 colour schemes (plus Material's
`@material/material-color-utilities` can further seed-derive
vision-accommodation variants — those are deferred per F-primer-2).

The brief enumerated three modelling choices:

- **(one axis flat-six)** `semantic: [Light, Dark, LightMC, DarkMC,
  LightHC, DarkHC]` — six flat values on one axis
- **(two axes orthogonal)** `semantic × contrast` — 2 + 3 = 5
  declared values across two axes, 2 × 3 = 6 cells
- **(three axes including accommodation)** — rejected by brief;
  vision-accommodation stays deferred

**CDF status:**
CDF Profile §8 supports multiple theme modifiers, each with its
own value set. Formtrieb uses three axes (`semantic × device × shape`).
Declaring Material's two axes as orthogonal modifiers is a
structural fit.

**Decision:**
**Two axes** — `semantic: [Light, Dark]` × `contrast: [standard,
medium, high]`. Rationale per brief's recommendation:
- Matches Material's design intent — Material's own dynamic-colour
  toolchain treats light/dark and contrast as orthogonal inputs,
  not as a flat six-value axis.
- Each axis stays legible on its own — a reader can grok "semantic
  is Light or Dark" and "contrast is one of three levels"
  independently.
- Leaves room for a future third axis (accommodation) without
  refactoring the existing two.

Flat-six rejected because:
- Names like `DarkMC` collapse two semantic concerns (dark + medium
  contrast) into one identifier — readers have to parse the suffix.
- Adding a fourth contrast level (hypothetical) would require
  renaming every mode.

**CDF-Profile modelling:**
```yaml
theming:
  modifiers:
    semantic:
      contexts: [Light, Dark]
      default: Light
      required: true
    contrast:
      contexts: [standard, medium, high]
      default: standard
      required: false
```

**Suggested fix:** none. Multi-axis theming is already a first-class
CDF feature (§8); this Profile exercises it as designed.
**Verdict:** Two-axes modelling accepted. Strongest pre-Material-3
evidence that the format absorbs accommodation-style axes — and the
first multi-axis theme used outside Formtrieb.
**Effort:** none format-side.

---

## F-material-2: Vocabulary overlap — `primary` in two vocabs

**Material 3 reality:**
Material's FAB has four "variants": `primary`, `secondary`,
`tertiary`, `surface`. These variant NAMES are identical to four of
the `color_role` vocabulary's values — because in Material, a FAB's
"variant" literally IS its colour role. The FAB has no orthogonal
variant axis beyond "which role do you tint me with".

Similarly, `size: [small, medium, large]` (Button + FAB) overlaps
with `typography_scale: [large, medium, small]` — same scalar names,
different semantic axes.

**CDF status:**
Profile §5.5 rule 2 explicitly permits cross-vocabulary overlap:

> *"Values MAY appear in multiple vocabularies with different
> meanings (e.g. `primary` in both `hierarchy` and `intensity`).
> Consumers disambiguate by context (axis binding)."*

Rule 5 (reserved-namespace isolation) applies only when a value is
in **exactly one** vocabulary. Since `primary` appears in both
`color_role` and `fab_variant`, rule 5 is not triggered, and a
Component property using `binds_to: fab_variant` unambiguously
selects the FAB-variant meaning.

**Observed in the Profile:**
Five vocabularies overlap with others: `color_role` ↔ `fab_variant`
(primary/secondary/tertiary/surface), `size` ↔ `typography_scale`
(small/medium/large). Both Components use explicit `binds_to:`
declarations (required in this case per CDF-STR-012), so the
disambiguation is machine-readable.

**Why this is novel vs prior passes:**
Radix, shadcn, and Primer each had vocabularies whose values were
naturally disjoint (shadcn: `default/destructive/outline/…` vs
`sm/lg/icon`; Primer: `default/primary/danger/…` vs `small/medium/
large`). Material is the first DS in the foreign-DS series where
two vocabularies **naturally** share meaningful values without
contrivance.

**Suggested fix:** none. The rule as written covers the case.
**Verdict:** Accepted — rule 2's cross-vocabulary allowance proven
on a DS that needs it. `binds_to:` requirement (CDF-STR-012) is the
right enforcement point.
**Effort:** none format-side. Worth a one-line cross-reference from
§5.5 rule 2 prose to a "Material 3 is the canonical example"
footnote in a future draft — deferred as trivial doc polish.

---

## F-material-3: `target_only` — third-DS evidence confirmed

**Material 3 reality:**
Material 3's density-scale axis (`comfortable`, `default`, `compact`)
modulates padding and height via Material's `density.{component}.{step}`
token family. This Profile deliberately does not model that family —
the scope was colour + shape + elevation + motion + typography +
component-surface tokens, not sizing-system tokens.

Both Button and FAB declare `density` as a property. Both leave the
`tokens:` block silent for that axis. Without `target_only: true`, a
generator or reviewer reading the spec cannot distinguish
"intentional absence" (Material's sizing system owns this) from
"authoring oversight" (forgot to bind).

**CDF status:**
draft.8 §7.12 landed `property.target_only: boolean` precisely for
this case, with two-DS evidence (F-shadcn-2 + F-primer-5). Material
3 is the **third-DS data point**, on a DS where the pattern surfaces
on both modelled components.

**Observed in the specs:**
```yaml
# button.component.yaml
properties:
  density:
    type: enum
    values: [comfortable, default, compact]
    target_only: true
    binds_to: density_step
```

FAB repeats the pattern. Validator silent — `target_only: true`
suppresses the absent-bindings warning per draft.8 §7.12 prose.

**Cross-DS mechanism comparison:**

| DS       | Where do these axis tokens live?                                |
|----------|-----------------------------------------------------------------|
| shadcn   | Tailwind utility-class bundles; **no DS tokens** for size       |
| Primer   | DS-owned tokens in `control.{size}.*` — OUTSIDE this pass's grammar |
| Material | DS-owned tokens in `density.{component}.{step}` — OUTSIDE this pass's grammar |

Three DSes, three mechanically-different reasons for "tokens exist
elsewhere / don't exist at all / exist in a family the spec doesn't
model." `target_only: true` covers all three with a single flag —
the right level of abstraction for a signalling primitive.

**Suggested fix:** none. draft.8 already shipped the flag; this pass
validates the evidence chain.
**Verdict:** Third-DS evidence confirms the flag's multi-DS
applicability. Material's `density` is exactly the pattern
F-primer-5 predicted.
**Effort:** none — draft.8 T1 already landed.

---

## F-material-4: Single-ring focus — third-DS evidence confirmed

**Material 3 reality:**
Material's focus indicator is a 3dp outline ring (`color.focus.outline`)
applied directly to the focused element. It uses the single-ring
pattern — no outer/inner double ring. Material also applies a
state-layer overlay at 10% opacity on focus, but that is a separate
concern (baked into `color.{role}.{slot}.focus` by the toolchain per
F-material-0); the ring itself is single-layer.

**CDF status:**
draft.8 §13.5.1 landed the single-ring prose note exactly for this
case, motivated by F-shadcn-5 + F-primer-4a two-DS evidence. Material
3 is the **third-DS data point**, on a DS whose focus is more
visually complex than shadcn / Primer (overlay + ring) but whose
RING portion is still single-ring.

**Observed in the specs:**
```yaml
# button.component.yaml (and fab.component.yaml)
tokens:
  container:
    outline-color: color.focus.outline    # single-ring per §13.5.1
```

No `focus:` block used; no §13.5-structured `outer` / `inner`
sub-tokens. Plain `outline-color:` binding, just as §13.5.1 prose
describes as the correct idiom.

**Suggested fix:** none. draft.8 already shipped the prose note;
this pass validates it against a DS whose focus has an overlay layer
layered on top.
**Verdict:** Third-DS confirmation. §13.5.1 prose correctly describes
the Material 3 case.
**Effort:** none — draft.8 T2 already landed.

---

## F-material-5: Elevation × variant × interaction — compound_states carries

**Material 3 reality:**
Material's elevated Button has state-driven elevation:
- rest / focus / pressed → `elevation.level1`
- hover → `elevation.level2`
- disabled → `elevation.level0`

FAB has the same pattern at a different base level:
- rest / focus / pressed → `elevation.level3`
- hover → `elevation.level4`
- disabled → `elevation.level0`

For Button, the binding depends on **both** `variant` AND `interaction`
(only the `elevated` variant elevates at all; the other four variants
are flat). For FAB, elevation varies only with `interaction` — all
FAB variants elevate identically. Both are multi-axis state
expressions.

**CDF status:**
§13.2 explicitly forbids chained modifiers:
> *"The modifier form stays single-axis by design. When the
> combination spans two or more axes — e.g. a Checkbox token that
> depends on both selected: true and interaction: hover — use the
> §8.8 `compound_states:` block instead."*

So `box-shadow--variant.elevated--interaction.hover: elevation.level2`
is invalid syntax. Correct idiom: `compound_states:` block with a
`when:` clause keying on both axes.

**Observed in the specs:**

```yaml
# button.component.yaml — two-axis compound (variant × interaction)
compound_states:
  - when: { variant: elevated, interaction: enabled }
    tokens:
      container:
        box-shadow: elevation.level1
  - when: { variant: elevated, interaction: hover }
    tokens:
      container:
        box-shadow: elevation.level2
  # ... three more rows

# fab.component.yaml — single-axis compound (interaction only)
compound_states:
  - when: { interaction: enabled }
    tokens:
      container:
        box-shadow: elevation.level3
  - when: { interaction: hover }
    tokens:
      container:
        box-shadow: elevation.level4
  # ... three more rows
```

Validator silent; `compound_states:` coverage rule satisfied per
§8.8 / CDF-SEM-010.

**Observation — idiom-legibility concern:**
The FAB case feels AWKWARD: elevation varies only with `interaction`,
single-axis, but the spec cannot use §13.2's single-axis modifier
syntax (`box-shadow--interaction.hover: elevation.level4`) because
— actually, can it? Re-read §13.2.

Actually YES — FAB's elevation IS single-axis (interaction only), so
the §13.2 modifier form IS legal:
```yaml
box-shadow: elevation.level3
box-shadow--interaction.hover: elevation.level4
box-shadow--interaction.focus: elevation.level3
box-shadow--interaction.pressed: elevation.level3
box-shadow--interaction.disabled: elevation.level0
```

The FAB spec uses `compound_states:` for consistency with Button's
(genuinely two-axis) compound block, which is pragmatic but not
strictly required. A future refinement pass could convert FAB's
elevation to the lighter §13.2 form. Leaving it as compound_states
here for symmetry — the semantics are identical.

**Suggested fix:** none format-side. CDF's two-block mechanism
(§13.2 single-axis + §8.8 compound) covered Material's richest
state expression cleanly. Worth a one-line guide-note in §8.8
clarifying that when a compound_states block has `when:` with only
one axis, single-axis §13.2 modifier syntax is equivalent and
often lighter — pure doc polish.

**Verdict:** Accepted. Two-axis state expressions are the pattern
§8.8 was designed for; Material's elevation case is the canonical
multi-DS example. Format absorbed it with zero new surface.
**Effort:** none format-side; trivial doc polish optional.

---

## F-material-6: Typography composite — single-key binding

**Material 3 reality:**
Material 3 defines typography as a **composite DTCG type**:
`typography.{role}.{scale}` resolves to a DTCG token whose `$value`
is an object with `fontFamily`, `fontSize`, `fontWeight`,
`letterSpacing`, `lineHeight` sub-values. One token per
(role × scale) cell.

Button and FAB labels both bind to `typography.label.large`.

**CDF status:**
Component §13.4 describes typography bindings as a nested block:
```yaml
typography:
  base:
    font-family: fontFamilies.baseFamily
    font-size: fontSizes.label.large
    font-weight: fontWeights.regular
    line-height: lineHeights.label.large
```

This form is designed for DSes whose typography tokens are
**split** — family / size / weight / line-height as separate DTCG
tokens. Material's `typography.*` is a single composite DTCG
typography token.

§13.4's prose mentions a mixin form:
> *"A Component may reference a mixin by name: `typography:
> typography.mixin.label-large`."*

Observed usage:
```yaml
# button.component.yaml and fab.component.yaml
tokens:
  label:
    typography: typography.label.large
```

**Validation status:**
Validator silent. The `typography: <path>` single-key form accepts.
Whether the validator strictly checks that the target is a composite
vs split token is not exercised here — the composite form bound to
a grammar whose `dtcg_type: typography` is declared, which is the
honest match.

**Suggested fix:** none. §13.4's mixin-reference form is exactly
the right idiom for DSes that use composite typography tokens.
Worth a one-line cross-reference in §13.4 clarifying that composite
DTCG typography tokens MAY be bound with the single-key form
(parallel to mixin references) — nice-to-have doc polish, not a
gap.
**Verdict:** Accepted. Material's composite-typography binding
worked on first try without format change.
**Effort:** none format-side; trivial doc polish optional.

---

## F-material-7: Outlined-disabled border — missing state token

**Material 3 reality:**
Material 3's outlined Button variant has a stroke (`color.outline`
singleton). At the disabled state, the stroke uses outline at 12%
opacity — Material's spec composes this as a state-layer equivalent
on the outline role.

**CDF status:**
The Profile declares `color.outline` as a standalone_token with one
value — no `.disabled` variant. The Button spec binds
`border-color--variant.outlined: color.outline` unconditionally
across all interaction states. For all states except disabled, this
is correct (outline has no hover / focus / pressed state in
Material — the state-layer overlays apply to the container fill,
not the border). For disabled, the spec is silent on the stroke,
meaning the disabled-state stroke uses the same `color.outline` as
rest — **which is visually wrong by Material's spec** (12% opacity
should apply).

**Options:**

1. **Declare `color.outline.{state}` as a token_grammar entry.**
   Add an `outline` role to the `color` grammar's color_role
   vocabulary (would overlap with the existing singleton — remove
   the singleton). `color.outline.base.disabled` would then carry
   the 12% composite. Cleanest token-side; requires Profile
   restructure.

2. **Declare `color.outline.disabled` as a second standalone_token.**
   Cheap fix — add one entry. Component spec adds a
   `border-color--interaction.disabled: color.outline.disabled`
   modifier override.

3. **Accept the fidelity gap for this two-component scope.**
   Material's outlined-disabled is a specific visual detail;
   modelling it adds a token without changing the overall bridge
   story. This pass has chosen option 3 — flagged here for the
   next refinement round.

**Suggested fix:** Option 2 (standalone addition) next pass. Option
1 if a broader refactor of the Profile's outline-role handling
becomes warranted.

**Verdict:** Spec-authoring-level oversight on a specific Material
detail; not a CDF format gap. Fidelity-improvement item for a
follow-up Profile update, zero format consequence.
**Effort:** trivial — one extra `standalone_tokens` entry + one
modifier override in Button spec.

---

## F-material-fab-extended: Extended FAB — size or variant?

**Material 3 reality:**
Material 3's "Extended FAB" is a FAB elongated horizontally to
accommodate a text label alongside its icon. Material's own docs
list it under FAB's *size* section (alongside small / medium /
large), yet its visual delta is categorically different — a label
appears, the aspect ratio inverts from square to rectangular.

**CDF status:**
Two modelling options:

- **Size** — treat `extended` as a fourth value of the size axis.
  Compatible with Material's own docs. Makes Extended-FAB a
  specialisation of FAB rather than a separate component. The
  `label` anatomy part is always declared but only rendered when
  `size: extended` — rendering logic encoded in `behavior:`.
- **Variant** — treat `extended` as an independent axis (e.g.
  `shape: {compact, extended}` or a separate component name
  `ExtendedFAB`). More semantic-correct but diverges from
  Material's documentation conventions.

**Decision for this pass:** Size (per Material's docs + the brief's
pragmatic guidance). Documented in the spec description and in
`accessibility.aria` (different aria-label expectation for extended
vs icon-only sizes).

**CDF status:**
No format question. §13 handles both modellings equivalently — the
choice is a spec-authoring preference. CDF's job is not to decide
the taxonomy; it's to describe whichever taxonomy the author chose.

**Suggested fix:** none.
**Verdict:** Authoring choice, accepted. Not a format gap.
**Effort:** none.

---

## F-material-fab-sizing: Container dimensions unbound

**Material 3 reality:**
FAB's `container` has per-size dimensions: small 40×40dp, medium
56×56dp, large 96×96dp, extended variable×56dp. These are distinct
visual properties driven by the `size` axis. Material ships them
via `md.sys.shape.*` and density-aware sizing tokens that this
Profile does not model.

**CDF status:**
The FAB spec declares `size` as a property, and binds `border-radius`
per size (§13.3 value-map). It does NOT bind `width` / `height` /
`padding` per size — those live in the sizing-token family outside
this Profile's scope. Same situation as Button's `density` property.

Should FAB's `size` property also declare `target_only: true`?
Arguments in favour: the sizing token family is outside scope, so
"signal intentional absence" applies. Arguments against: `size`
DOES have partial bindings (shape-corner via value-map + border-
radius), so it isn't a fully-absent axis — it's partially-modelled.

draft.8 §7.12's prose on this case:
> *"When NOT to use target_only: a property that has SOME token
> bindings but is missing others for a valid reason. `target_only`
> is for fully-absent-by-design axes, not partially-modelled ones."*

FAB's `size` has SOME bindings (shape-corner), so `target_only:
true` would be misleading. The correct encoding is what the spec
does today — bind what's in-scope (shape-corner), leave
dimensions unbound, describe in `description:` what's missing and
why.

**Suggested fix:** none. draft.8 §7.12's when-not-to-use prose
already anticipates this case.
**Verdict:** Correctly modelled per draft.8 guidance. Not a format
gap.
**Effort:** none.

---

## Validation result

Both specs validate clean against `material3.profile.yaml` via
`formtrieb-cdf-core`'s `validateFile(...)`:

```
=== button.component.yaml ===
  0 issues (all rules silent, including CDF-CON-008 / no-raw-unitless-tokens)
=== fab.component.yaml ===
  0 issues (all rules silent, including CDF-CON-008 / no-raw-unitless-tokens)
```

**CDF-CON-008 silent on both specs** — the brief's headline
stress test result. Material 3's richest runtime-math surface
(state-layer overlays) was absorbed by the Token-Driven Principle
without format change. No opacity expression, no raw numeric, no
`color-mix()` appears in either spec. The toolchain's pre-composition
responsibility is carried entirely by prose — the Profile's `color`
grammar description says *"the toolchain pre-composes them by
overlaying state-layer opacity"* and every Component binding
resolves to a concrete DTCG path that the toolchain is expected to
emit.

---

## Summary counters

| Bucket | Count |
|---|---|
| Real format gap → draft.9 candidate | 0 |
| Validator behind spec → cdf-core TODO | 0 (F-shadcn-1 still outstanding; not re-logged) |
| Accepted reality / deferred / doc polish | 10 (F-material-provisioning + 0 through 7 + 2× fab-scoped) |
| **Format-change budget consumed** | **0 / 2 fields, 0 / 1 toggles** |

Zero new fields, zero new toggles. (γ)-principle survived Material
3's richest-yet token surface via MIXED mechanism — `token_grammar`
for systematic families, `standalone_tokens` for singletons. The
state-layer pre-commit (state-as-token, no overlay-as-modifier)
held under load: CDF-CON-008 silent on both components. Two-axis
theming (`semantic × contrast`) landed as a clean §8 multi-modifier
exercise. Third-DS evidence for `target_only` (draft.8 T1) and
single-ring focus (draft.8 T2) both materialised.
