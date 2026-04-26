# Phase Completion Gates — Consolidated

Single-page summary of the gates each Phase must pass before advancing.
Drawn verbatim from each `references/phases/phase-N-*.md` §4. Use this
as a scan-check during a scaffold run; consult the full phase-doc for
any gate that needs clarification.

**Rule:** if any gate fails, do **not** advance. Later phases amplify
earlier gaps — loop back, don't patch forward.

---

## Pre-Phase 1 — Opening Checklist

- [ ] `.cdf.config.yaml` checked — resume / refresh / fresh decided.
- [ ] 🔴 `ds_name` + `figma.file_url` confirmed (hard-stop if missing).
- [ ] 🟡 token-source regime identified + ★-rating recorded.
- [ ] 🟢 DS-specific tooling + doc-frame convention asked (adapt if
  known).
- [ ] User given the three-tier opening message (advisor tone, not
  gatekeeper).
- [ ] `scaffold:` block seeded in `.cdf.config.yaml`.

## Phase 1 · Orient

- [ ] Full file inventory (COMPONENT_SETs, standalones) — no
  truncation residue.
- [ ] Every COMPONENT_SET entry has `propertyDefinitions` populated
  (not just `axes: [names]`). Phase 2 reads axis VALUES from this
  field — missing it means Phase 2 cannot aggregate without
  re-fetching.
- [ ] Standalone components classified (Utility / Documentation /
  Widget / Asset).
- [ ] Token-source regime confirmed (★-rating recorded).
- [ ] Tokens enumerated (via MCP if available; `Read` only as
  fallback).
- [ ] Figma Styles enumerated (Paint + Text + Effect) — regardless
  of regime.
- [ ] Theming-axes matrix recorded.
- [ ] Documentation surfaces surveyed; doc-frames ingested if
  present.
- [ ] Initial findings seeded (any drift, orphan, sparsity already
  visible).
- [ ] `.cdf.config.yaml` `scaffold:` block updated.

## Phase 2 · Extract Vocabularies

- [ ] Every COMPONENT_SET's axes accounted for in aggregation table.
- [ ] Each raw axis-name mapped to a concept (hierarchy / intent /
  size / state / selected / expanded / hasValue / progress / other).
- [ ] Property-name drifts surfaced as findings (at least one
  usually exists).
- [ ] State-axis decomposition proposal drafted (compound values
  broken apart into orthogonal dimensions).
- [ ] `active` ambiguity check done.
- [ ] Selection-modeling consistency check done.
- [ ] Every finding has Observation + Discrepancy +
  SoT-Recommendation filled; User-Decision empty for Phase 6.
- [ ] User has been shown the decomposition proposals and
  acknowledged (even "I'll think about it"); no silent assumptions.

## Phase 3 · Infer Grammars

- [ ] Full token tree enumerated — no truncation residue (Rule B
  verified).
- [ ] Every top-level token-group evaluated as grammar-candidate.
- [ ] Each grammar documented with: pattern, depth, axes, leaf_count,
  cartesian_count, sparsity.
- [ ] Sparsity per (axis × axis) mapped for each grammar (at least
  the headline grammar — smaller grammars can be summarized).
- [ ] Aliases classified into self-ref / cross-grammar /
  semantic-chain.
- [ ] Component-binding map generated for 5–10 representative
  components.
- [ ] DTCG vs Figma count-deltas recorded per grammar.
- [ ] Intent/emphasis folding check done on every grammar with a
  hierarchy-like axis.
- [ ] Grammar-level findings seeded in `findings.md` with 4-field
  template.

## Phase 4 · Theming Modifiers

- [ ] Every theming axis (from Phase 1 §1.5) enumerated with modes
  list.
- [ ] At least two representations cross-checked where both exist
  (DTCG `$themes.json` + Figma Variable modes). Drift recorded.
- [ ] Rule-B-for-theming applied: `list_themes` trusted over schema
  enums if the DS MCP shows signs of enum-gating.
- [ ] Mode-sparsity computed per multi-mode collection — leaf counts
  per mode in-hand.
- [ ] Component-layer gap check done for every axis with a plausible
  component-layer analogue (typically `device`).
- [ ] Always-on collections distinguished from single-mode axes; User
  consulted when unclear.
- [ ] Typography / Shadow representation-gap recorded if Phase 1
  flagged the DTCG-vs-Variables count delta.
- [ ] Brand-drift findings seeded with (a) count-delta, (b) per-leaf
  concentration, (c) alias-collapse scan (if aliases were classified
  in Phase 3).
- [ ] `.cdf.config.yaml` `scaffold:` block updated.

