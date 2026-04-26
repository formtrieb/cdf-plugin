# Primer Port — Findings

Running log of format frictions encountered while porting
`@primer/primitives`-backed Button and Label to CDF v1.0.0-draft.7.
Same categorisation as Radix / shadcn:

- **Real format gap** → draft.8 candidate (spec change + rationale)
- **Validator behind spec** → cdf-core TODO (spec fine, validator lags)
- **My misunderstanding** → NOT logged (fix the spec instead)

Template:

```
## F-primer-N: short title
**Primer reality:**
**CDF status:**
**Suggested fix:**
**Verdict:**
**Effort:**
```

**Format-change budget for this pass:** ≤2 new optional fields, ≤1 new
toggle. Same as shadcn. If exceeded → stop, write up, defer Material 3.

Carry-over Radix and shadcn findings stay in their own files; only
re-log here if Primer surfaces a NEW dimension of the same friction.

---

## F-primer-0: Primer provisioning and layout deviation

**Primer reality:**
Cloned `primer/primitives` into `<ds-test-dir>/.primer-primitives`
(gitignored). Pinned commit: **`c19e78df9f3b98a9be4ee5da8bd7f8cb5b74298f`**.
Clone date: **2026-04-16**.

The brief's expected layout assumed parallel per-theme folders:

```
src/tokens/functional/color/light/
src/tokens/functional/color/dark/
src/tokens/functional/color/light_colorblind/
…
```

The **actual** layout at this SHA is single-file-per-concept with
mode-specific values attached via DTCG `$extensions`:

```
src/tokens/
  base/color/{light,dark}/<files>        # base palette per mode
  functional/color/*.json5               # SEMANTIC mappings, one file per role
  component/*.json5                      # per-component token trees
```

Every functional/component token entry has an `$extensions.org.primer.overrides`
block that carries per-mode deltas — e.g. `control.bgColor.rest.$value`
(the light default) + `$extensions.org.primer.overrides.dark.$value`
(the dark override) + further overrides for `dark-dimmed`,
`dark-high-contrast`, `dark-tritanopia-high-contrast`,
`dark-protanopia-deuteranopia-high-contrast`, `light-high-contrast`,
`light-tritanopia-high-contrast`, `light-protanopia-deuteranopia-high-contrast`,
`light-dimmed`, etc. The brief's "eight theme variants" count is real
but the representation is **one canonical entry + named extension
overrides**, not eight parallel token trees.

Additionally, files are `.json5` (not `.json`). The `$extensions`
payload uses `org.primer.figma` (scopes, collection, group metadata)
and `org.primer.overrides` (per-mode value overrides) and `org.primer.llm`
(human/LLM usage rules on some functional tokens).

**CDF status:**
Neither layout assumption nor extension-based mode mapping is a CDF
requirement. CDF's contract with a token toolchain is *"every enumerated
path resolves to one DTCG value at token-build time, per theme mode"*
(Profile §6 Build-Time Enumerability, draft.7). Whether the toolchain
gets there via parallel files or `$extensions.overrides` is out of CDF
scope. The (γ) bridge stays intact — prose in `description:` carries
the source reference and mode-mapping note, and the Profile declares
`semantic: [Light, Dark]` as the axis without prescribing how values
resolve.

The `$extensions.org.primer.overrides` also carries multi-mode
metadata (`dark-dimmed`, eight+ vision-accommodation variants). The
brief pre-committed scope to Light + Dark only; vision-accommodation
modes are **out of scope for this pass** (see F-primer-2 for the theme
axis decision).

**Suggested fix:** none — layout + extension-based theming is Primer's
choice, not a CDF gap. Document the adaptation in Profile prose.

**Verdict:** Accepted reality. (γ) absorbs the source unchanged.
**Effort:** none (informational).

---

## F-primer-1: (γ) mechanism shift — standalone_tokens → token_grammar

