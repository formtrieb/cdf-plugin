# CDF Source Discovery — Shared Reference

**Purpose:** Common opening checklist, Figma-access tier detection, token-source
regime classification, parent-Profile inheritance, DS identifier short-code, and
`.cdf-cache/` output-layout convention. Loaded by any CDF skill that ingests a
design system from Figma + tokens (e.g. `cdf-profile-scaffold`,
`cdf-profile-snapshot`, future `cdf-component-scaffold`).

**Audience:** the LLM running the skill. **Not** end-user docs.

**Skill-agnosticism contract:** this file references no specific phase IDs,
synthesis flows, or output schemas. Each loading skill maps the concepts here
onto its own workflow.

---

## 1 · Opening Checklist (advisor tone, not gatekeeper)

When starting fresh against a new DS (no `.cdf.config.yaml` `scaffold:` block
yet, or User opted `fresh`), open with this message. The ★-rating teaches the
quality impact of each input.

```
I'll work on this design system. To do that well I need:

🔴 REQUIRED (no workflow without these):
   • DS name (short identifier, e.g. `formtrieb`, `mydesign`, `acme`)
   • Figma source URL (file where the DS lives)

🟡 QUALITY-CRITICAL (ranked by impact on output):
   Token source regime — pick the best available:
     ★★★  Tokens Studio export (DTCG JSON + Figma Variables sync)
     ★★   DTCG folder (hand-maintained) + Figma Variables
     ★    Figma Variables only
     △    Figma Paint/Text/Effect Styles only (becomes a Finding)
     ✗    No structured tokens (proceeds with `quality_rating: 0` —
          emits a skeleton Profile, seeds Finding #1 as methodology note)

   Parent Profile inheritance (CDF Profile Spec §15):
     • Does this DS extend from a shared baseline Profile?
       Common pattern for in-house DS families: a root Profile
       defines the shared vocabulary + token grammar + patterns;
       child Profiles override only what differs (identifier,
       theming contexts, assets). See Profile Spec §15.5 for the
       canonical Acme-extends-Formtrieb example.
     • If yes: relative path to parent (from the emit location).
       Skill writes `extends: <path>` and emits ONLY diverging
       blocks; shared vocabularies / token_grammar /
       interaction_patterns / accessibility_defaults / categories
       inherit unchanged. Typical child Profile is 100-200 lines
       vs 400+ for a standalone.
     • If no: Profile is self-contained (all sections inlined).
     • **Single-level only** in Spec v1.0.0 — chains (C extends B
       extends A) are rejected. If a candidate parent itself has
       `extends:`, emit a Finding + scaffold the child against the
       root Profile.

🟢 NICE-TO-HAVE (surfaced when relevant; ask if missing):
   • DS-specific token MCP server (e.g. `formtrieb-tokens`, `<ds>-tokens`)
   • Doc-frame convention (e.g. `_doc-content` frames per component)
   • External docs pointer (Confluence/Notion/Storybook URL)
   • DS identifier short-code (2–4 letter prefix used in
     `--{code}-*` tokens + `.{code}-*` CSS classes; defaults to
     first 3 chars of DS name, User-overridable — e.g. Formtrieb
     → `ft`, Primer → `pr`, Material 3 → `m3`, Acme → `acme`)

What can you give me?
```

The skill consuming this checklist may render fewer fields if its scope
doesn't need them (e.g. a Snapshot-style skill may skip `extends:` because
it doesn't emit inheritance-aware Profiles), but it MUST NOT add new
required fields without updating this shared doc.

**Survey First applies from here forward** — every "where does X live?"
question before every source inspection (see `tool-leverage.md` Rule A).

---

## 2 · Figma-Access Tier Detection

Before inspecting the Figma file, detect which **Figma-access tier** applies.
Tier determines how inventory is acquired. Auto-detected from filesystem +
`.cdf.config.yaml`; User can override.

| Tier | Signal | Inventory path |
|---|---|---|
| **T0** (default) | No file cache present | Live `figma_execute` enumeration |
| **T1** | `scaffold.figma.file_cache_path` exists on disk (e.g. `<dir>/data/library.file.json`) OR `figma-cache/library.file.json` under the DS test-dir | Mechanical walker (`cdf_extract_figma_file({source:"rest"})` MCP tool, or deprecated `scripts/extract-to-yaml.sh` bash) + pluggable resolver |
| **T2** | T1 signal + `scaffold.token_source.regime: enterprise-rest` + sidecar present | Same as T1, but resolver uses REST `/variables` endpoint |

**Detection algorithm** (run before any inventory work):

1. Check `scaffold.figma.file_cache_path` in `.cdf.config.yaml`. If set and
   file exists → T1.
2. Check `<ds-test-dir>/data/library.file.json` (common fetch default). If
   exists → T1.
3. Check `<ds-test-dir>/figma-cache/library.file.json`. If exists → T1.
4. Else → T0.
5. If T1 and `scaffold.token_source.regime == enterprise-rest` → T2.

