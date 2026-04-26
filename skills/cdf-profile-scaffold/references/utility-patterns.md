# Utility-Component Patterns (Rule F)

Many design systems implement cross-cutting A11y / interaction concerns
via **standalone utility components** — Focus Rings, Dividers, Tooltip
Backdrops, Scrims, Selection Indicators — rather than variant-axes on
every affected component. Without explicit classification, these show
up as silent holes in Phase-5 analysis ("this DS has no focus design")
and in the emitted Profile.

Rule F exists because of this: **after enumerating COMPONENT_SETs,
classify standalone COMPONENTs by role.** This file is the
recognition-heuristic library for that classification pass.

---

## 1 · Why utility-components need a dedicated category

A11y concerns like focus indication are *cross-cutting* — every
focusable control needs a focus treatment. Two shapes of implementation
coexist in real DSes:

| Shape | Where focus lives | Typical indicator |
|---|---|---|
| Variant-axis | `focused: [false, true]` on every focusable component | 20+ COMPONENT_SETs each carry a focused variant |
| Utility-component | One standalone `Focus Ring` used compositionally (INSTANCE_SWAP, doc-frame reference, overlay layer) | One standalone Focus Ring; variants stay lean |

Both are legitimate. Skipping utility-component detection makes the
Skill produce a false "no focus design" finding for the latter shape —
which is the exact failure that motivated Rule F.

## 2 · Known utility-component families

For each family: name patterns, typical role, phase where it matters.

### 2.1 Focus Ring / Focus Indicator

**Name patterns:** `focus`, `focus-ring`, `focus-indicator`, `focus-
style`, `ring`, `indicator/focus`.

**Role:** A11y — keyboard focus visual. Applied compositionally over
focusable components.

**Detection hints:**
- Usually a single standalone `COMPONENT` (not a `COMPONENT_SET`) —
  the treatment is non-varying.
- Common shapes: single ring / double ring (inner matches page
  background for contrast on any surface) / inset stroke / box-shadow
  glow.
- Often referenced from `_doc-content` frames' "Focus Style" section
  (Rule G — ingest before inferring).
- In figma-variables regime: check if the Focus Ring binds `color.
  focus.*` or similar grammar-set tokens.

**Phase-5 footprint:** sets `focus_strategy.pattern = "utility-
component"` and populates `accessibility_defaults.focus_ring.pattern`
with the detected shape (single-ring, double-ring, etc.).

### 2.2 Divider / Separator / Rule

**Name patterns:** `divider`, `separator`, `rule`, `hr`.

**Role:** Composition — visual separation between content regions.

**Detection hints:**
- Orientation may be encoded as a variant (`horizontal` / `vertical`)
  or as two separate components.
- Rarely A11y-bearing; the relevant ARIA-role is `separator` and
  most DSes don't make it explicit.

**Phase-5 footprint:** adds a `categories.utility.divider` entry or
similar; not load-bearing for `interaction_patterns` unless the
Divider is keyboard-interactive (rare — usually decorative).

### 2.3 Tooltip Backdrop / Scrim / Overlay / Surface

**Name patterns:** `backdrop`, `scrim`, `overlay`, `layer/surface`,
`tooltip-bg`.

**Role:** Composition — dim-layer behind modal / popover / tooltip.

**Detection hints:**
- Usually a single COMPONENT with solid fill + reduced opacity.
- Often binds an `opacity.scrim` or `color.surface.overlay` token —
  if so, the backdrop *is* the token's component-layer witness.
