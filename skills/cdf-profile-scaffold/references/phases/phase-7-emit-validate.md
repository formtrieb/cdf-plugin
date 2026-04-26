# Phase 7 · Emit + Validate

**Goal:** Materialize the Profile YAML from the accumulated Phase 1–6
inputs; validate; report coverage; iterate if needed. This is the
deterministic tail of the pipeline — Write + two MCP tools, one
optional iteration round, done.

**v1.5.0 change:** the previous `cdf_emit_profile` MCP tool has been
removed. The LLM now writes the Profile YAML file directly via `Write`
and runs structured validation via `cdf_validate_profile`. Same
correctness guarantees, simpler tool surface, closer to how component
specs already work (write-then-validate).

**Predecessor:** Phase 6 closed; `phase_6_output.profile_inputs` is
structured; `<ds>.findings.md` exists; `<ds>.conformance.yaml` exists
iff any finding was classified as `accept-as-divergence`.

**Successor:** None. Phase 7 is the scaffold's end state. Hand back to
the User with a short summary + a pointer to the emitted artefacts.

**Subagent-fit:** — Not applicable. Three MCP tool calls in sequence;
no research, no dialog.

**Shape authority (spec-only — no cross-reference).** During emit, the
ONLY authoritative shape references are:

1. The CDF-PROFILE-SPEC fragments under `cdf/specs/profile/`, loaded
   on-demand via `cdf_get_spec_fragment({ fragment: "<Name>" })`.
   Fragments are the canonical authoring source; the monolith
   `cdf/specs/CDF-PROFILE-SPEC.md` is a generated publication artefact.
   Phase 7 emit typically needs — in composition order —
   `index` (overview + front-matter), `Identity`, `Vocabularies`,
   `TokenGrammar`, `TokenLayers`, `StandaloneTokens`, `Resolution`,
   `TokenSources`, `Theming`, `Naming`, `InteractionPatterns`,
   `AccessibilityDefaults`, `Categories`, `Assets`, and `Extends` (iff
   the child emit uses `extends:`). Load the specific fragment the
   current emit slot needs; do not pull the monolith.
2. The parent Profile, iff `scaffold.extends.path` is set — read exactly
   that one file, nothing else.
3. The in-progress Profile file being written.

**Do NOT** read any other `*.profile.yaml` in the repo (e.g. sibling
adopter profiles such as `formtrieb.profile.yaml`, `radix.profile.yaml`,
or a child profile alongside its parent) for "shape confirmation" or
"canonical example" purposes. Other profiles are unrelated adopter DSes
and must be treated as noise. For
`extends: null` scaffolds this is architecturally enforced — the whole
point of `extends: null` is "ignore other profiles". For external
adopters (Radix, USWDS, third-party teams) the referenced file may not
even exist; hard-coding a peek would fail or contaminate with
Formtrieb-specific conventions. If shape uncertainty arises, go to
the relevant fragment — never to an adjacent Profile.

---

## 1 · Methodology

### Step 7.1 — Assemble the Profile YAML

The LLM writes the Profile YAML from the `phase_6_output.profile_inputs`
structured block.

**Template-fill first (Scope B).** Copy
[`templates/phase-7-output.schema.yaml`](templates/phase-7-output.schema.yaml) as the
starting skeleton, substitute `<placeholder>` tokens with the Phase-6 values,
delete sections that don't apply, and write. The template bakes the six
schema-shape gotchas from the 2026-04-23 real-run (see §7.1.5 below) into its
structure, so a template-faithful emit passes `cdf_validate_profile` L0–L7 on
the first try — no fix-up iteration needed.

**Do NOT assemble from scratch.** A free-form compose pass routinely loses to
four-to-six schema-shape errors (wrong vocab shape, bool-literals, list-typed
`token_grammar`, missing `dtcg_type`, grouped `token_sources.sets`,
`extends: null`) that cost a full emit-iterate roundtrip. The template is the
antidote; use it.

Top-level sections (per CDF Profile Spec v1.0.0):

