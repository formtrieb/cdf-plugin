# CDF Source Survey & Tool Leverage — Shared Reference

**Purpose:** The Survey-First discipline (Rule A) and the tool-leverage
map for source enumeration. Loaded by any CDF skill that inspects DS
artefacts (tokens, components, doc-frames, icons).

**Skill-agnosticism contract:** this file describes *what* sources to
survey and *which* tools tend to give the most leverage. It does NOT
prescribe synthesis flow, finding clusters, or User-dialog cadence.

---

## 1 · Survey First (Rule A)

Before inspecting any DS artefact (tokens, components, specs, icons,
reference examples, patterns library):

1. **Ask the User WHERE the source lives.** Figma Variables? Local DTCG
   files? External repo? Tokens Studio export? Hand-authored? Multiple
   sources bi-directionally linked?
2. **Check what tools are available for that source.** Prefer dedicated
   MCP tools over `Read`/`Grep`.
3. **Raw-file parsing is a LAST resort**, never the first move.

**Why:** LLM default is `Read some/file.json` because it needs no setup.
Dedicated MCPs give *resolved* / *validated* / *cross-referenced* views
that raw JSON cannot match.

**Applies to spec reads too.** For CDF-PROFILE-SPEC shape lookups, use
`cdf_get_spec_fragment({ fragment: "<Name>" })` to load only the relevant
fragment (`Vocabularies`, `TokenGrammar`, `Theming`, `InteractionPatterns`,
`AccessibilityDefaults`, etc.) rather than `Read`-ing the full monolith
at `cdf/specs/CDF-PROFILE-SPEC.md`. The monolith is a generated
publication artefact; fragments under `cdf/specs/profile/` are the
canonical authoring source.

**Truncation-awareness companion:** when a tool output is truncated
(`search_tokens` at 100 results, `use_figma` at ~20 kB, etc.), **never
rely on the partial dataset**. Re-query with narrower scope, use
`browse_tokens` with `path_prefix`+`depth` for complete enumeration, or
paginate explicitly. A token-search call returning "Showing 100 of 192"
hides 3 of 6 hierarchies — half the vocab-axis disappears.

**Note on Claude Code deferred tools.** On the Claude Code platform,
MCP-provided tools (`cdf-mcp`, `figma`, `figma-console`, DS-specific
tokens MCPs, plugin-bundled MCPs) are typically registered as **deferred
tools**, meaning their schemas are NOT in the initial prompt context.
The first invocation of any `mcp__plugin_cdf_cdf-mcp__cdf_*`
(or other MCP) tool requires a `ToolSearch select:cdf_*` round-trip
to load the schema. This is a one-time cost per session; subsequent
calls to the same tool family are free. Plan for ~1 ToolSearch
round-trip per MCP-family on first use, and batch related calls
where possible (one ToolSearch can pre-load several tool schemas
via `select:tool_a,tool_b,tool_c`). The cost is small per call but
visible during early phases — don't be surprised by the ping-pong.

---

## 2 · Rule A Enforcement: Tool-Survey BEFORE Resolver-Gap

The discipline above (Rule A — "Survey First") fails silently in
**non-interactive runs** (auto-mode scaffolds, snapshot single-pass
synthesis) where there is no User-dialog brake. The LLM can declare a
resolver-gap ("color tokens NOT enumerable", "theming axes NOT visible",
"variables NOT accessible") on the first source it inspects, never
checking whether the loaded MCP tools could fill the gap. The output
then bakes the false claim into deliverables.

**The enforcement rule (canonical, structural — L8.5).** Any claim that
asserts a **capability gap of a loaded MCP-tool surface** MUST be preceded
by an explicit tool-survey citation. The "loaded MCP-tool surface"
includes: `figma`, `figma-console`, `cdf-mcp`, any DS-specific tokens MCP,
and any plugin-provided MCP visible in the current session. The rule fires
**regardless of the exact wording** — paraphrases bypass any literal-text
filter. The structural test is *"does this sentence assert that a
capability of a loaded tool is unavailable, partial, or invisible?"*

