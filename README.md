# `cdf` — Component Description Format skills for Claude Code

A Claude Code plugin that bundles two complementary skills for working
with [CDF Profiles](https://github.com/formtrieb/cdf):

- **`/cdf:scaffold-profile`** (also `/scaffold-profile` when no other
  plugin claims it) — production-grade 7-phase Profile authoring from
  a design system (Figma + tokens) → validator-checked
  `<ds>.profile.yaml` + `<ds>.findings.md`. Wall-time ~30–40 min.
  Audience: DS teams committed to onboarding to CDF.
- **`/cdf:snapshot-profile`** (also `/snapshot-profile`) — 5–10 min
  first-touch evaluation sketch with explicit blind-spots and an
  upgrade path to the Production Scaffold. Audience: evaluators
  asking *"what would CDF say about my DS?"*

Both skills share a canonical source-discovery layer
(`shared/cdf-source-discovery/`) and orchestrate the
[`@formtrieb/cdf-mcp`](https://www.npmjs.com/package/@formtrieb/cdf-mcp)
toolchain (22 deterministic CDF tools — fetch, extract, validate,
diff, coverage, render, etc.).

## Install

This is a single-plugin repo packaged as a one-entry **marketplace** —
two-step install (Claude Code's `plugin install` expects a configured
marketplace, not a bare GitHub URL):

```bash
# 1. Register the repo as a marketplace named "cdf"
claude plugin marketplace add formtrieb/cdf-plugin

# 2. Install the cdf plugin from the cdf marketplace
claude plugin install cdf@cdf
```

Verify:

```bash
claude plugin list | grep cdf
# Expected: cdf@cdf   Version: 1.0.0   Status: ✔ enabled
```

Restart your Claude Code session after install — both slash-commands
appear once the session re-discovers components. The plugin's
`.mcp.json` declares an `npx`-launched `@formtrieb/cdf-mcp@^1.7.0`
server, so the 22 CDF MCP tools are auto-available — no separate
`npm install` required. First invocation may take ~5 s while npm
caches the package; subsequent calls are local-cached.

**Update later:**

```bash
claude plugin marketplace update cdf   # pulls latest from formtrieb/cdf-plugin
claude plugin update cdf@cdf           # applies the update (restart required)
```

## Prerequisites

| | Required | Optional |
|---|---|---|
| **Runtime** | Claude Code or Claude Desktop with MCP support; Node.js ≥ 20 | — |
| **Figma access (T1 — REST)** | `FIGMA_PAT` env var (scope: `file_content:read`) | — |
| **Figma access (T0 — runtime)** | `figma-console` MCP loaded + Figma Desktop with file open | — |
| **Figma access (T2 — Variables)** | T1 PAT + Enterprise plan permissions for `GET /v1/files/{key}/variables` | — |
| **Tokens regime** | — | DS-specific tokens MCP (e.g. `tokens-studio`) for `tokens-studio` regime |
| **Inheritance** | — | Parent CDF Profile via `extends:` (single-level only per CDF v1.0) |

The skill auto-detects the Figma tier (T0 / T1 / T2) — see
`skills/cdf-profile-snapshot/SKILL.md` §1.4 for the audience-fit
table; the same table appears in
`skills/cdf-profile-scaffold/SKILL.md` §0.

## Quickstart

```bash
# 1. Install the plugin (two-step — see "Install" above)
claude plugin marketplace add formtrieb/cdf-plugin
claude plugin install cdf@cdf

# 2. cd into your design-system repo (or any dir where you want
#    the Profile artefacts to land)
cd ~/code/my-design-system

# 3. Optional — seed a .cdf.config.yaml so the skill knows your
#    Figma file and token-source regime up-front (see
#    https://github.com/formtrieb/cdf#cdfconfigyaml-schema for shape)
cat > .cdf.config.yaml <<'EOF'
profile_path: ./my-ds.profile.yaml
token_sources: [./tokens/]
scaffold:
  ds_name: my-ds
  figma:
    file_url: https://figma.com/design/<KEY>/My-DS
  token_source:
    regime: tokens-studio   # or dtcg-folder | figma-variables | figma-styles | enterprise-rest | none
    path: ./tokens/
EOF

# 4. Launch Claude Code in this dir, then invoke a skill.
#    First-touch evaluation:
#      /cdf:snapshot-profile
#    Production-grade scaffold:
#      /cdf:scaffold-profile
```

The Snapshot writes two files (`my-ds.snapshot.profile.yaml` +
`my-ds.snapshot.findings.md`); the Production Scaffold writes the
canonical pair (`my-ds.profile.yaml` + `my-ds.findings.md`) plus
optional `my-ds.conformance.yaml` and `my-ds.housekeeping.md`.

## What's inside

```
plugin/
├── .claude-plugin/
│   └── plugin.json            ← manifest (name: "cdf", v1.0.0)
├── .mcp.json                  ← npx @formtrieb/cdf-mcp@^1.7.0
├── README.md                  ← this file
├── CHANGELOG.md
├── LICENSE                    ← Apache-2.0
├── commands/
│   ├── scaffold-profile.md    ← /cdf:scaffold-profile entry
│   └── snapshot-profile.md    ← /cdf:snapshot-profile entry
├── skills/
│   ├── cdf-profile-scaffold/  ← 7-phase Production Scaffold
│   └── cdf-profile-snapshot/  ← 5–10 min first-touch
└── shared/
    └── cdf-source-discovery/  ← canonical references both skills load
```

The two skills share `shared/cdf-source-discovery/` (three
canonical references: `source-discovery.md` for the opening
checklist + tier detection, `tool-leverage.md` for Rule A and the
spec-fragment lookup contract, `walker-invocation.md` for the
T0/T1/T2 walker invocation). Cross-skill references inside the
plugin use relative paths from each file's location, so they
resolve identically in monorepo dev mode and post-install plugin
mode.

## Troubleshooting

**`claude plugin install formtrieb/cdf-plugin` fails with "not found in any configured marketplace".**
This is the expected error — the install path needs an already-registered
marketplace. Use the two-step from the **Install** section above:
`marketplace add formtrieb/cdf-plugin` first, then `install cdf@cdf`.

**Plugin commands not appearing after install.**
Restart your Claude Code session (or `claude --resume`-equivalent)
to re-discover plugin components. On macOS, fully quitting the app
before relaunching is more reliable than just closing the window.

**`@formtrieb/cdf-mcp` first-call latency.**
The first invocation of any `cdf_*` tool downloads the npm package
into your local npm cache (~5 s on a warm network). Subsequent
calls are local-cached and instant.

**`FIGMA_PAT` not picked up.**
The MCP tool resolution order is: `pat:` arg overrides
`FIGMA_PAT` env var. If you set `FIGMA_PAT` after starting your CC
session, restart so the MCP server inherits the new env. Or pass
`pat: "figd_..."` directly as an argument to
`cdf_fetch_figma_file`.

**T0 path: "no figma-console MCP found".**
Load the `figma-console` MCP in your Claude session (separately —
it's not bundled with this plugin since it's a heavyweight
dependency for users not on the runtime path). With Figma Desktop
open and the target file active, `figma_execute` will then
populate `.cdf-cache/figma/<key>.runtime.json` for the walker.

**Skill loads but `Read` references fail (e.g. shared/ docs not
found).**
This was the empirical question that gated the v1.0.0 ship — see
the project_two_skills_shared_refs memory in the upstream monorepo.
If you hit this, please open an issue at
[`formtrieb/cdf-plugin`](https://github.com/formtrieb/cdf-plugin/issues)
with the failing `Read` path and your CC version.

## Related projects

- [`formtrieb/cdf`](https://github.com/formtrieb/cdf) — CDF v1.0
  spec (Component / Profile / Target / Architecture) + foreign-DS
  validation ports
- [`@formtrieb/cdf-core`](https://www.npmjs.com/package/@formtrieb/cdf-core)
  — TypeScript library: types, parser, validator, resolver, walker,
  renderer
- [`@formtrieb/cdf-mcp`](https://www.npmjs.com/package/@formtrieb/cdf-mcp)
  — MCP server wrapping cdf-core; this plugin's `.mcp.json`
  dependency

## License

Apache-2.0 — see [`LICENSE`](LICENSE).

## Contributing

This plugin is a periodic snapshot from the Formtrieb tooling
monorepo (sync via
[`scripts/sync-cdf-plugin.sh`](https://github.com/formtrieb/cdf-plugin)).
Issues and PRs welcome on
[`formtrieb/cdf-plugin`](https://github.com/formtrieb/cdf-plugin);
non-trivial changes are upstreamed to the monorepo before re-syncing.
