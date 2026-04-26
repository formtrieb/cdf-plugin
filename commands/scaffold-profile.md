---
description: Scaffold a CDF Profile for a design system (Figma + tokens → profile.yaml + findings.md)
argument-hint: "[optional context — DS name, Figma URL, token path, …]"
---

Load and follow the `cdf-profile-scaffold` skill.

**User-provided context:** $ARGUMENTS

**Behavior:**

1. If `$ARGUMENTS` is empty, present the Phase-1 three-tier opening checklist
   (🔴/🟡/🟢) from `SKILL.md §1.3`. Tone: advisor, not gatekeeper.
2. If `$ARGUMENTS` contains context, parse it for 🔴 required fields
   (DS name, Figma URL) + 🟡 quality-critical (token-source regime) +
   🟢 nice-to-have (DS-specific MCP, doc-frame convention). Acknowledge
   what's present; ask only for gaps.
3. Before Phase 1 begins, run the Phase-0 resume/refresh/fresh check against
   `.cdf.config.yaml` in the current working directory (SKILL.md §1.2).
4. Once prerequisites are satisfied, `Read
   ../skills/cdf-profile-scaffold/references/phases/phase-1-orient.md`
   and execute Phase 1.

Do not skip the opening checklist even when all 🔴 + 🟡 fields are parsed
from `$ARGUMENTS` — echo back what was understood and confirm with the
User before source-inspection begins. Rule A (Survey First) applies from
the very first tool-call.