```yaml
# ── Identity (always present) ───────────────────────────────────
name:                 # DS identity (PascalCase, e.g. "Formtrieb")
version:              # DS version (semver — ask User if not inherited)
cdf_version:          # Profile Spec range, e.g. ">=1.0.0 <2.0.0"
extends:              # optional — relative path to parent Profile
                      # (e.g. "../formtrieb.profile.yaml"). When set,
                      # inherited sections MAY be omitted (see §7.1.1).
                      # Single-level only in Spec v1.0.0.
dtcg_version:         # optional — DTCG spec version (e.g. "2025.10"),
                      # required iff token_grammar references DTCG types
description: >        # 1–3 sentence DS overview
  ...

# ── Token layer (present unless inherited unchanged) ────────────
vocabularies:         # Phase 2 output, post User-Decisions
token_grammar:        # Phase 3 output, post User-Decisions
standalone_tokens:    # Phase 3 output
token_sources:        # optional — where DTCG files live, structured by
                      # set. Consumed by generators to resolve tokens.
                      # Example:
                      #   directory: ./tokens
                      #   format: tokens-studio
                      #   sets:
                      #     Foundation: [Foundation/Foundation.json, …]
                      #     Semantic:   [Semantic/Light.json, Semantic/Dark.json]
                      # Whole-block REPLACE on `extends:`  (§15.1).

# ── Theming (present unless inherited unchanged) ────────────────
theming:              # Phase 4 output (modifiers + set_mapping)

# ── Patterns + A11y (present unless inherited unchanged) ────────
interaction_patterns: # Phase 5 output
accessibility_defaults: # Phase 5 output

# ── Structure (present unless inherited unchanged) ──────────────
categories:           # Phase 1 standalone classification + component categories
naming:               # identifier (short-code, 2-4 letters), casing,
                      # reserved_names

# ── Assets (optional, concrete DS only) ─────────────────────────
assets:               # optional — icon / illustration pipeline config.
                      # Typical shape:
                      #   icons:
                      #     source: ./figma-export/icons
                      #     format: svg
                      #     naming_case: kebab
                      # Whole-section per-asset-type REPLACE on `extends:`.
```

**Block findings need placeholders.** For each `block` finding from
Phase 6, emit a syntactically-valid stand-in with a `# TODO (see
findings.md#§N)` comment inline. The Profile parses and validates;
the stand-in is visibly unresolved.

**Defer findings ship normally — no placeholder, no special-case.**
A finding with `user_decision: defer` carries the same Profile-emit
consequence as `pending` from Phase 7's perspective: zero. The
finding is advisory only; Phase 7 emits the Profile values per
Phase-6 SoT-recommendation (or per the upstream phase output if the
SoT was already structured), exactly as it would for `adopt-as-is`.
The deferral lives in `findings.yaml.summary.deferred_findings[]`
and surfaces in the §7.7 handback so the User knows what to revisit
later — but the Profile is canonical-as-emitted, not stand-in-as-
emitted. **Treat `defer` like `pending`** for Profile-content
purposes: read it as "no objection — apply the SoT," not as "block-
lite." The Phase-6 contract guarantees `pending` is 0 outside
autopilot fallback, so in practice Phase 7 sees `defer` as the live
"User looked at it, agreed-by-default, wants to revisit later"
marker. (Rule landed 2026-04-25 after the L5 hypothesis-confirmation
re-run produced 13 deferred findings whose Profile-emit treatment
the doc had not specified.)

#### Step 7.1.5 — Common shape errors (check before writing)

These six gotchas cumulatively produced 25 validation errors on the
first Phase-7 emit of the 2026-04-23 real-run — each one a one-line
rule that is not obvious from a sequential read of CDF-PROFILE-SPEC,
only surfacing at `cdf_validate_profile` time. The
`templates/phase-7-output.schema.yaml` template encodes the fix for
every one; if you are assembling from scratch anyway, spot-check each:

| # | Pitfall | Invalid shape | Required shape | Fragment § |
|---|---|---|---|---|
| ★1 | Vocabulary is `{description, values}`, not a bare list | `hierarchy: [brand, primary, ...]` | `hierarchy: { description: "...", values: [brand, primary, ...] }` | `Vocabularies` §5.1 |
| ★2 | Boolean-axis values are quoted strings, not YAML bool literals | `values: [false, true]` | `values: ["false", "true"]` | `Vocabularies` §5.3 |
| ★3 | `token_grammar` is an object map keyed by grammar name, not a list | `token_grammar: [{ name: color.controls, ... }]` | `token_grammar: { color.controls: { ... } }` | `TokenGrammar` §6.1 |
| ★4 | Every grammar entry declares `dtcg_type` — REQUIRED | grammar body missing `dtcg_type` | `dtcg_type: color` (or typography/dimension/…) | `TokenGrammar` §6.3 |
| ★5 | `token_sources.sets` maps `<set-path>: <filename>` one per key, never a list-per-group | `Foundation: [Foundation/Foundation.json, ...]` | `"Foundation/Foundation": Foundation/Foundation.json` (sibling keys for each file) | `TokenSources` §7.4 |
| ★6 | `extends:` is a string path OR the field is omitted — `null` fails type-check | `extends: null` | **Omit the field entirely** for self-contained profiles | `Identity` §4.5 |
| ★7 | `interaction_patterns.<p>.token_layer` is a layer **name** from `token_layers[]`, NOT a grammar key from `token_grammar:` | `token_layer: color.controls` | `token_layer: Controls` (the matching `token_layers[].name`) | `InteractionPatterns` §10.3 |

