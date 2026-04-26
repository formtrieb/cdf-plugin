# shadcn/ui Port — Findings

Running log of format frictions encountered while porting shadcn/ui's
Button and Badge to CDF v1.0.0-draft.6. Per the brief (step 4) each
entry is categorised:

- **Real format gap** → draft.7 candidate (spec change + rationale)
- **Validator behind spec** → cdf-core TODO (spec fine, validator lags)
- **My misunderstanding** → NOT logged (fix the spec instead)

Format per the brief:

```
## F-shadcn-N: short title
**shadcn reality:**
**CDF status:**
**Suggested fix:**
**Verdict:**
**Effort:**
```

**Format-change budget for this pass:** ≤2 new optional fields, ≤1 new
toggle. Slightly looser than Radix because the token-bridge is genuinely
new territory. If exceeded → stop, write up, defer Material 3.

Carry-over Radix findings stay in the radix entry of the foreign-DS corpus; only
re-log here if shadcn surfaces a NEW dimension of the same friction.

---

## F-shadcn-0: token-bridge strategy — (γ) Hybrid semantic-shape

**shadcn reality:** shadcn ships tokens as CSS custom properties in
`globals.css`, configured by `tailwind.config.ts`. Consumer adoption
typically copies `globals.css` into the consumer's project and then
*forks* it. **The DS does not own the values — the consumer does.**
The token names are flat CSS vars (`--background`, `--primary`,
`--primary-foreground`, `--radius`, etc.), not a dotted grammar.

**CDF status:** CDF's token system in draft.6 offers two addressing
shapes:
  - `token_grammar` — pattern-matched dotted paths with axes
    (Profile §6). Good for families; wrong for shadcn's flat names.
  - `standalone_tokens` — singleton or small-enumeration token paths
    with `dtcg_type` + `description` (Profile §6.11). Good for
    shadcn's flat surface, but has no field indicating the values are
    *external / consumer-owned*.

Three strategies were considered before authoring (per the brief):
  - **(α)** — enumerate every shadcn token as a `standalone_tokens`
    entry, treat descriptions as informational. Works but is silent
    about ownership.
  - **(β)** — introduce a new Profile field `token_provider: { kind:
    external, source: tailwind, reference: ./globals.css }`, leave
    tokens un-enumerated. Most honest; spends 1 of 2 format-budget
    slots on single-pass evidence.
  - **(γ)** — declare the semantic concepts as `standalone_tokens`
    (shape), begin every `description:` with `"external — …"`
    (ownership). No new format fields; zero budget spent.

**Decision:** (γ), as recommended. Radix discipline says "budget 0/0
until two components prove a real gap"; spending a field slot pre-
emptively contradicts that. (γ) can also escalate cleanly to (β) if
Button+Badge show the `description:` prose isn't enough.

**Suggested fix:** None for draft.6 (the decision IS the fix). Log
downstream findings if the pairing pattern or the externality
signalling turns out to be insufficient structurally.

**Verdict:** Accepted format, deliberate convention choice.
**Effort:** none (convention-only).

**Post-authoring resolution (after Button + Badge):** (γ) held.
Both specs validate clean with zero format changes. The bridge
carried 20 standalone_tokens across six Button variants and four
Badge variants without structural gap. The pair-pattern observation
(F-shadcn-6 below) confirms the only "loss" is prose-duplication
across two components — that is cosmetic, not structural. Honest
verdict: the (γ) bridge is sufficient for this level of DS, and the
token_provider field (β) would have been over-engineered.

**Footnote added 2026-04-16 after Primer pass (F-primer-1):**
**(γ) is a principle, not a mechanism.** The principle is *prose-
ownership in `description:`, no new format field*. The mechanism
adapts to the source shape: shadcn's flat CSS-vars naturally land in
`standalone_tokens`; Primer's grammar-shaped DTCG paths
(`button.{variant}.{element}.{state}`) naturally land in
`token_grammar` with the same prose ownership in the grammar's
`description:`. Both expressions satisfy (γ). Future foreign-DS
briefs MUST NOT pre-commit to a specific structural mechanism
when pre-committing to (γ); the choice between
`standalone_tokens` and `token_grammar` is a property of the
source's shape, not of the bridge strategy.