**Positive-obligation trigger words.** When the synthesis prose contains
any of these tokens — `REST`, `Variables`, `enumerate`, `enumerable`,
`visible`, `missing`, `partial`, `accessible`, `available`, `surface` —
in the context of a token / vocab / theming-axis / metadata / a11y claim,
the surrounding sentence MUST either (a) cite a tool-survey, OR (b) be
reframed as a non-capability claim (e.g. *"the walker output does not
enumerate Figma Variables"* — observation about walker output, not a
capability claim about the file). Trigger-word presence is a heuristic,
not a stop-list — the structural rule above is canonical; trigger words
are a self-check signal that the structural rule may apply.

**Examples of paraphrases the L8.5 rule catches that the older literal
filter missed:**

| Paraphrase (would have escaped pre-L8.5) | Why it's a Rule-A violation |
|---|---|
| "only partial Variable surface" | "partial" + "surface" as capability claim |
| "REST cache lacks Variables data" | "REST" + "lacks" implying capability gap |
| "tokens-MCP path not visible from this session" | "not visible" capability claim about loaded tool |
| "color tokens are missing from the walker output" | observation OK; but if framed as "color tokens are missing from the DS" → Rule-A violation |
| "theming axes inferred but not enumerable from current tools" | "not enumerable" + "tools" capability claim |

**Three-step contract for all such claims:**

1. **List the loaded `mcp__*` tools** that conceivably address the
   resource type (e.g. for color tokens: `mcp__figma__get_variable_defs`,
   `mcp__<ds>-tokens__browse_tokens`, `mcp__figma-console__figma_get_variables`,
   `mcp__figma-console__figma_execute`).
2. **Probe at least ONE representative target** with one of those
   tools. For figma-variables regime against a Figma file, probing
   `mcp__figma__get_variable_defs(fileKey, nodeId)` against any
   COMPONENT_SET node returns the variables consumed by that node —
   one call refutes or confirms the gap.
3. **Record the probe result** in the resulting claim. The claim
   either becomes *"X NOT enumerable [probed `<tool>` → <result>]"*
   (still a gap, but qualified) or vanishes entirely (gap was false).

**Why this is on top of §1.** §1's "Survey First" tells the LLM to ASK
where the source lives. In auto-mode there is no User to ask. The
fallback for auto-mode + snapshot is *probe the tools you have* — and
the MUST in this section is the operational version of that fallback.

**`.cdf.config.yaml.resolver` is NOT a substitute.** A fresh DS auto-run
has no User-filled resolver block; whatever defaults the skill seeded
are speculative. Trusting `.cdf.config.yaml.resolver.kind` to decide
"can I see variables?" is an anti-pattern — the answer is "probe the
loaded tools."

### 2.1 Worked example — QL.E.1 Primer (2026-04-26)

Auto-mode scaffold against Primer (Figma file
`k4eLYQOFsumGUW3v8CM2kt`) declared in phase-3:

> *"Color tokens NOT enumerable (Figma Variables not visible in
> non-Enterprise REST). Color tokens live in Figma Variables, NOT
> visible to non-Enterprise REST."*

The claim was **technically true** for the static REST file
(`library.file.json`), but **operationally false**:
`mcp__figma__get_variable_defs` was loaded the entire run and resolves
Variables on demand per-node.

The corrective probe (5 calls, ~30s total wall-time):

```
get_variable_defs(fileKey=k4eLYQOFsumGUW3v8CM2kt, nodeId=28860:52225)  # Primary Button
get_variable_defs(fileKey=…, nodeId=34303:2712)    # Banner
get_variable_defs(fileKey=…, nodeId=18959:65008)   # Label
get_variable_defs(fileKey=…, nodeId=15341:46504)   # TextInput
get_variable_defs(fileKey=…, nodeId=18959:64987)   # IssueLabel
```

…surfaced the full token grammar:

```
button.{hierarchy}.{element}.{state}    e.g. button/primary/bgColor/rest = #1f883d
fgColor.{tone}                          var(--fgColor-default) = #1f2328
bgColor.{tone}.{prominence}             var(--bgColor-success-muted) = #dafbe1
borderColor.{tone}.{prominence}
space.{step}                            xxsmall=2 xsmall=4 small=6 medium=8
control.{size}.{property}[.{density}]   control/medium/paddingInline/normal = 12
text.body.{property}.{size}             text/body/size/medium = 14
shadow.{context}.{size}                 + _component.{comp}.shadow.{state}
focus.{property}                        focus/outlineColor = #0969da
```