Rationale lives in memory `feedback_phase7_schema_pitfalls` (captured
from the 2026-04-23 end-to-end real-run); ★7 lifted from the
2026-04-25 evening re-run, where the Phase-5 doc example used a
grammar key and the validator emitted 8 warnings on the first
profile-emit. If you find an eighth gotcha in a future emit, add the
row here and note it in the memory.

#### Step 7.1.6 — Vocabulary Near-Miss catalog + pre-emit verification

**Why:** `cdf_validate_profile`'s vocab-isolation rule (Profile §5.5)
catches the same value across multiple axes, but it cannot catch
**different but synonymous** values across vocabs (e.g. `leading` in
one axis, `left` in another) or **near-synonym axis names** (e.g.
`state` and `interaction` for the same runtime-state concept). Without
a catalog, those synonyms drift into bloat: same concept under two
names, downstream components author against whichever the LLM saw
last, inconsistency compounds. This section is the canonical catalog
the Phase-2 detector (§2.9.6) consults and the Phase-7 pre-emit guard
re-checks.

A match is **not** a defect. It may be a deliberate ARIA-distinct
split (e.g. `expanded` for trigger-points-at-region vs `open` for
component-itself-visible) or a standard idiom (boolean axes). The
catalog surfaces the pair so the decision is **explicit** — Phase-6
classifies via keep-both / merge / rename per §6.4-ter.

##### Canonical near-miss catalog (empirically grounded 2026-04-25)

The catalog is split into three sections: detected pairs (the lint
emits a finding), group-overload sets (axis-family collisions), and
sentinel-idiom whitelist (patterns the near-miss lint deliberately
DOES NOT emit because §2.9.5 vocab-isolation already covers them at
a different conceptual angle).

**Detected pairs (cluster C/Z near-miss findings):**

| # | Pair / pattern | When which | Authority / idiom |
|---|---|---|---|
| M1 | `state` ↔ `interaction` (axis names) | runtime-state via CSS pseudo-classes vs pointer/keyboard intent split | ARIA `aria-*` state attributes; convention is one axis-name DS-wide |
| M2 | case-variant axis duplicates (e.g. `Icon` ↔ `icon`) | accidental cross-component vocab merge with case drift | Pick canonical casing |
| M3 | `leading`/`trailing` ↔ `left`/`right` (values) | RTL-aware positioning vs physical-LTR-only positioning | `leading`/`trailing` is the standard RTL-aware idiom |
| M4 | homonym axis ↔ value (e.g. axis `active` AND value `active` elsewhere) | ARIA `aria-current`/selected vs runtime "is-active" state vs activation-flag | Disambiguate per ARIA — typically `active → selected` or rename axis |
| M5 | `false`/`true` everywhere (≥2 boolean axes) | standard boolean-axis idiom across DS | Universally adopted; usually `adopt-as-is` |
| G1 | ≥2 of {`type`, `hierarchy`, `emphasis`, `appearance`, `weight`} | rank-semantic family overlap (different DSes pick different head-axis name) | Pick one canonical (typically `hierarchy`); fold others |
| G2 | `brand` value in axes `hierarchy` AND `intent` | emphasis-rank vs status-flavour axis overload | One canonical home for `brand`; status side gets `info`/`accent`/etc. |

**Sentinel-idiom whitelist (lint deliberately does NOT emit; covered by §2.9.5):**

| Sentinel | Why suppressed by near-miss lint | Coverage |
|---|---|---|
| `none` value across vocabs | semantic null marker; same value, orthogonal axes | §2.9.5 cluster C |
| `base` value across vocabs | default-tier idiom (`size.base`, `density.base`, `emphasis.base`) | §2.9.5 cluster C |
| `error`/`success` value across `validation` × `intent` | semantic overlap by design | §2.9.5 cluster C |

The near-miss lint does NOT double-emit on these — surfacing them
once via §2.9.5 is enough; the User-Decision template for those is
"concept-collision rename" (§2.9.5 prose), not the keep-both / merge
/ rename template the near-miss lint uses.

##### Phase-2 mechanical detection (where the lint runs)