---

## F-shadcn-1: Profile-vocabulary type shorthand is rejected by cdf-core

**shadcn reality:** The Profile declares two vocabularies, `variant`
and `size`. Authoring Button naturally wants `type: variant` / `type:
size` on the corresponding properties, mirroring the spec's own
example at §7.2 ("a `type:` value that matches a Profile vocabulary
key … is shorthand for `type: enum` + `values: [<vocabulary values>]`,
profile-aware validators MUST resolve these at validation time").

**CDF status:** Spec §7.2 mandates the shorthand. The validator rule
`property-type-valid` does not implement it — it accepts only `enum`,
`boolean`, `string`, `IconName`, or a PascalCase custom type. `type:
variant` fails with *"Type 'variant' is not a recognized type."*
Workaround used here: fall back to `type: enum` + inline `values: […]`
duplicating the Profile vocabulary, with a comment pointing at this
finding.

This is the same category of drift as F-Radix-1 (parser treats
spec-optional fields as required). Spec is right; cdf-core lags.

**Suggested fix:** Implement the shorthand in `property-type-valid`:
when a `type:` value is not in the core list, resolve it against the
loaded Profile's `vocabularies:` keys before rejecting. The validator
already has the Profile in scope (ValidationContext.profile).

**Verdict:** Cdf-core TODO. Spec is already right.
**Effort:** small.

---

## F-shadcn-2: `size` axis has no DS tokens to bind to

**shadcn reality:** Button's `size` property (`default | sm | lg |
icon`) affects height + padding + font-size + gap. shadcn ships these
as Tailwind utility class bundles hardcoded in the variant
definitions (`h-10 px-4 py-2` for default, `h-9 px-3` for sm, …).
There are NO DS tokens like `button.height.default` or `spacing.sm`;
the DS owns only the colour + radius + ring variables.

**CDF status:** The Component `tokens:` block can legally omit a
binding — §13 does not require every property axis to have token
bindings. The spec authoring produces an honest result: `size`
declared as a property, but the `tokens:` block has no `height:`,
`padding-inline:`, or `gap:` bindings. The property therefore drives
NOTHING visible in the CDF's output — consumers of the spec (LLMs,
generators) see a size property with no effect unless they know to
read the Target layer.

A generator targeting shadcn would need to know: *"when Component
declares a property whose effects live entirely in the Target's
utility bundles, emit class-selection logic, not token lookups."*
CDF today has no formal handshake for that.

**Suggested fix:** Either
  (a) document as an accepted tension — utility-first DSes have
      axes whose effects are Target-owned. The `size` property is
      a signalling axis; the Target layer is where it lands.
  (b) add a `property.{p}.target_only: true` flag that makes the
      absence-of-bindings intentional rather than accidental.

(a) costs nothing. (b) would burn a format-budget slot but produces
a machine-readable signal. Single-component evidence is weak; defer.

**Verdict:** Accepted tension. Revisit if Material 3 shows the same
pattern — then it would be two-DS evidence for (b).
**Effort:** none (a) / small (b, deferred).

---

## F-shadcn-3: State-driven colour variation via opacity, not tokens

**REFRAMED after session review (2026-04-17).** The first version of
this finding described CDF as "missing a representation" for runtime
opacity math. That framing was wrong and would have misdirected the
Material 3 pass. Corrected below.

**shadcn reality:** Button's hover state darkens the variant
background by applying Tailwind's opacity-modifier syntax —
`hover:bg-primary/90`, `hover:bg-destructive/90`, etc. There is no
distinct `--primary-hover` CSS variable. Disabled state uses
`disabled:opacity-50` — same mechanism applied to the whole element.
shadcn's state model is "mutate the enabled colour via opacity at CSS
runtime," not "swap tokens per state."

**CDF status:** CDF is **token-driven by principle**. A Component's
`tokens.{part}.{property}` binds to exactly one token path; the
token-system resolves that path to a single DTCG value at
**token-build time**. When a Button has a distinct hover appearance,
the correct shape is **a distinct token**:

```
color.primary.base   → lch(54% 40 250)
color.primary.hover  → lch(54% 40 250 / 0.9)    ← alpha in the value
```

Two tokens, two entries in the token system. The alpha is baked into
the DTCG `$value` at build time, not computed at CSS runtime. This is
how Formtrieb already works (`color.controls.primary.stroke.hover` is its
own entry with its own value, computed by the token toolchain).

shadcn's `hover:bg-primary/90` is a **Tailwind runtime utility**:
`--primary` is stored without alpha, and the hover is computed in the
browser via `color-mix()` or equivalent. **The alpha exists only in
the stylesheet, never in the token system.** This is a legitimate
architectural choice for shadcn — but it is *not* token-driven for
states. That's the real tension.

**Consequence for this port:** Button's `tokens:` block binds only the
**enabled** colour per variant. The `interaction` state axis is
declared but has no per-state token overrides, because shadcn has no
per-state tokens to point at. A consumer who takes the spec as
normative would either:
  - (A) invent the missing hover/disabled tokens at their end
    (making shadcn more token-driven on the consumer side), or
  - (B) implement the runtime opacity modifier as a Target convention
    and skip the per-state token altogether.

The spec is silent on which choice is correct — both are reasonable
adaptations, but neither is captured in the CDF artifacts. That IS
a documentation gap, but it's not a format-mechanism gap.

**Suggested fix:**
  (a) Add a §13 prose note — "a token-driven DS declares distinct
      state tokens at build time (`color.X.hover` with alpha baked
      in). DSes that rely on CSS-runtime opacity modifiers (Tailwind,
      utility frameworks) diverge from this principle and MUST
      declare the divergence explicitly — typically as
      `description:` annotations on the affected Profile tokens." No
      format change.
  (b) **Reject** the earlier suggestion to extend §13.6 with
      derivation expressions (`color.primary @ 90%`). That would
      import runtime math into the format and break the
      build-time-resolution invariant. Not a draft.8 candidate —
      not ever, unless CDF abandons token-driven semantics.

**Verdict:** Documentation gap, not format gap. Add (a) to the draft.7
spec notes. (b) withdrawn.
**Effort:** small (docs-only).

**Material 3 implication (corrected):** Material's "state layers"
(12% base colour overlay on hover, 16% on pressed, etc.) is the same
architectural choice — runtime overlay math instead of discrete state
tokens. For a CDF port of Material 3, state layers MUST be declared
as discrete tokens with pre-computed alpha values. The Material
design spec's "12% overlay" rule becomes a token-build-time rule,
not a runtime rule. This is not CDF accommodating Material — it is
CDF imposing its token-driven discipline on a Material port.

---

## F-shadcn-4: Variant-destructive foreground — shadcn's own inconsistency

**shadcn reality:** The Profile declares `color.destructive` paired
with `color.destructiveForeground`, because older shadcn Buttons
used both. shadcn v4's Button source, however, uses a literal
`text-white` for destructive's label rather than the paired token.
Badge's destructive variant, meanwhile, still uses the pair. The DS
is not internally consistent across components.

**CDF status:** This is a shadcn-internal friction, not a CDF
friction — the format has no opinion on whether two components
should agree on token bindings. But it does surface a question the
format might want to answer: *"the Profile declares a pair; should
a validator warn when a Component uses only half of it, or binds the
half to a non-paired value?"*

Authored Button binds `color: color.primaryForeground` for the
destructive variant (treating it as white-ish), knowing this is a
cosmetic approximation. F-shadcn logs the inconsistency; no spec
change proposed.

**Suggested fix:** None for the format. Optionally, a Profile-level
advisory: pairs declared in `standalone_tokens` descriptions could
be formalised as `pairs_with: color.primaryForeground`, enabling a
"lint-level" check. That's the escalation path mentioned in F-shadcn-0
option (β) — still too little evidence.

**Verdict:** Accepted tension. Not a CDF gap.
**Effort:** none.

---

## F-shadcn-5: Focus ring is one token, not a focus block

**shadcn reality:** Focus-visible styling applies a single ring
colour + width + offset, derived from `--ring` (semi-transparent)
plus utility defaults. There is no outer+inner ring pattern, no
per-component focus variation.

**CDF status:** §13.5 `focus:` block is optimised for structured
patterns (`double-ring`, named groups like `focus.outer`/`focus.inner`).
For shadcn's single-ring case, using the §13.5 block would require
the Profile to declare a trivial focus grammar — overkill when the
entire need is `outline-color: color.ring`.

Spec authored the ring as a plain `outline-color:` binding on
`container`. Works, validates, but loses the semantic signal that
"this is the focus ring, not a regular outline." A downstream
generator wouldn't distinguish focus-visible styling from default
outline rendering without additional cues.

**Suggested fix:** Document that single-ring patterns MAY use a
plain `outline-color:` binding rather than the §13.5 block; add a
cross-reference from §13.5 explaining when the block is and isn't
appropriate. Pure docs fix.

**Verdict:** Spec clarification (draft.7). Single sentence in §13.5.
**Effort:** trivial.

---

## F-shadcn-6: Pair pattern duplicates literally across components

**shadcn reality:** Button and Badge both need variant → background +
foreground bindings. For the four variants they share (`default`,
`secondary`, `destructive`, `outline`), the Component-level bindings
are BYTE-IDENTICAL across the two specs:

```yaml
# Button (lines 150–170)
background:
  default: color.primary
  secondary: color.secondary
  destructive: color.destructive
  outline: color.background
color:
  default: color.primaryForeground
  secondary: color.secondaryForeground
  destructive: color.primaryForeground
  outline: color.foreground

# Badge — identical bindings for the same four variants
```

A third or fourth shadcn component using the same variant vocabulary
(Alert, Card, Tooltip trigger, …) would duplicate the same pairings
a third / fourth time. The Profile declares that the pair exists
(prose in descriptions); the binding of variant-name → pair is
re-typed per component.

**CDF status:** No format mechanism for shared variant-to-token
bindings. `inherits:` / `extends:` (§5) operate on WHOLE components,
not on fragments of a tokens: block. There is no "mixin" concept for
tokens (§13.4 typography mixins exist as an extension hint but no
grammar).

The question is whether the duplication is cosmetic or structural:
  - **Cosmetic argument:** each component's variants may diverge
    over time (Badge might gain a `subtle` variant Button doesn't
    need; Button's `ghost` maps differently than Badge would). A
    shared binding would force unintended coupling. The per-component
    re-typing is the price of per-component autonomy.
  - **Structural argument:** for the cases where bindings DO
    correspond (Button + Badge's first four variants), there is no
    way to assert that correspondence. A consumer swapping
    `color.primary` for `color.accent` must remember to update every
    variant=default binding everywhere; nothing in the format
    catches drift.

My read after writing both specs: **cosmetic**. The re-typing is
short (value-map form keeps it dense), and the autonomy is
genuinely useful — Button needs `ghost`/`link` bindings Badge
doesn't want. A format-level abstraction would optimise for the
4-of-6 overlap at the cost of making the 2-of-6 divergences
awkward. The accepted tension is the right call.

**Suggested fix:** Accept. Document the pattern as a shadcn-style
DS convention: variant-to-token pairing is Profile-declared in
prose, Component-enforced by convention, and MAY duplicate across
components where they share variants. A future Profile feature
could formalise it (e.g. `variant_bindings:` at Profile level,
Components inherit unless overridden) — but not from two-component
evidence.

**Verdict:** Accepted tension. Defer to third-component evidence.
**Effort:** none (a) / medium (format-level variant_bindings, deferred).

---

## Summary counters

| Bucket | Count |
|---|---|
| Real format gap → draft.7 candidate | 1 (F-shadcn-5, doc clarification) |
| Validator behind spec → cdf-core TODO | 1 (F-shadcn-1) |
| Accepted tension | 4 (F-shadcn-0/2/3/4/6 — 0 is strategy, 4 is shadcn-internal) |
| **Format-change budget consumed** | **0 / 2 fields, 0 / 1 toggles** |

Zero new fields; zero new toggles. The (γ) token-bridge absorbed
Button + Badge without any format change. The only new cdf-core TODO
is a validator implementation of §7.2 shorthand that already exists
as normative spec text.