**Primer reality:**
The brief pre-committed the (γ) token-bridge strategy, described in
shadcn findings F-shadcn-0 as *"declare the semantic concepts as
`standalone_tokens`, every `description:` starts with 'external —'
to signal consumer ownership."*  The brief also set a budget of
**≤25 `standalone_tokens`** as a tripwire — "if the bridge needs more
to stay honest, log as F-primer-1 before pushing past 25."

Primer's source at `src/tokens/component/button.json5` and
`src/tokens/component/label.json5` is natively **grammar-shaped**:
every leaf path has the form `{component}.{variant}.{element}.{state}`.
Modelling this via `standalone_tokens` with `values:` compression
(one entry per variant × element, a `values: [rest, hover, active,
disabled]` enumeration per entry) would take:

- Button: 5 variants × 3 elements = 15 `standalone_tokens` entries
- Label: 7 schemes × 3 elements = 21 `standalone_tokens` entries
- Singletons: 2 (radius, focus.outline)
- **Total: ~38 entries** — clean past the 25-entry budget tripwire.

**CDF status:**
Profile §6.11.4 explicitly addresses the choice between `token_grammar`
and `standalone_tokens`:

> A practical rule of thumb: if a path has `{placeholder}`-style
> variation a CDF Component might want to address through a property
> or state, it belongs in `token_grammar`.

Primer's paths have exactly that kind of variation — the Button spec
addresses `{variant}` through a property, and would address `{state}`
through the interaction state axis if state variation were wanted.
The honest CDF mechanism for grammar-shaped sources is `token_grammar`,
not `standalone_tokens`. The brief's "enumerate as standalone_tokens"
assumption treated Primer like a flat CSS-var dump, which it isn't.

**What changed in the Profile:**
`primer.profile.yaml` declares two `token_grammar` entries
(`color.button`, `color.label`) whose `description:` fields carry
the same "external — from @primer/primitives …" prose ownership
annotation that `standalone_tokens` would have carried. The (γ)
**principle** — prose ownership, zero new format fields — is
preserved. The (γ) **mechanism** (which section of the Profile
carries that prose) adapts to the source shape.

`standalone_tokens` count in the final Profile: **2** entries
(`radius.default`, `color.focus.outline`) — well under budget, but
only because 36 of the would-be entries became two grammar entries.

**Suggested fix:**
None format-side. The brief's budget framing assumed the mechanism.
The result — **0/2 format fields, 0/1 toggles** — is identical to
what a 15+21+2 standalone_tokens accounting would have scored on
the budget lines that matter (new fields, new toggles). The budget's
intent is preserved.

Documentation-wise: a small update to F-shadcn-0's language in the
shadcn findings that introduced the (γ) label would help — "(γ) is
a principle, not a mechanism; mechanism adapts to source shape
(flat names → standalone_tokens, grammar-shaped → token_grammar)."
This is a one-line footnote in BIG-DS-SHADCN-FINDINGS.md F-shadcn-0;
it is deferred here and called out in the summary doc verdict.

**Verdict:** Accepted reality. (γ) principle preserved via mechanism
shift. NOT an escalation to (β) (no new `token_provider` field needed).
**Effort:** none format-side; one-line doc clarification to F-shadcn-0
optional.

---

## F-primer-2: Theme axis — eight+ modes collapsed to two

**Primer reality:**
Primer ships an exceptionally rich theme matrix. The
`$extensions.org.primer.overrides` keys across the functional + component
token files include (in addition to the default `light` value):

```
dark
light-high-contrast
light-tritanopia-high-contrast
light-protanopia-deuteranopia-high-contrast
light-dimmed
dark-high-contrast
dark-dimmed
dark-dimmed-high-contrast
dark-tritanopia
dark-tritanopia-high-contrast
dark-protanopia-deuteranopia
dark-protanopia-deuteranopia-high-contrast
```

That's twelve+ distinct modes, organised along two informal axes:
**semantic** (light/dark) × **vision accommodation** (default,
high-contrast, tritanopia, protanopia-deuteranopia, dimmed, and
their combinations).

