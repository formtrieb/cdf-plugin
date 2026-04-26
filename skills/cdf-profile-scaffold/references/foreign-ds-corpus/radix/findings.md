# Radix Port — Findings

Running log of format frictions encountered while porting Radix's
Separator and Toggle to CDF v1.0.0-draft.5. Per the brief (step 4)
each entry is categorised:

- **Real format gap** → draft.6 candidate (spec change + rationale)
- **Validator behind spec** → cdf-core TODO (spec is fine, validator lags)
- **My misunderstanding** → NOT logged (fix the spec instead)

Format per the brief:

```
## F-Radix-N: short title
**Radix reality:**
**CDF status:**
**Suggested fix:**
**Verdict:**
**Effort:**
```

---

## F-Radix-1: Profile parser requires fields the spec marks optional

**Radix reality:** A headless DS has no interaction patterns, no
accessibility defaults, and no categories — Radix's primitives each
document their own a11y contract, and "Primitive vs. Interactive"
categories are an authoring convention, not a DS-level vocabulary.

**CDF status:** Profile spec §3 top-level schema marks
`interaction_patterns`, `accessibility_defaults`, and `categories` as
**optional**. The reference parser in
`packages/cdf-core/src/parser/profile-parser.ts:21-30` treats all three
as REQUIRED and throws on missing. Similarly `token_layers` is listed
optional in §6.10.5 ("A Profile that omits it is declaring …") but the
parser rejects a missing key.

**Suggested fix:** Parser follows spec — treat these fields as optional
with empty-default semantics. Author of a minimal headless Profile
should be able to omit them entirely.

**Verdict:** Cdf-core TODO. Spec is already right.
**Effort:** small.

---

## F-Radix-2: `tokens:` is a hard REQUIRED on every Component

**Radix reality:** A Separator has no visual contract. Same for a
headless Toggle. Consumers decide the look entirely in their own CSS
(or Tailwind, CSS Modules, etc.). The CDF authoring contract "every
component declares the tokens that drive its appearance" does not
apply because the component owns no appearance.

**CDF status:** Component §3 lists `tokens: REQUIRED` (top-level
schema). The structural validator
(`packages/cdf-core/src/validator/rules/structural.ts:27`) enforces
this as an error: *"Required field 'tokens' is missing."* There is no
opt-out today — not via `inherits:` (both Radix components stand
alone), not via category toggle, not via an empty `tokens: {}` that
might have been intended to signal "owns no paint" (untested here but
would still address zero anatomy parts, triggering §13.7 addressing
errors on any later binding).

**Empirical status (after writing Separator):** The structural
validator accepts an **empty** `tokens: {}` block without complaint —
`tokens: { ... }` is treated as "present" regardless of content. So
the friction is ***purely in the spec text***: §3 says "REQUIRED" and
the opening paragraph of §13 says the block "maps every visual
property of every anatomy part to a token path." Both statements are
false for headless components but no rule fires.

**Suggested fix:** Either
  (a) document `tokens: {}` as the canonical "component owns no paint"
      shape — one sentence in §13 + an example. Zero code change.
  (b) introduce a `profile.categories.{cat}.visual_contract: false`
      toggle that makes the `tokens:` key omittable entirely, so the
      empty-object workaround isn't needed.

Option (a) is the cheap, honest move — we already pass the validator.
Option (b) is only worth it if Toggle or later primitives hit a
downstream rule that an empty `tokens: {}` cannot satisfy.

**Verdict:** Spec change (draft.6), option (a) baseline. Revisit
after Toggle.
**Effort:** small (doc) or small (validator, if option b).

---

## F-Radix-3: `asChild` — runtime element polymorphism has no model

**Radix reality:** Almost every Radix primitive accepts an `asChild`
boolean prop. When true, the primitive renders into a
consumer-provided child element instead of its own default. Separator
with `asChild` renders into an `<hr>` or a `<li>`; Toggle with
`asChild` renders its behaviour onto a consumer's `<a>`. This inverts
the ownership model CDF assumes — `anatomy.container.element` is
supposed to be the tag Radix emits, but for Radix the tag is
*whatever the consumer passes*.

