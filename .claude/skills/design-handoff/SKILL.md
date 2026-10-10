---
name: design-handoff
description: The Claude Design handoff loop — which repository is which, how a design repository is laid out, the three routes into the design project, writing a brief, reading an export back, and closing a brief out. Use when creating or reviewing a design repository, writing a design brief, handing work to Claude Design, reading an export back into the design repository, or building a surface from a design page.
---

# Working with Claude Design: the handoff loop

How a design change gets from an idea to something this application renders, and what an agent may and may not touch on the way.
This is an operating procedure — the order matters, and two of its steps exist to stop a class of silent loss.

If this project has no user interface, delete this skill and the design row of `AGENTS.md`.

## 1. Three names, and which one you are in

| | what it is | you may edit it |
|---|---|---|
| **`dotsync`** (this repository) | the application — code, tests and decision records | yes |
| **`dotsync-ds`** (the design repository) | the briefs, the pages Claude Design returns, a mirror of the design project's export, and the generator for the one artefact that crosses | the briefs and what the repository authors — yes; the export mirror, never (§3) |
| **`dotsync-ds`**, the Claude Design project | where pages, components and specimens are drawn | through the three routes in §2, never directly |
| **`cli-ds`** (the shared terminal design system) | the widgets, glyphs, spacing and base palette every terminal client shares, vendored into `dotsync-ds/vendor/cli-ds/` | only in its own repository; a request for a shared widget is a brief there |

**A design project is named for the codebase it draws for** — `dotsync-ds` beside `dotsync` — so the name says which checkout its export syncs into.
A design system shared by several projects is named for its brand or the package that ships it, never for its platform: a `web-ds` points at no repository, and stops being true the day a second web system exists.

**Every design repository has one layout**, whether it holds a product's design or a shared design system: [`layout.md`](layout.md) states it folder by folder. Read it before adding a folder to one; create one with the `design-repo` skill.

The design repository and the design project share a name. Say *repository* or *project*: the difference decides whether an edit survives.

Design content lives outside this repository because it grows without bound, and an application repository carrying it stops being code — one terminal client's pages reached 920 KB before they were moved out.

## 2. What crosses, and by which route

**Exactly one generated artefact reaches this application**, and it is data — a token set, or a stylesheet bundle.
For dotsync it is `dotsync-ds/dist/tokens.toml`, mirrored to `design/tokens.toml` here. The cockpit does not read it yet: its colours are hand-written, and the per-user `[colors]` and `[icons]` overrides in a dotsync config win over any token.
A page is read by a person designing or building a surface; it is never a build input, and code never cites one.

The design project holds its own files and nothing else — it cannot open either repository. Everything it knows arrives by one of three routes, each started by a person:

| route | carries | lifetime |
|---|---|---|
| **a brief**, pasted into the project | one ask | spent on arrival; deleted when its surface ships (§8) |
| **`/design-sync`**, from Claude Code | named files, under a plan the person approves | until overwritten |
| **the export**, downloaded as a zip | the whole project, back to the design repository | a commit of the mirror |

`/design-sync` needs a claude.ai login in Claude Code, and is unavailable on Bedrock, Vertex and Foundry. It writes one change at a time, never as a wholesale replace.
It never writes `CLAUDE.md` or `.claude/`, which instruct the design agent: a repository that authors its system pushes `AGENTS.md` alone and commits no `CLAUDE.md` beside it, and only a project that authors its own files can create the import.

- **A rule that must hold for every future export goes into the project's own `readme.md` through `/design-sync`**, which the project reads before it draws. Pasted into a brief, the same rule dies with the brief.
- **The project's agent context holds principles, never decisions about particular elements.** A principle — shape names the field, colour flags attention, absence is calm — holds for elements not drawn yet. A decision about one chip or one column is drawn in its page, and changes without the agent context changing; written into it, the decision becomes a second copy of the page that drifts, and the file grows with the elements instead of with the product's ideas. A ruling that is a principle amends the agent context; a ruling about one element is drawn in that element's page. An index that only names what exists — components, pages, tokens — is not a decision, and stays: it carries no rule to drift.
- **The mirror is refreshed only through the export** and the design repository's sync script, whose refusals — an export that is not a design system's, a file the repository owns that the project edited — are the review gate.

