<!--
  snapshot.findings.template.md  (template / reference — DEPRECATED)

  ⚠ DEPRECATED as of QL.D (2026-04-26): the renderer
  `cdf_render_snapshot` MCP tool (or its bash equivalent
  `scripts/render-snapshot.sh`) is now canonical. Synthesis writes ONLY
  the two YAML inputs (`<ds>.snapshot.profile.yaml` +
  `<ds>.snapshot.findings.yaml`); the renderer emits the .md.

  This file is preserved as documentation of the rendered Markdown shape
  for future maintainers. The renderer's output diverges from the
  skeleton below — see CRITICAL FORMAT INVARIANTS for the authoritative
  contract.

  CRITICAL FORMAT INVARIANTS (renderer-enforced; the trust handshake):
    1. The "DRAFT — UNCLASSIFIED" banner is the FIRST element after the
       title. Renderer uses a GitHub `[!WARNING]` admonition + ⚠ glyph
       so the marker is unmissable in any Markdown viewer.
    2. NO decision-vocab column. NO block / defer / adopt / accept-as-
       divergence labels per finding. Findings are flag-only.
       Classification is upgrade-path territory; labelling them here is
       a Rule-E violation (see cdf-profile-scaffold/references/phases/
       phase-6-findings-classify.md for the production classification
       contract).
    3. NO ship-blocker section, NO deferred section, NO conformance
       section, NO cluster grouping, NO summary statistics. Snapshot
       has no concept of these. If the production findings.md renderer
       (render-findings.sh) is the inspiration — borrow the mechanical
       patterns (yq/jq), but stay slim.
    4. Renderer section order: BANNER → FINDINGS → BLIND_SPOTS →
       UPGRADE-PATH. The banner itself is the first trust handshake;
       blind-spots is the second, given its own H2 ("What this snapshot
       did NOT check") immediately after findings. Inventory copy that
       earlier drafts placed up-top is dropped — `metadata.tier` and
       `token_regime` surface in the banner instead.
    5. The upgrade-path paragraph is the FINAL element, with a copy-
       pasteable invocation phrase (`/scaffold-profile`). It is the
       call-to-action the evaluator audience leaves the file with.

  Field substitutions (renderer/synthesis fills):
    {{DS_NAME}}              — metadata.ds_name
    {{IDENTIFIER}}            — metadata.identifier
    {{GENERATED_AT}}          — metadata.generated_at
    {{TIER}}                  — metadata.source.tier
    {{TOKEN_REGIME}}          — metadata.source.token_regime
    {{COMPONENT_SETS_COUNT}}  — inventory.component_sets.tree_unique_count
    {{STANDALONE_COUNT}}      — sum of inventory.standalone_components.*
    {{REMOTE_REFS_COUNT}}     — inventory.component_sets.remote_only_count
    {{TOKEN_COUNT}}           — inventory.tokens.total_tokens (or "not enumerated")
    {{DESC_COVERAGE_PCT}}     — inventory.documentation_surfaces.figma_component_descriptions.ratio × 100
    {{BLIND_SPOTS}}           — bullets from blind_spots[] (one per line)
    {{VOCAB_COUNT}}           — len(vocabularies) — "not detected" if absent
    {{GRAMMAR_COUNT}}         — len(token_grammar)
    {{MODIFIER_COUNT}}        — len(theming.modifiers)
    {{PATTERN_COUNT}}         — len(interaction_a11y.patterns)
    {{FINDINGS}}              — bullets from findings_unclassified[]
                                each finding renders as 3 lines:
                                  - **{topic}** — {observation}
                                    *Evidence:* `{evidence_path}`
    {{UPGRADE_PATH}}          — upgrade_path string, prose

  Related:
    - Plan: docs/plans/active/2026-04-25-quick-look-mode.md (QL.A, QL.D)
    - Schema: snapshot.profile.schema.yaml (sibling)
    - Skill: ../SKILL.md
    - Production analogue (do NOT copy verbatim — different audience):
        cdf-profile-scaffold/references/phases/phase-6-findings-classify.md
        cdf_render_findings MCP tool (or scripts/render-findings.sh)
-->

# {{DS_NAME}} — Snapshot

> ## ⚠ DRAFT — UNCLASSIFIED
>
> This is a **first-look snapshot** of `{{DS_NAME}}` produced by
> `cdf-profile-snapshot` in ~5–10 min. It is **not** a Production CDF
> Profile. Findings are **unclassified** (no block/defer/adopt
> decisions). Sections marked *draft* are LLM single-pass synthesis on
> top of mechanical Phase-1 extract — sketch-grade.
>
> **For production-grade Profile authoring, run `/scaffold-profile`** —
> see *Upgrade path* at the end of this document.

---

## What we looked at

- **DS:** `{{DS_NAME}}` (identifier `{{IDENTIFIER}}`)
- **Generated:** {{GENERATED_AT}} · tier `{{TIER}}` · token regime `{{TOKEN_REGIME}}`
- **Inventory** (mechanical, from Phase-1 walker):
  - {{COMPONENT_SETS_COUNT}} component sets (unique)
  - {{STANDALONE_COUNT}} standalone components (utility / documentation / widget / asset)
  - {{REMOTE_REFS_COUNT}} remote-library refs
  - {{TOKEN_COUNT}} tokens (enumeration: see snapshot.profile.yaml)
  - {{DESC_COVERAGE_PCT}}% of component sets carry Figma descriptions

These numbers come from the walker — they are the trustworthy ground
under everything else in this document.

---

## What this snapshot did NOT check

This is the honest list. Read it before reading anything below.

{{BLIND_SPOTS}}

If any of the items above matters for your evaluation, the **Production
Scaffold** (see *Upgrade path*) covers them. The Snapshot deliberately
does not, in exchange for time-to-first-output.

---

## Sketch — what stood out

These sections are **draft synthesis** on top of the inventory above.
Each section is one LLM pass over the walker output — useful as a
starting point, not as authority. Validator status: this snapshot is
**not** validator-checked (see blind-spots).

### Vocabularies (draft) — {{VOCAB_COUNT}} detected

See `{{DS_NAME}}.snapshot.profile.yaml` § `vocabularies`. Each entry
carries an `evidence_path` pointing back at the walker output cell that
sourced it.

### Token grammar (draft) — {{GRAMMAR_COUNT}} detected

See `{{DS_NAME}}.snapshot.profile.yaml` § `token_grammar`. Patterns are
inferred from a single `browse_tokens` pass — assume coverage gaps.

### Theming (draft) — {{MODIFIER_COUNT}} modifier(s) detected

See `{{DS_NAME}}.snapshot.profile.yaml` § `theming`. Inferred from
Figma Variables collection mode-names; not cross-checked against actual
component usage.

### Interaction & a11y (draft) — {{PATTERN_COUNT}} pattern(s) sketched

See `{{DS_NAME}}.snapshot.profile.yaml` § `interaction_a11y`. **Lowest-
trust section** — patterns are sketched from variant-property naming,
not validated against component state axes. A11y notes are heuristic.

---

## Findings — flag-only (max 15)

These are observations the synthesis pass thought worth surfacing. They
are **NOT classified**. The Production Scaffold's Phase 6 produces a
full classification (block / defer / adopt-as-divergence) with audit
trail; this list is the upstream signal, not the decision.

{{FINDINGS}}

---

## Upgrade path

{{UPGRADE_PATH}}

```
/scaffold-profile
```

The Production Scaffold reads this snapshot's
`{{DS_NAME}}.snapshot.profile.yaml` as a Phase-1 seed (~5 min savings vs
from-scratch) and emits a validator-checkable
`{{DS_NAME}}.profile.yaml` plus a fully classified
`{{DS_NAME}}.findings.md`.