…plus a confirmed Code↔Figma drift finding (Figma uses `default` where
code uses `secondary` for the second button hierarchy) — which would
have been silently swallowed by the false-claim path.

Full corrective patch: `primer/.cdf-cache/phase-3.5-output.yaml`.

### 2.2 Applies to BOTH auto-mode scaffold AND snapshot

Both skills run without User-dialog at the gap-declaration boundary:

- **Auto-mode `cdf-profile-scaffold`** skips Phase-6 classification
  dialog; phase-3 token-grammar declarations have no User-dialog brake.
- **`cdf-profile-snapshot`** has no User-dialog by design (single-pass
  synthesis); blind_spots claims are written without interactive
  challenge.

For Rule-A enforcement purposes both are "auto-mode-equivalent." This
section's MUST applies to both.

`cdf-profile-scaffold/references/phases/phase-3-grammars.md` and
`cdf-profile-snapshot/references/synthesis.md` enforce this rule via
cross-reference and skill-specific contracts (Snapshot Contract 3
extends `blind_spots` with a `tool_survey:` sub-field).

---

## 3 · Rule B — Capability-Probe Before Default-Fallback

Rule A ("Survey First", §1) tells the LLM to ask **WHERE** sources live. Rule
B extends that discipline to **WHICH PATH** to use when multiple paths could
serve the same source. The trap is *mechanical-correct-but-wrong-by-survey*:
falling to a default fallback because some signal is absent, when a probe
would have shown a faster/preferred path is reachable.

**The rule.** When a workflow has a default fallback path AND a
preferred-but-reachability-conditional path (depends on env vars, MCP
availability, or file state), the workflow MUST probe the preferred path's
reachability *before* defaulting. Probe-output gates the decision; the probe
and the fallback are NEVER run in parallel.

**Worked example — large real-world DS T0 misclassification.** Two
Snapshot debug-runs against a representative mid-size DS hit this trap.
Algorithm pre-fix:

```
1. .cdf.config.yaml.scaffold.figma.file_cache_path exists?  → T1
2. <ds-test-dir>/data/library.file.json exists?             → T1
3. <ds-test-dir>/figma-cache/library.file.json exists?      → T1
4. else                                                      → T0
```

Operator's self-critique on the failure:

> *Ich habe nie geprüft, ob `FIGMA_PAT` gesetzt ist. Genau das ist die
> T1-Voraussetzung. Der korrekte Probe wäre einfach
> `cdf_fetch_figma_file({file_key})` einmal versuchen — bei vorhandenem PAT
> → T1 (3 s), bei "PAT missing"-Fehler → kontrolliert auf T0 fallen.
> Stattdessen habe ich aus "kein Cache auf Platte → T0" geschlossen.*
>
> *Determinismus. Der REST-Adapter ist der gold-pfad — fünf golden fixtures,
> byte-identisch getestet. Der runtime-Adapter ist neuer und weniger
> battle-tested. Bei zwei gleich erreichbaren Pfaden ist T1 die
> default-richtige Wahl.*

Scale: the file had 81 pages × 152 COMPONENT_SETs × 1615 COMPONENTs. T0 via
the figma-console WebSocket bridge against T1's REST-walker path is
potentially 50–100× wall-time. The Snapshot 5–10 min budget breaks silently
under T0; with probe-first, the same run lands on T1 in ~3 s.

### 3.1 — Three-step contract (per fallback decision)

For any tier-decision / source-mode-selection / capability-bound dispatch:

1. **Declare the candidate tiers explicitly.** Listed in preferred-first
   order with their reachability conditions — e.g. *"T2 (enterprise-REST),
   T1 (REST + walker), T0 (figma_execute runtime)"*.
