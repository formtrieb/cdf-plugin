# Documentation Surfaces (Rules G + H)

Most DSes carry authored documentation *somewhere* — it just isn't always
where an LLM would look first. Rules G and H exist to keep the Skill
from inferring what the DS author has already written.

- **Rule G:** Documentation-frames are first-class input. Ingest them
  FIRST in Phase 5; author intent beats inferred intent.
- **Rule H:** Before assuming intent/purpose/pattern, check if the DS
  author has documented it. Phase 1 must enumerate all documentation
  surfaces.

This file is the triage matrix + ingestion protocols that operationalize
both rules.

---

## 1 · The five surfaces

| Surface | Primary signal | Typical content |
|---|---|---|
| **DTCG `$description`** | JSON `$description` key on tokens or groups | Intent, deprecation status, usage notes, cross-references |
| **Figma Component Description** | `ComponentSetNode.description` / `ComponentNode.description` | ARIA role, pattern name, 1-line usage, cross-references |
| **Figma Annotations** | sticky-note-like annotations on nodes | A11y notes, tab-order, edge-cases (**not reliably reachable** from `use_figma` Plugin-JS in current runtime — treat as unavailable) |
| **Doc-frames** | `_doc-content` / `_component-docu` / similar named frames containing prose + examples | Focus Strategy, Best Practices, Property semantics, Responsiveness, Do/Don't lists |
| **External docs** | User-pointed URL (Confluence / Notion / Storybook / internal wiki) | Anything — full component guidance, design-team conventions |

## 2 · Triage matrix — Profile vs Component scaffold relevance

| Surface | Profile-Level | Component-Level |
|---|---|---|
| DTCG `$description` on tokens | ★ (intent, deprecation) | — |
| Figma Component Description | ★ (category hints, pattern vocab) | ★★ |
| Figma Annotations | — | ★★ (A11y, tab-order) — but unavailable |
| Doc-frames (`_doc-content`) | ★★ (systemic patterns, focus-strategy) | ★★ (component specifics) |
| External docs | ★ (on request) | ★ |

**★ legend:** ★★ = primary source; ★ = supporting source; — = not
applicable at this level.

The Skill only cares about Profile-level. Component-level ingestion
belongs to `cdf-author`. If the DS has deep component-level docs
(doc-frames per component), capture their *presence* + a sample in
Phase 1; leave detailed ingestion to component-authoring time.

## 3 · Ingestion protocols (per surface)

### 3.1 DTCG `$description`

**Detection:** `$description` keys in DTCG JSON (v2+ convention). Check
both leaf-level (per-token) and group-level.

```json
{
  "color": {
    "controls": {
      "$description": "Interactive-controls grammar; see Profile §3.",
      "brand": {
        "background": {
          "active": {
            "$value": "{color.brand.primary}",
            "$description": "Deprecated alias for enabled; do not use in new components."
          }
        }
      }
    }
  }
}
```

**Ingestion:**
- During Phase 1 `$description` presence-scan: record count + 2–3
  samples. Enough to know whether the DS uses the field.
- During Phase 3 (grammar inference): ingest group-level descriptions
  that explain the grammar's intent. These often name the grammar
  correctly ("interactive-controls grammar"), preventing guess-work.