**CDF status:**
CDF's `theming.modifiers` block (§9) supports multiple axes with
disjoint value sets — Formtrieb uses three (`semantic × device × shape`).
So modelling Primer's twelve modes as **two axes** is structurally
possible:

```yaml
theming:
  modifiers:
    semantic:
      values: [Light, Dark]
    accommodation:
      values: [default, high_contrast, tritanopia, protanopia_deuteranopia, dimmed]
```

That's 2 × 5 = 10 cells, not a perfect match for Primer's twelve
(some combinations don't exist — `light-dimmed` for instance is not
shipped), but close. `set_mapping:` with `null` for non-existent
cells would cover the gap.

**Decision for this pass:**
Declare only `semantic: [Light, Dark]`. Vision accommodation is
**out of brief scope** (the brief explicitly says *"Pick light + dark
as the canonical axis; log vision-accommodation variants as future-
scope in F-primer-2."*). Rationale for Light/Dark only:

1. Two components exercise almost none of the accommodation surface
   — Button and Label don't test contrast guarantees meaningfully
   enough to warrant the axis-definition work.
2. The structural question (one-axis-twelve-values vs two-axes-
   semantic×accommodation) is worth a dedicated pass, not a side-
   observation buried in a two-component port.
3. Primer's own `$extensions.overrides` keys mix the axes (e.g.
   `dark-tritanopia-high-contrast` is three combined); disentangling
   whether Primer itself treats them as orthogonal or as discrete
   modes requires reading Primer's documentation the brief flagged
   as "reference only."

**Suggested fix:**
When the next DS-port pass touches real accommodation work (likely
Material 3 via dynamic-colour + accessibility — the seed/contrast
surface), re-open the question. If Material 3 surfaces a similar
but different accommodation model, the two data points together
decide whether CDF's `theming.modifiers` multi-axis syntax is
sufficient or whether a dedicated `accommodation` modifier type
(with explicit vision/contrast semantics) is justified.

**Verdict:** Deferred scope — out of this pass's two-component frame.
Not a format gap yet; structural question re-opens with Material 3.
**Effort:** n/a (pass-boundary only).

---

## F-primer-3: DTCG `$type` redundancy vs discoverability

**Primer reality:**
Every leaf token in Primer's tree carries `$type: color` (or
`$type: dimension`, etc., for non-colour families). The CDF Profile's
grammar entry `color.button` declares `dtcg_type: color` once at the
grammar level, which covers every leaf of the family. The per-leaf
`$type` is therefore redundant relative to the Profile's grammar
`dtcg_type` declaration.

Primer's rationale for per-leaf `$type` is DTCG spec compliance —
DTCG v2025.10 requires `$type` at the leaf level for well-formedness.

**CDF status:**
CDF treats `dtcg_type` at the grammar level (Profile §6) as the
source of truth for *CDF purposes* (type-checking component bindings,
validator coverage). The fact that DTCG itself requires per-leaf
`$type` is outside CDF's enforcement scope — the CDF Profile and
the DTCG token files live side by side, each with their own typing
conventions. A CDF-aware toolchain reading both would see agreement;
a DTCG-only toolchain reading just the tree would see standard
DTCG.

No conflict. No mismatch. The brief's watch-item *"F-primer-3 if
the mismatch is more than cosmetic"* resolves with "cosmetic" — the
two typings overlap 100%, the redundancy is a DTCG-spec requirement
not a CDF-spec requirement, and a Profile reader loses nothing by
relying on the grammar's `dtcg_type` without also inspecting
per-leaf `$type`.

**Suggested fix:**
None. Worth a one-line cross-reference in the next CDF spec
evolution — something like *"when a CDF grammar's `dtcg_type` covers
a DTCG tree whose leaves also declare `$type`, the per-leaf `$type`
is redundant but harmless; both conventions can coexist."* —
already implicit in current draft.7 text.

**Verdict:** Accepted cosmetic redundancy. No action.
**Effort:** none.

---

## F-primer-4: Focus ring + pending state — two sub-items

### F-primer-4a: Single-ring focus pattern, second DS evidence

