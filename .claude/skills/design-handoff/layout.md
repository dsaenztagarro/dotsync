# How a design repository is organised

Every design repository has the same layout, whatever it designs and whichever Claude Design project type it mirrors.
A folder means the same thing in each one, so an agent that has worked in one can find its way around any other without reading the README first.
Read this file before creating a design repository, adding a folder to one, or reviewing one; the `design-repo` skill creates one in this layout from its skeleton.

## Two kinds, one layout

| kind | what it designs | its Claude Design project | who consumes what it generates |
|---|---|---|---|
| **a product's design** — `<project>-ds` | one application's own surfaces | a **Project**: pages, plus a `_ds/` snapshot of the design system it is bound to | that application |
| **a shared design system** — `<brand>-ds` | what every application in a family shares: components, tokens, patterns | a **Design System**: `components/`, `tokens/`, `guidelines/`, `docs/`, `assets/` | each product design, and each application in the family |

A product may also own a Design System project of its own, when it extends a shared system with tokens or components only it uses. It then has both `pages/` and `system/`.

**The project type decides only which folder an export lands in**: a Project export in `pages/`, a Design System export in `system/`. It never decides what a folder is called or what else the repository holds.

## Names

- **The repository, the Claude Design project, the generated bundle and its cascade layer all take one name.** A product's is `<project>-ds`, beside the application `<project>`; a shared system's is `<brand>-ds`, named for its brand or the package that ships it.
- **Never a platform name** (`web-ds`): it points at no repository, and stops being true the day a second system for the same platform exists.
- **Never a folder named after the repository** inside it (`engineer-ds/engineer-ds/`). The export folder is `pages/` or `system/`.
- **A Claude Design project that is renamed takes its old name with it.** Every document saying the old name means the new owner of that name from then on; date a reference before trusting it, and rewrite the ones you touch.

## The tree

```
<name>-ds/
+-- README.md               what this repository is, the tree below filled in, the commands
+-- AGENTS.md               the rules an agent working here needs; CLAUDE.md is `@AGENTS.md`
+-- CLAUDE.md
+-- Rakefile                `rake` is the gate: every check, then the tests
+-- .gitignore              tmp/, .DS_Store, .claude/worktrees/
+-- .github/workflows/      the gate, weekly on the default branch and by hand
+-- briefs/
|   +-- README.md           what belongs here, the lifecycle, how to write one
|   +-- proposed/           <topic>.brief.md, one per open request
+-- pages/                  a Project export, mirrored                     (product)
|   +-- _ds/<project-id>/   the design-system snapshot the pages render against, committed
+-- system/                 a Design System export, mirrored; or authored and pushed up
+-- references/             hand-authored material the projects draw on; never touched by bin/sync
+-- vendor/<shared>-ds/     the shared system's build inputs, copied whole  (when the generator needs them)
+-- docs/                   the contract the generated artefact keeps, one file per theme
+-- lib/                    the generators
+-- test/                   the generators' tests and bin/sync's
+-- dist/                   the generated artefacts that cross, committed
+-- bin/
|   +-- sync                mirror a fresh export
|   +-- ds-status           whether pages/_ds/ carries what the shared system does   (product)
|   +-- vendor-sync         refresh vendor/ from the shared system's checkout
+-- .design-sync/           config.json and NOTES.md, when files are pushed up with /design-sync
+-- .claude/skills/         skills that only make sense here, such as the contract's
```

A folder that does not apply is absent, never empty. A folder not in this tree is not added without amending this file first.

**`test/layout_test.rb` holds a repository to this layout** in its own `rake`: the closed rules below — the root's entries, no symlinks, nothing in an export ignored, how briefs and vendored systems are named, `CLAUDE.md` as an import, scratch kept untracked. Every design repository carries a copy of it, taken from the `design-repo` skill's skeleton and refreshed from there, never edited in place.

## Folder by folder

### `briefs/`

The requests made **to this repository's Claude Design project**, and nothing else.

- A product's `briefs/` asks its own project for surfaces; a shared system's asks for what every application shares.
- **A request belongs to the repository whose project will draw it.** A product that needs a shared component writes the brief in the shared system's `briefs/proposed/`, not its own, and not inside its project.
- One self-contained `<topic>.brief.md` per request. A request that carries code — a component's complete files — is still a brief.
- Deleted once what it asked for has landed and its durable half has a home elsewhere (the `brief-closer` agent and §8 of the skill). `git log --diff-filter=D -- briefs/` finds one again.
- `briefs/README.md` states what belongs here, the lifecycle and the writing rules, in the words of this repository.

