---
description: Snapshot a CDF Profile for first-touch DS evaluation (5–10 min, with blind-spots + upgrade path)
argument-hint: "[optional context — DS name, Figma URL, …]"
---

Load and follow the `cdf-profile-snapshot` skill.

**User-provided context:** $ARGUMENTS

**Behavior:**

1. `Read ../skills/cdf-profile-snapshot/SKILL.md` first — that file
   carries the audience contract, source-discovery setup, the §1.4
   audience-fit table (T0/T1/T2 paths), and the §3 Discovery → Commit
   handoff prompt verbatim.
2. If `$ARGUMENTS` is empty, present the §1 source-discovery opening
   from the shared checklist. Tone: advisor, not gatekeeper.
3. If `$ARGUMENTS` contains context, parse it for 🔴 required fields
   (DS name, Figma URL). Acknowledge what's present; ask only for gaps.
4. The Snapshot is a single-pass synthesis — Rule A (Survey First)
   applies from the very first tool-call. No autopilot mode (see §3
   "No autopilot" clause): if no User is reachable, halt before the
   handoff branch instead of silently auto-deciding.

The Snapshot is intentionally draft-grade: classification, validator
runs, and vocab-isolation belong to `/scaffold-profile` (the
production-grade sibling skill). The §3 handoff offers the upgrade
path once the sketch is on disk.