- A11y-relevant if it traps pointer events (modal scrims do; tooltip
  backdrops usually don't).

**Phase-5 footprint:** informs the Profile's modal/popover categorical
defaults (e.g. `aria-modal` treatment) and the `theming.affects`
list for the scrim token.

### 2.4 Selection Indicator / Check / Dot

**Name patterns:** `check`, `checkmark`, `indicator/check`,
`selection-dot`, `radio-dot`.

**Role:** Selection — visual witness that a boolean-selected state
holds.

**Detection hints:**
- Often a standalone COMPONENT referenced from Checkbox / Radio /
  SelectionTag via INSTANCE_SWAP.
- **Key signal:** if the same standalone is the `defaultValue` of
  INSTANCE_SWAP slots on ≥ 3 selectable components, it is a
  first-class selection-indicator (see phase-2-vocabularies.md Step
  2.8.5 — slot-primitive detection).

**Phase-5 footprint:** sets `selectable` pattern's `token_mapping`
rationale; may surface a format-gap finding (Cluster F) if the Profile
can't cleanly declare the indicator as a canonical slot primitive.

### 2.5 Loader / Spinner / Progress Indicator

**Name patterns:** `loader`, `spinner`, `progress`, `indicator/progress`,
`loading`.

**Role:** Progress — visual witness of async-op lifecycle.

**Detection hints:**
- Often a standalone used compositionally (INSTANCE_SWAP on Button's
  `pending` state, Badge's `loading` state).
- May have a small variant-axis (size S / M / L).
- A11y-bearing: usually needs `aria-busy` / `role=progressbar`
  treatment on the parent.

**Phase-5 footprint:** `progress` interaction-pattern's token-layer
binding often points here; the Profile's `progress.pending` state
gets its visual treatment from this utility-component, not from a
token.

### 2.6 Icon (debatable: utility or asset?)

**Name patterns:** `icon`, `icons/*`, named glyph shapes
(`icon-check`, `icon-close`).

**Role:** Asset — reusable visual elements.

**Detection hints:**
- Usually a large family (100+ components).
- **Classify as Asset, not Utility** unless individual icons carry
  interaction-patterns (e.g. `icon-close` with hover-pressed states).
- Most DSes have icons bound to `color.controls.*.icon.*` tokens;
  Phase 3 should have surfaced the binding.

**Phase-5 footprint:** minimal — asset bucket; not an
interaction-pattern carrier.

### 2.7 Label / Helper Text / Error Message (debatable: widget or utility?)

**Name patterns:** `label`, `helper-text`, `helper`, `error-text`,
`hint`.

**Role:** Widget — text-carrying affordances attached to form controls.

**Detection hints:**
- Almost always `Widget`, not Utility. The distinction:
  - **Utility** = invisible cross-cutting concern (focus, scrim).
  - **Widget** = visible component the DS intentionally exposes.
- Usually varies by validation state — part of the `validation`
  interaction-pattern wiring.

**Phase-5 footprint:** classify as widget; record `validation`
pattern contribution in component-pattern map.

## 3 · Recognition heuristic — two-step classification

Phase 1 Step 1.3 classifies every standalone. Use this two-step pass:

**Step A — name-pattern match** (mechanical):

```
for each standalone COMPONENT:
  if name matches /focus|ring/i          → Utility (focus)
  if name matches /divider|separator/i   → Utility (divider)
  if name matches /backdrop|scrim|overlay|surface/i → Utility (overlay)
  if name matches /check|checkmark|selection-dot|radio-dot/i → Utility (selection indicator)
  if name matches /loader|spinner|progress/i → Utility (progress)
  if name matches /_?doc|docu|description/i → Documentation
  if name matches /icon|illustration|logo|badge-glyph/i → Asset
  else → Widget (provisional)
```

**Step B — User confirmation** (Rule F in practice):

```
"Phase 1 classified these standalones as Utility:
  • Focus Ring
  • Divider
  • Scrim Layer

And these as Widget (provisionally):
  • Label
  • Helper Text
  • Loading Spinner   ← might actually be Utility?

Can you confirm or correct? Specifically:
  (a) Any Utility-role components whose name doesn't hint at the role?
  (b) Any Widgets that should actually be Utility?
  (c) Any Documentation-role components I missed?"
```

Always ask (c) — a single unnoticed `_component-docu` frame can
invalidate Phase-5's entire pattern-derivation (Rule G).

## 4 · Phase-5 composition signals

When Phase 5 analyzes a COMPONENT_SET's interaction patterns, scan for
these composition signals that indicate a utility-component involvement:

| Signal | Meaning |
|---|---|
| INSTANCE_SWAP property with a standalone as `defaultValue` | Utility-component is compositionally embedded |
| Doc-frame content citing a standalone by name ("Focus Style uses the Focus Ring component") | Rule G + Rule F — utility-component is the author-intended focus strategy |
| Variant-axis conspicuously absent (no `focused` variant on a focusable component) | Either utility-component OR css-delegated — check utility first |
| Token binding points at a grammar-set that the utility component also binds | Confirms the utility-component is the visual witness for that token state |

## 5 · Profile-side representation

Utility-components land in the Profile in two places:

```yaml
categories:
  utility:
    components: [FocusRing, Divider, ScrimLayer]
    role: >
      Cross-cutting A11y / composition primitives, used by other
      components via INSTANCE_SWAP or doc-frame reference.

accessibility_defaults:
  focus_ring:
    description: Double-ring focus indicator; outer ring = focus color,
      inner ring = page background
    pattern: utility-component       # <- this value
    utility_component: FocusRing     # <- reference to categories.utility
    token_group: color.focus
```

If the Profile Spec v1.0.0 doesn't cleanly accommodate the
`utility_component` reference (known format-gap), record as Cluster-F
finding and emit the field anyway — the spec will catch up in v1.1.0.

## 6 · Anti-signals (don't classify as Utility when…)

- **Component has its own interaction patterns** → it's a Widget that
  happens to have a utility-like name. E.g. a `Focus` component that
  renders a full focused-state demo for a component gallery is a
  Widget/Documentation, not a Utility.
- **Component lives in a "showcase" / "test" / "sandbox" page** →
  scaffold-artifact, not DS-component. Flag in Cluster Z (housekeeping).
- **Component name includes "example" or "demo"** → almost always not
  a Utility; often a Documentation component or a showcase leftover.

When in doubt, ask the User. Rule F exists because utility-components
are easy to miss; rule-by-name alone over-classifies noise as Utility.