The detector is `scripts/lint-vocab-near-miss.sh`, called by
phase-2-vocabularies.md §2.9.6 against the synthesized
`system_vocabularies` block. It emits seeded-findings JSON which the
§2.last `phase-2-output.yaml` emit folds into `seeded_findings[]`.
Findings then flow through Phase 6 like any other seeded finding.

##### Phase-7 pre-emit defensive verification (this step)

After assembling the Profile YAML (Step 7.1) but BEFORE writing it
(Step 7.2), re-run the detector against the assembled profile's
vocabularies. This is a defensive check: the User may have introduced
new vocab values during Phase-6 classification (e.g. a rename that
created a near-miss with an inherited parent vocab via `extends:`).
Two outcomes:

1. **Detector returns `[]`** → proceed to Step 7.2.
2. **Detector returns ≥1 finding NOT already in `findings.yaml`** →
   stop. Surface the new finding(s) to the User as a Phase-7 sidebar
   (the COVERAGE contract from §6.4 doesn't bind here because Phase 7
   doesn't classify — but the user MUST see the surprise before write).
   Two recovery paths: (a) accept the near-miss (record an
   `accept-as-divergence` decision, append to `findings.yaml`,
   re-render), or (b) revise the Phase-6 decision that introduced it.

The defensive guard exists because the Phase-2 detector runs on the
*synthesized* vocab; Phase-6 User-Decisions can rewrite values in
ways the §2.9.6 emit didn't anticipate (rare but real — happened on
the 2026-04-25 evening re-run with the `state → interaction` rename).

##### Decision template (Phase-6 §6.4-ter)

When a near-miss finding reaches Phase-6 batch-ask, the
AskUserQuestion shape diverges from the standard
adopt-as-is/adopt-DTCG/.../block menu. Each near-miss carries four
options:

- **A. Keep both (deliberate split):** Add `description:` to both
  vocab entries explaining the split. No rename. Use when the pair is
  ARIA-distinct (e.g. `expanded`/`open`) or covers different DS layers.
- **B. Merge to X:** Pick one canonical term; rewrite the other's
  occurrences across components and tokens; update `description:` to
  note the merge.
- **C. Merge to Y:** Same as B but the other side wins.
- **D. Rename both:** Both terms are wrong for this profile; pick new
  names the profile actually wants.

Per-pair templates live in §6.4-ter; Phase-7 only emits the table.

##### Reference

- Detector: `scripts/lint-vocab-near-miss.sh`
- Tests:    `scripts/test/lint-vocab-near-miss.test.sh` (24 assertions across 7 test cases — synthetic 7+3 spec, schema fidelity, L5.I prose contract, id-uniqueness, real-data integration)
- Phase-2 hook:    `references/phases/phase-2-vocabularies.md` §2.9.6
- Phase-6 dialog:  `references/phases/phase-6-findings-classify.md` §6.4-ter
- Plan: `docs/plans/done/2026-04-24-lever-2a-vocab-near-miss-lint.md`
- Empirical seed: `docs/plans/active/2026-04-25-bug-check-results.md`
  §"L2A vocab-near-miss-lint — empirical seed table"

#### Step 7.1.1 — Emit when `extends:` is set (merge-aware omission)

When `extends: <parent-path>` is present, the emit rules change:
only **diverging** content is written. The parent's values flow in
via the merge semantics of Spec §15.1 (per-key REPLACE at the smallest
documented unit).

**Per-section emit decision table (applies only when `extends:` is set):**

