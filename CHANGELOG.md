# Changelog — `cdf` Claude Code plugin

All notable changes to this plugin are documented here. The plugin
follows semantic versioning. Plugin version is independent of the
underlying [`@formtrieb/cdf-core`](https://github.com/formtrieb/cdf-core)
and [`@formtrieb/cdf-mcp`](https://github.com/formtrieb/cdf-mcp) versions
— see [`.mcp.json`](.mcp.json) for the pinned MCP-server range.

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