**T0 is fully backwards-compatible** — existing workflows continue unchanged.
Users who want T1 run `cdf_fetch_figma_file({file_key, pat?})` once
(MCP tool, ≥ cdf-mcp v1.7.0; PAT resolves arg > `FIGMA_PAT` env), or the
deprecated `specs-cli fetch` / `curl` against `GET /v1/files/{key}` for
clients without cdf-mcp v1.7.0+. Either path lands the file at
`<ds-root>/.cdf-cache/figma/<file_key>.json`.

**Why tier split:** Live `figma_execute` enumeration on a large file takes
30–45 min on a mature DS. With the REST file on disk, the same inventory
comes from a single-pass walker in ~2–3 s (TS implementation in
`@formtrieb/cdf-core`'s extractor; deprecated bash equivalent
`scripts/extract-to-yaml.sh` produces byte-identical output through
v1.8.0).

**Pluggable resolver slot** (T1/T2 only): the Variable-ID → path mapping
is project-specific. Three drop-ins:

| `scaffold.token_source.regime` | Resolver |
|---|---|
| `tokens-studio` (+ DS-specific tokens-MCP) | `<ds>-tokens.list_themes` / `browse_tokens` |
| `figma-variables` | One Plugin-API call — `figma.variables.getLocalVariableCollectionsAsync()` — result cacheable at `<ds-test-dir>/figma-cache/variables.json` |
| `enterprise-rest` | REST sidecar `GET /v1/files/{key}/variables` |

All three return the same axis/mode + variable-path shape; downstream
theming/grammar work uses the resolver output without knowing which
backend filled it.

---

## 3 · Token-Source Regime Classification

If not already captured in `.cdf.config.yaml` `scaffold:` block, ask the User:

| Regime | Indicator | ★-rating | Implication |
|---|---|---|---|
| **tokens-studio** | `.tokens.json` export + Figma Tokens plugin sync | ★★★ | Both sources of truth in reach; drift-detection is the main downstream surface. |
| **dtcg-folder** | hand-maintained DTCG files, Figma Variables may mirror | ★★ | DTCG is canonical; cross-check Figma Variables = near-miss detection. |
| **figma-variables** | only Figma Variables; no DTCG | ★ | Figma is canonical; export-path needed before generators run. |
| **figma-styles** | no Variables; only Paint/Text/Effect Styles | △ | Seed Finding #1 (methodology: "Styles-only, Variables migration recommended"). |
| **none** | no structured tokens | ✗ | Skeleton Profile only; `quality_rating: 0`; seed Finding #1 + hard warning. |

The regime classification is recorded in `phase-1-output.yaml`
(`token_source.regime`) and the `.cdf.config.yaml` `scaffold:` block.
Downstream synthesis branches on this value.

---

## 4 · Parent-Profile Inheritance

A CDF Profile MAY extend another Profile via the top-level `extends:` field
(Spec §4.5 + §15). For in-house DS families this is the norm, not the
exception: a root Profile defines shared vocabularies + token grammar +
patterns, and child Profiles override only what differs.

**Asking about this is load-bearing — a workflow that skips the question
will silently inline inherited content and produce a 3×-oversized child
Profile with drift risk.**

Ask the User:

> "Does this DS extend from a shared baseline Profile? (Common pattern
> for DS families sharing a common architecture.) If yes, name the
> relative path from this Profile's emit location — e.g.
> `../formtrieb.profile.yaml`. If no, the Profile is self-contained."

Record in inventory output:

```yaml
extends:
  path: ../formtrieb.profile.yaml      # null if self-contained
  parent_name: Formtrieb               # from parent's `name:` field
  parent_cdf_version: ">=1.0.0 <2.0.0" # child MUST fit within this
```

**Spec constraints (surface as findings if violated):**

| Constraint | Check | On-violation |
|---|---|---|
| Single-level only | Read parent Profile; does it also have `extends:`? | If yes: seed a format-gap finding + scaffold against the root instead |
| cdf_version must fit parent | Child `cdf_version:` range ⊆ parent's range | If no: warn; ask User whether to narrow the child's range |
| Circular reference | Child path ≠ parent path (direct) | If identical: hard stop |
| Parent file exists | Path resolves to an existing `.profile.yaml` | If not: hard stop, ask for correct path |

**Merge semantics to internalize (§15.1):** per-key REPLACE at the smallest
documented unit. The skill's output artefact for each section is:

- "No divergence from parent" → omit the section entirely
- "Partial divergence" → emit only the diverging keys (e.g. just
  `naming.identifier`, not the whole `naming:` block)
- "Full replacement" → emit the whole block (always for `theming.set_mapping`
  — §15.1 mandates whole-block replace)

Skills that synthesise downstream sections (vocabularies, token_grammar,
patterns) build their outputs as *differences from parent* when `extends:`
is set, not as absolute characterizations. This keeps the emit cycle trivial.

