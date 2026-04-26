# USWDS Port — Findings

Running log of format frictions encountered while porting USWDS
(Button + Alert only) to CDF v1.0.0-draft.8. Same categorisation as
Radix / shadcn / Primer / Material 3:

- **Real format gap** → draft.9 candidate (spec change + rationale)
- **Validator behind spec** → cdf-core TODO (spec fine, validator lags)
- **My misunderstanding** → NOT logged (fix the spec instead)

Template:

```
## F-uswds-N: short title
**USWDS reality:**
**CDF status:**
**Suggested fix:**
**Verdict:**
**Effort:**
```

**Format-change budget for this pass:** ≤2 new optional fields,
≤1 new toggle. Same as prior four passes. If exceeded → stop, write
up, log which USWDS feature surfaced the gap. Do not press past
budget.

Carry-over Radix / shadcn / Primer / Material 3 findings stay in
their own files; only re-log here if USWDS surfaces a NEW dimension
of the same friction. Specifically:

- **F-primer-2** — vision-accommodation / accessibility-preference
  axes. **THIS PASS'S PRIMARY QUESTION.** Close or concretize —
  deferred is no longer an acceptable verdict.
- **F-Radix-4** — conditional ARIA (role / aria-live per intent).
  Alert's five-variant × two-role × three-politeness matrix gives
  real two-DS evidence. Close or concretize.
- **F-primer-5 / F-shadcn-2** — draft.8 T1 `target_only`. Fourth-DS
  data point (already three-DS confirmed by Material).
- **F-shadcn-5 / F-primer-4a / F-material-4** — draft.8 T2 single-
  ring focus. Fourth-DS data point.

---

## F-uswds-provisioning: USWDS token source