**Primer reality:**
Button applies focus-visible styling through a single-ring CSS
outline using `color.focus.outline` (standalone_token in the
Profile). No outer/inner ring pattern, no per-variant focus
variation. Exactly the same shape as shadcn (F-shadcn-5).

**CDF status:**
Same as F-shadcn-5: §13.5 focus block is optimised for structured
double-ring patterns and is overkill for single-ring. The Primer
spec uses a plain `outline-color:` binding on `container`. Validates
clean, but loses the semantic signal that this is the focus ring.

**Suggested fix:**
Same as F-shadcn-5 (deferred cross-reference from §13.5). With two
DSes now using single-ring focus (shadcn + Primer), the prose-only
fix to §13.5 is well-motivated. draft.8 candidate — same effort
estimate as F-shadcn-5 (trivial).

**Verdict:** Doc clarification, second-DS evidence strengthens the
draft.8 case. No new format surface needed.
**Effort:** trivial.

### F-primer-4b: Pending / loading state — open modelling question

**Primer reality:**
Primer's Button has a native pending state with a spinner icon
replacing children (Primer's React `ButtonComponent.tsx` wraps this
as `loading: boolean` + internal `aria-busy`). The token tree does
not carry pending-specific tokens — visual treatment reuses the
`rest`-state tokens, with an overlay/opacity effect for the spinner
ghost layer that is component-CSS-level, not token-level.

**CDF status:**
Formtrieb Button handles pending via `states.pending: {values: [false,
true], token_expandable: false}` — a boolean state axis that's
declared but doesn't drive token variation. This is the established
CDF shape for "state that exists behaviourally but has no token
consequence."

For this pass, pending was deliberately deferred to keep the
`tokens:` block focused on the token-driven principle stress test.
Mentioning it here as an OPEN QUESTION rather than a closed finding:
*"is Formtrieb's boolean-state-with-token_expandable:false the right
shape for Primer Button's pending, or would a dedicated
`states.pending: { implied_behavior: ... }` construct surface more
semantic information?"*

**Suggested fix:**
Defer until Material 3 pass. Material's loading patterns are
richer (circular progress vs. linear vs. indeterminate) and the
third-DS data point will decide whether the existing Formtrieb pattern
suffices or whether a dedicated idiom is worth introducing.

**Verdict:** Open, deferred. Not a format gap; modelling guidance
gap that a third DS will clarify.
**Effort:** n/a (deferred).

---

## F-primer-5: `size` axis unbound — second-DS evidence for F-shadcn-2

**Primer reality:**
Button's `size` property ({small, medium, large}) drives height,
padding, gap, and font-size via Primer's `control.{size}.*` tokens —
tokens that exist in Primer's tree but lie OUTSIDE this pass's
modelled grammar (`color.button.*` only). The Button spec therefore
declares `size` as a property + has no `size`-keyed entries in its
`tokens:` block for dimension, padding, etc.

This is **exactly** the friction F-shadcn-2 logged: an axis whose
effects live in a token family the Component spec doesn't address
produces a property with no declared binding.

**CDF status:**
F-shadcn-2 surfaced this first (shadcn's size axis via Tailwind
utility bundles). That finding noted:
> *"Single-component evidence is weak; defer. Revisit if Material 3
> shows the same pattern — then it would be two-DS evidence for
> a `property.target_only: true` flag."*

Primer is the second DS — making this **two-DS evidence**, crossing
the F-shadcn-2 deferral threshold, but the mechanism is slightly
different:

| DS      | Where do size tokens live?                           |
|---------|------------------------------------------------------|
| shadcn  | utility-class bundles (Tailwind), no DS tokens       |
| Primer  | DS-owned tokens (`control.{size}.*`), outside the modelled grammar |

Both produce the same spec outcome (property declared, bindings absent),
but the **reason** differs: shadcn has no tokens at all; Primer has
tokens but they're in a different token family than this pass chose
to model.

**Suggested fix:**
Two-DS evidence is enough to justify draft.8 consideration of either:

- **(a)** A `property.target_only: true` flag — signals "bindings
  absent by design, not by omission." Same proposal F-shadcn-2
  deferred.
