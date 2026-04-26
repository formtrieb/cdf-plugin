# Findings-Doc Template

Canonical shape for `<ds>.findings.md` — the prose companion to
`<ds>.profile.yaml`. Every scaffold run emits one. Its quality is the
single biggest differentiator of this Skill over a token-tree auditor.

---

## 1 · The 4-field schema

Every finding uses the same four fields, in this order:

```markdown
## §N · [Finding Title]

**Observation:** [what the source(s) actually say — quote data, not
inference. Name token paths, component IDs, counts exactly.]

**Discrepancy:** [DTCG says X, Figma says Y, Components say Z — OR
"none; this is a clean pattern worth documenting."]

**Source-of-Truth-Recommendation:** [Which side to canonize, with
rationale. The LLM authors this; the User decides in Phase 6.]

**User-Decision:** [adopt-as-is / adopt-DTCG / adopt-Figma /
adopt-Components / accept-as-divergence / drop / block — filled in
Phase 6.]
```

**Field discipline:**

- **Observation** is pure fact. If you're inferring, move it to
  Discrepancy or SoT-Recommendation. The Observation field should be
  re-producible from the source in < 1 minute.
- **Discrepancy** is optional-content but not optional-field. Write
  "none; this is a clean pattern worth documenting" when there's no
  drift. This is how clean patterns get canonized explicitly rather
  than assumed.
- **SoT-Recommendation** carries the Rule-E value. One paragraph max;
  lead with the decision, follow with 2–3 reasons. Don't hedge — the
  User can override, but a wishy-washy recommendation makes the
  classification dialog twice as long.
- **User-Decision** is empty through Phases 1–5. Phase 6 fills it.
  Empty ≠ `block`. `block` is an explicit User response; empty means
  not-yet-classified.

## 2 · Document structure

```markdown
# <DS-Name> — CDF Profile Findings

**Scaffold date:** <YYYY-MM-DD>
**Skill version:** cdf-profile-scaffold v1.4.0
**Profile:** [<ds>.profile.yaml](./<ds>.profile.yaml)
**Conformance overlay:** [<ds>.conformance.yaml](./<ds>.conformance.yaml)
   (omit this line if no divergences)

## Overview

<2–4 sentence summary of the DS's architectural shape. What regime,
what theming axes, what's the headline grammar. Feeds into a DS-meeting
agenda without the reader needing to read the whole doc.>

---

## Cluster A · Token-Layer Architecture

### §1 · [Title]
**Observation:** …
**Discrepancy:** …
**Source-of-Truth-Recommendation:** …
**User-Decision:** …

### §2 · [Title]
…

---

## Cluster B · Theming & Coverage
…

## Cluster C · Component-Axis Consistency
…

## Cluster D · Accessibility Patterns
…

## Cluster E · Documentation Surfaces
…

## Housekeeping (quality / naming)   # only if §Z ≤ 10

### §Z1 · [Title]
**Observation:** …
(SoT-Recommendation optional for §Z entries — drop-target is usually
self-evident)

---

## Phase-2 Carry-forward to Phase 3 (proposed `system_vocabularies`)

(Append the vocabulary freeze-candidate block here — see
references/phases/phase-2-vocabularies.md §2.2 for format.)
```

**Section order is Cluster A → E → (F → separate artefact) → Z.**
Cluster F content lives in `docs/specs/cdf-profile-spec-v1.1.0-issues.md`;
the DS findings-doc only carries one-liner cross-references per format-gap.

## 3 · Worked example (Formtrieb DS — illustrative)

Below is a single cluster rendered as the real artefact would read.
Use this as a shape reference, not as content to copy.

