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

---

## 2 · Rule A Enforcement: Tool-Survey BEFORE Resolver-Gap

The discipline above (Rule A — "Survey First") fails silently in
**non-interactive runs** (auto-mode scaffolds, snapshot single-pass
synthesis) where there is no User-dialog brake. The LLM can declare a
resolver-gap ("color tokens NOT enumerable", "theming axes NOT visible",
"variables NOT accessible") on the first source it inspects, never
checking whether the loaded MCP tools could fill the gap. The output
then bakes the false claim into deliverables.

**The enforcement rule.** Before declaring ANY resolver-gap claim of
the form *"X NOT enumerable / NOT visible / NOT accessible / NOT
available"*, the synthesis pass MUST:

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
   either becomes "X NOT enumerable [probed `<tool>` → <result>]"
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

## 3 · Tool-Leverage Map (Source Enumeration)

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

---

## 4 · Documentation-Surfaces Survey

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

## 5 · Verify, Don't Trust

Verify User-claims AND your own earlier LLM-conclusions against data
before baking into findings. The act of verifying surfaces adjacent
findings you'd otherwise miss.

**Field observation:** a User-claim about a token family turned out
wrong; the verification attempt surfaced a different, real DTCG ↔ Figma
count delta that would otherwise have gone unnoticed.

---

## 6 · Tool-Agnosticism

Skills describe WHAT to find and WHY, not WHICH tool to invoke (except
for near-universal constants: `figma-mcp`, `cdf-mcp`). For DS-specific
tools, Rule A applies — the skill says "ask the User what's available,
adapt."

**Why:** every DS-specific tool-name baked into instructions is a
regression for the next DS-architect.

---

## 7 · Utility-Components Awareness

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