2. **Probe the preferred-but-conditional tier.** The probe is a real call
   (typically the same call you would make to *use* the tier), not a
   theoretical *"is the env var set?"* check. Capture the outcome —
   success, capability-gap error (e.g. *"FIGMA_PAT not set"*), or
   hard-failure (network, 4xx, 5xx).
3. **Record the probe outcome on the decision.** The chosen tier carries
   provenance: *"T1 selected — `cdf_fetch_figma_file({file_key})` returned
   cache-hit at `.cdf-cache/figma/<key>.json`"*, or *"T0 selected —
   `cdf_fetch_figma_file({file_key})` returned 'FIGMA_PAT not set';
   `figma-console` MCP loaded + Desktop file open."* Without provenance,
   the next operator cannot reproduce or audit the decision.

### 3.2 — Sequencing: probe BEFORE decide, NOT in parallel

The probe must complete and inform the decision; running probe and fallback
in parallel wastes the probe. Operator's second-run self-critique:

> *Ich habe gleichzeitig figma_execute-Probe gestartet UND mit T0-default
> begonnen — der Probe-Output kam nach der ersten T0-walker-Antwort und
> half nichts mehr.*

The probe is cheap (one tool call, ~3 s typical) and definitive. The only
acceptable parallelism is across **independent** decisions; never within a
single decision.

### 3.3 — Anti-pattern table (mechanical-vs-survey)

| Decision input | Mechanical interpretation | Survey-aware interpretation |
|---|---|---|
| "no legacy cache on disk" | "T1 unreachable → T0" ✗ | "T1-legacy unreachable; **probe T1-modern next**" ✓ |
| "`FIGMA_PAT` not set" (after probe) | "T1-modern unreachable" | "T1-modern unreachable, **real fallback to T0**" ✓ |
| "no `figma-console` MCP loaded" | "T0 unreachable → halt" | "T0 unreachable, **real fallback to halt-with-diagnostic**" ✓ |
| "tokens MCP not loaded" (Phase-3) | "tokens NOT enumerable" ✗ | "tokens-MCP path unreachable; **probe filesystem-walk path next**" ✓ |

The first column captures the *"kein Cache auf Platte → T0"* failure mode.
The second column is the Rule-B-aware path: every absence-signal triggers a
probe of an alternate path before declaring the capability gap. The last row
shows Rule B's parallel structure to Rule A's enforcement (§2) on
token-source claims — same discipline, different surface.

### 3.4 — Applies to BOTH auto-mode scaffold AND snapshot

Like Rule A, Rule B's enforcement is most load-bearing where there's no
User-dialog brake:

- **Auto-mode `cdf-profile-scaffold`** — tier selection runs at Phase-0.5;
  no User to course-correct if *"no legacy cache"* silently picks T0.
- **`cdf-profile-snapshot`** — single-pass synthesis; tier-detection is
  one-shot, downstream synthesis is bound to it.

For Rule-B-enforcement purposes both are "auto-mode-equivalent." The
probe-first algorithm in `source-discovery.md` §2 is the operational
implementation; this section documents the discipline behind it.

`cdf-profile-scaffold/references/phases/phase-1-orient.md` and
`cdf-profile-snapshot/references/synthesis.md` Contract 3-bis cite Rule B as
sister-rule to Rule A (§2).

---

## 4 · Tool-Leverage Map (Source Enumeration)

| Tool | Leverage | Use when |
|---|---|---|
| `use_figma` (Plugin-JS enumeration) | ★★★ | Primary T0 enumeration — deterministic full-file view. **Always pass a descriptive `description` param** (e.g. `"Pass-1 Batch A — propertyDefinitions for pages 0–30 (preferredValues stripped)"`). Makes the tool-call log self-documenting; essential for truncation-awareness audits after the fact. |
| `figma-mcp.get_variable_defs(nodeId)` | ★★ | Sampling Variable-bindings on a representative node. |
| DS-specific tokens MCP (per Rule A) | ★★★ | Token enumeration via MCP — prefer over `Read`. **Ask the DS-MCP owner for the list of available tools**; look especially for: `find_placeholders` (unresolved-value scan — seeds §A findings), `compare_themes` (Light↔Dark mode-diff — seeds §B findings), `list_themes` (mode enumeration), `check_design_rules` (a11y/contrast). DS-MCPs vary widely in what they expose; the skill is tool-agnostic, but knowing the category-level shapes lets you pull more value than `browse_tokens` alone. |
| `figma-mcp.get_design_context(nodeId)` | ★ | Sample doc-frame content for documentation-surfaces ingestion. |
| `figma-mcp.get_metadata(0:1)` | ✗ low | Returns first page only — misleading as file-structure. |
| `figma-mcp.get_libraries` | ✗ low | Returns **global** team libraries, not DS-specific. |
| `figma-mcp.whoami` | ✗ 0 | Health-check only; skip unless auth-debugging. |
| `Read` on DTCG files | ★ | Last-resort fallback; Rule A → MCP first. |