| Section | Has divergence? | Emit behavior |
|---|---|---|
| `vocabularies` | No | Omit section entirely. Parent's vocabularies flow through unchanged. |
| `vocabularies` | Partial (new vocab added OR existing replaced) | Emit ONLY the diverging keys — not the whole block (§15.1 per-key REPLACE). Follow §15.2 for replacement-lists (full list, not partial-add syntax). |
| `token_grammar` | No | Omit. |
| `token_grammar` | Partial | Emit only diverging keys. |
| `token_layers` | No | Omit. |
| `token_layers` | Additive | Emit only new layers (additive-only per §15.1); existing layers MAY extend `grammars:`/`references:` entries but MUST NOT remove. |
| `standalone_tokens` | No | Omit. |
| `standalone_tokens` | Additive | Emit only new tokens (additive-only per §15.1). |
| `token_sources` | No | Omit (parent's `token_sources:` flows through). |
| `token_sources` | Any | **Whole-block REPLACE** (§15.1) — emit the full new block. |
| `theming.modifiers` | No | Omit. |
| `theming.modifiers` | Per-modifier replace | Emit only the diverging modifier entries. |
| `theming.set_mapping` | No | Omit (**but** §8.3 requires coverage — verify parent's set_mapping still covers the child's token source layout). |
| `theming.set_mapping` | Any | **Whole-block REPLACE** (§15.1) — emit the full new block. |
| `naming` | No | Omit. |
| `naming` | Per-key (typical: only `identifier` differs) | Emit only the diverging keys — NOT the whole `naming:` block. Example: `naming: { identifier: "mp" }` alone when casing / reserved_names inherit. |
| `interaction_patterns` | No | Omit. |
| `interaction_patterns` | Per-pattern replace | Emit only diverging patterns. |
| `accessibility_defaults` | No | Omit. |
| `accessibility_defaults` | Per-block replace | Emit only diverging blocks. |
| `categories` | No | Omit. |
| `categories` | Per-category replace | Emit only diverging categories. |
| `assets` | No divergence AND parent has no assets | Omit. |
| `assets` | Child introduces concrete assets OR replaces | Emit per-asset-type REPLACE (`assets.icons` replaces whole `icons:` sub-block). |

**Hard constraints to verify BEFORE emit:**

- [ ] Parent file exists at resolved path. If not: hard stop.
- [ ] Child `cdf_version:` range ⊆ parent's range (§15.4). If outside:
  warn + ask User to narrow the child's range.
- [ ] Parent Profile's own `extends:` field is empty (single-level only,
  §15.6). If parent itself has `extends:`: hard stop, ask User
  whether to scaffold against the root Profile instead.
- [ ] Child and parent paths are not identical (no self-reference,
  §15.3).

**Typical child Profile size:** 100–200 lines (vs. 400+ standalone).
Reference shape: CDF Profile Spec §15.5 (`Acme extends Formtrieb`) —
~40 lines showing `name` + `version` + `extends:` + `description:` +
one `naming.identifier` override + one replaced `theming.modifiers`
entry + a full `theming.set_mapping` replacement + a concrete
`assets.icons` block. All other sections inherit unchanged.

**Do not emit inherited blocks as a "safety redundancy".** The whole
point of `extends:` is to avoid the drift risk of duplicated content.
If in doubt about a section: check parent's value, check child's
value, emit only if they truly differ.

#### Step 7.1.7 — Run the near-miss verifier (defensive)

Right before Step 7.2 `Write`, run the detector against the assembled
Profile's `vocabularies:` block:

```bash
yq -o=json '{ system_vocabularies: .vocabularies | to_entries | map({ (.key): .value.values // .value }) | from_entries }' \
  <assembled-profile-as-tempfile> \
| scripts/lint-vocab-near-miss.sh -
```

Compare the JSON-array output to `<ds>.findings.yaml` near-miss ids
(`§Z-vocab-near-miss-*`). Any id present in the verifier output but
NOT in `findings.yaml` is a Phase-6→Phase-7 drift signal — see §7.1.6
recovery paths. Empty array OR full-overlap → proceed to Step 7.2.

This step is cheap (deterministic bash + jq, sub-second); the cost of
skipping it is a Profile that surfaces a near-miss only when downstream
components author against it inconsistently.

### Step 7.2 — Write the Profile YAML

The LLM writes the Profile + sister artefacts directly using its
`Write` tool. There is no MCP wrapper — same pattern as component
specs and DTCG token files.

**Pre-write checks (do these first; skip none):**

1. **Path resolution.** Default output path is
   `./{ds_identifier}.profile.yaml` (cwd-relative). User may override
   via prior conversation; use that absolute path if given.
2. **Existence guard.** Before writing, check whether the target file
   already exists. Use a `Read` attempt — if it returns content, this
   is a refresh run; ask the User explicitly "overwrite existing
   `<path>`?" before proceeding. **Never overwrite silently.**
3. **Sister-file paths.** Compute `<output_dir>/<ds_identifier>.findings.md`
   and (if applicable) `<output_dir>/<ds_identifier>.conformance.yaml`.
   Apply the same existence guard.

**Write order:**

1. `<ds_identifier>.profile.yaml` — Profile YAML from Step 7.1.
2. `<ds_identifier>.findings.md` — findings doc from Phase 6.
3. `<ds_identifier>.conformance.yaml` — only if any
   `accept-as-divergence` finding exists. The Conformance Overlay Spec
   (Plan 3) formalizes a future `cdf_overlay_emit` tool; today the
   LLM writes this from the Phase-6 template.

**`<ds>.housekeeping.md` was already written in Phase 1** when §Z
exceeded 10 entries — don't re-emit here.

### Step 7.3 — Call `cdf_validate_profile`

