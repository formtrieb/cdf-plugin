---
title: Snapshot Synthesis — Single-Pass Prompt
loaded_by: skills/cdf-profile-snapshot/SKILL.md §1 step-3
read_at: step-3 (synthesis dispatch — point-of-need)
requires:
  - shared/cdf-source-discovery/walker-invocation.md  # §1 source-of-truth contract; T0/T1 inventory semantics
  - shared/cdf-source-discovery/tool-leverage.md      # §2 Rule A enforcement (Contract 3-bis); §4 Token enumeration paths block (Contract 4 fallback)
# source-discovery.md is upstream (Read at SKILL.md §1 step-1) — not re-declared here
---

# Snapshot Synthesis — Single-Pass Prompt

**Loaded by:** `../SKILL.md` §1 step-3 (the cdf-profile-snapshot SKILL.md
orchestration table) after source-discovery resolves and the walker artefact
is on disk.

**Output target:** `<ds>.snapshot.profile.yaml` conforming to
`references/snapshot.profile.schema.yaml`, plus the inputs the renderer
needs for `<ds>.snapshot.findings.md` (template at
`references/snapshot.findings.template.md`).

**Time budget:** the synthesis is a SINGLE LLM pass. Aim for ~5 min
end-to-end including the one optional `browse_tokens` call. If you find
yourself looping (re-reading the walker, second `browse_tokens` calls,
classifying findings) — STOP. That is Production-Scaffold territory; the
upgrade-path handoff in SKILL.md §3 is how those signals get acted on.

---

## §0 · Inputs

Before drafting any section, you MUST have read:

1. **`.cdf-cache/phase-1-output.yaml`** — the walker's mechanical
   inventory (`Phase1Output` consumer-shape). Treat as authoritative.
   Do NOT re-read live Figma to "confirm" its counts (per
   `../../../shared/cdf-source-discovery/walker-invocation.md` §1
   source-of-truth contract). The synthesis is **source-mode-blind**:
   the file may have been produced by the REST adapter (T1/T2) or the
   runtime adapter (T0) — `Phase1Output` is the contract, not the
   underlying serialisation. The walker output records `generated_by.tier`
   if you need to surface the mode in `metadata:`.

   **Large-file fallback (Read-tool 25k-token cap).** Probe walker file size
   first (`ls -lh .cdf-cache/phase-1-output.yaml`; `wc -l` the same file).
   If `phase-1-output.yaml` exceeds **100 KB OR 2000 lines**, use the
   YAML-pipe fallback directly — do NOT attempt `Read` and "improvise +
   chunk":

   ```bash
   yq -o=json '.<section>' .cdf-cache/phase-1-output.yaml | jq '.<aggregator>'
   ```

   **❌ DO NOT inline-construct in `yq`.** mikefarah `yq`'s lexer rejects
   inline object construction:

   ❌ `yq -o=json '.<path> | {field1, field2}' file.yaml`
      → `Error: 1:6: lexer: invalid input text "field1, ..."`

   ✅ ALWAYS pipe `yq → jq` — emit JSON from `yq`, construct in `jq`:
   ✅ `yq -o=json '.<path>' file.yaml | jq '{field1, field2}'`

   **Applies to ALL queries against `phase-1-output.yaml`**, not just the
   §0 100-KB-fallback path. The mistake is tempting because Python `yq`
   (kislyuk/yq) DOES accept inline construction — but mikefarah `yq`
   (the variant declared in §0 host-tool prerequisites) does not. If
   you author a fresh aggregator query and `yq` errors with `lexer:
   invalid input`, that's this anti-pattern firing — switch to
   `yq → jq` separation immediately, do not retry-with-quoting-tweaks.

   The 100-KB threshold reproduces against any DS with ≥150 component
   sets (a 175-set DS produced 149 KB / 5475 lines; a 152-set DS
   produced ~28k tokens — both exceed the 25k-token Read cap). The
   previous 2-MB threshold was too lax — it pushed authors into chunking
   attempts that wasted ~3 min before falling back. See `inventory:`
   aggregator block in §2.2 for a paste-ready query covering every field
   the synthesis needs from `ds_inventory`. Cross-references in
   [`shared/cdf-source-discovery/tool-leverage.md` §4 — Extraction
   Recipes](../../../shared/cdf-source-discovery/tool-leverage.md) cover
   token enumeration + DTCG paths; this paragraph is self-contained for
   `phase-1-output.yaml`. The synthesis contract (anchor every claim to
   walker evidence) STILL HOLDS; only the read-strategy changes.
2. **`.cdf.config.yaml`** (if present) — for `scaffold.ds_name`,
   `scaffold.figma.file_url`, `scaffold.tier`,
   `scaffold.token_source.regime`, `scaffold.resolver.mcp_name`. These
   feed the `metadata:` section verbatim.
3. **`references/snapshot.profile.schema.yaml`** — the shape contract
   for the YAML you will Write. Annotations there bind; this file
   tells you WHAT to fill, the schema tells you the field names.

If `.cdf-cache/phase-1-output.yaml` is absent, halt and ask the
operator to run `cdf_extract_figma_file` first (T1: after
`cdf_fetch_figma_file`; T0: after capturing `figma_execute` output to
`.cdf-cache/figma/<key>.runtime.json`). See SKILL.md §1.4 for the
audience-fit table.

---

## §1 · The Six Mandatory Contracts (Load-Bearing — Read Twice)

Every section below operates under all six contracts simultaneously. If a
section drafts content that violates any of them, redraft that section —
do NOT relax the contract.

### Contract 1 — STRUCTURE: single-pass, seven sub-sections + framing

You MUST emit, in this order, exactly the eight top-level blocks the
schema declares:

1. `metadata` (REQUIRED · HIGH trust · config + walker)
2. `inventory` (REQUIRED · HIGH trust · walker verbatim)
3. `blind_spots` (REQUIRED · HIGH trust · template + targeted)
4. `upgrade_path` (REQUIRED · HIGH trust · template verbatim)
5. `vocabularies` (OPTIONAL · `_quality: draft` · LLM)
6. `token_grammar` (OPTIONAL · `_quality: draft` · LLM + 1× browse_tokens)
7. `theming` (OPTIONAL · `_quality: draft` · LLM)
8. `interaction_a11y` (OPTIONAL · `_quality: draft` · LLM — lowest trust)
9. `findings_unclassified` (OPTIONAL · `_quality: draft` · LLM, max 15)

The four required blocks come FIRST so even a partial run produces
trustworthy ground truth + the trust-handshake before any drafted
content. Do NOT reorder — the schema ordering is a UX decision (HIGH
trust on top, draft below the soft boundary) the renderer relies on.

### Contract 2 — CITATION: every quantitative claim cites the walker

You MUST cite the walker output (or token-MCP path) for any number,
count, ratio, vocabulary value, modifier name, or pattern reference
that appears in the YAML. The schema has an `evidence_path:` field on
every drafted entry for exactly this reason — fill it.

Acceptable citation forms (use the actual path that holds the value):