- **(b)** A `property.token_family_ref: control.{size}` field — lets
  the Component declare "this axis binds into a token family the
  Profile grammar covers, but is not part of THIS component's modelled
  grammar subset." More precise but more structural.

Both burn format budget. Recommend (a): smallest change, widest
applicability (covers both shadcn + Primer patterns under the same
flag), weakest machine-readable signal (just "intentional absence").

**Verdict:** Draft.8 candidate. Two-DS evidence justifies the field
F-shadcn-2 first proposed. Scope is surface-marking, not value-binding.
**Effort:** small (one optional boolean on properties schema).

---

## F-primer-6: Semantic ↔ colour naming gap — Label scheme vs token colour

**Primer reality:**
Primer's React Label component exposes a `variant` prop with semantic
values: `default | accent | success | attention | severe | danger |
done | sponsors`. These values do NOT appear anywhere in
`@primer/primitives src/tokens/component/label.json5` — the token
tree keys by COLOUR name (`green`, `orange`, `purple`, `red`,
`yellow`, `gray`, `blue`, `auburn`, `brown`, `lemon`, `olive`,
`lime`, `pine`, `teal`, `cyan`, `indigo`, `plum`, `pink`, `coral`).

The semantic-to-colour mapping lives inside `@primer/react`'s
`Label.tsx` component source:

```
default → gray       accent → blue       success → green
attention → yellow   severe → orange     danger → red
done → purple        sponsors → pink
```

**CDF status:**
CDF Profiles model the **token surface**, not a specific component
library's API. The Primer Profile's `label_scheme` vocabulary uses
the colour-keyed values because that is what the tokens provide.
Modelling the semantic names in the Profile would require a
`label_scheme_semantic: [accent, success, …]` vocabulary plus an
explicit mapping from semantic names to colour-keyed tokens —
equivalent to embedding Primer-React's Label-component logic in the
Profile, which conflates concerns.

The same friction COULD appear in other DSes that separate
semantic-API-layer naming from token-keyed naming. shadcn doesn't
have it (shadcn's variant values match its token names 1:1). Formtrieb
doesn't have it (hierarchy names are used both in tokens and
Components). Primer is the first DS in this pass series where the
consumer-facing API and the token-key surface diverge.

**Suggested fix:**
None format-side. The CDF Profile honestly models the colour-keyed
surface; a component library wrapping it (Primer-React's Label.tsx,
or a hypothetical CDF-consuming Angular library) adds the semantic
wrapper at its own layer. Document this as the recommended pattern:
*"when a DS's component library exposes semantic API naming that
differs from the token key naming, the Profile models the token
keys; the semantic wrapper lives at the component-library layer."*
A one-paragraph addition to CDF Profile §5 (vocabulary naming)
would anchor the pattern.

**Verdict:** Accepted tension. Doc-level recommendation candidate for
draft.8 prose.
**Effort:** trivial doc addition.

---

## Summary counters

| Bucket | Count |
|---|---|
| Real format gap → draft.8 candidate | 1 (F-primer-5, `property.target_only`; two-DS evidence) |
| Validator behind spec → cdf-core TODO | 0 (F-shadcn-1 re-seen, not re-logged) |
| Accepted reality / deferred / doc fix | 6 (F-primer-0, 1, 2, 3, 4a, 4b, 6) |
| **Format-change budget consumed** | **0 / 2 fields, 0 / 1 toggles** |

Zero new fields; zero new toggles. The (γ)-principle (prose ownership
via `description:`) absorbed Primer's real DTCG source with the
mechanism shifted from `standalone_tokens` to `token_grammar` — same
budget outcome, different structural form. Draft.7's Token-Driven
Principle prose (§1.1 #2, §13 intro, §6 intro) described Primer
correctly without bending. CDF-CON-008 (the `no-raw-unitless-tokens`
rule — renumbered from the draft.7 plan's CDF-CON-006 because 006/007
were already taken) did not fire on either component — expected and
observed.

