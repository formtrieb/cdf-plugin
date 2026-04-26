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
| **Figma access (T1 — REST)** | `FIGMA_PAT` env var **or** per-call `pat:` arg (scope: **File content — Read** minimum) — see [Figma PAT section below](#figma-personal-access-token-pat) for the full how-to | — |
| **Figma access (T0 — runtime)** | `figma-console` MCP loaded + Figma Desktop with file open | — |
| **Figma access (T2 — Variables)** | T1 PAT + Enterprise plan permissions for `GET /v1/files/{key}/variables` | — |
| **Tokens regime** | — | DS-specific tokens MCP (e.g. `tokens-studio`) for `tokens-studio` regime |
| **Inheritance** | — | Parent CDF Profile via `extends:` (single-level only per CDF v1.0) |

The skill auto-detects the Figma tier (T0 / T1 / T2) — see
`skills/cdf-profile-snapshot/SKILL.md` §1.4 for the audience-fit
table; the same table appears in
`skills/cdf-profile-scaffold/SKILL.md` §0.

## Figma Personal Access Token (PAT)

The **T1 (REST)** path is the recommended setup for engineers — it's
fast (~3 s walker pass on a mature DS) and doesn't require Figma
Desktop to be running. It needs a Figma Personal Access Token.

### 1. Create a PAT

Go to <https://www.figma.com/settings> → **Personal access tokens**
→ *Generate new token*. The dialog asks you to scope each capability;
for the cdf plugin you need:

| Scope | Required for | Notes |
|---|---|---|
| **File content — Read** | `cdf_fetch_figma_file`, `cdf_extract_figma_file` (`source: "rest"`) | Minimum scope. The vast majority of users only need this. |
| **Variables — Read** | `cdf_resolve_figma_variables` (T2 path) | Enterprise plan only — non-Enterprise tokens silently get `null` from this endpoint. |
| Comments / Webhooks / etc. | — | Leave **No access** — the cdf plugin doesn't use them. |

The token format is `figd_…` followed by ~40 characters. Copy it
**immediately after creation** — Figma won't show it again. If you
lose it, regenerate.

### 2. Provide the PAT to the plugin

> [!IMPORTANT]
> **A `.env` file in your project dir is NOT auto-loaded** by Claude
> Code or by the MCP launcher. If you've put `FIGMA_PAT=...` into a
> `.env` and expected it to "just work" — that's why the first
> `cdf_fetch_figma_file` call fails. `.env` files only work if you
> explicitly source them before launching `claude` (see Option C
> below).

The cdf-mcp tools resolve the PAT in this order:
**`pat:` arg → `FIGMA_PAT` env var → actionable error.** The
question for you is *where* `FIGMA_PAT` ends up in the env that
cdf-mcp runs with.

The plugin's bundled `.mcp.json` already declares the passthrough:

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

`${FIGMA_PAT}` interpolates from the **shell environment that
launched Claude Code**, not from any `.env` file in your project.
So the goal of every option below is "make sure `FIGMA_PAT` is in
the shell env when you run `claude`."

#### Option A — Shell rc (recommended for daily use)

Add the PAT to your shell rc so every new terminal — and every
Claude Code session launched from it — inherits it.

```bash
# ~/.zshrc (or ~/.bashrc for bash)
export FIGMA_PAT="figd_YOUR_TOKEN_HERE"
```

Apply + verify + restart CC:

```bash
source ~/.zshrc                      # apply in current terminal
echo $FIGMA_PAT | cut -c1-5          # expect: figd_
# Fully quit Claude Code (Cmd+Q on macOS — closing the window is
# not enough), then relaunch from a terminal that has the new env.
```

#### Option B — Per-call `pat:` argument (multi-account / one-off)

If you don't want a long-lived token in your shell rc — for example,
you work across multiple Figma accounts and want a different PAT
per file — skip the shell-env step and pass the PAT inline when
invoking the skill. Inside a Claude Code session:

> Run `cdf_fetch_figma_file` against
> `https://figma.com/design/abc123XYZ/My-DS` with
> `pat: "figd_YOUR_TOKEN_HERE"`.

The skill threads the arg through to the tool call. The arg-form
**overrides** any `FIGMA_PAT` env var, so you can keep a default
token in the shell and override per-run when needed.

#### Option C — `.env` file in the DS dir (project-scoped)

`.env` files don't auto-load — but they're a clean way to keep one
PAT per project as long as you remember to source the file before
launching CC.

```bash
# <ds-repo>/.env  (DO NOT commit — add .env to .gitignore)
FIGMA_PAT=figd_YOUR_TOKEN_HERE
```

Launch CC like this every time:

```bash
cd <ds-repo>
set -a && source .env && set +a     # exports each KEY=VALUE pair
claude                                # CC inherits FIGMA_PAT
```

`set -a` makes every variable set in the next commands automatically
exported; `set +a` turns it off again. Without it, `source .env`
only sets the var inside the current process, not its children.

You can wrap this in a shell function if you launch CC frequently
from this dir:

```bash
# add to ~/.zshrc
cdf-launch() {
  ( set -a && source .env && set +a && claude "$@" )
}
# usage:  cd <ds-repo> && cdf-launch
```

#### Option D — Override the plugin's MCP config (project-pinned PAT)

If you want a project-pinned PAT *without* relying on shell env
sourcing, add a project-level `.mcp.json` with the PAT hardcoded.
This **overrides** the plugin's `.mcp.json` for this project:

```json
{
  "mcpServers": {
    "cdf-mcp": {
      "command": "npx",
      "args": ["-y", "@formtrieb/cdf-mcp@^1.7.2"],
      "env": {
        "FIGMA_PAT": "figd_YOUR_TOKEN_HERE"
      }
    }
  }
}
```

Save as `<ds-repo>/.mcp.json`, restart CC, done. This is the
"standard MCP config" pattern familiar from Claude Desktop's
`claude_desktop_config.json`. The trade-off is that the PAT lives
in a project file — make sure `.mcp.json` is gitignored (or use
`${FIGMA_PAT}` interpolation here too and keep the actual token in
the shell). Use this when shell-rc is awkward (shared dev machine,
sandboxed env) and per-call args feel repetitive.

### 3. Verify the PAT reached cdf-mcp

Two layers can fail independently — the var being set in your
shell, and the var being inherited by the MCP server. Check both:

```bash
# Layer 1 — is the PAT in the shell that launched CC?
echo $FIGMA_PAT | cut -c1-5      # expect: figd_

# Layer 2 — is the MCP server connected?
claude mcp list | grep cdf-mcp   # expect: ✓ Connected
```

If Layer 1 shows `figd_` but Layer 2 shows `✗ Failed to connect`,
fully quit CC (Cmd+Q) and relaunch — the MCP launcher only reads
env at launch time. If Layer 2 shows `✓ Connected` but tool calls
still error with auth, the PAT is wrong (scope, account, or
expiry — see below).

Then inside a Claude Code session in your DS dir:

> Run `cdf_fetch_figma_file({ file_key: "abc123XYZ" })` against my
> Figma file. (Substitute `abc123XYZ` with the file key from your
> Figma URL — the segment between `/design/` and the next slash.)

Expect a JSON response with `cached: false` on first call (REST
fetch) and `cached: true` on subsequent calls within the same DS
dir (read from `.cdf-cache/figma/<file_key>.json`).

If you get `Forbidden` or `Unauthorized`:

- The PAT scope is wrong — regenerate with **File content — Read**.
- The PAT is for an account that doesn't have access to the file —
  open the file in Figma to confirm the account.
- The PAT expired — Figma PATs don't expire by default, but if you
  set an expiry on creation, regenerate.

If you get `FIGMA_PAT not set` despite having it in your shell —
the MCP launcher didn't inherit it. Most common cause: CC was
already running when you set the var. Quit + relaunch.

### 4. Security notes

- **Never commit the PAT to git.** Add `.env` to `.gitignore` if
  using Option C. Treat the token like a password.
- **Revoke unused tokens** at <https://www.figma.com/settings>
  (same page where you created it) — each token shows last-used
  timestamp.
- **One PAT per use case.** If you set up CI that uses cdf-mcp,
  generate a separate CI-only PAT so you can revoke it without
  breaking your local setup.
- **Enterprise Variables access** uses the same PAT but requires
  the Enterprise plan + the **Variables — Read** scope. Without
  Enterprise, `cdf_resolve_figma_variables` falls back to the T1
  REST file's partial Variables data (which is enough for most
  scaffold passes).