Skills that don't emit Profiles (e.g. quick-look snapshots) record the
`extends:` value for downstream traceability but do not have to honour merge
semantics in their own output.

---

## 5 · DS Identifier Short-Code

Distinct from `ds_name` (the long filename-safe identifier used in paths):
`naming.identifier` is a 2–4 letter short code used to derive prefix
conventions downstream:

- `--{code}-*` for CSS custom property token names
- `.{code}-*` for CSS class name conventions
- Target-spec Identifier Template DSL (CDF-TARGET-SPEC §5.6) derives concrete
  Target prefixes from this code.

Default: first 3 lowercase letters of `ds_name`. User can override.

| DS | ds_name | identifier | Rationale |
|---|---|---|---|
| Formtrieb | `formtrieb` | `ft` | Pronunciation — "F-T" |
| Primer | `primer` | `pr` | First 2 letters |
| Material 3 | `material3` | `m3` | Letter+digit (Google convention) |
| Acme | `acme` | `acme` | Short enough already |

Ask the User (only if not already set via `.cdf.config.yaml`):

> "DS identifier short-code — 2-4 letters used in `--{code}-*` tokens
> and `.{code}-*` classes. Default: first 3 chars of ds_name
> (`{auto_default}`). Override?"

If the DS extends a parent and the identifier is inherited-unchanged, the
child Profile's emit simply omits `naming:` entirely (Spec §15.1 per-key
REPLACE).

---

## 6 · `.cdf-cache/` Output Layout

The skill writes three categories of artefacts into the User's DS-test-dir,
each with a defined home:

| Category | Definition | Examples | Where |
|---|---|---|---|
| **Cache** | Regenerable from `data/` + skill rerun. No User input. | Phase-N-output YAMLs, walker artefacts | `<ds-test-dir>/.cdf-cache/` |
| **Canonical user-input** | User decisions captured in dialog. Re-deriving costs User time. | `<ds>.findings.yaml` | top-level, DS-prefixed |
| **Deliverables** | What humans read. | `<ds>.profile.yaml`, `<ds>.findings.md`, `<ds>.conformance.yaml`, `<ds>.housekeeping.md`, snapshot variants | top-level, DS-prefixed |

The walker (`extract-to-yaml.sh`) creates `.cdf-cache/` if missing; skills
that write into `.cdf-cache/` MUST `mkdir -p "$(dirname "$OUT")"` before
writing.

**`.gitignore` recommendation:** add `/.cdf-cache/` to the User's
`.gitignore` once. If their DS-test-dir has no `.gitignore` yet, mention it
during the closing handback — opt-in offer, do not write the file silently.
Mirrors the `node_modules/` / `.next/` / `.cache/` family of
regenerable-cache conventions; one line in `.gitignore` covers all skill
cache output.

**Snapshot-style skills:** still place ephemeral intermediates under
`.cdf-cache/` (e.g. raw walker output) and emit their own deliverables with
the snapshot prefix at top-level (`<ds>.snapshot.profile.yaml`,
`<ds>.snapshot.findings.md`). The convention is regime-of-artefact, not
skill-of-origin.

---

## 7 · `.cdf.config.yaml` Discovery

Both Production and Snapshot-style skills MUST `Read` `.cdf.config.yaml`
from cwd at start of run if it exists. Common fields a skill may consume
read-only (write-back is skill-specific):

```yaml
spec_directories: [./specs]
token_sources: [./tokens/]
profile_path: ./formtrieb.profile.yaml

scaffold:
  ds_name: formtrieb                     # 🔴 required
  figma:
    file_url: https://figma.com/design/… # 🔴 required
    file_cache_path: ./data/library.file.json  # 🟢 T1/T2 — REST fetch on disk
  tier: T1                               # auto-detected §2; User can override
  token_source:
    regime: tokens-studio                # tokens-studio|dtcg-folder|figma-variables|figma-styles|enterprise-rest|none
    path: ./tokens/
    quality_rating: 3                    # 1-3 stars (0 when regime=none)
  resolver:                              # 🟡 T1/T2 only — Variable-ID → path mapping
    kind: tokens-mcp                     # tokens-mcp | plugin-cache | enterprise-rest
    mcp_name: formtrieb-tokens           #   (tokens-mcp) DS-specific MCP name
    cache_path: ./figma-cache/variables.json  # (plugin-cache) local cache location
  doc_frames:
    convention: _doc-content             # 🟢 optional
  external_docs: []                      # 🟢 optional
```

Skill-specific sub-blocks (`scaffold.last_scaffold`, `scaffold.auto_mode`,
future `snapshot.last_snapshot`, etc.) belong in the consuming skill's own
docs, not here. The shared contract is ONLY the fields above.

**Spec formalization:** the `scaffold:` block is deferred to CDF Profile Spec
v1.1.0 (Plan 2). Implementations write the fields today; formal schema follows.