- `ds_inventory.component_sets.tree_unique_count`
- `ds_inventory.component_sets.entries[3].propertyDefinitions.Hierarchy.variantOptions`
- `ds_inventory.standalone_components.utility[].name`
- `ds_inventory.figma_component_descriptions.ratio`
- `ds_inventory.documentation_surfaces.doc_frames_info`
- `theming_matrix.collections[0].modes` (after resolver fill)
- `tokens[].path` (only available if a token-MCP `browse_tokens` call ran;
  cite the MCP call's response shape, e.g.
  `formtrieb-tokens.browse_tokens(depth=2).color.controls.brand`)

Forbidden patterns (these are hallucinations — redraft):

- "There are roughly 20 components" → must be exact + cited.
- "A `secondary` hierarchy is conventional" → must trace to a
  `variantOptions` cell.
- "Most DSes have a `hover` state" → training-data lift, not in the file.
- "Tokens follow `color.{role}.{state}` (paraphrased)" without an
  `evidence_path` to a real token path.

If the walker did NOT surface enough signal for a section, OMIT the
section and ADD a blind-spot entry naming the gap. Empty draft sections
beat fabricated draft sections.

### Contract 3 — BLIND_SPOTS: honest, scan-specific, never boilerplate

The `blind_spots:` block is the trust handshake. You MUST populate it
honestly per what was actually scanned, NOT copy-paste from the schema's
suggestion list. Two paired examples (good vs bad) appear below in §3 —
study them before drafting.

A blind-spot entry MUST be falsifiable: stating a concrete capability
the Snapshot did NOT verify, ideally referencing a count from
`inventory:` so the reader knows what is unverified. Boilerplate (e.g.
"this is just a snapshot") does NOT pass.

List length scales with the actual scan. A 12-component DS has fewer
blind-spots than a 200-component DS. Do NOT pad to a target count.

#### 3-bis · Tool-survey requirement for resolver-gap claims

Snapshot has no User-dialog brake on gap-declarations. The walker's
mechanical inventory (`phase-1-output.yaml`) faithfully reports what
the source adapter (REST or runtime) was able to surface from the
underlying Figma file, and Contract 2 (CITATION) requires walker-
verbatim sourcing — but Contract 2 alone does NOT prevent the LLM
from extrapolating "the walker output does not show X" into "X NOT
enumerable." That extrapolation is a Rule-A violation. See
`../../../shared/cdf-source-discovery/tool-leverage.md` §2 (Rule A
Enforcement: Tool-Survey BEFORE Resolver-Gap) for the canonical rule.

The §2 rule is **structural** (L8.5): it fires on the *meaning* of the
sentence — *"does this assert that a capability of a loaded tool is
unavailable, partial, or invisible?"* — not on literal phrases. Paraphrases
like *"only partial Variable surface"*, *"REST cache lacks Variables
data"*, or *"tokens-MCP path not visible from this session"* trigger the
rule the same way *"NOT enumerable"* does. The positive-obligation trigger-
word list (`REST`, `Variables`, `enumerate`, `visible`, `missing`,
`partial`, `accessible`, `available`, `surface`, `enumerable`) is a
self-check heuristic — when any of these appear in a token/vocab/
theming-axis/metadata claim sentence, run the survey-vs-reframe gate.

`tool-leverage.md` §3 (**Rule B — Capability-Probe Before Default-Fallback**)
is the sister-rule covering the upstream tier-decision in
`source-discovery.md` §2: choosing T0 over T1 because no on-disk cache
is visible, when a `cdf_fetch_figma_file({file_key})` probe would have
shown T1 is reachable, is the same family of failure as declaring "X
NOT enumerable" without surveying loaded MCP tools. Rule B operates at
the path-selection layer; Rule A operates at the gap-declaration layer.
Snapshot synthesis runs *after* tier-selection has resolved, so
Contract 3-bis enforcement here scopes to Rule A; Rule B governs the
upstream walker-invocation step. Both apply in auto-mode and Snapshot.

**Hard rule for Snapshot (L8.5-generalized).** Any blind_spot entry that
asserts a **capability gap of the loaded MCP-tool surface** MUST carry a
`tool_survey:` sub-field listing the loaded `mcp__*` tools and the result
of probing AT LEAST ONE on a representative target. The structural test:
*"is this sentence claiming that something the loaded tools could in
principle reveal is unavailable, partial, or invisible?"* — if yes,
tool_survey is required regardless of the exact wording.

Paraphrased forms equally trigger the rule (non-exhaustive):

- *"X NOT enumerable / NOT visible / NOT accessible / NOT available"*
- *"only partial X surface"*
- *"REST cache lacks X data"*
- *"X path not visible from this session"*
- *"tokens-MCP not loaded so X is missing"*

Trigger-word self-check: if the sentence contains `REST`, `Variables`,
`enumerate`, `visible`, `missing`, `partial`, `accessible`, `available`,
`surface`, or `enumerable` in the context of a token / vocab / theming /
metadata / a11y claim, run the survey-vs-reframe gate before accepting it.

The `tool_survey:` sub-field lists:

- The loaded `mcp__*` tools that conceivably address this resource.
- The result of probing AT LEAST ONE of them on a representative target.

This applies to claims about:

- Color tokens / Variables enumerability
- Dimension tokens / Spacing scale visibility
- Theming axes / Variable mode enumeration
- Typography Style enumeration
- Accessibility annotations availability
- Doc-frame content ingestion (Rule G)
- Any other "the file has it but I'm not enumerating" assertion

#### Probe budget for Snapshot

Snapshot is single-pass and time-bounded (5–10 min). The probe budget
is correspondingly tight:

- **One probe per gap-claim is the floor.** A single `get_variable_defs`
  call on a representative button or banner refutes/confirms the
  Variables-visibility claim in ~5s.
- **Probes do NOT count against Contract 4's 1× `browse_tokens` cap** —
  that cap is for DS-tokens-MCP enumeration loops. Tool-survey probes
  are a different category (verification, not enumeration). 1
  `get_variable_defs` for survey + 1 `browse_tokens` for grammar
  enumeration is the maximum tool-call budget.