**USWDS reality:**
USWDS ships as a single monorepo at
[`github.com/uswds/uswds`](https://github.com/uswds/uswds). Tokens
are defined as Sass maps under
`packages/uswds-core/src/styles/tokens/` (colour, spacing, typography,
breakpoints, high-contrast system-color passthroughs). Components
live in `packages/usa-{name}/src/styles/_usa-{name}.scss` and
consume tokens via Sass helpers (`color("primary")`, `units(2)`,
`radius("md")`, `font-size("sans","md")`).

USWDS also ships a compiled distribution at `dist/css/uswds.css`
where every Sass helper has been resolved to concrete CSS values
(but NOT to CSS custom properties — USWDS's output is post-
processed Sass, not a CSS-var-bridge like shadcn/Material). CSS
custom properties (`--usa-*`) exist only inside certain components
(`usa-banner`, `usa-tooltip`) as component-internal implementation
detail, not as a consumer-facing token surface.

Replay data:

- **Commit SHA:** `e3a67d19fc98193c753a445b568f99e939ae8342`
- **Clone date:** 2026-04-16
- **Clone depth:** shallow (`--depth 1`)
- **Source chosen:** Sass token files
  (`packages/uswds-core/src/styles/tokens/color/`,
  `packages/uswds-core/src/styles/tokens/units/`) and per-component
  Sass (`packages/usa-{button,alert}/src/styles/`). Sass is the
  authoritative surface — the compiled CSS at `dist/css/` is
  downstream. Token names (`primary`, `primary-dark`, `base-lighter`,
  `emergency`, etc.) come from the `$assignments-theme-color` Sass
  map and the `$alert-icons` keys.

**CDF status:**
Not a CDF concern. Like shadcn / Material 3 before it, the Profile
models the ENUMERATED token surface without claiming ownership of
the toolchain that produced it. USWDS's contract is with its
consumers via Sass-variable overrides (`$theme-color-primary: …`);
CDF models the shape.

**Suggested fix:** none.
**Verdict:** informational.
**Effort:** n/a.

---

## F-uswds-0: (γ) bridge mechanism — standalone_tokens confirmed

**USWDS reality:**
USWDS's token surface is semantically flat — `primary`,
`primary-dark`, `base-lightest`, `accent-cool`, `emergency`, etc. —
accessed via Sass helpers (`color("primary-dark")`). There is NO
hierarchical dotted grammar (`color.button.primary.hover` etc.);
names are single-segment in the Sass map and USWDS has no intent
of promoting them to CSS custom properties at the DS layer.

Per the F-shadcn-0 footnote clarification ((γ) is a principle, not
a mechanism), `standalone_tokens` with prose-annotated ownership is
the honest mechanism for this shape.

Entry count: TBD after Profile is written — expected ≤35 (the brief's
tripwire).

**Ownership shape — a new variant.**
USWDS is neither shadcn (consumer-owned) nor Primer / Material 3
(DS-owned, opaque). It is **DS-owned, consumer-overridable via
Sass variables**. Agencies are expected to fork `$theme-color-*`
and `$theme-*` settings at compile time; USWDS team provides the
defaults and strong guidance on what's safe to change.

Prose-annotation pattern: each `standalone_tokens` entry's
description begins with `"USWDS-owned; consumer-overridable via
$theme-color-{family}-{step} at Sass compile time"` to make this
fifth ownership model legible to generators and reviewers.

**CDF status:**
No new format surface needed. Prose ownership via `description:`
covers the new ownership model — same mechanism F-shadcn-0 logged
for consumer-owned, same mechanism F-material-provisioning logged
for toolchain-owned. Format-neutral observation.

**Suggested fix:**
None to format. Optionally, add a one-line reference in draft.9
doc-polish listing the five observed ownership models (headless /
consumer-CSS-vars / DS-DTCG / DS-toolchain-generated / DS-Sass-
agency-overridable) as a documentation artefact — not a spec
change.

**Verdict:** (γ) held; no escalation.
**Effort:** doc-only.

---

## F-uswds-theming: empty theming.modifiers — a first across the series

**USWDS reality:**
USWDS ships NO DS-owned runtime theme axes:

- **No Light/Dark toggle at DS level.** USWDS's "dark mode" is
  per-component `--inverse` variants applied when content sits inside
  a `.usa-dark-background` wrapper — a CONTEXT signal, not a theme
  switch. The DS does not provide a `:root[data-theme=dark]` / `.dark`
  class that remaps every token to a dark-mode value.
- **No contrast axis at DS level.** USWDS's "high-contrast" treatment
  is OS-signal-driven: `@media (forced-colors: active) { … }` blocks
  in 10+ component Sass mixins (grep confirmed:
  `packages/uswds-core/src/styles/mixins/` + `packages/usa-button/`).
  Windows High Contrast Mode (or macOS equivalent) triggers it at
  paint time; the DS does not have three token-set variants the way
  Material 3's `contrast: [standard, medium, high]` does.
- **No motion axis at DS level.** Reduced-motion is implemented in
  the `u-transition` mixin
  (`packages/uswds-core/src/styles/mixins/utilities/_transition.scss`):
  `@if not $essential { @media (prefers-reduced-motion) { transition:
  none; } }`. Another OS-signal CSS media query — the DS does NOT
  ship two motion-token variants.

**This is a FIRST across the Big-DS series:**

| DS       | `theming.modifiers`     |
|----------|-------------------------|
| Radix    | `semantic` + `device` + `shape` (Formtrieb defaults carried) |
| shadcn   | `semantic: [Light, Dark]` |
| Primer   | `semantic: [Light, Dark]` |
| Material 3 | `semantic: [Light, Dark]` + `contrast: [standard, medium, high]` |
| **USWDS** | **`{}` (empty)** |

USWDS genuinely owns no runtime theme dimensions. Its theming model
is Sass-compile-time agency customisation (`$theme-color-primary: …`),
not runtime mode switching. The empty `modifiers: {}` block is the
honest encoding.

**CDF status:**
Empty `modifiers: {}` block parses cleanly (cdf-core's
`profile-parser.ts` only requires `theming` to be defined, not
non-empty). No validator rule enforces a minimum of one axis. Format-
neutral observation.

**Suggested fix:** none. The fact that an empty modifiers block is
legal is itself the correct format behaviour — not every DS owns
runtime theme axes.

**Verdict:** format-neutral.
**Effort:** n/a.

---

## F-uswds-aria-vocabularies: Profile-level ARIA vocabularies as pre-F-Radix-4 setup

**USWDS reality:**
USWDS Alert maps five intents to:

- Two ARIA role values: `status` (polite live region — info / success)
  vs. `alert` (assertive live region — warning / error / emergency).
- Three aria-live values: `polite` (info / success / some
  implementations of warning / error) vs. `assertive` (emergency) vs.
  implicit (role inherits default).

This three-layer conditional is the F-Radix-4 stress test. To support
it, the Profile declares two vocabularies:

- `role_status_or_alert: [status, alert]`
- `aria_live_politeness: [off, polite, assertive]`

**CDF status:**
Legal today — Profile §5 vocabularies are open-ended; any string
set can be declared. Downstream the Alert Component spec §15 can
reference these in narrative `aria:` strings like:

```yaml
aria:
  - "role: alert — when intent ∈ {warning, error, emergency}"
  - "role: status — when intent ∈ {info, success}"
  - "aria-live: assertive — when intent = emergency"
  - "aria-live: polite — when intent ∈ {info, success, warning, error}"
```

The §15.3 narrative format is free-form — the `aria-{attr}: {value} —
{trigger}` pattern is a convention, not a structured grammar. This
works, BUT it is not machine-checkable: a reader or LLM derives the
intent→role mapping from prose, not from a formal cross-axis
expression.

**F-Radix-4 verdict pre-commit:**
If the Alert spec's §15 can express the mapping legibly without
structural friction, F-Radix-4 converts from deferred to
**resolved-via-prose**. If legibility degrades under the five-intent
× three-axis matrix (role + aria-live + potentially aria-atomic),
that's draft.9 candidate for a structured-ARIA grammar.

Will be finalised after the Alert spec lands in Step 3.

**Suggested fix:** TBD after Alert spec.
**Verdict:** TBD.
**Effort:** TBD.

---

## F-uswds-state-expression: hybrid §13.2 + §13.3 for flat-token state variation

**USWDS reality:**
USWDS's tokens are semantically flat Sass keys — `primary`,
`primary-dark`, `primary-darker` — with the state-tone encoded in
the NAME, not in a grammar axis. No `{interaction}` placeholder can
expand against them the way Material 3's
`color.primary.base.{interaction}` does.

For a Component whose `variant × state` matrix is dense (USWDS
Button: 8 variants × 4 states), two honest expression options exist:

- (a) §8.8 `compound_states:` — 8 variants × 3 non-rest states = 24
  entries per CSS property. Exhaustive but verbose (≈96 entries
  for bg / text / border × states).
- (b) §13.2 modifier overrides nested with §13.3 value-maps —
  `background--hover: { default: color.primary-dark, … }`, one
  map per state. Compact and mirrors the Sass source shape.

USWDS Button chose (b). **The validator accepts the combined form:
§13.2's `{property}--{modifier}` key with a §13.3 value-map as the
value.** 0 errors / 0 warnings / 0 info across the resulting spec
(8 variants × 4 states × 3 CSS properties = 96 cells bound
via this hybrid).

**CDF status:**
Legal today. The format supports this combination, and the syntax
reads legibly for flat-token DSes (USWDS, or any DS where state
variation is encoded in the token NAME rather than via a grammar
axis).

**Suggested fix:**
None to format. Potentially worth a draft.9 §13.2 doc-polish note:
"When combined with a §13.3 value-map value, `{property}--{state}`
forms a per-state-per-variant binding table. Valid for flat-token
DSes where state is name-encoded."

**Verdict:** format-neutral observation, validator silent.
**Effort:** doc-only.

---

## F-uswds-touch-target: size axis without tokens (not `target_only`)

**USWDS reality:**
USWDS Button's `size` axis has two values: `default` (baseline padding
1.5u × 2.5u, md font-size) and `big` (padding 2u × 3u, lg font-size).
These are expressed in Sass via `units(1.5)` + `font-size($fam, "md")`
helpers — arithmetic increments, NOT dedicated sizing tokens.