```markdown
## Cluster A · Token-Layer Architecture

### §1 · `color.controls` grammar

**Observation:**
The `color.controls.*` namespace holds 192 DTCG tokens at depth 5,
all matching the pattern
`color.controls.{hierarchy}.{element}.{state}` where:
  - hierarchy ∈ [brand, primary, secondary]
  - element   ∈ [background, stroke, text, text-on-color, icon, icon-on-color]
  - state     ∈ [enabled, hover, pressed, disabled, error, success]
Leaf count is below the full cartesian (3 × 6 × 6 = 108 would be
cartesian against the 3-hierarchy space; actual 192 reflects a
separate layering per element — see §2).

**Discrepancy:** None at grammar-shape level. Pattern is consistent
across all 192 leaves; no depth-outliers within the namespace.

**Source-of-Truth-Recommendation:** Adopt as-is. This is the canonical
interactive-controls grammar. Declare in Profile as:
`token_grammar.color.controls.pattern = "color.controls.{hierarchy}.{element}.{state}"`
with `state_subsets:` capturing per-(hierarchy × element) sparsity.

**User-Decision:** _filled in Phase 6_

---

### §2 · Intent/Emphasis folding in `hierarchy` vocab

**Observation:**
The `hierarchy` vocab currently has 6 values:
`[brand, primary, secondary, accent, warning, negative]`. Three of
these (brand, primary, secondary) describe **visual emphasis**; three
(accent, warning, negative) describe **semantic intent**.

**Discrepancy:** Same pattern mirrors at the component-layer —
`Warning Button` and `Destructive Button` are carried as separate
`type:` variants on Button. Token-layer and component-layer conflate
together.

**Source-of-Truth-Recommendation:** Decompose orthogonally:
  - `hierarchy: [brand, primary, secondary]`
  - `intent:    [none, information, warning, danger, success]`

Token-layer refactor target:
`color.controls.{hierarchy}.{intent?}.{element}.{state}` (intent
optional → defaults to `none`). Additive migration: old path
deprecates, new path co-exists initially.

Rationale:
  (a) The current fold makes Profile authoring awkward — components
      cannot pick "primary emphasis with warning intent" cleanly.
  (b) The two axes are genuinely orthogonal (a warning-secondary
      button is a real design need).
  (c) Downstream generators can emit either path; migration is
      mechanical.

**User-Decision:** _filled in Phase 6 — deep DS-level refactor decision._

---

### §3 · DTCG↔Figma count delta in `color.controls`

**Observation:**
DTCG `color.controls.*` has 192 leaves. Figma Variables in the
matching collection show 195 variables. 3-variable delta on the Figma
side.

**Discrepancy:** Bi-directional Token Studio sync is imperfect. The
3 extra Figma variables suggest local author edits that never flowed
back to DTCG, OR DTCG cleanup that didn't flow forward to Figma.

**Source-of-Truth-Recommendation:** Canonize DTCG. Rationale:
  (a) DTCG is the declared SoT in the DS contract (see DS README).
  (b) The Figma surplus is unreproducible via the DTCG Resolver —
      generators would emit only the 192 DTCG leaves.
  (c) The 3 Figma strays are safer to audit + remove than to absorb
      as canonical.

Action: identify the 3 Figma-only leaves; file them as housekeeping
(§Z subset) for DS-team removal.

**User-Decision:** _filled in Phase 6 — needs specific Figma-variable
inspection._
```

## 4 · Writing discipline

- **Lead with data, not narrative.** Every Observation starts with a
  count, a path, or a concrete name. "The DS uses an interesting
  approach to X" is not an Observation.
- **One finding per concern.** If a finding is becoming 500 words,
  split it. Two crisp findings beat one sprawling one.
- **Numbering is continuous across clusters.** §1, §2, §3 — not §A1,
  §B1. Clusters group, numbers don't reset per cluster. This matches
  Phase 2/3 references back to findings-doc-§N.
- **`§Z` entries are allowed to be 1-field** (Observation only).
  Housekeeping doesn't always need SoT-recommendation; the
  drop-target for a typo is self-evident.
- **Don't embed screenshots or Figma links.** The findings-doc is
  meant to be readable without Figma access. Reference nodes by ID +
  name; let the reader look them up.
- **Cross-reference between findings freely.** "§2 re-enters here
  because the component-layer mirror of §2 affects this decision."
  The doc is a graph, not a list.