## 3. The export mirror is generated — never hand-edit it

The sync script mirrors the export with `rsync -a --delete`. A hand-edit there is destroyed by the next sync, silently, and it makes the record lie: the mirror is committed so its diff shows what Design produced.
Commit the mirror as produced, defects included, with what you found named in the commit message — and fix it through a brief.

If the design repository authors a file the project draws against — a checked palette — that file flows **up** through `/design-sync`, and the sync script refuses an export that disagrees with it.

## 4. A page draws the surface, never the application

The application keeps changing; a drawn page changes only when someone redraws it.
A sentence on a page about how the application behaves is true the day it is drawn and drifts after, nothing checks it, and the next reader building from the page takes it as current.

- **A page shows a surface in every state it can be in** — empty, loading, error, long data; read, edit and create where they apply. The states share one page, one panel each, and a state switcher on the page reaches every one of them; nothing shows two states at once. Each state is named in two or three words, and that name is the switcher's label — the page carries no other caption.
- **Interaction belongs on the page; the business does not.** A prototype may animate a drawer opening, a row expanding, a toast arriving — that is the surface. Validations, save rules, time windows, who may write what and the data model belong to the application, stated by its tests and decision records.
- **The test for a sentence on a page: could someone open the running application and find it false?** Then it comes out.
- **The design project keeps no decision log, rulings page or behaviour hand-off.** Each is a second copy of an application record, and drifts from it.
- **A behaviour question raised by drawing goes back as a question.** It is drawn and labelled as open, never settled on the page, and answered here (§7).
- **A state that needs a paragraph to be understood is a missing state.** Draw it.
- **Sweeping claims out of a page removes sentences, never drawings.** An artboard asserts nothing about the application; one that goes out with the prose around it is a defect, sent back through a brief.
- **A component's example page is a page too.** It shows the component in each case it has, as states, and nothing else. Each of its rules has one home: the shared system's component file once it has landed there, which is where most of them already are; the comment beside the class for a difference only this product has; a request to the shared system when every product should follow it. Options weighed, research and rollout sweeps belong in the design chat and the tracker. Keeping a page does not exempt it from this rule.

**This rule goes into the design project's own `readme.md` through `/design-sync`** when the project is created: it must hold in every export, and a rule pasted into a brief dies with the brief (§2).

## 5. A component the shared design system lacks: one stand-in, landed by deletion

Only where a shared design system is vendored (§1).
When the project's pages need a component that system does not ship, the project draws it once, in its own leaf, under a `STAND-IN — delete when the design system lands <Component>` marker, and writes a brief in the **shared system's repository**, `briefs/proposed/<component>.brief.md`, carrying the same rules and class names, byte for byte. The application writes those classes from the start.

- **Byte-identical is the point.** When the component lands, the stand-in is deleted and no markup changes; a stand-in that drifted from its brief turns landing into a migration.
- **The request lives with the system that will draw it.** One brief per component, attached to the shared system's project one at a time, and deleted once it lands.
- **Delete the stand-in only against a snapshot that carries the component.** Removed against a stale copy of the shared system, the surface loses its styling and nothing fails.

### The project's copy of the shared system, and how it stays current

A product's design project draws every page against `_ds/<id>/`, **its own copy** of the shared system, frozen at the moment it was copied.
The copy does not follow the shared system: a request that lands there reaches this project only when **the project refreshes its copy**, and nothing does that for it. The export carries whatever copy the project holds, so a sync cannot fix a stale one.

**Whether the copy is current is read from the manifests Claude Design writes**, never from a file someone keeps by hand. The shared system's `_ds_manifest.json` and the copy's each list the tokens and components they carry, and Claude Design rewrites both on every export, so neither can fall behind what it describes.