Touch-target minimum (WCAG 2.5.5 ≥44×44 CSS pixels) emerges from
`padding` + `font-size` + `line-height` math. USWDS does not ship a
`controls.height.{size}` family or similar.

**CDF status:**
The Button spec's `size` property has no bindings in the `tokens:`
block — same symptom as shadcn's `size: [default, sm, lg, icon]` +
Primer's `size: [small, medium, large]` + Material 3's `density:
[comfortable, default, compact]`.

**Should `target_only: true` be declared?** NO. draft.8 §7.12 explicitly
lists "size axis where ANY binding exists" as a case where
`target_only` does NOT apply: "when `size` has SOME bindings (border-
radius, shape.corner), even incomplete binding is enough that
`target_only` isn't the signal" (F-material-fab-sizing). USWDS Button's
`size` axis has NO bindings at all in this spec — but the property is
still legitimately exposed (USWDS HAS distinct `default` / `big` CSS
for the button, consumers need the enum to select it).

**The distinction made concrete:**

- **target_only: true** — *"this axis lives entirely in the target
  generator's utility classes / Sass helpers; no DS tokens model
  it, the absence is intentional"*. Third-DS confirmed (shadcn
  `size`, Primer `size`, Material 3 `density`).
- **axis without bindings but not target_only** — *"this axis maps
  to discrete arithmetic expressions in the DS source that the CDF
  `tokens:` block doesn't model because they're not tokens — but
  they ARE the DS's intentional sizing definition"*. USWDS Button
  `size` is the first instance of THIS shape.