- Deprecated-alias descriptions feed Cluster A findings directly
  ("§N · 3 tokens marked deprecated in DTCG descriptions; not yet
  removed").

### 3.2 Figma Component Description

**Detection:** `ComponentSetNode.description` and `ComponentNode.description`
properties (available via `use_figma` Plugin-JS as a field, or via
`figma-mcp.get_design_context` which surfaces it in the node payload).

**Ingestion:**
- During Phase 1: record `N of M COMPONENT_SETs have a non-empty
  description.` Seed Cluster-E finding if count < 50%.
- During Phase 5: mine descriptions for pattern-vocab ("this is a
  pressable + selectable"), ARIA-role ("role=menuitemcheckbox"), and
  explicit tab-order / keyboard notes. One-sentence descriptions are
  often load-bearing — don't skim.

**Typical shapes:**

| Description text | What it tells you |
|---|---|
| "Radio-group item; single-select pattern" | Pattern: `selectable` (not tristate); group-context required |
| "Equivalent to native `<button>`; Space + Enter activate" | Pattern: `pressable`; keyboard bindings explicit |
| "Error-validation message; always role=alert" | Pattern: `validation`; ARIA-role explicit |
| "" (empty) | Nothing actionable |

### 3.3 Figma Annotations (unavailable — 2026-04 runtime)

**Status:** `figma.annotations.getAllAsync()` and related APIs throw
"not a function" in the current `use_figma` runtime. This may change;
verify with a minimal test script before writing them off for a new
DS run.

**Fallback:** Component Descriptions + doc-frames carry what annotations
would carry in most DSes. Mark annotations as "unavailable" in
Phase 1 output; seed a Phase-1 note to re-test on skill updates.

### 3.4 Doc-frames (`_doc-content` and friends)

**Detection (two-stage):**

1. **Name pattern match** — look for FRAMEs (not COMPONENTs) named
   `_doc*`, `doc-*`, `docu*`, `description`, `_documentation`.
2. **Composition fallback** — if stage 1 yields nothing, find
   top-level FRAMEs whose children include INSTANCEs of a standalone
   `_doc*` / `_component-docu*` COMPONENT. The frame-name itself
   may be literally `" "` (single space) or duplicate a page name —
   author intent lives in what the frame *contains*, not what it's
   *named*.

**Ingestion protocol:**

- During Phase 1 §1.6: record convention (`_doc-content` vs
  `_component-docu` etc.) + count per COMPONENT_SET.
- During Phase 5 Step 5.1 (**Rule G — FIRST**): read doc-frame content
  for each COMPONENT_SET before doing any pattern inference. Look
  specifically for:
  - "Focus Style" / "Focus Strategy" sections (→ `focus_strategy`)
  - "Best Practices" / "Do / Don't" lists (→ component conventions)
  - "Keyboard" / "Interaction" tables (→ `keyboard_defaults`)
  - Property-semantics prose ("this property controls emphasis")
  - Responsiveness rules ("collapses below 640px")

**Read strategy:** `figma-mcp.get_design_context(nodeId)` on the
frame's ID returns React+Tailwind code + screenshot; for doc-frames
you want the *text content*, not the code. Extract text nodes
specifically via `use_figma` Plugin-JS:

```js
const frame = await figma.getNodeByIdAsync("__FRAME_ID__");
const texts = frame.findAll((n) => n.type === "TEXT")
  .map((n) => ({ id: n.id, name: n.name, chars: n.characters }));
return texts;
```

**Volume discipline:** Large doc-frames can exceed the 20kB payload
cap. Batch per frame; don't try to extract the whole file's doc-frame
content in one call. See phase-1-orient.md Pass-1b/lite strategies
for the general payload-management pattern.

### 3.5 External docs

**Detection:** User-volunteered only. Phase-1 opening checklist has a
🟢-tier slot for this:

```
Any external docs for this DS? (Confluence, Notion, Storybook, a
component gallery, an internal wiki page?) Paste URLs; I'll reference
them where relevant.
```

**Ingestion:**
- Do not fetch URLs without explicit User consent. Confluence / Notion
  URLs almost always require auth; scraping externally-hosted pages
  is a separate consent boundary.
- If the User pastes URLs + wants them used: use `WebFetch` for public
  URLs; ask the User to paste excerpts for auth-gated ones.
- Cite external-doc URLs in the findings-doc for every finding where
  they informed the SoT-recommendation. Without citation the User
  can't audit the reasoning.

## 4 · Rule-G practice — "author intent beats inferred intent"

The one-line version of Rule G: **if a doc-frame tells you how focus
works, write that down. Don't infer.**

**When inference is OK:** no doc-frame exists, no component description
covers it, no external doc was provided. Then the LLM's variant-axis
analysis + utility-component classification is the best we have. Seed
a Finding that the DS has no authored A11y docs; the Skill's output
becomes the first draft.

**When inference is NOT OK:** a doc-frame says "focus lives in the
Focus Ring utility component" and the Skill's variant-axis scan
reports "no focus design." This was the field observation that made
Rule F + Rule G exist. Ingest → then infer. Never the other way.

## 5 · Rule-H practice — "check before assuming"

Rule-H is **a procedural rule for Phase 1**, not an ingestion protocol.
The Phase 1 opening checklist and §1.6 documentation-surfaces survey
exist to operationalize it:

- Every surface's presence is enumerated.
- A surface may be absent — that's fine, seed a Cluster-E finding and
  move on.
- A surface may be present but empty — also fine, same treatment.
- A surface is only **silent** if Phase 1 didn't check.

If Phase 5 is about to declare something about focus-strategy, or
Phase 3 is about to name a grammar, or Phase 2 is about to propose a
decomposition: the corresponding documentation surfaces must have been
surveyed in Phase 1. If they weren't, loop back.

## 6 · Seeding Cluster-E findings

Documentation-surface findings go in Cluster E of the findings-doc.
Common seed shapes:

| Finding | Seed shape |
|---|---|
| Doc-frames absent | "§N · No doc-frames detected; Phase 5 inferences labelled as such. Recommend: DS-team authors doc-frames for at least `focus-strategy` and `keyboard-defaults` sections going forward." |
| Doc-frames partial | "§N · Doc-frames present on 12 of 50 COMPONENT_SETs. The 12 inform Phase-5 classifications; the 38 use inference. Flagged in per-component notes." |
| External docs not provided | "§N · No external docs pointed at during scaffold. DS-team should decide if Profile should cite a DS-wiki URL as the canonical source." |
| DTCG `$description` absent | "§N · No `$description` fields on tokens or groups. Consider adopting for grammar-intent and deprecation tracking." |
| Figma Component Description sparse | "§N · 8 of 50 COMPONENT_SETs carry a description. Recommend: DS-team adopts a minimum 1-sentence description convention." |

Cluster-E findings are often `adopt-as-is` (Profile documents what
the DS has) or `block` (DS-team wants to add authoring conventions
before canonizing). Rarely `accept-as-divergence`.

## 7 · Anti-patterns

- **Preferring inference over author intent** because inference "feels
  more structured." Rule G forbids this.
- **Skipping Phase 1 §1.6** because "the DS probably doesn't have
  docs." Half the Phase-5 corrections in field runs came from doc-
  frame ingestion that the Skill nearly skipped.
- **Treating Component Descriptions as decorative.** A one-sentence
  description often names the pattern + keyboard bindings. Read them.
- **Fetching external URLs without User consent.** Confluence /
  Notion / auth-gated sources need explicit permission. Public doc
  URLs still get a "may I fetch this?" courtesy.
- **Writing doc-frame content as inference.** When a finding is
  sourced from a doc-frame, cite it: "per doc-frame `_doc-content`
  on Button (id 123:456)."