- **`bin/ds-status`** in the product's design repository compares `pages/_ds/<id>/_ds_manifest.json` with the shared system's `system/_ds_manifest.json`, and names every token and component the copy lacks, and every token whose value moved. It sees names and values, not a component whose files changed under the same name.
- **The landing, in order** — skipping the second step is how a landed component goes on reading as missing:
  1. the request lands in the shared system's project, and its repository syncs the export;
  2. the product's project refreshes its copy, and its repository syncs that export;
  3. `bin/ds-status` reports the copy current;
  4. the stand-in the landing retires is deleted.
- **A stale copy is refreshed first** — never a reason to re-send a request, never a copy to compare a page against.
- **What landed when is history**, on the tracker; the manifests hold only what each side carries now.

**Rejected: a receipt kept by hand** — landed requests and a date stamp. It is correct only while every export remembers to update it; the manifests are rewritten by Claude Design every time.

## 6. The loop

```
  a brief in dotsync-ds/briefs/proposed/
        |
        v
  pasted into the design project                  <- a person
        |
        v
  the project draws it; export downloaded         <- a person
        |
        v
  in dotsync-ds: sync, regenerate, run the suite
        |
        v
  review the sync diff: a rule changed or only a comment?
  every changed page well-formed? a removal that orphaned a heading?
  a drawing gone with the prose around it?
        |
        v
  commit the mirror, as produced; a defect becomes a new brief
        |
        v
  in this repository: vendor the artefact
        |
        v
  build the surface against the page; tests hold the behaviour
        |
        v
  close out the brief it satisfied                brief-closer
```

**The last step is the one that gets skipped**, because nothing fails when it is.

## 7. Writing a brief

1. **State the constraint; do not cite the artefact.** A decision's ruling is written out as a sentence, with its theme named beside it. A link out of the design repository resolves to nothing at the far end.
2. **Every proper noun must resolve inside the design project.** Pages, components, tokens — yes. File paths, commands, frameworks, issue numbers — no.
3. **A brief never cites another brief.** Each is deleted on its own schedule.
4. **A technical decision belongs in a decision record here, not in the design.** The brief asks Design to *depict* a ruling, never to make it. A behaviour the page must show that nothing has settled is drawn and labelled as an **open question**, never as a rule.

## 8. Closing a brief out

A brief ends when its surface ships here, so the ticket that ships a surface carries a checkbox to delete its brief. Before the deletion: verify each ask in the design project's export, re-point everything that cited the brief, rewrite future-tense prose about it, and close the tracking issue.

A brief whose asks all landed closes. One where some did not stays, with the remainder reported. One that got what it asked for while the doing broke something else closes, and owes a follow-up brief. The **`brief-closer`** agent does this, and verifies before it deletes.

### Before a reshape, triage the queue

A reshape — a sweep or redraw across many pages of the design project — starts only once every open brief has been checked against the current export. A brief is written against the pages as they stood; a reshape that moves them leaves each one describing a page that no longer exists, and nobody notices until someone pastes it. So, for every brief in `briefs/proposed/`, before the reshape is asked for:

- **landed** — delete it;
- **outdated** — its premise is gone: delete it, or rewrite it against the current pages;
- **in the wrong repository** — it changes a shared component: move it to the shared system's `briefs/proposed/`, rewritten for that project;
- **still open** — carry it into the reshape's brief, or keep it and check it again once the reshape's export lands.

A long queue is the signal to triage, not to reshape: the reshape waits until the queue holds only briefs that will survive it.

## 9. What an agent must not do

- **Edit the export mirror**, or the vendored artefact here.
- **Style anything outside the vendored artefact** — a colour, a spacing, a component the design system does not ship. The fix is a brief, not a local rule.
- **Cite a brief or a design page from code.** Cite the decision record for *why* and the test for *what*.
- **Answer a behaviour question on a page.** Behaviour is decided here, in a test.
- **Start a route that §2 says a person starts.**