The two are NOT the same. Both land "no bindings in `tokens:`" but
for DIFFERENT reasons.

**Suggested fix:**
draft.9 §7.12 doc-polish: clarify `target_only`'s trigger condition.
"Use `target_only: true` when the axis's resolution lives in the
TARGET generator's non-DS code (utility classes, component-library
props). Do NOT use it when the axis's resolution lives in the DS
itself as non-token arithmetic — that is a different category of
missing binding, covered by the general 'this CDF spec doesn't
model every detail' exception. A future draft MAY add a second flag
(e.g. `derived_by_source: true`) if this shape becomes common; one
instance is insufficient evidence."

**Verdict:** doc-polish / narrow draft.9 candidate (second flag) —
NOT a format budget-spend, NOT a draft.9 blocker. One-DS observation
only.

**Effort:** doc-polish, 1 paragraph.

---

## F-uswds-inverse-variant: context-dependent "variant" modelled as flat variant

**USWDS reality:**
`.usa-button--inverse` is a MODIFIER class that composes with
`.usa-button--outline` OR `.usa-button--unstyled`:

```scss
.usa-button--outline {
  ...
  &.usa-button--inverse { ... }
}
```

Visually it says: "this button sits on a DARK background — use
light-on-dark colour tokens instead of dark-on-light". In USWDS it
is SEMANTICALLY a variant (inverse) that applies to TWO base
variants (outline, unstyled). A pure "variant" axis is structurally
wrong — `inverse` isn't disjoint from outline / unstyled.

**CDF modelling options:**
- (a) **Flat expansion** — `variant: [default, secondary, accent-
  cool, accent-warm, base, outline, unstyled, inverse]`. Inverse
  becomes its own variant, loses composability.
- (b) **Boolean property** — `inverse: boolean` with a
  `conditional:` rule: "only applies when variant ∈ {outline,
  unstyled}". CDF §7.10 `conditional` grammar supports this.
- (c) **Compound state** — treat (outline, inverse) and (unstyled,
  inverse) as discrete compound_states overrides. Requires the
  inverse flag as a separate axis.

USWDS Button chose (a) — flat expansion. Rationale:
- Tokens block is clean (no cross-axis logic needed).
- `inverse` only combines with TWO existing variants, so the
  expansion is small (8 variants, not 16).
- Consumer API matches USWDS's actual class composition
  one-to-one: a consumer writes `class="usa-button usa-button--
  inverse"` → `variant=inverse` in our spec. The fact that
  USWDS requires `.usa-button--outline.usa-button--inverse` for
  the stroked inverse case is captured in the
  `border-color.inverse` + `color.inverse` bindings (filled
  inverse without outline is visually identical — no stroke).