```
cdf_validate_profile({
  profile_path:   "<absolute path to written Profile>",
  resolve_tokens: false,    // default — L0–L7 only
  severity:       "warning" // default — hides info-level depth marker
})
```

`cdf_validate_profile` (v1.5.0) runs a deep schema check against the
CDF Profile Spec:

| Level | What it catches |
|---|---|
| L0 | Parseable YAML |
| L1 | Required top-level fields (extends-aware: only `name`+`version` strict on children) |
| L2 | Field types correct (vocabularies = map<string, string[]>, etc.) |
| L3 | Schema-baking — only known top-level keys (catches typos: `theme:` vs `theming:`) |
| L4 | Cross-field structural (`interaction_patterns.<p>.token_layer` references valid layer) |
| L5 | Vocabulary Isolation Rule (Profile §5.5) |
| L6 | `extends:` resolution (target exists, parses, no cycles per §15.6) |
| L7 | `set_mapping` glob syntax + targets |
| L8 | Token-reference resolution against `token_sources` (opt-in: `resolve_tokens: true`) |

**When to enable L8:** if the Profile declares `token_sources` and the
DTCG files are reachable on disk, set `resolve_tokens: true` for the
Phase-7 validation pass. Catches dangling
`interaction_patterns.<p>.token_mapping` references that wouldn't be
caught at L0–L7. Skip L8 only when token files aren't checked in or
aren't yet authored — the validator degrades gracefully (warns + skips
L8, doesn't block).

Expected outcomes:

- **Clean pass** → advance to Step 7.4.
- **Warnings only** → Profile is usable; decide per-warning whether to
  iterate. Common benign warning: `block`-finding placeholders that
  show up as unknown-field / unresolved-token warnings.
- **Errors** → stop. Do not hand back a broken Profile. Loop:
  1. Read the error message — the validator returns each Issue with
     `path`, `message`, `rule`, often a `Did you mean …` hint.
  2. Identify which Phase-6 decision produced the invalid structure.
  3. Patch the YAML directly via `Edit` (do not re-run Phase 6 unless
     the error is fundamental).
  4. Re-run `cdf_validate_profile`.

Typical error shapes + fixes:

| Error | Root cause | Fix |
|---|---|---|
| Vocabulary value not disjoint across scopes | Phase 2 mis-classified a value under two vocabularies | Re-check Phase 2 Step 2.6 / 2.7 — usually a selection-ambiguity residue |
| Grammar axis references undefined vocabulary | Phase 3 declared an axis whose values weren't registered in Phase 2 | Register the vocab OR drop the axis |
| `theming.set_mapping` references unknown modifier | Phase 4 declared a `set_mapping` entry for a modifier not in `modifiers:` | Add the modifier OR remove the mapping |
| `interaction_patterns.<p>.token_mapping` references undefined state | Phase 5 mapped a pattern-state to a grammar-state that isn't declared | Align; often Phase 3 sparsity table missed the state |

### Step 7.4 — Call `cdf_coverage` (component-spec scope)

```
cdf_coverage({ profile: "<absolute path>", token_sources: [...] })
```

**Scope clarification (v1.5.0):** `cdf_coverage` operates on the
**component-spec layer** — it walks `spec_directories` and reports
how many `tokens:` references in component specs resolve against the
token sources. This is meaningful only when component specs already
exist for the DS being scaffolded; on a first-scaffold run for a new
DS this step often returns "no component specs found" and that is
expected, not a defect.

When component specs do exist, the report covers:

- **Token-coverage:** how many component-declared tokens resolve in
  the token sources.
- **Vocabulary-usage:** how many declared vocabulary values are
  actually referenced by component specs.
- **Sparsity summary:** per-grammar coverage against its cartesian.

Profile-internal token-reference checks (L8) live in
`cdf_validate_profile` (Step 7.3) — set `resolve_tokens: true` there
to surface `interaction_patterns.<p>.token_mapping` references that
don't resolve.

Expected outputs on a clean first scaffold:

- **Coverage < 100%** is normal. Most DSes have sparsity — that's
  information, not defect. Phase 3's `state_subsets` should account
  for most sparsity; unaccounted gaps are Phase-3 findings that got
  missed.
- **Vocabulary-usage < 100%** indicates vocabulary values declared but
  not bound anywhere. Usually means Phase 2 was over-generous. Record
  as a Cluster-C finding for a follow-up scaffold refresh.

Do **not** iterate on coverage in Phase 7. Coverage deltas are input
to the *next* scaffold refresh, not blockers for this one.

### Step 7.5 — Optional: `cdf_suggest`

