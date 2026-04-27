---
name: cdf-profile-snapshot
description: Use for first-touch CDF evaluation against an unfamiliar design system. Triggers on "/snapshot-profile", "snapshot", "quick look", "first look", "evaluate cdf for my DS", "what would CDF say about my DS", "is this DS worth onboarding to CDF". Produces a 5–10 min sketch (`<ds>.snapshot.profile.yaml` + `<ds>.snapshot.findings.md`) with explicit blind-spots and an upgrade path to the full Production Scaffold. NOT a substitute for `cdf-profile-scaffold` (which authors validator-checked Profiles via the 7-phase pipeline) — distinct audience: evaluators, not adopters.
---

# CDF Profile Snapshot — Quick-Look Skill

Produces a first-touch sketch of a design system as a CDF Profile in
**5–10 min**. Output is explicitly draft-grade with mandatory blind-
spots framing — the trust handshake lives in the artefact, not in a
validator.

**Audience contract.** This skill is for **first-touch evaluation**:
"Is CDF useful for my DS? What would it say at a glance?" For
production-grade Profile authoring (validator-checked, classified
findings, generator-consumable) use **`cdf-profile-scaffold`** (the
7-phase Production Scaffold).

**Artefacts produced (per run):**
- `<ds>.snapshot.profile.yaml` — Profile-shaped sketch with `_quality:
  draft` markers on inferred sections (validator NOT run)
- `<ds>.snapshot.findings.md` — flag-only findings rendered under a
  *DRAFT — UNCLASSIFIED* banner with prominent blind-spots block

---

## §0 · Pre-Flight (Plugin Install + Runtime Prerequisites)