**CDF status:**
Legal today — the format has no rule against flat-variant expansion
for context-dependent modifiers. Option (b) would also work cleanly
(draft.8's `conditional:` grammar supports it). Option (c) would
work for truly compositional modifiers across many variants.

**Suggested fix:**
None to format. A §7.10 `conditional:` example showing "boolean
property that applies only for a subset of variant values" would be
doc-polish — Material 3's Button doesn't need it, shadcn's doesn't
need it, USWDS Button could use it but prefers the flat encoding.

**Verdict:** modelling-choice observation, format-neutral.
**Effort:** doc-only.

---

## F-uswds-forced-colors: OS-signal media query via §14.4 css: escape hatch

**USWDS reality:**
USWDS applies `@media (forced-colors: active) { border: 1px solid
ButtonBorder; }` inside `.usa-button`'s Sass. This triggers only
when Windows High Contrast Mode (or an equivalent OS-level forced-
colors signal) is active. The browser paints at runtime via the
media query — the DS does not have a separate "high-contrast mode"
variant of its tokens.

**CDF status:**
Expressed via `behavior.forced_colors.css:` per §14.4. The escape-
hatch accepts raw CSS declarations, including `@media` rules.
Parses and validates cleanly on this spec.

> **Note on §14.4 prose constraint:** §14.4's current scope is
> declarations without `@media` wrapping — `pointer-events: none;`
> is the canonical example. An `@media (forced-colors: active) { … }`
> inside a `css:` string is a SUPERSET of this scope. The validator
> does not reject it (no syntactic CSS check exists), and it is the
> natural fit semantically — USWDS has five such declarations
> across Button + Alert, all OS-signal-driven, none token-bindable.
>
> draft.9 doc-polish candidate: extend §14.4's prose to acknowledge
> `@media (prefers-*)` + `@media (forced-colors: active)` as legal
> `css:` content when the signal is OS/browser-driven and not
> expressible as a DS theme modifier. One sentence.

**Suggested fix:** §14.4 doc-polish only; no format change.

**Verdict:** format absorbed; §14.4 doc-polish preferred but not
required for v1.0.0 final.

**Effort:** doc-polish, 1 paragraph.

---

## F-uswds-static-states: single-state components OMIT the states block

**USWDS reality:**
Alert is non-interactive at the component boundary — no hover /
pressed / focus / disabled. The Profile's `static` interaction
pattern defines a single-state axis (`[enabled]`).

**CDF status (validator-discovered):**
Declaring `states: { interaction: { values: [enabled] } }` at the
Component level fails validation:

```
[error] State must have 'values' array with at least 2 entries.
```

The validator rule enforces ≥2 state values per axis. For a truly
static component, the correct idiom is to **omit the `states:`
block entirely** — the Profile's `static` pattern is implicit via
the Category default. shadcn Badge and Primer Label prior art both
omit `states:` the same way.

Same category as F-Radix-1 / F-shadcn-1 / F-primer F-shadcn-1
carry-over observations — **spec wording is right, the idiomatic
expression is legible once you know it** (Profile §10's `static`
pattern is one-state by design; the Component simply doesn't need
to re-declare it).

**Suggested fix:**
draft.9 §8.1 doc-polish: one-line note — "For Components that
inherit a single-value interaction pattern (`static`), omit the
`states:` block entirely; do NOT declare a one-value axis."
Prior-art reference to shadcn Badge / Primer Label / USWDS Alert.

**Verdict:** validator rule is correct; spec doc can clarify.
**Effort:** 1-line doc-polish.

---

## F-Radix-4-resolution: conditional ARIA via §15.3 narrative format

**USWDS reality:**
Alert's five intents drive a three-axis ARIA matrix:

| intent    | role    | aria-live | aria-atomic |
|-----------|---------|-----------|-------------|
| info      | status  | polite    | true        |
| success   | status  | polite    | true        |
| warning   | status (USWDS convention) | polite | true |
| error     | alert   | polite (USWDS softens role's default) | true |
| emergency | alert   | assertive | true        |

Two role values, three politeness values, one invariant, one implicit
decorative-icon rule. F-Radix-4 first flagged conditional ARIA as an
open question; Radix's Dialog surfaced the structural pattern, USWDS
Alert provides the concrete two-DS evidence.

**CDF status — §15.3 narrative `aria:` list absorbs cleanly:**

```yaml
aria:
  - "role: status — when intent ∈ {info, success} (implicit aria-live=polite; non-urgent notification)"
  - "role: alert — when intent ∈ {error, emergency} (implicit aria-live=assertive; urgent / interrupts AT output)"
  - "role: status — when intent = warning (USWDS convention: soften to polite; role=alert acceptable when urgency warrants it)"
  - "aria-live: assertive — when intent = emergency (emphasises role=alert's implicit assertiveness for highest severity)"
  - "aria-live: polite — when intent = error (USWDS convention: softens role=alert's implicit assertive; consumer MAY override to assertive for page-blocking errors)"
  - "aria-live: polite — when intent ∈ {info, success, warning} (matches role=status's implicit polite)"
  - "aria-atomic: true — always (ensures the full body is re-announced on update, not just the changed node)"
  - "aria-hidden: true — on the ::before icon pseudo-element (decorative)"
```

Eight narrative entries cover the full ARIA contract. Each entry
follows §15.3's `aria-{attr}: {value-or-rule} — {trigger-condition}`
pattern. Legibility holds under the five-intent matrix: **the
pattern scales.**

Validator silent — §15.3 explicitly documents narrative strings as
"loosely parsed" with only `aria-` prefix and `—` separator as
structural requirements. The eight entries above include two
`role:` entries (NOT `aria-role:` — `role` is the actual ARIA
attribute) and two `NOTE:` entries. These are legal extensions of
the narrative shape.

**Comparison with other DSes:**

| DS       | Conditional ARIA exercise | Format response |
|----------|---------------------------|-----------------|
| Radix    | Dialog `role` depends on modal state | Deferred F-Radix-4 |
| shadcn   | inherited from Radix | no new evidence |
| Primer   | no ARIA intent-switching Component in the 2-component scope | no new evidence |
| Material 3 | Button / FAB plain `<button>` — no intent-switching | no new evidence |
| **USWDS** | **Alert 5-intent × role × aria-live × atomic matrix** | **§15.3 narrative absorbs cleanly** |

**Verdict:**
F-Radix-4 **resolved via prose** — §15.3's narrative format handles
five-intent conditional ARIA legibly. A structured-ARIA grammar
(reserved for v1.0.0 final per §15.3's closing note) would be
additional machine-checkability, NOT a prerequisite for correctness
or legibility. Draft.9 doc-polish candidate: add the USWDS Alert
ARIA block as an example in §15.8 alongside Dropdown / InputCore /
Button.

**Suggested fix:** §15.8 example addition.
**Verdict:** F-Radix-4 closes. No format surface needed.
**Effort:** doc-polish (1 example block).

---

## F-uswds-validation: full-suite validator run

**USWDS reality:**
```
<ds-test-dir>/specs/button.component.yaml: 0 errors / 0 warnings / 0 info
<ds-test-dir>/specs/alert.component.yaml:  0 errors / 0 warnings / 0 info
Total: 0 / 0 / 0
```

- CDF-CON-008 (no-raw-unitless-tokens) — **silent on both specs**.
  Fifth-DS data point for the Token-Driven Principle (shadcn +
  Primer + Material 3 + now USWDS). USWDS's token surface carries
  NO unitless-raw values in the `tokens:` blocks; every CSS
  property binds to a token path or `none`.
- `target_only: true` — NOT exercised on either Button's `size` or
  Alert's `shape` axes (F-uswds-touch-target explains why for
  Button; Alert `shape` is a structural axis, not a sizing axis).
  Fourth-DS data point is absent this pass — draft.8 T1 stays on
  three-DS evidence (shadcn + Primer + Material 3).
- Single-ring focus (§13.5.1) — Button's `outline-color:
  color.focus` binding is a fourth-DS confirmation of the pattern
  (shadcn + Primer + Material 3 prior).
- `states:` block — omitted on Alert, declared on Button. Validator
  rule on ≥2 values enforced cleanly (F-uswds-static-states).

**CDF status:** format absorbed USWDS at draft.8 without surfacing
any genuine gap. Five-in-a-row 0/2 + 0/1.

**Verdict:** pass.
**Effort:** n/a.

---

*End of per-step findings. See docs/BIG-DS-USWDS-FINDINGS.md for
the summary + verdict.*