### `pages/` — a Project export

- **A mirror.** `bin/sync` writes it with `rsync -a --delete`; nobody edits it by hand, and it is committed as produced, defects included.
- **`pages/_ds/<project-id>/` is committed.** It is the snapshot of the shared system the pages were drawn and render against, as the export carries it. A page must render the same on any clone, so it is never a symlink to a local checkout of the shared system, and never git-ignored.
- **`bin/ds-status` says whether that snapshot is current**, by comparing its `_ds_manifest.json` with the shared system's; `design-handoff` §5 has how the copy is refreshed.
- The snapshot is not a second source: the shared system's repository is. A diff between `pages/_ds/<project-id>/` and the shared system's `system/` shows how far behind it is.
- What a page may hold is ruled in §4 of the skill: the surface, never the application.

### `system/` — a Design System project

Two directions, and the README says which path goes which way:

- **Downstream** — drawn in the project, exported, mirrored by `bin/sync`. A hand edit is reverted by the next sync.
- **Upstream** — authored here, checked by `rake`, pushed to the project with `/design-sync` (a palette, a component tier, the project's own `readme.md`). `bin/sync` **refuses an export that disagrees** with an upstream file, because `--delete` would otherwise overwrite the only copy the checks ran against.

### `references/`

Hand-authored material the projects draw on and the generators do not read: cross-application references, explorations kept on purpose, a component tier stated as data. Never touched by `bin/sync`.

### `vendor/<shared>-ds/`

What the **generator** needs from the shared system — its generator code, its base palette, its component tier — copied whole by `bin/vendor-sync` and committed, so `rake` runs on a clone with nothing else checked out.
It is not the rendering snapshot (that is `pages/_ds/`), and it is absent when the generator needs nothing from the shared system.

### `dist/`

The generated artefacts that cross into applications — a stylesheet bundle, a token file. **Committed**, and `rake` fails when they disagree with their sources, which is what makes *generated, not copied* true.
A product's bundle is wrapped in its own cascade layer, declared after the shared system's.

### `docs/`

The contract the generated artefact keeps — what each field carries and why it is computed here. One file per theme, never one per change, component or request.

### `lib/` and `test/`

The generators, and their tests. `test/` also holds `bin/sync`'s tests, each running a copy of the script in a throwaway checkout: what a clean export mirrors, and each export it refuses.

### `bin/`

- **`sync`** mirrors a fresh export. Its refusals are the review gate, and each has a test:
  - an export of the wrong kind or the wrong project — a consuming product's export into a shared system, a namespace that is not this repository's;
  - an export that disagrees with a file this repository authors upstream;
  - a page that is not one canonical prototype per surface — a versioned copy, an audit, a rationale or an options page.
- It stages into a git-ignored `tmp/`, deletes only inside the checkout, mirrors, reports what changed, and leaves committing to a person.
- **`ds-status`**, in a product's repository, compares the `_ds/` snapshot's manifest with the shared system's, and exits 1 when the snapshot lacks a token or component the shared system carries.
- **`vendor-sync`** refreshes `vendor/` from a checkout of the shared system.

### `.design-sync/`

`config.json` pins the Claude Design project's id, the bundle's namespace and the repository's shape; `NOTES.md` records what a future `/design-sync` must know about this repository. Present only where files are pushed up.

### Root files

- **`README.md`** opens with what the repository is and who consumes it, then the tree above with this repository's folders filled in, then the commands.
- **`AGENTS.md`** holds the rules an agent needs here and nowhere else — which files flow which way, what the generator guarantees; `CLAUDE.md` is the one line `@AGENTS.md`. The application's own rules stay in the application's `AGENTS.md`, linked.
- **`Rakefile`**: `rake` runs every check, then the tests, and is the gate before every merge. CI runs the same `rake`, weekly and by hand; the local run is what guards a merge.

## What is never in a design repository

- **The application's behaviour** — validations, save rules, the data model. Tests in the application hold it.
- **The reasoning behind an application decision.** The application's decision records hold it; a brief states the ruling in a sentence.
- **A symlink into another checkout.** What a clone renders, builds or tests must come from that clone.
- **A copy of another design repository's pages** — a terminal client's mockups inside a web product's repository. Each design has one repository.
- **A file per work item** — a spec per feature, a log per sync, an archive of shipped briefs.