**CDF status:** Component §11.1 says `element:` is one of a concrete
HTML tag or an abstract box. There is no declared way to express
"this element is consumer-overridable." A boolean `as_child` property
would type-check fine, but would not interoperate with the Tier-4
cross-layer rule (CDF-XLY, per Sketch §3.4) that wants
`accessibility.element` to match `anatomy.container.element`.

**Suggested fix:** Several options, roughly in order of invasiveness:
  (a) Treat `asChild` as a *documentation-only* boolean property on
      affected components — the spec notes the override but does not
      formalise it. This loses the Tier-4 check.
  (b) Add an optional `anatomy.{part}.element_polymorphic: true` flag.
      When set, the `element:` value becomes a *default* rather than
      a contract; Tier-4 skips element-match checks for that part.
  (c) Model it as a slot with `accepts: "element"`, i.e. treat the
      rendering element itself as projected content.

(a) is what Separator and Toggle specs in this repo do today (neither
models `asChild`). It's enough to pass validation but is not honest
— a consumer reading the spec does not learn about the polymorphism.
(b) is the least invasive real fix.

**Verdict:** Spec change (draft.6 candidate) OR accepted tension,
depending on how important Radix-level fidelity is.
**Effort:** medium — one optional anatomy flag + Tier-4 rule
adjustment + doc.

---

## F-Radix-4: conditional ARIA has no declarative mechanism

**Radix reality:** Separator's `decorative` prop flips the ARIA
contract: `decorative=false` → `role="separator"` + `aria-orientation`;
`decorative=true` → `role="none"`, no `aria-orientation`. Toggle's
`pressed` state drives `aria-pressed="true|false"` (and Radix's
`data-state="on|off"` mirror). Both are *property-conditional ARIA
emissions*, not constant attributes.

**CDF status:** Component §15.3 makes `accessibility.aria:` a list of
**narrative strings**, with the rationale that "ARIA attributes have
conditional triggers that a flat attribute-to-value map cannot express
without losing legibility." The spec's own examples use the pattern
`"aria-X: value — when condition"`. So the human-readable side is
fine; the *machine-readable* side is missing. Generators cannot
derive the conditional from a narrative string.

**Suggested fix:** Leave `aria:` list-of-strings for legibility, but
add a sibling `aria_conditional:` structured block for the
machine-consumable form. Emit the narrative from the structured form
at generation time. Out of scope for draft.6; log as a draft.7
candidate so it doesn't spend budget now.

**Verdict:** Spec change (draft.7). Component-level prose is
sufficient for draft.5/6.
**Effort:** medium — new spec block, generator changes.

---

## F-Radix-5: `mirrors_state` hard-codes boolean ↔ `[false, true]`

**Radix reality:** Radix Toggle's on/off axis is externally named in
two orthogonal vocabularies — `data-state="on|off"` for CSS hooks,
`aria-pressed="true|false"` for ARIA. Neither is "wrong"; both are
normative for different audiences. My first draft declared the state
axis as `[off, on]` to make the DOM contract live inside the spec,
matching the downstream CSS selector names.

**CDF status:** Component §7.11 rule 2 says "A `boolean` property
mirrors a state axis with `values: [false, true]`." The validator
(`mirrors-state-target`) enforces this literally — my `[off, on]`
axis failed with *"not type-compatible"*. The only legal shape today
is `[false, true]`.

Workaround used in the spec: changed `toggleable` to `[false, true]`
and documented the external `on|off` vocabulary in prose. The Target
layer would do the `true → "on"` translation when emitting
`data-state`.

**Suggested fix:** Accept the tension. Two things mitigate it:
  (a) The Target layer is already the right home for DOM-naming
      conventions (§9 in CDF-TARGET-SPEC). Putting `on|off` in the
      axis values would smear a Target concern into the Component.
  (b) Formtrieb's Checkbox also uses `[false, true]` for `selected` and
      `indeterminate` — so this is consistent with how an existing
      production DS models the same concept.