### 4.1 — Token Enumeration Paths (precedence + filesystem-walk fallback recipes)

Token enumeration in CDF skills runs along three precedence tiers. Pick
the highest available; the DS-MCP path costs ~1 tool call, the
cdf-tokenTree path costs ~1 tool call, the filesystem-walk path costs
~1 jq invocation per file scanned.

| Tier | Surface | Skill behavior |
|---|---|---|
| **1 — DS-MCP loaded** | `mcp__<ds>-tokens__browse_tokens` (e.g. `formtrieb-tokens`, or any per-DS adapter wired up under that name pattern) | Snapshot Contract 4 binds — ONE `browse_tokens` call max. Scaffold Phase-3 has higher budget. |
| **2 — cdf-mcp `tokenTree` loaded** | `cdf_check_tokens` / `cdf_coverage` (DTCG-aware via `.cdf.config.yaml.token_sources`) | Use as enumeration vehicle even though primary purpose is cross-reference; the tree is in scope. Tier-2 is the right path when DTCG files are on disk but no DS-specific MCP is configured. |
| **3 — filesystem walk** | Direct `Read` on DTCG files + `jq paths` recipe (G.3 below) | Fallback when neither MCP path loaded. **Encouraged** in Snapshot's filesystem-walk fallback path (Contract 4 carve-out): emit at minimum set-level + top-level 2-segment-prefix grammar, depth-2 cap. |

**v1.8.0 sunset note.** A generic `@formtrieb/tokens-mcp@2.0.0` (with
path-parameter, non-DS-specific) is queued in
[`docs/plans/active/2026-04-26-v1.8.0-roadmap.md`](../../../docs/plans/active/2026-04-26-v1.8.0-roadmap.md).
When v1.8.0 ships, Tier 3's filesystem-walk recipe is superseded by a
single MCP call (`cdf_browse_tokens(token_sources_path?)`) that returns
the same enumeration. The recipe below is a **bridge** — it preserves
the synthesis flow until the proper tool exists.

#### Tier-3 recipe — `jq paths` over DTCG files

The recipe surfaces top-level 2-segment dotted prefixes as
grammar-candidate seeds, depth-capped to prevent unbounded enumeration
on large token-trees:

```bash
# Read tokens/Semantic/Light.json (or any DTCG file). Outputs each
# leaf-path as a dotted string. The sed strips the `.$value` suffix
# DTCG leaves carry, the awk truncates to top-2-segments, sort-u
# dedupes, head-20 caps display. Adjust file path per DS.
jq -r '
  paths(scalars) | join(".")
' tokens/Semantic/Light.json \
  | sed -E 's/\.\$value$//' \
  | awk -F. 'NF >= 2 {print $1"."$2}' \
  | sort -u \
  | head -20
```

Sample output (a real-world `Semantic/Light.json`, ~664 leaves):

```
color.controls
color.interaction
color.surface
color.system-status
color.text
shadow.elevation
spacing.component
typography.body
typography.heading
```

Each entry is a **grammar candidate** — its dotted-prefix shape is the
input to grammar-pattern detection. To go deeper for one specific
prefix (e.g. `color.controls`), repeat the recipe with `awk` capturing
3+ segments:

```bash
jq -r '
  paths(scalars) | join(".")
' tokens/Semantic/Light.json \
  | sed -E 's/\.\$value$//' \
  | grep '^color\.controls\.' \
  | awk -F. 'NF >= 4 {print $1"."$2"."$3"."$4}' \
  | sort -u
```

