# Changelog — `cdf` Claude Code plugin

All notable changes to this plugin are documented here. The plugin
follows semantic versioning. Plugin version is independent of the
underlying [`@formtrieb/cdf-core`](https://github.com/formtrieb/cdf-core)
and [`@formtrieb/cdf-mcp`](https://github.com/formtrieb/cdf-mcp) versions
— see [`.mcp.json`](.mcp.json) for the pinned MCP-server range.

**Install:** see [`README.md`](README.md#install) — two-step
(`marketplace add` → `install cdf@cdf`).

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