## Phase 5 · Interaction Patterns + A11y Defaults

- [ ] Documentation-surfaces ingested **first** (Rule G) — at least
  doc-frames + Component Descriptions scanned before pattern
  inference.
- [ ] Utility-component review done with User; Focus-Ring-class
  components confirmed in or out (Rule F).
- [ ] Every COMPONENT_SET assigned one or more interaction-patterns.
- [ ] Focus-strategy classified (one of the 4 shapes, or `unknown`
  with a pending User-question).
- [ ] Phase-2 anti-patterns re-confirmed at the interaction lens.
- [ ] `accessibility_defaults` drafted in full — focus-ring,
  min-target-size, contrast, keyboard, category-defaults.
- [ ] `token_mapping` proposed per pattern; missing grammar →
  Finding.
- [ ] User has been shown the `focus_strategy` and
  `accessibility_defaults` and acknowledged (first-write DSes nearly
  always need a "let me check / revise" round).
- [ ] `.cdf.config.yaml` `scaffold:` block updated.

## Phase 6 · Findings + Classify

- [ ] All findings from Phases 1–5 collated into `<ds>.findings.md`.
- [ ] Every finding has non-empty Observation + Discrepancy + SoT
  fields (patch prior phases if gaps remain; don't patch from here).
- [ ] Findings clustered A–F + Z.
- [ ] Cluster-F findings moved to format-issues backlog with
  one-line cross-references back.
- [ ] Every Cluster-A–E finding has a User-Decision value.
- [ ] User has been walked through every cluster; no silent adoption.
- [ ] `<ds>.conformance.yaml` emitted iff any
  `accept-as-divergence`.
- [ ] Every `block` finding has a placeholder-plan for Phase 7
  emit.
- [ ] Cluster-Z handling chosen (inline ≤10, sibling-file >10).
- [ ] Profile-inputs structured and ready for direct `Write` in Phase 7.

## Phase 7 · Emit + Validate

- [ ] Profile YAML assembled from `phase_6_output.profile_inputs`
  with all required top-level sections present.
- [ ] Existence guard run before each `Write` (Read attempt; explicit
  User confirmation on overwrite).
- [ ] Profile + findings YAML written via `Write`.
- [ ] `cdf_validate_profile` returns clean OR only-warnings (errors
  trigger iteration loop). L8 (`resolve_tokens: true`) enabled when
  `token_sources` declared AND files reachable.
- [ ] `cdf_coverage` run when component specs exist; diagnostic output
  captured. Skipped (with note) on first-scaffold runs.
- [ ] Conformance YAML written iff any `accept-as-divergence`
  finding.
- [ ] `.cdf.config.yaml` `scaffold.last_scaffold` block updated with
  artefact paths, phases list, timestamp.
- [ ] User has been handed the summary (Phase-7 §1 Step 7.7).
- [ ] Any remaining `block` findings clearly surfaced in the
  handback.

---

## Inter-phase smoke-tests

Quick cross-phase checks to run at key transitions — they catch gate
regressions that don't show up in a single phase's gate list.

**Between Phase 1 and Phase 2:**
- [ ] Does a sample `propertyDefinitions` entry from Phase 1 actually
  contain `variantOptions` (not just `type` keys)? Open one entry and
  verify.

**Between Phase 2 and Phase 3:**
- [ ] Does `system_vocabularies.hierarchy` (or the DS-equivalent) have
  at least one value that also appears in a token-path-segment in the
  source tree? If not, Phase 3 will surface every Phase-2 vocab as
  "orphan" — sanity-check for gross misalignment.

**Between Phase 3 and Phase 4:**
- [ ] Does at least one grammar have non-zero alias count? Complete
  absence of aliases is unusual; if true, verify Phase 3 Step 3.4
  actually ran (not silently skipped).

**Between Phase 5 and Phase 6:**
- [ ] Does every interaction-pattern declared in Phase 5 have a
  `token_layer` reference that matches a Phase-3 grammar name? If
  not, Phase 6 has a cleanup to do before classification.

**Between Phase 6 and Phase 7:**
- [ ] Count `block` findings. If > 0, surface explicitly before
  Phase 7 writes the Profile YAML — Phase 7 will emit placeholders,
  and the User should know that before the YAML lands.

**Post-Phase 7:**
- [ ] `<ds>.profile.yaml` exists at expected path.
- [ ] `<ds>.findings.md` exists next to it.
- [ ] `.cdf.config.yaml` `scaffold.last_scaffold.phases_completed`
  = `[1, 2, 3, 4, 5, 6, 7]`.
- [ ] Handback summary delivered to User.
