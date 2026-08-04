# Design system & the Claude Design project

**Not applicable to this repo (yet).**

dotsync's only user interface is a **terminal TUI** — the full-screen review-and-apply cockpit. Claude Design produces high-fidelity **HTML** canvases bound to a web design system, which does not map to a text/ANSI terminal surface. So there is no Claude Design project binding here, and no HTML design system to conform to.

What replaces it for the TUI is described in `AGENTS.md` → **Design workflow (the TUI cockpit)**: a new or reworked screen starts as a short **design brief** in [`briefs/`](briefs/) with an **ASCII mockup** standing in for the HTML canvas, is built to that brief, and must degrade to the classic line renderer on non-TTY / `--yes` / `--quiet` / piped / CI. The TUI's colors and glyphs come from the user-overridable `[colors]` / `[icons]` config, not a static token set.

If dotsync ever grows a genuine **web** surface (a docs site UI, a hosted dashboard), restore the full Claude Design binding from the [ai-engineering-template](https://github.com/dsaenztagarro/ai-engineering-template) and record the project ↔ design-system binding here, and capture the adoption as an [ADR](../architecture/decisions/).