- **If a probe REFUTES the gap (returns real data):** drop the
  blind_spot entry entirely and either populate `token_grammar:` /
  `theming:` with the discovered data OR add a finding ("grammar
  visible via probe but not fully enumerated — Production Scaffold
  for full pass"). Surfacing real data is always preferred over a
  qualified gap-claim.
- **If a probe CONFIRMS the gap (returns nothing / errors / shows
  unrelated data):** the blind_spot stays, with the probe attempt
  documented.

#### Good vs bad — tool_survey worked example

❌ **BAD** — bare gap-claim without survey (the QL.E.1 anti-pattern):

```yaml
blind_spots:
  - "Color tokens NOT visible in non-Enterprise REST. Most of Primer's
    color system lives in Figma Variables."
```

Reader has no signal whether the LLM tried to bypass the REST gap or
just stopped at the cache file.

✅ **GOOD** — gap-claim qualified by recorded tool-survey:

```yaml
blind_spots:
  - claim: "Full color-grammar enumeration not performed."
    tool_survey:
      probed: mcp__figma__get_variable_defs(fileKey, nodeId=28860:52225)
      result: >
        Returned 17 token paths including button.primary.bgColor.rest=#1f883d,
        focus.outlineColor=#0969da. Color grammar is reachable; Snapshot did
        not full-enumerate (Production Scaffold should — see token_grammar
        section above for the partial sample).
      tools_not_probed:
        - mcp__figma-console__figma_execute (Plugin-API JS shell)
        - mcp__<ds>-tokens__browse_tokens (no DS-specific MCP loaded for Primer)
```

…or, in the more common case where the probe REFUTES the gap entirely,
the entry vanishes from `blind_spots:` and the discovered data lands
under `token_grammar:` with an evidence_path naming the probe call.

The `tool_survey:` sub-field shape is part of the Snapshot output
schema for any gap-style blind_spot. Boilerplate gap claims without
this sub-field are Contract 3 violations.

### Contract 4 — TOKEN-MCP: one `browse_tokens` call MAX (DS-MCP path only)

**Path applicability (F11-clarified).** Contract 4 binds the **DS-tokens-MCP
path** specifically — when a DS-specific tokens MCP is loaded
(`scaffold.resolver.mcp_name` set, or detected at run time, or
`mcp__<ds>-tokens__browse_tokens` visible in tool surface). On that path,
you MAY make ONE `browse_tokens` call to inform `token_grammar:` +
`inventory.tokens.total_tokens`. **ONE.**

**Probe budget — consolidated across Contract 3-bis, Contract 4, and
`tool-leverage.md` §4.1.** Below is the full per-path probe ledger. Use
this table as the single source-of-truth; do NOT triangulate across
the three sources for budget answers.

| Path | Trigger | Max calls | Counts against Contract 4 budget? | Counts against Rule-A `tool_survey:` quota? |
|---|---|---|---|---|
| **Path 1** — DS-tokens-MCP `browse_tokens` | `mcp__<ds>-tokens__browse_tokens` visible OR `scaffold.resolver.mcp_name` set | **1** (depth=2 typical) | **YES** (the canonical Contract 4 cap) | NO |
| **Path 2** — Filesystem-walk DTCG | `tokens/` dir on disk + DS-MCP absent | **unbounded** (depth-2 cap on `jq paths` recommended) | NO (filesystem path is budget-exempt — see §-block in `tool-leverage.md` §4.1) | NO |
| **Path 3** — Figma-MCP Variables | `regime: figma-variables` AND DS-MCP absent AND `tokens/` absent | **1** `figma_get_variables(format=summary)` + **1–3** `figma_get_variable_defs(nodeId)` (sparse evidence sampling only) | **YES** (`format=summary` call counts; `get_variable_defs` calls count if invoked) | NO |
| **Rule-A tool-survey** (Contract 3-bis) | Any blind-spot claim asserting capability gap of loaded MCP-tool surface | **As many as needed** to populate `tool_survey: {probed, result, tools_not_probed}` (Contract 3-bis floor: 1 per gap-claim) | NO (Rule-A probes are budget-exempt — they qualify a blind-spot, not the synthesis-content) | YES (the probes ARE the survey) |

**Forbidden across all paths** (already in Contract 4 prose, repeated
for table-completeness): multi-call `browse_tokens` analysis loops;
`resolve_token` per-leaf; `compose_theme` / `find_placeholders` /
`check_design_rules` / `compare_themes` (audit tools, not Snapshot
tools); `format=full` or `resolveAliases=true` on Path 3.

In the **filesystem-walk fallback path** (no DS-tokens MCP loaded, but
DTCG/Tokens-Studio JSON files exist on disk), path-level enumeration is
**encouraged, not budget-bound** — emit at minimum set-level + top-level
2-segment-prefix grammar. The fallback path uses a different tool surface
(`jq paths` over DTCG files, depth-capped) — it is governed by the
"Token enumeration paths" §-block in
`../../../shared/cdf-source-discovery/tool-leverage.md` (under §4),
NOT by Contract 4's `browse_tokens` cap. Per-leaf enumeration remains
best-effort even in the fallback path; depth-2 is the recommended cap to
prevent unbounded `jq paths` traversal on giant token-trees.

Forbidden on the DS-MCP path:

- Multi-call `browse_tokens` analysis loops ("let me check `color.*` then
  `dimension.*` separately"). That is Production-Scaffold Phase-3
  territory.
- Calling `resolve_token` per leaf to confirm values.
- Calling `compose_theme` / `find_placeholders` / `check_design_rules`
  / `compare_themes` — these are audit tools, not Snapshot tools.

Single call shape (DS-MCP path): `browse_tokens` with the broadest
practical depth (`depth=2` typical) over the root namespace. Paste the
result into prose-form summary inside `token_grammar:` entries'
`evidence_path` + `inventory.tokens.note`. Do NOT round-trip the call
results into multiple `token_grammar` entries that imply per-leaf
inspection happened — it didn't.

**Path 3 (Figma-MCP Variables) — when `regime: figma-variables` AND
no DS-MCP loaded AND no `tokens/` directory exists.** Figma Variables
ARE the token system; treat
`mcp__figma-console__figma_get_variables` as the canonical
token-source probe — not as outlier-fallback. Budget on this path:

- **1× `figma_get_variables(format=summary)`** for collection / mode /
  total-count enumeration (preferred — single round-trip, returns the
  full collection list with mode names).
- **1–3× `figma_get_variable_defs(nodeId)`** for per-component-binding
  sampling, ONLY if a finding-level claim requires per-node binding
  evidence.

Do NOT use `format=full` or `resolveAliases=true` at the Snapshot stage
— those are Production-Scaffold Phase-3 territory. Snapshot enumerates
names + collection / mode structure; per-mode resolved values stay in
the `Snapshot did not deep-resolve …` blind-spot. Path 3 is
budget-equivalent to Path 1's single `browse_tokens` call: ONE
structural enumeration probe, optional sparse evidence sampling.

If no token-MCP is available **and** no DTCG files are on disk **and**
the regime is not `figma-variables`, set
`inventory.tokens.enumeration_method: walker_only` (or `none`) and emit
`token_grammar:` only when grammars are inferable from token PATHS
visible in `phase-1-output.yaml`. Add a blind-spot naming the missing
token surface.

**Components/* heuristic.** If `tokens/Components/<Name>.json` (or
similar `tokens/<Component-or-Override>/`) sets exist, read content
**even if budget-tight** and emit a separate `Components`-style
token_layer entry — this is structural signal about the DS's
token-cascade architecture, not detail-noise. The Production-Scaffold
reference Profile typically surfaces Components as a `token_layer` with
`always_enabled: true`; Snapshot can flag the layer's presence in
~30 s with `ls tokens/Components/*.json | wc -l` + per-file leaf-count.

### Contract 5 — FINDINGS: max 15, flag-only, no decision-vocab

`findings_unclassified[]` carries at most **15** entries. Each entry is
three fields: `topic`, `observation`, `evidence_path`. That's it.

Forbidden fields (these are Production-Scaffold features — adding them
silently classifies, which is a Rule-E violation):

- `decision`, `severity`, `cluster`, `defer_reason`, `block_reason`
- `plain_language`, `concrete_example`, `default_if_unsure`
- `user_decision`, `accepted_as_divergence`

Forbidden behaviours:

- Sub-clustering findings into batches.
- Sorting by severity (you have no severity to sort by).
- Recommending action ("we should …", "consider …"). Snapshot is
  flag-only: "this is what stood out." The Production Scaffold's
  Phase-6 classifies. The upgrade-path is how that gets unlocked.

If more than 15 findings surface, prune to the most signal-bearing.
Add a blind-spot entry naming "additional findings beyond 15-cap not
surfaced."

### Contract 6 — STANDALONE-TOKENS: leaf-only (defensive)

`snapshot.profile.schema.yaml` does NOT include `standalone_tokens:` —
Snapshot deliberately omits it (the soft-boundary section is
`token_grammar` only). If you find yourself reaching for
`standalone_tokens:` mid-draft, that is a sign you are drifting toward
Production-Scaffold output shape — STOP and reclassify the entry.

If `standalone_tokens:` is emitted anyway (e.g. drift, or because the
LLM is treating the snapshot as a Profile-shaped seed for downstream
re-use), the **same leaf-only rule the Production Phase-7 schema's
(★7) marker enforces** applies here verbatim:

> Every entry MUST be a leaf path in the DTCG corpus, with a declared
> `dtcg_type` and `description`. Namespaces (`colors`, `shadow`,
> `Display`, `dimension`, …) are grammar candidates, NEVER standalones.
> A namespace has children with their own values; a leaf resolves
> directly to a single value (or to a small flat enumeration listed
> inline under `values:`). Flat lists are not accepted.

Self-check before promoting any path to `standalone_tokens`: would
`browse_tokens(path_prefix=$path, depth=1)` return ≥1 child? If yes,
it is a namespace — reclassify as a `token_grammar` candidate, OR
demote to a finding ("token namespace `$path` not yet structured into
a grammar — Production Scaffold Phase-3 should resolve").

Good vs bad examples appear in §4 below.

---

## §2 · Per-Section Synthesis

Run the synthesis as one continuous pass. Draft section by section, in
schema order, citing as you go. The schema's annotations
(`[walker]`, `[config]`, `[llm-draft]`) tell you the source for each
field — never invent a value the schema marks `[walker]` or
`[config]`.

### 2.1 — `metadata` (REQUIRED · HIGH trust)

Source: `.cdf.config.yaml` for `ds_name`, `figma_file_url`,
`identifier`, `tier`, `token_regime`, `parent_profile`. Walker's
`figma_file.file_name` for `figma_file_name`. Walker's
`schema_version` for `walker_version` (must be `phase-1-output-v1`;
hard-fail if mismatch — bump skill, don't paper over).

`generated_at:` is the current ISO 8601 UTC timestamp at emit.
`generated_by.skill_version:` is `0.1.0-spike` until the skill bumps.

`parent_profile:` is RECORDED from config but the snapshot does NOT
honour `extends:` merge semantics — emit absolute observations (per
`../../../shared/cdf-source-discovery/source-discovery.md` §4
last-paragraph). Note the parent in `metadata` so the upgrade-path
inherits it.

### 2.2 — `inventory` (REQUIRED · HIGH trust)

Verbatim subset of `phase-1-output.yaml.ds_inventory`. Copy these
fields one-to-one (no recomputation, no rounding):

- `pages.total`, `pages.content`
- `component_sets.tree_unique_count`, `indexed_count`,
  `remote_only_count`
- `standalone_components.{utility,documentation,widget,asset}` — counts
  from the array lengths; if walker pre-classified, trust it (per
  walker-invocation.md §2: standalone classification is "starting
  point, not truth," but Snapshot is flag-only — surface
  reclassification need as a finding, do NOT relabel)
- `documentation_surfaces.figma_component_descriptions.{with_description,
  without_description,ratio}`
- `documentation_surfaces.doc_frames_detected` — count of name-pattern
  matches from walker's `doc_frames_info`

For `tokens:` sub-block: ONE `browse_tokens` call at most. Record
`enumeration_method`, `total_tokens`, and one-line `note`. If no
token-MCP, set `enumeration_method: none` and `total_tokens: null`.

Citation rule: every numeric value here MUST trace to a walker field
of the same name. The schema annotates each as `[walker]` for exactly
this reason — copy, don't compute.

**Inventory aggregator — paste-ready (large-file path).** When §0's
100-KB / 2000-line threshold fires, do NOT hand-author a fresh jq
query. Use this canned aggregator — it produces every field the
`inventory:` block needs from `ds_inventory` in one round-trip:

```bash
yq -o=json '.ds_inventory' .cdf-cache/phase-1-output.yaml | jq '{
  pages: {total: .pages.total, content: .pages.content},
  component_sets: {
    tree_unique_count: .component_sets.tree_unique_count,
    indexed_count: (.component_sets.indexed_count // .component_sets.total),
    remote_only_count: .component_sets.remote_only_count
  },
  standalone_components: {
    utility: (.standalone_components.utility | length // 0),
    documentation: (.standalone_components.documentation | length // 0),
    widget: (.standalone_components.widget | length // 0),
    asset: (.standalone_components.asset | length // 0)
  },
  documentation_surfaces: (.documentation_surfaces // {
    figma_component_descriptions: (.figma_component_descriptions // {with_description: 0, without_description: 0, ratio: 0}),
    doc_frames_detected: (.doc_frames_info.count // 0)
  }),
  tokens: {
    enumeration_method: .tokens.enumeration_method,
    total_tokens: .tokens.total_tokens
  }
}'
```

**Walker-drift bridges in this aggregator** (sister to v1.0.6's
`(.indexed_count // .total)`):

- `(.component_sets.indexed_count // .component_sets.total)` — bridges
  v1.7.x walker's `total` field rename to `indexed_count`. Documented
  in [`walker-invocation.md` §2](../../../shared/cdf-source-discovery/walker-invocation.md);
  falls back to `.total` when `.indexed_count` is absent so the snapshot
  succeeds against either walker version. Sunsets when v1.8.0
  alias-bridge lands.
- `(.documentation_surfaces // {figma_component_descriptions: ..., doc_frames_detected: ...})` —
  bridges v1.7.x walker's flat `figma_component_descriptions` +
  `doc_frames_info` to the schema-expected `documentation_surfaces`
  wrapper. Walker auto-emit queues for v1.8.0; until then this alias
  keeps `inventory:` synthesis green against the live walker. Inner
  `// {with_description: 0, ...}` defaults trigger when neither flat
  fields NOR wrapper exist — synthesis still completes (with 0-counts
  surfaced as a documentation-blind-spot finding).

**Walker top-level metadata aggregator — paste-ready (sibling to the
`ds_inventory` aggregator above).** Use this when you need
walker-top-level fields for `metadata:` synthesis or seeded-findings
review, NOT another hand-rolled query (V1+V3 item 1 reproduces in
ad-hoc authoring):

```bash
yq -o=json '.' .cdf-cache/phase-1-output.yaml | jq '{
  schema_version: .schema_version,
  generated_at: .generated_at,
  generated_by: .generated_by,
  figma_file: .figma_file,
  libraries: (.libraries // {}),
  theming_matrix: (.theming_matrix // {collections: []}),
  token_regime: .token_regime,
  token_source: .token_source,
  seeded_findings_count: (.seeded_findings | length // 0),
  seeded_findings: (.seeded_findings // [])
}'
```

Note the `(.libraries // {})` and `(.theming_matrix // {collections: []})`
defaults — older walker versions OR figma-variables-regime runs may
omit the field entirely; the default keeps downstream synthesis
robust against absence.

**T0/T1 inventory-semantic note (F12).** If both T0 (runtime walker) and
T1 (REST walker) artefacts are available — e.g. tier-detection ran a
probe before falling to T0, and both produced data — emit a one-line
note in `inventory:` explaining which metric was used and why. T0
counts every variant-instance (`componentsTotal` field), T1 dedupes by
COMPONENT id (`component_count` field); on the same file these can
differ by 5–10× (e.g. T0 = 1615 vs T1 = 191 on a real-world mid-size DS).
Prefer T1's deduped counts when both are available. The semantic detail
lives in `../../../shared/cdf-source-discovery/walker-invocation.md`
(Inventory-counting semantic difference T0 vs T1) — cite that section
in the note. If only one tier ran (the typical case), no note is needed.

### 2.3 — `blind_spots` (REQUIRED · HIGH trust · LLM-targeted)

The trust handshake. See Contract 3 above. Use the seven
recurring blind-spot topics in the schema's annotation as a CHECKLIST:
include each topic if applicable to this scan, skip if genuinely not
relevant. Then add scan-specific entries (numbers from
`inventory:`).

Every blind-spot entry follows the shape: "<concrete capability not
verified> — <one short clause naming the count or context that makes
this a real gap, not a generic disclaimer>."

Anchor at least one entry to an `inventory:` count. If you cannot
anchor any entry to a real number, the blind-spots list is too
generic — redraft.

Examples and a good vs bad pair appear in §3 below.

### 2.4 — `upgrade_path` (REQUIRED · HIGH trust · template)

Copy the canonical text from the schema's `upgrade_path:` literal
verbatim. You MAY append ONE sentence iff something in the scan makes
the upgrade path materially nontrivial (e.g. T0 path; non-cached
file; `quality_rating: 0` token regime). Do NOT pad with motivational
prose — the renderer hard-codes the call-to-action invocation
separately.

Canonical text (from schema):

```yaml
upgrade_path: |
  Run cdf-profile-scaffold for the rigorous 7-phase scaffold. It can
  use this snapshot as a Phase-1 seed (~5 min savings vs from-scratch).
  The Production Scaffold classifies findings (block/defer/adopt),
  validates the emitted Profile against cdf_validate_profile L0–L7,
  and produces a Profile generators can consume.
```

### 2.5 — `vocabularies` (OPTIONAL · `_quality: draft`)

Source: variantOptions across
`ds_inventory.component_sets.entries[].propertyDefinitions`. Each
detected vocabulary becomes one entry (name + description + values +
evidence_path).

#### Detection threshold (F10-loosened — bridge to v1.8.0 `analyzeInventory()`)

The pre-F10 threshold (≥2 sets sharing overlapping value-set) lost signal
on messy real-world DSes — single-set DS-wide concepts (`intent`,
`density`, `progress`, `orientation`, `range-position`) were demoted to
findings, halving the vocab-count vs the Production-Scaffold reference.
The new threshold:

```
Default rule:           ≥2 sets sharing overlapping value-set → vocabulary
Single-set promotion:   ≥1 set IF the value-set is semantically self-evident
                        as a DS-wide concept. Two qualifying signals (either
                        is sufficient):
                        (a) canonical names — the property name is one of
                            `intent`, `density`, `progress`, `orientation`,
                            `position`, or close lexical variants — these
                            are DS-architecture primitives that recur across
                            DSes regardless of single-instance count
                        (b) closed-enum shape — value-set has ≥3 distinct
                            named values forming a closed enumeration with
                            non-generic semantic names (e.g. `[completed,
                            current, upcoming]` qualifies; `[s, m, l]`
                            does not — names are too generic to confirm
                            DS-wide concept)
Boolean-shape promotion: VARIANT properties with `[true, false]` value-set
                        recurring on ≥3 sets surface as TWO entries:
                        (i)  top-level `vocabularies.<name>` entry
                        (ii) `interaction_a11y.patterns.<verb>` entry
                        E.g. `selected` (8 sets) → BOTH `vocabularies.selected`
                        AND `patterns.selection`. The vocabulary surfaces
                        the concept; the pattern surfaces the interaction
                        contract. Both views are signal.
Icon-Set heuristic:     If a `name` (or `icon-name`, `Icon`) VARIANT
                        property recurs on ≥10 sets with single-icon-name
                        value-shape (one icon name per variant; values
                        like `chevron-down`, `arrow-right`), elevate as
                        ONE icon-name vocabulary across the family —
                        not N separate findings. The full name-set is
                        the union of all 10+ sets' values.
```

#### Worked examples (good vs bad)

❌ **BAD — pre-F10 strict reading**:

```yaml
vocabularies:
  hierarchy:        # 4 sets — qualifies under default rule
    values: [primary, secondary, tertiary]
findings:
  - topic: "Status Chip has single-set `intent` axis"
    observation: "Status Chip declares intent variant [error, info, neutral, success, warning] but no other component shares it"
```

✅ **GOOD — F10-loosened reading**:

```yaml
vocabularies:
  hierarchy:                              # default rule (≥2 sets)
    values: [primary, secondary, tertiary]
  intent:                                 # single-set promotion (a) — canonical name
    values: [error, info, neutral, success, warning]
    evidence_path: ds_inventory.component_sets.entries[<i>].propertyDefinitions.intent.variantOptions
    note: "Single-set canonical concept; mirrors token-grammar `color.system-status.{intent}.*`"
  selected:                               # boolean-shape promotion (8 sets)
    values: [true, false]
    evidence_path: <8 sets where `selected` recurs>
    note: "Also surfaced as interaction_a11y.patterns.selection"
interaction_a11y:
  patterns:
    selection:                            # paired with vocabularies.selected
      states: [unselected, selected]
      evidence_path: <same 8 sets>
```

The reframed view: `intent` was a vocab-with-token-mirror missed; `selected`
was a vocab-and-pattern dual-view missed. Both are signal under F10.

#### Risk note — when in doubt, surface-as-finding

These promotion rules apply when the LLM can **confidently identify** the
semantic concept. If unsure (the value-set is ambiguous, the property name
is generic like `state` or `style`, the values are mostly numbers), default
to surfacing-as-finding — Production Scaffold Phase-2 isolation pass will
promote it later if appropriate. Snapshot's promotion rules are
**high-recall** by design, but the LLM's "confidence" gate is the
quality control. R6 mitigation: if Snapshot output surfaces obvious junk
vocabs (e.g. one-off color modifiers, internal property-name leaks),
the threshold should re-tighten on next iteration.

#### Demotion rule — polymorphic-name guard (V1+V3 retro item 8)

F10 promotes generously; this clause catches the symmetric failure mode —
generic-named **per-component-role** properties that look like vocabularies
but resolve to disjoint role-sets per component. **Demote to a finding,
NOT a vocabulary entry**, when ALL THREE conditions hold:

1. **Property name** ∈ {`Type`, `Style`, `Configuration`, `Layout`,
   `Variant`} OR a close lexical variant.
2. **Value-set size** ≥ 20 distinct values across the union.
3. **Cross-cluster shape** — the values span multiple semantic clusters
   (e.g. button hierarchies + chip styles + image fits + color-scheme
   aliases all under one axis), not one homogeneous concept.

All three required: a 25-value `Type` axis on chips alone is a vocabulary
(homogeneous role-set), but a 59-value `Type` spanning Day-Picker / Filter
Chip / Avatar / Modal / Banner is the polymorphic case this clause
catches. Surface as:

```yaml
findings_unclassified:
  - topic: "`<Property>` is a polymorphic per-component property, not a global vocabulary"
    observation: "<N> component sets share a `<Property>` variant property, but its <M>-value union is the union of disjoint per-component role-sets — <name1> uses [<sample-3>], <name2> uses [<sample-3>], <name3> uses [<sample-3>]. Production Scaffold Phase-2 will surface as N per-component vocabularies (or accept-as-divergence)."
    evidence_path: "ds_inventory.component_sets.entries[].propertyDefinitions.<Property>.variantOptions"
```

This complements F10's promotion rules: promotion catches missed vocabs;
demotion catches over-promoted vocabs. Both work the same evidence (the
`variantOptions` map across all sets) — just different failure modes.

#### Citation rule (unchanged)

Every vocabulary's `values:` list traces to specific
`entries[i].propertyDefinitions.<PropName>.variantOptions`. The
`evidence_path:` field MUST reach down to the variantOptions cell. If
multiple entries share the same vocabulary, cite the canonical-looking
one (or the first detected) — do not list all.

Snapshot OMITS Profile §5 fields per the schema annotation: `aliases`,
`per_category`, `notes`, `casing`. Surfacing those is Production
synthesis work.

#### v1.8.0 sunset note

The F10 threshold rules above are an **LLM-policy bridge**. v1.8.0 ships
`cdf_analyze_inventory` as a deterministic-code synthesis primitive that
replaces this §2.5 policy with a pure function — see
`docs/plans/active/2026-04-26-v1.8.0-roadmap.md`. Until then, the LLM
applies the rules above; their job is to make Snapshot output close enough
to the v1.8.0 mechanized result that the v1.8.0 swap is a quality
improvement, not a behavior break.

### 2.6 — `token_grammar` (OPTIONAL · `_quality: draft`)

Source: ONE `browse_tokens` call (Contract 4). Each detected dotted
prefix becomes one grammar entry with `pattern`, `dtcg_type`,
`description`, compact `axes`, and `evidence_path` (the MCP call +
prefix). Do NOT promote a path to a grammar without verifying it has
≥2 axes worth of structure visible in the browse output.

`dtcg_type` is REQUIRED per schema (matches Profile §6 / phase-7-output
(★4)). If the browse output does not surface a clear DTCG `$type`,
omit the grammar entry and surface as a finding ("grammar candidate
`<prefix>` could not be confirmed without per-leaf inspection — out of
Snapshot scope").

Snapshot OMITS Profile §6: `contrast_guarantee`, per-axis notes,
`token_layers`, `resolution`. Production-only.

If no token-MCP available: skip this section entirely (set in
blind_spots). Do NOT infer grammars from token paths surfaced
incidentally in `phase-1-output.yaml` unless those paths follow a
clear dotted-prefix pattern across ≥3 tokens — a single observed token
path is not a grammar.

### 2.7 — `theming` (OPTIONAL · `_quality: draft`)

Source: `theming_matrix.collections[]` (filled by the resolver per
walker-invocation.md §3) OR — if resolver did not run — the
`browse_tokens` output's mode-name list if available. One modifier per
collection.

Each modifier carries `description`, `contexts:` (the mode names),
optional `default:`, and `evidence_path:` ("Figma Variables collection
`Semantic`" or equivalent).

Snapshot does NOT emit `set_mapping` (Profile §8.3) — that requires
real DTCG file paths and is validator-territory. If the User asks for
it, point to the upgrade-path.

Modifier-name inference is heuristic. Add a blind-spot entry naming
"theming axes inferred from variable-collection mode-names; not
cross-validated against component usage" (verbatim from schema's
suggested topics).

**Fallback when `theming_matrix.collections: []` is empty.** If the
walker emits an empty `theming_matrix.collections` (typical when
`.cdf.config.yaml` has no explicit `resolver:` block but `regime:
tokens-studio` is set and `tokens/$themes.json` exists on disk), the
walker has not auto-resolved the theming-axes. Manual recovery:

```bash
# Surface theme-collection groups + member-counts:
jq -r '
  group_by(.group) | map({
    group: .[0].group,
    members: [.[] | .name]
  })
' tokens/\$themes.json
```

Each `group` becomes a theming-modifier; each `members[]` becomes its
`contexts[]` value list. Cross-validate against component-side VARIANTS
named after these axes (e.g. `device` axis → `device` VARIANT
property).

Walker auto-resolve queues for v1.8.0 (`cdf_extract_figma_file` will
auto-fill `theming_matrix.collections` from `tokens/$themes.json` when
`regime: tokens-studio`).

**Fallback when `theming_matrix.collections: []` is empty AND
`regime: figma-variables`** (sister to the `tokens-studio` fallback
above; resolved inline rather than via 3-doc-hop). The walker has not
auto-resolved theming-axes from the Figma Variables collections (queued
for v1.8.0 walker work). Recover via Path 3 of Contract 4:

```
mcp__figma-console__figma_get_variables({format: "summary"})
```

Each collection in the response becomes a theming-modifier; each mode
becomes its `contexts[]` value list. Worked example: a 4-collection
Variables file (e.g. one M3 mode pair Light/Dark, one font theme pair
Plain/Expressive, plus single-mode Typescale and Shape collections) →
modifiers `color_scheme: [light, dark]` + `font_theme: [plain,
expressive]` (Typescale and Shape have one mode each — surface as
scope-bound, not modifier-axes).

Budget: this is the SAME single `figma_get_variables(format=summary)`
call that Contract 4 Path 3 budgets — it covers token-source
enumeration AND theming-axis recovery in one round-trip. Do NOT issue
a second call for theming.

Walker auto-resolve queues for v1.8.0 (`cdf_extract_figma_file` will
auto-fill `theming_matrix.collections` from `figma_get_variables`
when `regime: figma-variables`). Until then this fallback is
load-bearing for figma-variables-regime DSes.

### 2.8 — `interaction_a11y` (OPTIONAL · `_quality: draft` · LOWEST trust)

Source: variant property names like `State`, `Interaction`, `Focus` in
`entries[].propertyDefinitions`. Treat these as PATTERN SKETCHES, not
validated patterns.

Each pattern carries `description`, `states:` list, `evidence_path:`
(the variant-property reference). Snapshot OMITS `token_layer`,
`token_mapping`, `orthogonal_to`, `promoted` — Production-only.

`accessibility_notes:` is free-form prose with a REQUIRED "NOT
VALIDATED" prefix. Heuristic-only — focus-strategy intuition,
contrast posture (without contrast checks), reduced-motion presence.
If you cannot say something concrete with a "NOT VALIDATED" prefix,
omit and add a blind-spot.

This is the lowest-trust section. The blind-spots list MUST flag this
explicitly.

### 2.9 — `findings_unclassified` (OPTIONAL · max 15)

Source: anything that stood out during the synthesis pass that wasn't
a clean fit for the structured sections. Common topics:

- Vocab-near-misses (`hover` vs `hovered`, `xs` vs `extra-small`).
  Detection is observational here — Snapshot does NOT run the
  near-miss lint (that is `cdf-profile-scaffold` Phase-2 territory).
- Component-local variant properties that look like vocabulary
  candidates but only appear on one component set.
- Standalone-component classifications that look mis-labeled
  (walker's pre-class is starting-point — flag the candidate as
  finding, do NOT relabel inventory).
- Doc-frame coverage gaps (count from walker, paired with the
  description-ratio).
- Token namespaces that look like grammar candidates but lack
  per-leaf signal in the single browse_tokens pass (per Contract 6).
- Remote-library refs that may be intentional vs legacy (walker's §C
  seed-finding gives the count).

Each entry carries ONLY: `topic` (short title), `observation` (one
paragraph, factual, no "we should"), `evidence_path` (walker path or
MCP ref). Contract 5 forbids decision/severity/cluster fields.

15-cap is hard. If pruning happens, add one blind-spot entry naming
"additional findings beyond 15-cap not surfaced — Production Scaffold
Phase-6 classifies the full set."

---

## §3 · `blind_spots` Examples (Good vs Bad)

The blind_spots list is where the trust handshake breaks if drafted
lazily. Below: one paired example for each of two recurring failure
modes.

### Failure mode A — boilerplate copy-paste (no scan-specificity)

❌ **BAD** — generic, unfalsifiable, copy-pasteable to any DS:

```yaml
blind_spots:
  - "Findings are unclassified. Run cdf-profile-scaffold for full audit."
  - "Vocab-collisions not analyzed."
  - "Token gaps not audited."
  - "Theming axes not validated."
  - "This is a snapshot — production review recommended."
```

Reader cannot tell whether the Snapshot looked at this DS or any other
DS. The last entry is meta-disclaimer, not a blind-spot.

✅ **GOOD** — anchored to inventory counts, scan-specific:

```yaml
blind_spots:
  - "Findings classification status — 8 findings surfaced unclassified
    (no block/defer/adopt). Production Scaffold Phase-6 classifies."
  - "Vocab-collision analysis across the 23 detected component sets
    not run — Profile §5.5 isolation pass would surface near-misses
    like `hover` vs `hovered` if present."
  - "Token gap audit — 1 of 192 sets carry Figma descriptions (0.5%
    coverage). Whether doc-frames cover the gap not verified."
  - "Theming axes inferred from `theming_matrix.collections[0].modes`
    (`Light`, `Dark`); not cross-validated against component-set
    mode-aware variant usage."
  - "Interaction patterns sketched from `State` variant property on 4
    of 23 sets; component-state coverage not validated."
  - "Validator status — Snapshot is NOT validator-grounded
    (cdf_validate_profile not run). Production Scaffold Phase-7 runs
    L0–L7."
  - "Standalone-classification author-confirmation — walker
    pre-classified 12 utility / 3 doc / 0 widget / 8 asset; not
    User-confirmed."
  - "Remote-library refs (3 of 26 indexed) not deep-inspected; may be
    intentional foundation-library or legacy stale ref."
```

Each entry is falsifiable, anchored to an `inventory:` number, names a
concrete capability the Snapshot did not run. Production-Scaffold
upgrade actually addresses each one.

### Failure mode B — over-claiming what the Snapshot DID do

❌ **BAD** — claims certainty Snapshot did not earn:

```yaml
blind_spots:
  - "Token grammar fully audited via 12 browse_tokens calls"  # Contract 4 violation
  - "Component states cross-validated against Figma reactions"  # Snapshot doesn't do this
  - "0 vocab-near-misses detected"  # Snapshot didn't run the lint
```

A blind-spot list must list what was NOT done, not over-claim what
was. Three lines above are claims masquerading as confessions.

✅ **GOOD** — already covered in failure-mode-A example.

---

## §4 · Standalone-Tokens Leaf-Only Examples (Good vs Bad)

Snapshot's schema does NOT include `standalone_tokens:` (Contract 6).
If the synthesis emits one anyway, the leaf-only rule applies. Below:
borrowed wording from `cdf-profile-scaffold` Phase-7 schema's (★7)
marker, adapted to Snapshot context.

### ✅ Leaf paths — RESOLVES TO A SINGLE VALUE

```yaml
standalone_tokens:
  color.page:
    dtcg_type: color
    description: Page-level background fill
    values: [primary, secondary]   # optional small inline enum
  focus.outer:
    dtcg_type: color
    description: Focus-ring outer halo color
  border.radius.pill:
    dtcg_type: dimension
    description: Fully-rounded radius for pill-shaped controls
```

Each path is a leaf in the DTCG corpus: `browse_tokens(path_prefix=
"color.page", depth=1)` returns no children; `color.page` resolves
directly to a value (or to the small inline `values:` enumeration).

### ❌ Namespaces — HAS CHILDREN, NOT A LEAF

```yaml
standalone_tokens:
  colors:                  # ✗ namespace — has children color.controls.*, color.text.*, …
    dtcg_type: color
    description: All colors in the system
  Display:                 # ✗ namespace — has children Display.heading.*, Display.body.*, …
    dtcg_type: typography
    description: All display text styles
  dimension:               # ✗ namespace — has children dimension.spacing.*, dimension.size.*, …
    dtcg_type: dimension
    description: All sizing values
```

Each path is a NAMESPACE: it has children with their own values.
Reclassify as a grammar candidate (`color.controls.{hierarchy}.{element}`,
`Display.{role}.{size}`, `dimension.spacing.{step}`) and surface a
finding if the grammar is unclear, OR demote the entry entirely if
the single-pass synthesis cannot confirm the grammar shape.

### Self-check before promotion

For any path you are about to write under `standalone_tokens:`, ask:
*"Would `browse_tokens(path_prefix=<path>, depth=1)` return ≥1 child?"*

- If YES → namespace. Do NOT emit as standalone. Reclassify as
  grammar candidate or finding.
- If NO → leaf. Safe to emit. `dtcg_type` + `description` REQUIRED.

This is the same self-check Production Phase-3 runs (per the
phase-3-grammars.md Step 3.2 reference embedded in the (★7) marker
of phase-7-output.schema.yaml). Snapshot deliberately avoids the
underlying `browse_tokens(depth=1)` round-trip (Contract 4 — one call
total), so the safe default is: **don't emit standalone_tokens from
Snapshot at all**. Surface ambiguous paths as findings, let the
upgrade-path resolve them.

---

## §5 · Architecture Reminders (Load-Bearing)

### Source-of-truth: the walker, NOT live Figma

The walker artefact at `.cdf-cache/phase-1-output.yaml` IS the
inventory (per
`../../../shared/cdf-source-discovery/walker-invocation.md` §1). Do
NOT re-read Figma to "confirm" walker output. Synthesis interprets
the walker; it does not re-derive.

If a number in the walker output looks wrong, that is a tier-detection
or fixture-path issue — surface as a blind-spot ("walker output looks
inconsistent with file-name; recommend re-running `cdf_extract_figma_file`
after refreshing the source cache: `cdf_fetch_figma_file({force_refresh:true})`
for T1, or recapturing the `figma_execute` tree for T0") and continue.
Do NOT patch by re-reading Figma in this skill.

### Output layout: `.cdf-cache/` cache, top-level deliverables

Per `../../../shared/cdf-source-discovery/source-discovery.md` §6
deliverable convention:

| Artefact | Where |
|---|---|
| `<ds>.snapshot.profile.yaml` | top-level (DS-test-dir root), DS-prefixed |
| `<ds>.snapshot.findings.md` | top-level, DS-prefixed |
| Raw synthesis intermediates (if any) | `<ds-test-dir>/.cdf-cache/snapshot/` |

`mkdir -p ".cdf-cache/snapshot/"` before writing any intermediate. The
walker already created `.cdf-cache/` if it ran.

### NO cross-references to Production-Scaffold phase docs

This synthesis pass is self-contained. You MUST NOT load (`Read`) any
of the following — they are scaffold-internal and will pull in
contracts inappropriate for Snapshot's audience:

- `../../cdf-profile-scaffold/references/phases/phase-1-orient.md`
- `…/phase-2-vocabularies.md`
- `…/phase-3-grammars.md`
- `…/phase-4-theming.md`
- `…/phase-5-interaction-a11y.md`
- `…/phase-6-findings-classify.md`
- `…/phase-7-emit-validate.md`
- `…/foreign-ds-corpus/*` reference Profiles
- `…/findings-doc-template.md`

Snapshot has its own SKILL.md, its own schema, its own renderer
(QL.D). The only files outside the snapshot skill that you may load
are the three under `../../../shared/cdf-source-discovery/` (already
loaded by SKILL.md §1) and `.cdf.config.yaml` if present.

The exception to the no-cross-reference rule: this synthesis doc
borrows leaf-only wording from `phase-7-output.schema.yaml`'s (★7)
marker — the wording is borrowed inline (§4 above). Do NOT re-read
phase-7-output.schema.yaml at run time.

### NO Production-Scaffold features sneak in

Concretely forbidden in Snapshot output (each is a Production-only
feature; reaching for it is the adoption-funnel anti-pattern this
skill exists to prevent):

| Feature | Where it belongs |
|---|---|
| Findings classification (block / defer / adopt-as-divergence) | `cdf-profile-scaffold` Phase 6 |
| Vocab-isolation lint / §5.5 isolation pass / CDF-STR-011 | `cdf-profile-scaffold` Phase 2 + `cdf_validate_profile` L8 |
| Validator runs (`cdf_validate_profile` L0–L7) | `cdf-profile-scaffold` Phase 7 |
| Token-gap audit (placeholders, magenta, contrast guarantees) | `token-audit` skill |
| Conformance overlays (Profile-Spec divergences) | `cdf-profile-scaffold` Phase 6 dialog |
| Component-level scaffolding | future `cdf-component-scaffold` |

If the User asks for any of these mid-Snapshot, point to the
upgrade-path in SKILL.md §3. Do NOT silently start running them.

---

## §6 · Hand-Off

Once the eight schema blocks are drafted and self-checked against the
six contracts:

1. `Write` `<ds>.snapshot.profile.yaml` at the DS-test-dir root.
   Filename uses the `metadata.ds_name` value. The schema-shaped
   YAML is the canonical artefact — humans + downstream tools read it.
2. `Write` `<ds>.snapshot.findings.yaml` (sibling, same prefix). Shape
   is `schema_version: snapshot-findings-v1` with a top-level
   `findings:` array of `{topic, observation, evidence_path}` entries
   (≤15). The shape contract is documented in the header comment of
   `scripts/render-snapshot.sh` (and mirrored by the
   `cdf_render_snapshot` MCP tool). Synthesis writes ONLY the YAML —
   `<ds>.snapshot.findings.md` is the renderer's job.
3. SKILL.md §4 dispatches `cdf_render_snapshot({snapshot_dir})`
   (or the deprecated `bash scripts/render-snapshot.sh <ds-test-dir>`),
   which discovers the two YAML files and emits the four-section
   findings.md (banner → findings → blind-spots → upgrade-path).
4. Return to SKILL.md §3 for the Discovery → Commit handoff prompt.
   Do NOT auto-invoke `cdf-profile-scaffold`.

The synthesis pass ENDS here. No second pass, no refinement loop, no
"now let me also …". One pass — that is the time-budget contract.

---

## §7 · Self-Check Checklist (before §6 hand-off)

Run this checklist on the drafted YAML before Writing. If any item
fails, redraft the affected section. Do NOT ship a Snapshot that
fails self-check.

- [ ] All four REQUIRED blocks present, in order: `metadata`,
      `inventory`, `blind_spots`, `upgrade_path`. (Contract 1)
- [ ] Every numeric value in `inventory:` is copied verbatim from a
      walker field of the same name. No recomputation, no rounding.
      (Contract 2)
- [ ] Every drafted entry under `vocabularies` / `token_grammar` /
      `theming` / `interaction_a11y` / `findings_unclassified` has a
      non-empty `evidence_path:`. (Contract 2)
- [ ] No quantitative claim appears without a citation. (Contract 2)
- [ ] `blind_spots:` list is anchored to ≥1 `inventory:` count and
      lists scan-specific gaps, not boilerplate. (Contract 3)
- [ ] At most ONE `browse_tokens` call was made. (Contract 4)
- [ ] `findings_unclassified[]` has ≤15 entries. Each carries ONLY
      `topic` + `observation` + `evidence_path`. No decision /
      severity / cluster / plain_language / default_if_unsure
      fields. (Contract 5)
- [ ] No `standalone_tokens:` block. If present, every entry passes
      the `browse_tokens(depth=1) returns no children` self-check.
      (Contract 6)
- [ ] Each best-effort section (vocabularies, token_grammar,
      theming, interaction_a11y, findings_unclassified) carries
      `_quality: draft` at its top level. (schema)
- [ ] `interaction_a11y.accessibility_notes` (if emitted) starts
      with `NOT VALIDATED:`. (schema)
- [ ] No cross-reference to any Production-Scaffold phase doc was
      loaded during synthesis. (§5)
- [ ] No Production-only feature (classification / vocab-isolation
      lint / validator run / token-audit) snuck in. (§5)

If all green: Write the YAML, render the findings.md, return to
SKILL.md §3.