This skill ships in the [`formtrieb/cdf-plugin`](https://github.com/formtrieb/cdf-plugin)
Claude Code plugin. If you are reading this in a `~/.claude/plugins/`
install — you already have it. Otherwise: `claude plugin install
formtrieb/cdf-plugin`.

**Hard prerequisites (any path):**

- Claude Code or Claude Desktop with MCP support
- Node.js ≥ 20 (the plugin's `.mcp.json` runs `@formtrieb/cdf-mcp` via
  `npx`; first invocation caches it locally)
- A target design-system directory with write permissions for the two
  Snapshot deliverables (`<ds>.snapshot.profile.yaml` +
  `<ds>.snapshot.findings.md`)

**Host-tool prerequisites (one-time install, not per-run):**

The synthesis pass uses standard POSIX shell utilities for YAML/JSON
extraction. The toolchain is **PyYAML-frei** — Python is used only with
its stdlib; YAML→JSON conversion goes through `yq`. A typical macOS
install: `brew install yq jq`. On Debian/Ubuntu: `apt install yq jq
python3`. (`yq` must be the **mikefarah** variant — Go-based, ≥ 4.x. The
older `kislyuk/yq` Python wrapper is NOT compatible with the recipes in
this skill.)

| Tool | Min version | Install hint |
|---|---|---|
| `yq` (mikefarah) | ≥ 4.x | `brew install yq` / `apt install yq` |
| `jq` | any modern | `brew install jq` / `apt install jq` |
| `python3` | stdlib only — no PyYAML needed | usually pre-installed; `brew install python3` if not |
| Bash 4+ or zsh | any modern | macOS 11+/Linux: pre-installed |

To verify your environment in one shot:

```bash
bash <plugin-root>/scripts/check-host-deps.sh
```

The script returns 0 + prints the resolved versions on success, or 1 +
prints `MISSING: <tool>` on the first absent dependency.

**Path-specific prerequisites** (see §1.4 audience-fit for selection):

| Path | What you need |
|---|---|
| **T1 (REST)** — Engineer with PAT | `FIGMA_PAT` env var **or** pass `pat:` arg to `cdf_fetch_figma_file`. PAT scopes: `file_content:read` minimum |
| **T0 (runtime)** — Evaluator without PAT | `figma-console` MCP loaded in the Claude session + Figma Desktop with the target file open |
| **T2 (Variables)** — Enterprise | T1 PAT plus permission for `GET /v1/files/{key}/variables` (Enterprise plans) |

**Optional (richer regime):**

- DS-specific tokens MCP (the synthesis pass burns its single
  `browse_tokens` budget against it if loaded — Contract 4 in
  `references/synthesis.md`)

**First-run smoke test:** with the plugin installed, type `/cdf` in
your Claude Code session — both `/cdf:scaffold-profile` and
`/cdf:snapshot-profile` should appear. If they don't, restart the CC
session to re-discover plugin components.

---

## §0.5 · Read-Path Resolution

All `Read`/`yq`/`jq` paths in this skill and its `references/` + `shared/`
docs resolve **relative to the directory containing this SKILL.md**, not
relative to the user's `cwd`. Two consequences:

1. **You can call `Read references/synthesis.md` directly.** No `ls`-
   discovery needed. The Read tool resolves the relative path against
   the SKILL.md base.
2. **If a Read fails with "file does not exist"** because relative-path
   resolution didn't pick up SKILL.md as anchor, locate the skill root
   ONCE via `find ~/.claude/plugins -name SKILL.md -path "*<skill-name>*"`
   and prefix subsequent reads with the resulting absolute path. Cache
   the path; do NOT re-discover per Read.

This anchor applies to:
- `references/*.md` (skill-internal)
- `../../shared/cdf-source-discovery/*.md` (shared refs)
- `../../shared/<other>/...` (any future shared module)

---

## §1 · Orchestration — Point-of-Need Reads (β-strict)

The Snapshot is single-pass with four steps. Each step Reads the shared
references it needs **immediately before invoking** — do NOT pre-load the
shared docs upfront. Per-step Read budget is 0–2 files, not 3-upfront.

| Step | What | Read before this step |
|---|---|---|
| 1 | Source-discovery + tier-detection + opening checklist | `../../shared/cdf-source-discovery/source-discovery.md` (opening checklist §1, F6-corrected probe-first tier-detection §2, parent-Profile §4, identifier §5, `.cdf-cache/` layout §6) |
| 2 | Walker invocation (T1/T2) or T0 capture | `../../shared/cdf-source-discovery/walker-invocation.md` (walker invocation §2, source-of-truth contract §1, resolver §3, mechanical seeds §4) |
| 3 | Single-pass synthesis | `references/synthesis.md` (six contracts + per-section guidance) **and** `../../shared/cdf-source-discovery/tool-leverage.md` (Rule A enforcement §2 — gates blind_spots; Rule B §3 if any tier-decision still pending; Token enumeration paths §-block under §4 — Contract 4 fallback recipes) |
| 4 | Render | (no shared/-deps; one MCP tool call to `cdf_render_snapshot`) |

`references/synthesis.md` declares its own `requires:` deps in YAML
frontmatter so this dispatch is grep-verifiable. If you arrive at a step
without having Read its required docs, Read them now before continuing —
**point-of-need is the contract; skipping is not**.

The Snapshot consumes the same source-discovery layer as the Production
Scaffold; the shared docs are one canonical source, both skills load them
on-demand.

### §1.4 · Audience-fit — choose your source-path

The Snapshot consumes Phase-1 walker output (`Phase1Output`), regardless
of which source-mode produced it. Two paths feed the same downstream
synthesis:

| Audience | Path | Setup |
|---|---|---|
| Engineer with PAT | T1 (REST) | `FIGMA_PAT` env var or `pat:` arg → `cdf_fetch_figma_file({file_key})` → `cdf_extract_figma_file({source: "rest", file_key})` |
| Evaluator without PAT | T0 (runtime) | figma-console MCP loaded in Claude session → capture Plugin-API tree via `figma_execute` to `.cdf-cache/figma/<key>.runtime.json` → `cdf_extract_figma_file({source: "runtime", file_key})` |
| Enterprise with full Variables access | T2 (REST + Variables) | T1 path plus `cdf_resolve_figma_variables({file_key})` for the resolved Variable map |

The synthesis (§2) is source-mode-blind — it operates on
`.cdf-cache/phase-1-output.yaml` regardless of which adapter wrote it.
The walker output's `generated_by.tier` field records which path was
used (`T0` / `T1` / `T2`); surface that in the metadata but do not
branch synthesis logic on it.

**Snapshot-specific narrowing of the opening checklist:**

The shared checklist asks about:
- 🔴 DS name + Figma URL — **Snapshot REQUIRES both** (the URL drives
  `file_key` resolution for either source-path).
- 🟡 Token regime — Snapshot accepts any regime; quality-rating ★ is
  surfaced in metadata but does not gate the run.
- 🟡 Parent-Profile (`extends:`) — Snapshot **records** the value in
  `metadata.source.parent_profile` for upgrade-path traceability but
  does **NOT** honour merge semantics in its own output (per
  `source-discovery.md` §4 last-paragraph: skills that don't emit
  Profiles record extends but don't merge).
- 🟢 DS-specific tokens MCP — useful for the single `browse_tokens`
  pass in §2 if available; not required.

**.cdf.config.yaml.** Read at start of run if present. Use
`scaffold:` block fields read-only (Snapshot uses the Production-
established source-discovery state — does NOT write its own config
block in this spike). The `scaffold.tier:` field (T0/T1/T2) determines
which `cdf_extract_figma_file` source-mode to invoke — see §1.4 above.

---

## §2 · Single-pass Synthesis Dispatch

After source-discovery resolves, the Snapshot runs a **single-pass
synthesis** over the Phase-1 mechanical extract output. The full
synthesis prompt (per-section structure, citation contract, blind-spot
template, token-MCP contract, findings cap, leaf-only standalone-tokens
contract) lives in `references/synthesis.md`.

Dispatch is one-line:

```
Read references/synthesis.md
```

…then follow it. The synthesis doc covers the seven snapshot-shape
sections (`metadata`, `inventory`, `vocabularies`, `token_grammar`,
`theming`, `interaction_a11y`, `findings_unclassified`) plus the
mandatory `blind_spots` and `upgrade_path` framing, and enforces six
load-bearing contracts (STRUCTURE, CITATION, BLIND_SPOTS, TOKEN-MCP,
FINDINGS, STANDALONE-TOKENS leaf-only). The schema contract these
populate is `references/snapshot.profile.schema.yaml` (QL.A).

**Hard caps the synthesis pass enforces (locked in this spike):**

- Max **15** unclassified findings — flag-only, NO decision-vocab
  field. The Production Scaffold's Phase-6 classification is what makes
  findings actionable; the Snapshot deliberately leaves them as raw
  signal.
- Max **1** `browse_tokens` call against any DS-tokens MCP. Snapshot
  is single-pass; multi-call analysis loops are Production territory.
- **Citation contract:** every quantitative claim in the synthesis MUST
  cite a Phase-1 walker output path (`ds_inventory.…`) or a token-MCP
  reference. Synthesis SHALL NOT invent counts, name vocabularies the
  walker did not surface, or extrapolate values from training data.

---

## §3 · Discovery → Commit Handoff

After the Snapshot writes its two artefacts, prompt the User with the
upgrade-path offer. Canonical phrasing:

> *"Snapshot complete. This is a draft — Findings are unclassified,
> tokens not audited, vocab-collisions not surfaced. Want to upgrade
> to a Production Scaffold (~25–35 min, full 7-phase, blocking-finding
> classification, validator-ready)? It can use this snapshot's output
> as a Phase-1 seed."*

If the User opts in: invoke `cdf-profile-scaffold` (the existing
skill — `Read ../cdf-profile-scaffold/SKILL.md`) with the
`<ds>.snapshot.profile.yaml` filepath as the Phase-1 seed-input. The
Production Scaffold reviews the seed, refines, and runs the full
classification pass.

**The Snapshot output is read-only seed.** Do NOT round-trip — the
Production Scaffold writes its own `<ds>.profile.yaml` (no
`.snapshot.` infix) and `<ds>.findings.md` (no DRAFT banner). The
Snapshot artefacts remain on disk as evaluation history.

If the User declines or doesn't respond: end cleanly. The two snapshot
artefacts on disk are the deliverable.

**No autopilot.** If invocation framing implies "run autonomously"
or no User is reachable, halt before §3 — do not silently auto-decide
the upgrade-path branch.

---

## §4 · Render

The Snapshot's synthesis pass emits two YAML artefacts; the renderer
turns the second into Markdown:

- `<ds>.snapshot.profile.yaml` — written via `Write`, conforms to
  `references/snapshot.profile.schema.yaml`.
- `<ds>.snapshot.findings.yaml` — written via `Write`, raw findings
  list (`schema_version: snapshot-findings-v1`, see header comment in
  `scripts/render-snapshot.sh` or the `cdf_render_snapshot` tool docs
  for the shape).
- `<ds>.snapshot.findings.md` — emitted by `cdf_render_snapshot`
  (or the deprecated `scripts/render-snapshot.sh`) reading the two
  YAML files above.

Dispatch is one MCP-tool call:

```
cdf_render_snapshot({ snapshot_dir: "<ds-test-dir>" })
```

…which discovers the matching `<prefix>.snapshot.profile.yaml` +
`<prefix>.snapshot.findings.yaml` pair in the directory, hard-fails on
schema mismatch or >15 findings, and emits
`<prefix>.snapshot.findings.md` alongside them.

If MCP tools are unavailable, the bash equivalent
`bash scripts/render-snapshot.sh <ds-test-dir>` produces identical
output (DEPRECATED, removed in cdf-mcp v1.8.0). The renderer
guarantees four sections, in this order:

1. **DRAFT — UNCLASSIFIED** banner (GitHub admonition + ⚠ glyph).
2. Findings — flag-only bullets (no decision-vocab columns).
3. *What this snapshot did NOT check* — blind-spots, own H2.
4. Upgrade path — final paragraph with copy-paste `/scaffold-profile`
   invocation.

The `.profile.yaml` is a passthrough — the renderer does not modify
it, only reads metadata + blind-spots + upgrade-path from it.

**Output layout** (per `source-discovery.md` §6 deliverable convention):

| Artefact | Where |
|---|---|
| `<ds>.snapshot.profile.yaml` | top-level (DS-test-dir root), DS-prefixed |
| `<ds>.snapshot.findings.md` | top-level, DS-prefixed |
| Raw synthesis intermediates (if any) | `<ds-test-dir>/.cdf-cache/snapshot/` |

Both top-level files are deliverables — humans read them. Cache is
regenerable. `mkdir -p` on `.cdf-cache/snapshot/` if writing
intermediates.

---

## §5 · Audience Distinction (Skill-Picker Disambiguation)

If invocation context is ambiguous between Snapshot and Production
Scaffold, ask the User one clarifying question:

> *"Two CDF Profile skills are available — which fits your need?
> **Snapshot** (~5–10 min, draft sketch with blind-spots, for first-
> touch evaluation) or **Production Scaffold** (~30–40 min, validator-
> checked output, for committed onboarding)?"*

Trigger words that lean Snapshot: *"snapshot"*, *"quick look"*,
*"first look"*, *"evaluate"*, *"is it worth"*, *"at a glance"*,
*"what does CDF think"*.

Trigger words that lean Production: *"scaffold"*, *"refresh"*,
*"author the profile"*, *"validator"*, *"generators"*, *"committed"*,
*"build the profile"*.

When in doubt, default to Snapshot — it's reversible (5–10 min cost),
and the Discovery → Commit handoff (§3) lets the User upgrade once
they've seen the sketch.

---

## §6 · Out-of-Scope (this spike, this skill)

| Concern | Where it lives |
|---|---|
| Findings classification (block / defer / adopt) | `cdf-profile-scaffold` Phase 6 |
| Vocabulary-isolation (Profile §5.5 / CDF-STR-011) | `cdf-profile-scaffold` Phase 2 + `cdf_validate_profile` L8 |
| Validator runs (`cdf_validate_profile` L0–L7) | `cdf-profile-scaffold` Phase 7 |
| Token-gap audit (placeholders, magenta, contrast guarantees) | `token-audit` skill |
| Conformance overlays (Profile-Spec divergences) | `cdf-profile-scaffold` Phase 6 acceptance dialog |
| Component-level scaffolding | future `cdf-component-scaffold` (backlog) |
| Code-only DS (no Figma) | future Source-Adapter Track G |

These are deliberately not Snapshot's job. Reaching for them is the
adoption-funnel anti-pattern that this skill exists to prevent.
