# Designs — the Claude Design workflow

This folder is the **visual source of truth** for the project's UI, and the front of the delivery pipeline. UI is not hand-built ad hoc: it is **designed first with Claude Design**, then implemented against that design. `AGENTS.md` enforces this.

## The pipeline

```
bound project           brief (markdown)        Claude Design            design canvas            /epic skill
Claude Design project ─▶ docs/designs/briefs/ ─▶ generates a high-  ─▶ docs/designs/*.html   ─▶  decomposes the canvas
+ design system          proposed/*.brief.md     fidelity UI canvas     (self-contained,          into phased tickets,
(DESIGN-SYSTEM.md)                                in the bound project   the visual truth)         built & verified to match
```

0. **Bind a project to the design system.** All designs are generated in a **Claude Design project** attached to this repo's **design system**, so they inherit its components by construction. Record the binding once in [`DESIGN-SYSTEM.md`](DESIGN-SYSTEM.md).
1. **Brief.** Describe the surface, its states, and the intent in `briefs/proposed/<name>.brief.md` (see [`briefs/README.md`](briefs/README.md)). A brief is short — it's a prompt for the design, not a spec.
2. **Canvas.** Use **Claude Design** to turn the brief into a **high-fidelity, self-contained HTML design canvas** in this folder, rendered against the project's design system (tokens, components, typography). The canvas is what "done" looks like.
3. **Build to it.** `/epic` (or a normal ticket) implements the canvas. `AGENTS.md`'s design rules require matching it exactly — no colors, spacing, radii, or components outside the token set — and every interactive workflow the canvas shows gets a test (**design fidelity is verified, not assumed**).
4. **Promote.** When the surface ships, move its brief `proposed/ → shipped/`. A design decision worth keeping (a pattern, a contract) becomes an ADR.

## What Claude Design is, in this workflow

**Claude Design** is the step that *produces the design*: given a brief and a design system, it generates a polished, reviewable UI canvas as self-contained HTML you can open in a browser. In this template it plays one role — it makes the **visual source of truth** that the rest of the pipeline (`AGENTS.md` enforcement + `/epic` implementation) builds against. Without it, "build the UI" has no reference and fidelity can't be verified; with it, the design is an artifact in the repo, versioned alongside the code that implements it.

## The design system

The design system — and the Claude Design project bound to it — is recorded in [`DESIGN-SYSTEM.md`](DESIGN-SYSTEM.md). That binding is what makes generated canvases consistent by construction: they render against the system's components and tokens, and implementations must use those tokens, never hardcoded values. Set it up once per project there.

## Conventions

- **Canvases are self-contained** `*.html` (inline everything) so they open with no build step and render identically for any reviewer.
- **ASCII diagrams** in the accompanying markdown, per the repo documentation style.
- Keep **one canvas per surface**; keep the brief next to it in `briefs/`.
- If this project has **no UI**, delete this folder and the design section of `AGENTS.md`; the `/epic` skill still works on markdown backend designs.