The friction is **ergonomic, not structural**: the error message
could be kinder ("boolean mirrors require literal `[false, true]`;
DOM/ARIA names belong in Target"). Rule itself is correct.

**Verdict:** Accepted tension. Improve the validator message only.
**Effort:** small (message copy).

---

## F-Radix-6: `token_expandable:` required on states with no grammar

**Radix reality:** Radix ships no tokens. The Profile's
`token_grammar: {}`. Every Toggle state axis (`interaction`,
`toggleable`) exists purely to drive `data-*` attributes and
ARIA — no axis value will ever be substituted into a token path,
because there are no token paths.

**CDF status:** Component §8.1 says `token_expandable` is REQUIRED
on every state axis, and `CDF-STR-004` (Tier 1) rejects its absence.
In a headless Profile, setting `token_expandable: false` on every
axis is ceremony — the answer is already implied by the Profile's
empty grammar.

**Suggested fix:** When the referenced Profile declares
`token_grammar: {}` (or the resolved-for-this-component set of
grammars is empty), make `token_expandable:` default to `false` and
drop the required-field check. Preserves strict enforcement for
DSes that DO have tokens.

**Verdict:** Cdf-core TODO. Validator is slightly stricter than
needed for the headless case; spec can stay as-is with a §8.1 note.
**Effort:** small.

---

## F-Radix-7: controlled/uncontrolled pair (`pressed` × `defaultPressed`)

**Radix reality:** Toggle exposes two related props — `pressed`
(controlled, bound by consumer) and `defaultPressed` (initial value,
used only when `pressed` is not bound). Setting `pressed` wins and
`defaultPressed` is ignored; the inverse has no meaning.

**CDF status:** CDF's closest construct is
`properties.{p}.mutual_exclusion:` (§7.9), but §7.9 says the
relation SHOULD be symmetric and the validator warns when it isn't.
Radix's relation is asymmetric: `pressed` dominates `defaultPressed`,
not the other way around. Modelling it as `mutual_exclusion` would
be a lie, and the validator would correctly warn.

Current spec: both props declared, no cross-reference. The friction
is documented only in the `defaultPressed` description. A consumer
reading the spec does not learn the dominance rule from the
structured fields.

**Suggested fix:** Either
  (a) a new optional `properties.{p}.supersedes: other_prop` field
      that declares one-way dominance — the inverse of
      `mutual_exclusion`. Cheap to add, narrow semantics.
  (b) accept the tension — React's controlled/uncontrolled idiom is
      React-specific; a Swift or Kirby Target would not emit the
      `defaultPressed` prop at all, making the pair framework-local.
      Document it in prose, keep the spec plain.

(b) is the less disruptive call. The pattern is endemic to React;
other frameworks express initial-value differently (SwiftUI
`@State` initialiser, Angular form defaults).

**Verdict:** Accepted tension. Revisit only if a later port
(Dialog's `open`/`defaultOpen`) produces a second instance.
**Effort:** would be small if ever implemented (option a).

---

## F-Radix-8: empty `token_grammar` passes spec but bypasses §6

**Radix reality:** Profile ships `token_grammar: {}` because the DS
has no visual contract.

**CDF status:** Profile §6.1 reads "one or more" grammars implicitly
(the schema example always shows at least one entry). An empty map
is not explicitly blessed or forbidden. The parser accepts it — the
for-loop at `profile-parser.ts:32` just iterates zero times. All
downstream references (token_layers empty, interaction_patterns
without `token_layer:`, categories without `token_grammar:`) work
out because every reference is optional.

**Suggested fix:** Add a one-line §6.1 note — "A Profile with no
visual contract MAY declare `token_grammar: {}`. Every downstream
reference to a grammar becomes correspondingly optional." No spec or
validator change; just confirmation that the headless path is
intentional. Paired with F-Radix-2's option (a).

**Verdict:** Spec change (draft.6) — documentation only.
**Effort:** small.

