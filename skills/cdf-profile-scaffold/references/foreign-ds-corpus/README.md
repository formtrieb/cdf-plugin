# Foreign-DS Corpus

Five CDF Profile examples from real-world design systems, mirrored from
`cdf/examples/`. Used by the `cdf-profile-scaffold` skill as a
reference library when the LLM needs prior-art for grammar shapes,
theming arrangements, or token-bridge conventions.

## Why these five

Each was chosen to stress a distinct corner of the CDF Profile format:

| DS | Focus |
|---|---|
| `radix/` | Unstyled primitives — minimum Profile; no tokens, pure patterns. Good baseline for `focusable` / `pressable` / `selectable` pattern vocab. |
| `shadcn/` | Hybrid semantic-shape token-bridge (γ). Consumer-owned token VALUES via `standalone_tokens` + `external —` prose. Useful when scaffolding a DS whose tokens live downstream of Profile. |
| `primer/` | GitHub's DS — scale-heavy, rich grammar, multi-brand. Good reference for brand-drift arrangements and multi-mode theming. |
| `material3/` | Token-layered architecture (Core → Role → Component). Densest grammar example; reference when scaffolding a Material-lineage DS. |
| `uswds/` | US Web Design System — accessibility-first. Strong example of explicit A11y-defaults and pattern declarations aligned with WCAG levels. |

## How the skill uses them

- **Phase 3 (Grammars):** reference-shape for grammar declarations when
  proposing a pattern like `color.controls.{hierarchy}.{element}.{state}`.
- **Phase 4 (Theming):** reference for how multi-mode + always-on
  collections are typically arranged in `theming.set_mapping`.
- **Phase 5 (Interaction + A11y):** reference for interaction-pattern
  vocab, `token_mapping` shapes, `accessibility_defaults` blocks.
- **Phase 6 (Findings):** use the paired `findings.md` to see how
  real-world 4-field findings read — especially SoT-recommendations.

## What NOT to do

- Do **not** copy blocks wholesale into a new DS's Profile. The corpus
  is illustrative, not reusable content. Every DS's Profile reflects
  its own Phase 1–6 decisions.
- Do **not** treat the corpus as exhaustive. Patterns outside the
  corpus are still valid; absence from here isn't evidence of
  incorrectness.