Sample drill-down output:

```
color.controls.brand.background
color.controls.brand.icon
color.controls.brand.text
color.controls.negative.background
color.controls.primary.background
color.controls.primary.text
color.controls.secondary.background
color.controls.secondary.text
```

→ Grammar inferable: `color.controls.{hierarchy}.{element}.{state}` (with
state at position [4] from a deeper drill).

#### Components/* heuristic

If the DS uses a per-component-override token-set layout (e.g.
`tokens/Components/<Name>.json` for Focus, InputGroup, Overlay,
Sidebar, Icon, Divider), surface that **as its own token-layer entry**
even when the rest of the token-grammar is enumerated at coarser
granularity. The Production-Scaffold reference Profile typically
records this as a `token_layer` with `always_enabled: true`. Snapshot
flags it in ~30 s:

```bash
ls tokens/Components/*.json 2>/dev/null \
  | while read f; do
      echo "$(basename "$f" .json): $(jq -r 'paths(scalars) | length' "$f" 2>/dev/null) leaves"
    done
```

Sample output (a real-world DS with a Components/* token-layer):

```
Divider: 6 leaves
Focus: 6 leaves
Icon: 12 leaves
InputGroup: 24 leaves
Overlay: 18 leaves
Sidebar: 30 leaves
```

This is **structural signal**, not detail-noise — it tells the reader
the DS treats certain components as token-cascade-overrides distinct
from the base grammar.

---

## 5 · Documentation-Surfaces Survey

Before assuming intent / purpose / pattern, check if the DS-author has
documented it. Enumerate all documentation surfaces:

- Token descriptions (DTCG `$description`)
- Component descriptions (Figma built-in)
- Annotations on nodes (Figma sticky-note system)
- Doc-frames (e.g. `_doc-content` per component)
- External docs (Confluence/Notion/Storybook — User-pointed only)

Triage matrix (Profile-level vs Component-level relevance):

| Surface | Profile-Level | Component-Level |
|---|---|---|
| DTCG `$description` on tokens | ★ (intent, deprecation) | — |
| Figma Component Description | ★ (category hints) | ★★ |
| Figma Annotations | — | ★★ (A11y, tab-order) |
| Doc-frames (`_doc-content`) | ★★ (systemic patterns) | ★★ (component specifics) |
| External docs | ★ (on request) | ★ |

**Author intent beats inferred intent.** Many DSes have `_doc-content`
frames (or similar) per component containing author-intended
documentation: Best Practices, Focus-Strategy, Property semantics,
Responsiveness rules. **This is more authoritative than any LLM-inference
from variants.** If present: ingest FIRST, infer SECOND.

---

## 6 · Verify, Don't Trust

Verify User-claims AND your own earlier LLM-conclusions against data
before baking into findings. The act of verifying surfaces adjacent
findings you'd otherwise miss.

**Field observation:** a User-claim about a token family turned out
wrong; the verification attempt surfaced a different, real DTCG ↔ Figma
count delta that would otherwise have gone unnoticed.

---

## 7 · Tool-Agnosticism

Skills describe WHAT to find and WHY, not WHICH tool to invoke (except
for near-universal constants: `figma-mcp`, `cdf-mcp`). For DS-specific
tools, Rule A applies — the skill says "ask the User what's available,
adapt."

**Why:** every DS-specific tool-name baked into instructions is a
regression for the next DS-architect.

---

## 8 · Utility-Components Awareness

Not all DS functionality lives in variants. Shared utility components
(focus rings, dividers, tooltip backdrops, animation wrappers) implement
cross-cutting concerns by composition, not by variant-properties. Without
this classification, A11y / Interaction analysis is incomplete.

**Heuristic:** After enumerating COMPONENT_SETs, classify standalone
COMPONENTs by role (Utility / Documentation / Widget / Asset) via name
patterns + User confirmation.

**Field observation:** an initial claim "this DS has no focus design"
turned out wrong — the DS had a standalone `Focus Ring` component used
compositionally via doc-frames. Invisible to pure variant-axis analysis.