If the User wants pattern-completeness nudges ("what might I be
missing?"), call `cdf_suggest({ profile: "<path>" })`. It surfaces:

- Missing canonical fields (e.g. `accessibility_defaults.focus_ring`
  without a `pattern` key)
- Incomplete cross-references (pattern-to-grammar bindings)
- Deprecated or soon-to-be-deprecated Profile sections

Treat the output as a next-scaffold-run feed. Phase 7 doesn't act on
it beyond passing it back in the handoff.

### Step 7.6 — Persist scaffold state

Final update to `.cdf.config.yaml`:

```yaml
scaffold:
  # …existing fields…
  last_scaffold:
    timestamp: <ISO 8601>
    skill_version: 1.5.0
    phases_completed: [1, 2, 3, 4, 5, 6, 7]
    artefacts:
      profile:     ./<ds>.profile.yaml
      findings:    ./<ds>.findings.md
      conformance: ./<ds>.conformance.yaml   # omit if no divergence
      housekeeping: ./<ds>.housekeeping.md   # omit if §Z ≤ 10 inlined
```

### Step 7.7 — Handback summary to the User

Short, structured. The User should be able to act within 2 minutes
of reading it. Preferred shape:

```
Scaffold complete.

Artefacts:
  • <ds>.profile.yaml         (<line-count> lines, validates clean / with <N> warnings)
  • <ds>.findings.md          (<finding-count> findings, <N> blocked, <N> deferred)
  • <ds>.conformance.yaml     (only if any divergence; <N> divergences)

Validation: <clean | N warnings | N errors>
Coverage:   <summary headline — e.g. "192 of 192 controls tokens resolved">

Next steps (prioritised):
  1. Review <N> blocked findings in <ds>.findings.md — these need
     DS-team decisions before the Profile is canonical.
  2. (Advisory, ships) <N> deferred findings parked in
     `summary.deferred_findings[]` for a follow-up review.
  3. <any follow-on from validation warnings>
  4. Re-run the scaffold as `refresh` once blocked findings are
     resolved (values persist via `.cdf.config.yaml`).

Anything to adjust, or shall I hand this off?
```

If `<N> blocked` is 0 the line still appears with "0 blocked" — the
explicit zero is signal that no ship-blockers remain. The deferred
count is informational; Phase 7 does not iterate on it. The User
revisits deferred findings out-of-band (or in a `refresh` run).

**Do not drop the dialog after emit.** Phase 7 closes with one last
User-confirmation — the handback. If the User wants to tweak, fix,
or revise, that's a Phase-6 iteration, not a new scaffold.

---

## 2 · Output

```yaml
phase_7_output:
  artefacts:
    profile:     ./<ds>.profile.yaml
    findings:    ./<ds>.findings.md
    conformance: ./<ds>.conformance.yaml   # optional
  validation:
    status: clean | warnings | errors
    warning_count: 0
    error_count:   0
  coverage:
    token_coverage_pct: 100
    vocabulary_usage_pct: 95
    sparsity_summary:
      color.controls: "192/192 leaves bound"
      color.text:     "14/18 values used (4 declared-unused)"
  suggestions: []   # from cdf_suggest if called
  iteration_count: 1   # how many emit/validate cycles were needed
```

---

## 3 · Tool-leverage Map (Phase-7 specific)

| Tool | Leverage | Notes |
|---|---|---|
| `Write` (built-in) | ★★★ | Primary — emit Profile + findings + conformance YAMLs directly |
| `Read` (built-in) | ★★ | Pre-write existence guard; never overwrite silently |
| `cdf_validate_profile` | ★★★ | Hard gate on broken Profiles. L0–L7 default; L8 opt-in via `resolve_tokens: true` |
| `cdf_validate_component` | — | Not used in Phase 7 (component-spec scope, not Profile scope) |
| `cdf_coverage` | ★ | Diagnostic on existing component specs; often returns "no specs" on first scaffold |
| `cdf_suggest` | ★ | Optional; component-spec hints, not Profile-level — feeds the next refresh |
| `cdf_overlay_emit` | ✗ | Deferred — Plan 3. Conformance YAML is written from Phase-6 template |

---

## 4 · Completion Gates

- [ ] Profile YAML assembled from `phase_6_output.profile_inputs` with
  all required top-level sections present.
- [ ] Near-miss verifier (§7.1.7) run against the assembled Profile;
  any new `§Z-vocab-near-miss-*` finding NOT already in `findings.yaml`
  surfaced to User and resolved before Write.
- [ ] Existence guard run before each `Write` (Read attempt; explicit
  User confirmation on overwrite).
- [ ] Profile + findings YAML written via `Write`.
- [ ] `cdf_validate_profile` returns clean OR only-warnings (errors
  trigger iteration loop). L8 enabled when `token_sources` declared
  AND files reachable.
- [ ] `cdf_coverage` run when component specs exist; output captured.
  Skipped (with note) on first-scaffold runs with no component specs.
- [ ] Conformance YAML written iff any `accept-as-divergence` finding.
- [ ] `.cdf.config.yaml` `scaffold.last_scaffold` block updated with
  artefact paths, phases list, timestamp.
- [ ] User has been handed the summary (§1 Step 7.7).
- [ ] Any remaining `block` findings clearly surfaced in the handback.
- [ ] `defer` findings surfaced in the handback as advisory (count
  + pointer to `summary.deferred_findings[]`); Profile is NOT
  treated as not-ship-ready on `defer` count alone.

---

## 5 · Findings-Seed Candidates

Phase 7 should **not** seed findings. If validation fails in a way
that reveals a structural issue the earlier phases missed, record it
as a follow-up note in `<ds>.phase-7-notes.md` and surface in the
handback — but do **not** retroactively add it to `<ds>.findings.md`.
Findings-doc is a Phase-1–5 artefact; Phase 7 is emit-only.

---

## 6 · Typical Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Emitting with unresolved `block` findings silently | Profile has TODOs that nobody notices until a consumer breaks | Surface every `block` in the handback summary — explicitly |
| Ignoring validation warnings | User ships a Profile that generators can't handle cleanly | Either iterate once OR document each warning in the handback |
| Treating coverage gaps as errors | Iteration loop on a Profile that's structurally fine | Coverage is a diagnostic; Phase-7 doesn't block on it |
| Running `cdf_overlay_emit` | Tool doesn't exist yet (Plan 3) | Write conformance.yaml from Phase-6 template |
| Skipping `.cdf.config.yaml` update | Next `refresh` run has no state to resume | Step 7.6 is load-bearing for resume/refresh UX |
| Writing over an existing Profile without User confirmation | `Write` silently overwrites; user loses prior hand-edits | Run a `Read` attempt first; on hit, explicitly ask the User before overwriting (Step 7.2 existence guard) |
| Skipping L8 because token files exist but `resolve_tokens` was left at default | Dangling `interaction_patterns.<p>.token_mapping` references slip through | When `token_sources:` declared AND files reachable on disk, set `resolve_tokens: true` |
| Calling `cdf_validate_component` instead of `cdf_validate_profile` | Validates component specs (often "no specs found"), not the Profile | Use `cdf_validate_profile` in Phase 7 — the names are paired for clarity |
| Cross-referencing adjacent `*.profile.yaml` for "shape confirmation" | Minutes lost to self-directed peeks at e.g. `formtrieb.profile.yaml` during an `extends: null` emit; contaminates output with conventions from unrelated adopter DSes; hard-fails for external adopters whose repos have no such file | Shape authority is CDF-PROFILE-SPEC.md (+ parent Profile iff `extends:` set). See preamble constraint. |
| Assembling Profile YAML from scratch instead of copying the template | First emit hits 4–6+ schema-shape errors (wrong vocab shape, bool-literals, list-typed `token_grammar`, missing `dtcg_type`, grouped `token_sources.sets`, `extends: null`); full iterate roundtrip wasted | Start from `templates/phase-7-output.schema.yaml` — it bakes every §7.1.5 pitfall into its structure. Substitute placeholders, delete unused sections, write |
| Skipping the near-miss verifier (§7.1.7) because Phase-2 §2.9.6 already ran | Phase-6 User-Decisions can introduce new vocab values that weren't in `system_vocabularies` at §2.9.6 detection time (rename, parent-extends, accept-as-divergence with a new term). Profile ships with a silent near-miss; downstream components author inconsistently | Run §7.1.7 on the assembled profile every emit. Detector is sub-second; the cost of skipping is structural drift caught only when consumers break |

---

## 7 · Cross-Reference

Phase 7 is the end of the Skill. Follow-up workflows:

- **Profile refresh** — re-run the Skill with `refresh` option; prior
  User-Decisions carry forward via `.cdf.config.yaml`.
- **Component authoring** — switch to the `cdf-author` skill to write
  per-component spec YAMLs against the now-stable Profile.
- **Token coverage audit** — switch to the `token-audit` skill for
  deeper follow-up on coverage gaps flagged by `cdf_coverage`.
- **Generator scaffolding** — once the Profile stabilizes, the
  `generator-angular` (or target-specific) package consumes it.