### Falling back to T0 (no PAT)

If you can't or don't want to manage a PAT — for example, you're
evaluating CDF on a file you only have read-access to via the Figma
Desktop app — the T0 path works without auth. It requires the
[`figma-console`](https://github.com/figma/figma-console-mcp)
MCP loaded in your Claude session and Figma Desktop with the target
file open. See `skills/cdf-profile-snapshot/SKILL.md` §1.4 for the
T0 setup; performance is slower (~30–45 s walker pass on a mature
DS, vs ~3 s for T1) but the output is shape-equivalent.

## Quickstart

```bash
# 1. Install the plugin (two-step — see "Install" above)
claude plugin marketplace add formtrieb/cdf-plugin
claude plugin install cdf@cdf

# 2. (T1 path — recommended) Set your Figma PAT in the shell, then
#    fully quit + relaunch Claude Code so the MCP launcher inherits it.
#    See the "Figma Personal Access Token (PAT)" section below for
#    creation steps + scope requirements + alternative delivery methods.
export FIGMA_PAT="figd_YOUR_TOKEN_HERE"

# 3. cd into your design-system repo (or any dir where you want
#    the Profile artefacts to land)
cd ~/code/my-design-system

# 4. Optional — seed a .cdf.config.yaml so the skill knows your
#    Figma file and token-source regime up-front (see
#    https://github.com/formtrieb/cdf#cdfconfigyaml-schema for shape).
#    Note: leave `profile_path` commented out on first run — the
#    scaffold writes the profile YAML mid-run and will set this line
#    for you. Uncommenting before the file exists used to crash the
#    MCP server (fixed in @formtrieb/cdf-core@1.0.3 + cdf plugin
#    v1.0.2; warning still logged to be safe).
cat > .cdf.config.yaml <<'EOF'
# profile_path: ./my-ds.profile.yaml   # uncomment after first scaffold run
token_sources: [./tokens/]
scaffold:
  ds_name: my-ds
  figma:
    file_url: https://figma.com/design/<KEY>/My-DS
  token_source:
    regime: tokens-studio   # or dtcg-folder | figma-variables | figma-styles | enterprise-rest | none
    path: ./tokens/
EOF

# 5. Launch Claude Code in this dir, then invoke a skill.
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
