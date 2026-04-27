# Changelog — `cdf` Claude Code plugin

All notable changes to this plugin are documented here. The plugin
follows semantic versioning. Plugin version is independent of the
underlying [`@formtrieb/cdf-core`](https://github.com/formtrieb/cdf-core)
and [`@formtrieb/cdf-mcp`](https://github.com/formtrieb/cdf-mcp) versions
— see [`.mcp.json`](.mcp.json) for the pinned MCP-server range.

**Install:** see [`README.md`](README.md#install) — two-step
(`marketplace add` → `install cdf@cdf`).

---

## 1.0.7 — 2026-04-27

Post-v1.0.6 runtime-smoke hot-fix wave: six Skill-doc-only fixes from
the v1.0.6 Material 3 fresh-install retro (12 frictions surfaced; 6
absorbed here, 5 deferred to v1.8.0 Item 3, 1 deferred to v1.9.0+).
Doc-only release — no `@formtrieb/cdf-core` / `@formtrieb/cdf-mcp`
version bumps; `.mcp.json` caret-pin unchanged.

### Fixed (`shared/cdf-source-discovery/source-discovery.md`)

- **Friction 1 (Bucket A)** — §2 Tier-Detection algorithm gains an
  anti-shortcut callout above the T1-modern probe step: an
  `❌ DO NOT substitute a shell-env-existence check for step 3`
  block warning that `echo $FIGMA_PAT` is NOT a valid PAT-probe.
  `.mcp.json` `env` blocks inject only into the MCP-server process —
  shell-env is empty by design for designer-friendly setups. The
  ONLY reliable probe is calling `cdf_fetch_figma_file({file_key})`
  and reading the `isError` payload. Sister to Rule B's
  `feedback_capability_probe_before_default` — shell-existence is
  the classic mechanical-vs-survey anti-pattern.

### Fixed (`cdf-profile-snapshot/references/synthesis.md`)

- **Friction 4 (Bucket B)** — §0 large-file fallback gains an explicit
  `❌`/`✅` yq inline-construction anti-pattern pair with the verbatim
  lexer-error message (`Error: 1:6: lexer: invalid input text "field1, ..."`).
  Mikefarah `yq` rejects inline object construction; the recipe now
  prefixes "ALWAYS pipe `yq → jq`" and applies to ALL queries against
  `phase-1-output.yaml`, not just the §0 fallback path. V1+V3 retro
  item 1 reproduced in the v1.0.6 Material 3 run despite the §0
  positive recipe — explicit anti-pattern closes the gap.
- **Friction 4 extension (Bucket C)** — §2.2 gains a sibling
  paste-ready aggregator for **walker top-level metadata**
  (`schema_version`, `generated_at`, `generated_by`, `figma_file`,
  `libraries`, `theming_matrix`, `token_regime`, `token_source`,
  `seeded_findings`). Authors no longer hand-roll fresh `yq → jq`
  for `metadata:` synthesis or seeded-findings review — V1+V3 item 1
  reproduces in ad-hoc authoring without a canned aggregator. Defaults
  (`(.libraries // {})`, `(.theming_matrix // {collections: []})`)
  keep the query robust against figma-variables-regime omissions.
- **Friction 3 (Bucket D)** — §2.2 `inventory:` aggregator extends
  the `(.indexed_count // .total)` walker-drift bridge with a
  `documentation_surfaces` bridge: when the v1.7.x walker emits flat
  `figma_component_descriptions` + `doc_frames_info` (no wrapper),
  the aggregator falls back to constructing the schema-expected
  `documentation_surfaces` shape. Inner defaults (`with_description: 0`
  etc.) keep synthesis green even when both flat AND wrapper are
  absent. Walker auto-emit queues for v1.8.0; this alias keeps the
  v1.0.7 → v1.8.0 window unblocked. Adjacent prose now consolidates
  both bridges under a single "Walker-drift bridges in this aggregator"
  heading.
- **Friction 2 (Bucket E)** — §2.7 theming gains a parallel fallback
  block for **`regime: figma-variables`** alongside the existing
  `tokens-studio` fallback. Walker emits empty `theming_matrix.collections`
  for figma-variables runs (auto-resolution queued for v1.8.0); the
  inline fallback recovers via Path 3 of Contract 4 — single
  `figma_get_variables(format=summary)` call enumerates collections +
  modes. Budget shared with Path 3's token-source enumeration (NOT a
  second call). Material 3 retro: 4 collections → modifiers + scope-
  bound axes resolved without 3-doc-hop.
- **Friction 8 (Bucket F)** — Contract 4 (TOKEN-MCP) gains a
  consolidated probe-budget table immediately under the
  Path-applicability intro paragraph. Single source-of-truth across
  Contract 3-bis (Rule-A `tool_survey:`), Contract 4 (Path 1/2/3),
  and `tool-leverage.md` §4.1 — "max calls", "counts against
  Contract 4 budget?", "counts against Rule-A quota?" answered per
  path in one place. Authors no longer triangulate three doc
  locations to compute a budget.

### Fixed (`shared/cdf-source-discovery/tool-leverage.md`)

- **Friction 4 mirror (Bucket B)** — §4.2 (YAML extraction) gains the
  same `❌`/`✅` anti-pattern + verbatim lexer-error block as
  synthesis.md §0, plus the "Applies to ALL queries against
  `phase-1-output.yaml`" prose. Two skills referencing the same
  yq-vs-jq rule from two doc locations now share one canonical
  pattern.

### Deferred to v1.8.0 Item 3

- Walker auto-fill `theming_matrix.collections` for
  `regime: figma-variables` (Friction 2 walker-side).
- New MCP tool `cdf_validate_snapshot` (Friction 6).
- New MCP tool `cdf_query_phase1` (Friction 12).
- §Z-frame-named investigation against M3-style files (Friction 9).
- `synthesis.md` doc-restructure alongside Synthesis-as-Code rewrite
  (Friction 7).

### What didn't change

Plugin-manifest only release for the doc-side; no
`@formtrieb/cdf-core` / `@formtrieb/cdf-mcp` plugin-config changes
— `.mcp.json`'s caret-pin keeps cdf-mcp 1.7.3 + cdf-core 1.0.4. All
nine §"What NOT to touch" items from the v1.0.7 plan preserved (F10
vocab-promotion thresholds, V1+V3 polymorphic-name demotion,
Rule-A Contract 3-bis trigger-word list, B2 Path-3 Contract 4,
B5 polymorphic-name guard, B7 git-rev-parse probe, §0 100-KB threshold,
B1.b canned aggregator core, renderer telemetry shape + 15-finding cap,
Track A "What this snapshot surfaced" block).

---

## 1.0.6 — 2026-04-27

Post-V1+V3 doc hot-fix wave: seven Skill-doc-only fixes from the V1+V3
Material 3 retro. Ships in coordination with
[`@formtrieb/cdf-mcp` v1.7.3](https://github.com/formtrieb/cdf-mcp/releases/tag/v1.7.3)
(Renderer "What this snapshot surfaced" block — V1+V3 retro item 10);
the plugin's `.mcp.json` caret-pin `^1.7.2` picks up 1.7.3 transparently
on next `npx` resolution.

### Fixed (`cdf-profile-snapshot`)

- **Item 3 + 4** — `synthesis.md` §0 fallback threshold tightened from
  2 MB to **100 KB OR 2000 lines** (Read-tool 25k-token cap calibration);
  the `yq -o=json | jq` recipe is now inlined directly in §0 rather than
  cross-linked. §2.2 `inventory:` section gains a paste-ready canned
  aggregator query so authors do NOT hand-roll fresh jq for every
  large-DS run. The aggregator includes
  `(.indexed_count // .total)` to bridge the v1.7.x walker drift until
  v1.8.0 alias-bridge lands.
- **Item 5** — `synthesis.md` Contract 4 (TOKEN-MCP) gains a third
  allowed path: **Path 3 (Figma-MCP Variables)** for
  `regime: figma-variables` with no DS-MCP loaded. Path-3 makes
  `figma_get_variables(format=summary)` canonical (single round-trip
  collection/mode enumeration), not outlier-fallback. Treated as
  budget-equivalent to Path 1's single `browse_tokens` call.
- **Item 1** — yq lexer recipe inlined in §0 directly (resolved
  alongside Item 3 + 4 — the threshold-tighten edit embedded the
  recipe verbatim).
- **Item 7** — `SKILL.md` §1.4 directive: **Maximum 1
  `AskUserQuestion` at session start**; identifier + parent-Profile
  combine into one multi-field question; tier-probe is mechanically
  deterministic — run the §1 algorithm, *report* the tier, do NOT
  ask the User to confirm.
- **Item 8** — `synthesis.md` §2.5 gains a **demotion rule** symmetric
  to F10's promotion rules: properties named `Type` / `Style` /
  `Configuration` / `Layout` / `Variant` (or close lexical variants)
  with ≥20 distinct values spanning multiple semantic clusters
  surface as findings, NOT as `vocabularies` entries (catches the
  polymorphic per-component-role case where a 59-value `Type` axis
  is the union of disjoint role-sets).
- **Item 9** — both `SKILL.md` files (snapshot + scaffold) gain a §0
  tip recommending **batch `ToolSearch` at session start** —
  `select:cdf_fetch_figma_file,cdf_extract_figma_file,cdf_render_snapshot,cdf_validate_profile,figma_get_status,figma_get_variables`.
  Saves ~5 round-trips compared to lazy per-tool loading. Documents
  the two-batches-of-three fallback if `max_results=10` returns
  truncated.

### Fixed (`shared/cdf-source-discovery`)

- **Item 13** — `source-discovery.md` §6 `.gitignore` recommendation
  is now precondition-gated. Probe with
  `git rev-parse --is-inside-work-tree 2>/dev/null` — if the
  DS-test-dir is not git-tracked (typical for `~/Desktop/<scratch>/`,
  `/tmp/...` evaluation runs), skip the offer entirely. Both SKILL.md
  files declare `git` as a host-tool prerequisite alongside
  `yq`/`jq`/`python3`.

### What didn't change

Plugin-manifest only release for the doc-side; no
`@formtrieb/cdf-core` / `@formtrieb/cdf-mcp` plugin-config changes —
`.mcp.json`'s caret-pin pulls in cdf-mcp 1.7.3 + cdf-core 1.0.4 on
next npx resolution (may need `~/.npm/_npx/` clear if cache is stale,
same caveat as 1.0.5's bump). All six §"What NOT to touch" items from
the v1.0.6 plan preserved (probe-first tier-detection, Contract 3-bis
tool-survey, walker auto-seeding, Phase1Output source-of-truth
contract, `cdf_render_snapshot` telemetry shape, hard 15-finding cap).

---

## 1.0.5 — 2026-04-27

Post-V2 doc hot-fix wave: six doc-only fixes from the V2 MoPla Snapshot
validation retro. Skill-content + plugin-manifest only release; no
`@formtrieb/cdf-core` / `@formtrieb/cdf-mcp` version bumps.

### Fixed

- **A1** — both `SKILL.md` files gain a `§0.5 · Read-Path Resolution`
  anchor clarifying that `Read` / `yq` / `jq` paths in the skill and
  its `references/` + `shared/` docs resolve **relative to the
  SKILL.md base**, not relative to the user's `cwd`. Eliminates the
  `ls`-discovery friction observed in V2 first-touch runs and gives a
  one-shot recovery instruction (`find ~/.claude/plugins -name
  SKILL.md -path "*<skill-name>*"`) when the harness doesn't auto-
  resolve the relative path.
- **A2-doc** — `synthesis.md` §0 (Inputs) appends a *Large-file
  fallback (>25k Read tokens)* paragraph cross-referencing the yq+jq
  recipe in `tool-leverage.md` §4. Walker outputs exceeding the
  25,000-token `Read` limit (typical for DSes with ≥150
  component_sets) no longer block synthesis: the contract holds, only
  the read-strategy changes. Probe walker file size first
  (`ls -lh .cdf-cache/phase-1-output.yaml`); branch directly to
  fallback if >2 MB.
- **A3** — `tool-leverage.md` §4 adds a §4.2 *YAML extraction
  (mikefarah yq + jq)* sub-section documenting the
  `yq -o=json '...' file.yaml | jq '...'` pipe pattern. Mikefarah `yq`
  rejects inline jq-style object construction (`yq '.foo | {bar:
  .baz}'`); the pipe pattern is the canonical fallback. Includes
  WRONG / RIGHT examples.
- **A4** — `walker-invocation.md` §2 documents the
  `total` ↔ `indexed_count` field-name drift between what the walker
  emits (`ds_inventory.component_sets.total`) and what the snapshot
  schema expects (`indexed_count`). Both refer to the same metric
  (union of tree-resolved + remote-only sets); the alias-mapping is
  authoritative until the walker rename ships in v1.8.0.
- **A5-doc** — `synthesis.md` §2.7 (theming) appends a *Fallback when
  `theming_matrix.collections: []` is empty* recipe. When the walker
  emits an empty collections list (typical when `.cdf.config.yaml`
  has no explicit `resolver:` block but `regime: tokens-studio` is
  set and `tokens/$themes.json` exists on disk), operators can derive
  theming-modifiers via a single `jq -r 'group_by(.group) | …'`
  invocation against `tokens/$themes.json`. Cross-validation note
  against component-side VARIANTS included.
- **A6** — `walker-invocation.md` §2 adds an *Output-Shape Examples*
  block for jq/yq query construction. Several walker fields emit
  flat-string arrays (NOT object arrays) — `standalone_components.*`,
  `pages.separators[]`, `libraries.linked[]`, `doc_frames_detected[]`.
  Documents the WRONG `.utility[].name` (returns null) vs RIGHT
  `.utility[]` query shapes.

### Deferred to v1.8.0 (Synthesis-as-Code wave)

- **A2-walker** — `cdf_extract_figma_file` `summary_only` mode emitting
  `phase-1-summary.yaml` (drops inline `propertyDefinitions` for
  >25k cases)
- **A5-walker** — walker auto-resolves `theming_matrix.collections`
  from `tokens/$themes.json` when `regime: tokens-studio` and no
  explicit `resolver:` is configured
- **A7** — Renderer hyphen-line-break lint (cosmetic)
- **B5** — `libraries.linked` walker output bug — under fresh-chat
  investigation in v1.8.0

### Accepted as platform constant

- **A8** — ToolSearch round-trip latency for first-time MCP tool
  invocation. Documented in v1.0.4's `tool-leverage.md` §1
  deferred-tool note; no further action.

### No package version bumps in v1.0.5

- `@formtrieb/cdf-core@1.0.x` and `@formtrieb/cdf-mcp@1.7.x` unchanged
- `.mcp.json` still pins `@formtrieb/cdf-mcp@^1.7.2`
- Skill-content + plugin-manifest only release

### Upgrade for existing installs

```bash
claude plugin marketplace update cdf
claude plugin update cdf@cdf
# Fully quit Claude Code (Cmd+Q) and relaunch — closing the window
# is not enough; the MCP launcher needs to reload .mcp.json env.
```

---

## 1.0.4 — 2026-04-27

Snapshot stability bundle: 8 fixes (5 mechanical + 3 inhaltliche) from
two real-world Snapshot validation runs. Skill-content + plugin-manifest
only release; no `@formtrieb/cdf-core` / `@formtrieb/cdf-mcp` version
bumps.

### Fixed — tier-detection probe-order bug (HIGH, F6)

Snapshot/scaffold no longer silently defaults to T0 (slow runtime path)
when on-disk Figma caches are absent but `FIGMA_PAT` is set. The
detection algorithm in `shared/cdf-source-discovery/source-discovery.md`
§2 now follows a probe-first order:

1. T2 (enterprise-REST regime)
2. T1-legacy-cache (deprecated `extract-to-yaml.sh` paths)
3. T1-modern-probe via `cdf_fetch_figma_file({file_key})`
4. T0 (figma_execute runtime, if `figma-console` MCP + Desktop file open)
5. Halt with diagnostic

The trap was mistaking *"no legacy cache on disk"* for *"T1
unreachable"* — when in fact `FIGMA_PAT` may be set and a single
`cdf_fetch_figma_file` call would resolve T1 in ~3 s. On a mature DS
(~150 component sets × ~1600 component instances), unnecessary T0
fallback costs 30–45 min of `figma_execute` enumeration via the
WebSocket bridge and breaks the 5–10 min Snapshot budget.

Adds **Rule B — Capability-Probe Before Default-Fallback** as
sister-rule to Rule A in `tool-leverage.md` §3, with 3-step contract
(declare candidate tiers → probe → record outcome) and explicit
sequencing rule (probe BEFORE decide, NOT in parallel).

### Improved — pre-reading lazy-load (F1, β-strict)

Both SKILL.md §1 redesigned. Snapshot now uses a 4-step dispatch table
(point-of-need Reads, no upfront eager-load of 3 shared/-refs).
Scaffold §1.3 / §1.4 / §1.4-bis softened from "Read before Phase 1
fires" to "Read at point-of-need". All 7 Scaffold phase-docs +
Snapshot synthesis.md gain `requires:` YAML frontmatter for
grep-verification.

Result: per-step Read budget at first source inspection drops from 3
(eager) to 0–2 (point-of-need).

### Improved — Rule-A literal-loophole closed (L8.5)

`tool-leverage.md` §2 Rule-A enforcement was firing only on literal
phrases like *"X NOT enumerable / NOT visible / NOT accessible"*.
Paraphrases (*"only partial Variable surface"*, *"REST cache lacks
Variables data"*, *"tokens-MCP path not visible from this session"*)
bypassed the literal filter.

The rule is now **structural**: it fires on the meaning of the
sentence (*"does this assert that a capability of a loaded tool is
unavailable, partial, or invisible?"*), regardless of wording. A
positive-obligation trigger-word list (`REST`, `Variables`,
`enumerate`, `visible`, `missing`, `partial`, `accessible`,
`available`, `surface`, `enumerable`) provides a self-check signal.
Mirrored in `synthesis.md` Contract 3-bis,
`phase-3-grammars.md` Step 3.1.0, and the
`snapshot.profile.schema.yaml` `blind_spots[]` description.

### Improved — host-tool prerequisites declared explicitly (F8)

Both SKILL.md §0 list a one-time-install host-tool table: `yq`
(mikefarah ≥ 4.x), `jq`, `python3` (stdlib only — no PyYAML),
bash 4+/zsh. The toolchain is **PyYAML-frei**: YAML→JSON conversion
goes through `yq`, not Python.

A new `plugin/scripts/check-host-deps.sh` verifies the environment
in one shot: returns 0 + resolved versions on success, or 1 +
`MISSING:<tool>` + install hint on first absent dependency.
Distinguishes mikefarah's Go `yq` from kislyuk's Python `yq` wrapper
(only the former is compatible with the inline-jq recipes).

### Improved — deferred-tool note (F4)

`tool-leverage.md` §1 documents the Claude Code deferred-tool surface:
MCP-provided tools require a one-time `ToolSearch select:tool_name`
round-trip per tool-family per session. Subsequent calls to the same
family are free. Includes batching hint
(`select:tool_a,tool_b,tool_c` pre-loads multiple schemas in one
round-trip).

### Improved — vocabulary-threshold loosened (F10, inhaltliche)

`synthesis.md` §2.5 vocab-detection rule loosened from strict ≥ 2-sets
to a tiered policy:

- **Default:** ≥ 2 sets sharing overlapping value-set → vocabulary
- **Single-set promotion:** ≥ 1 set IF (a) canonical name (`intent`,
  `density`, `progress`, `orientation`, `position`) OR (b) closed
  enum with ≥ 3 distinct named values
- **Boolean-shape promotion:** `[true, false]` VARIANT recurring on
  ≥ 3 sets surfaces as BOTH `vocabularies.<name>` AND
  `interaction_a11y.patterns.<verb>`
- **Icon-Set heuristic:** `name` VARIANT on ≥ 10 sets with
  single-icon-name shape → ONE icon-name vocabulary across the family

Worked-example block (good vs bad pairs) added for `intent` and
`selected`. Risk note: when in doubt, default to surfacing-as-finding
— the LLM's "confidence" is the quality control.

The rule is an **LLM-policy bridge** to be replaced in v1.8.0 by a
deterministic-code synthesis primitive (`cdf_analyze_inventory`).

### Improved — token-grammar fallback-path depth (F11, inhaltliche)

Contract 4 in `synthesis.md` clarified: the 1× `browse_tokens` cap
binds the **DS-MCP path only**. In the **filesystem-walk fallback
path** (no DS-tokens MCP loaded, but DTCG / Tokens-Studio JSON files
on disk), path-level enumeration is **encouraged, not budget-bound**.
Per-leaf enumeration remains best-effort; depth-2 cap prevents
unbounded traversal.

`tool-leverage.md` §4.1 ("Token enumeration paths") adds:

- 3-tier precedence list: DS-MCP loaded > cdf-mcp `tokenTree` loaded
  > filesystem-walk fallback
- `jq paths` recipe (depth-2 cap) for surfacing top-level 2-segment
  dotted prefixes from DTCG files as grammar-candidate seeds, plus a
  drill-down recipe for one specific prefix
- Components/* heuristic — recognize per-component-override
  token-set layouts as a separate `Components` token_layer
- v1.8.0 sunset note pointing to the queued generic
  `@formtrieb/tokens-mcp@2.0.0` that supersedes the recipe

### Improved — T0/T1 walker inventory-counting documented (F12, inhaltliche)

T0 (`figma_execute` runtime) and T1 (REST + walker) emit different
inventory metrics for the same Figma file: T0's `componentsTotal`
counts every variant-instance; T1's `component_count` dedupes by
COMPONENT id. On the same file these can differ by 5–10× (e.g.
T0 = 1615 vs T1 = 191 on a real-world mid-size DS).

`walker-invocation.md` adds an *"Inventory-counting semantic
difference (T0 vs T1)"* §-block with the metric table and worked
example. `synthesis.md` §2.2 inventory section gains an *"if both
ran, emit a one-line note"* instruction.

### Deferred to v1.8.0 (companion roadmap)

- Walker `summary_only` mode (`cdf_extract_figma_file` option)
- Generic `@formtrieb/tokens-mcp@2.0.0` (path-parameter,
  non-DS-specific) — supersedes the F11 jq-paths fallback recipe
- `libraries.linked` walker output bug fix
- Bash-script deletion (`scripts/extract-to-yaml.sh` retirement)
- Synthesis-as-Code (`cdf_analyze_inventory`) replacing the F10
  LLM-policy bridge in `synthesis.md` §2.5

### No package version bumps in v1.0.4

- `@formtrieb/cdf-core@1.0.x` and `@formtrieb/cdf-mcp@1.7.x` unchanged
- `.mcp.json` still pins `@formtrieb/cdf-mcp@^1.7.2`
- Skill-content + plugin-manifest only release

### Upgrade for existing installs

```bash
claude plugin marketplace update cdf
claude plugin update cdf@cdf
# Fully quit Claude Code (Cmd+Q) and relaunch — closing the window
# is not enough; the MCP launcher needs to reload .mcp.json env.
```

---

## 1.0.3 — 2026-04-26

### Fixed — `FIGMA_PAT` not reaching the MCP server from the user's shell

The plugin's `.mcp.json` did not explicitly forward `FIGMA_PAT` from
the user's shell environment, so whether the env var reached cdf-mcp
depended on Claude Code's MCP-launcher inheritance behavior. In real
runs (Phase 4 validation against MoPla DS, 2026-04-26) the first
`cdf_fetch_figma_file` call failed because the launcher didn't pass
the var through, even though the user had `export FIGMA_PAT=...` set
in their shell rc.

`.mcp.json` now declares an explicit env passthrough:

```json
{
  "mcpServers": {
    "cdf-mcp": {
      "command": "npx",
      "args": ["-y", "@formtrieb/cdf-mcp@^1.7.2"],
      "env": {
        "FIGMA_PAT": "${FIGMA_PAT}"
      }
    }
  }
}
```

The `${FIGMA_PAT}` syntax interpolates at MCP launch time. If the
shell var is set, cdf-mcp receives it; if not, it passes through as
an empty string and cdf-mcp's existing actionable-error path fires
(directing the user to set `FIGMA_PAT` or pass `pat:` arg).

Behavioral effect for users: the README's "set `FIGMA_PAT` in your
shell rc → it just works" promise now actually holds. The per-call
`pat:` arg fallback (Option B in the README) was unaffected.

### Fixed — `_quality: draft` schema annotation invalid on
`findings_unclassified` list

`snapshot.profile.schema.yaml` documented `_quality: draft` as a
top-level marker on every best-effort section, but
`findings_unclassified` is a YAML list — a sibling `_quality: draft`
key produces a mixed scalar+list shape that breaks parsers. The
schema now omits the marker on the list section and adds an explicit
note that draft-status there is implicit via the soft-boundary
position rather than an inline key. Mapping sections
(`vocabularies`, `token_grammar`, `theming`, `interaction_a11y`)
keep the inline marker — they're objects, where it's well-formed.

Surfaced by Phase 4 MoPla validation run (2026-04-26).

### Upgrade for existing installs

```bash
claude plugin marketplace update cdf
claude plugin update cdf@cdf
# Fully quit Claude Code (Cmd+Q) and relaunch — closing the window
# is not enough; the MCP launcher needs to reload .mcp.json env.
```

---

## 1.0.2 — 2026-04-26

### Fixed — MCP server crash on startup with bootstrap `.cdf.config.yaml`

The MCP server crashed on startup (`MCP error -32000: Connection
closed`) when the working directory contained a `.cdf.config.yaml`
with `profile_path:` pointing to a not-yet-existing file. This is the
**default state for new plugin users following the Quickstart** — the
profile YAML is what `/cdf:scaffold-profile` will *produce*, so it
doesn't exist before the first scaffold run. The fix lives upstream:

- `@formtrieb/cdf-core@1.0.3` — `parseConfigFile` now skips profile
  loading + emits a stderr warning when the file is missing, instead
  of throwing.
- `@formtrieb/cdf-mcp@1.7.2` — pins `^1.0.3` for clean dep refresh.
- This plugin (`.mcp.json`) bumped from `^1.7.1` to `^1.7.2` to force
  npx to re-resolve past stale `^1.7.1` cache entries.

### Fixed — README Quickstart `.cdf.config.yaml` example pre-set
`profile_path:` before the profile existed

The Quickstart skeleton seeded `profile_path: ./my-ds.profile.yaml`
into the config, then immediately invoked the MCP server (which would
crash on the missing file). Even with the parser fix above, sequencing
is cleaner if `profile_path` is set *after* the scaffold writes the
profile. The Quickstart now shows `profile_path` as a commented-out
line with a note explaining when to uncomment it; the scaffold can
also auto-populate it on first run.

### Upgrade for existing installs

```bash
claude plugin marketplace update cdf
claude plugin update cdf@cdf
# Restart Claude Code (Cmd+Q then relaunch — closing the window is not enough).
```

If the MCP still doesn't connect after that, clear the npx cache so
any stale `^1.7.1` resolution is dropped:

```bash
rm -rf ~/.npm/_cacache/_npx ~/.npm/_cacache/index-v5/_npx
```

…then restart again.

---

## 1.0.1 — 2026-04-26

### Fixed — MCP server fails to launch (`could not determine executable to run`)

`.mcp.json` now pins `@formtrieb/cdf-mcp@^1.7.1` (was `^1.7.0`). v1.7.0
of the MCP server shipped without a `bin` field or shebang on
`dist/index.js`, so `npx -y @formtrieb/cdf-mcp` failed with
`could not determine executable to run` and Claude Code reported
*"plugin:cdf:cdf-mcp ✗ Failed to connect"*. v1.7.1 of the MCP server
ships the fix; bumping the caret floor to `^1.7.1` forces npx to
re-resolve cleanly even if a stale `^1.7.0` resolution was cached.

### Documented

- README install command corrected to the two-step
  `claude plugin marketplace add formtrieb/cdf-plugin` →
  `claude plugin install cdf@cdf` (single-plugin repos package as
  one-entry marketplaces; the bare-URL install path expects an
  already-configured marketplace).
- README troubleshooting expanded with the
  *"plugin install ... not found in any configured marketplace"*
  symptom and the marketplace-add fix.

### Upgrade for existing installs

```bash
claude plugin marketplace update cdf
claude plugin update cdf@cdf
# Restart Claude Code so the new MCP server config takes effect.
```

If the MCP still doesn't connect after that, clear the npx cache
(`rm -rf ~/.npm/_cacache/_npx ~/.npm/_cacache/index-v5/_npx`) so the
old cached `^1.7.0` resolution is dropped, then restart again.

---

## 1.0.0 — 2026-04-26

### Added — initial release

- **`cdf-profile-scaffold` skill** — production-grade 7-phase Profile
  authoring (Orient → Vocabularies → Grammars → Theming → Interaction
  + A11y → Findings + Classify → Emit + Validate). Triggers on
  `/cdf:scaffold-profile` slash-command, `/scaffold-profile` short
  form (when no other plugin claims it), and natural-language
  description matches like *"create a CDF profile"*, *"scaffold a DS
  profile"*.
- **`cdf-profile-snapshot` skill** — 5–10 min first-touch evaluation
  sketch with explicit blind-spots and an upgrade path to the
  Production Scaffold. Triggers on `/cdf:snapshot-profile`,
  `/snapshot-profile` short form, and description matches like
  *"snapshot"*, *"quick look"*, *"first look"*, *"evaluate cdf for
  my DS"*.
- **`shared/cdf-source-discovery/`** — three canonical references both
  skills load: `source-discovery.md` (opening checklist, tier
  detection, parent-Profile inheritance), `tool-leverage.md` (Rule A
  Survey-First, Rule B Truncation-Awareness, spec-fragment lookup
  contract), `walker-invocation.md` (T0/T1/T2 walker invocation +
  source-of-truth contract).
- **`.mcp.json`** — pins
  [`@formtrieb/cdf-mcp@^1.7.0`](https://www.npmjs.com/package/@formtrieb/cdf-mcp)
  via `npx` so all 22 CDF MCP tools (`cdf_validate_profile`,
  `cdf_fetch_figma_file`, `cdf_extract_figma_file`,
  `cdf_render_findings`, `cdf_render_snapshot`, `cdf_get_spec_fragment`,
  `cdf_diff_profile`, `cdf_coverage_profile`, etc.) become available
  on plugin-load. First invocation may take ~5 s while npm caches the
  package; subsequent calls are local-cached.
- **`commands/scaffold-profile.md` + `commands/snapshot-profile.md`**
  — thin slash-command wrappers that load the corresponding skills
  with `$ARGUMENTS`-aware parsing of optional context.

### Compatibility

- Requires Claude Code or Claude Desktop with MCP support.
- Requires Node.js ≥ 20 (for `npx @formtrieb/cdf-mcp`).
- Requires `figma-mcp` MCP loaded in the Claude session for any
  Figma-source workflow (T0 runtime path needs it; T1 REST path
  benefits from it).
- Works with or without a Figma Personal Access Token (PAT) — see
  the audience-fit table in `skills/cdf-profile-snapshot/SKILL.md`
  §1.4 for T0/T1/T2 path selection.
