# Config resolution

*How dotsync turns a config path into a validated, direction-specific mapping list — and how it knows which files on disk it read.* Complementary to [ADR 0002](decisions/0002-rewrite-in-go-as-a-single-binary.md), which records the choice of TOML parsed to a dynamic tree; this records how the pipeline behaves today.

## The mental model

Resolution is **lossy on purpose**. `source` is replaced by the tree it points at and `include` is consumed by the deep-merge, so the tree that reaches the rest of the program has no memory of the files that produced it. That is the right shape for a merged configuration — but the run still needs to name those files, because under `source` the path dotsync was pointed at is the one file nobody edits, and because a mapping can be pointed at a config file. `Provenance` is the small record carried alongside the tree to keep that knowledge.

The second idea: **a configuration can be both an input to a run and a payload of it.** The mappings that decide what gets copied are themselves copyable. dotsync reports that rather than refusing it.

## How it works

```
  path ──> parseTOMLFile ──> normalizeMap
                │
                v
         has "source"? ──yes──> resolveSource ──> parse the sourced file
                │                                        │
                no                                       v
                │                                 (include base dir is the
                v                                  SOURCED file's directory)
         resolveInclude <───────────────────────────────┘
                │
                v
         deepMerge(base, overlay) ──> map[string]any  +  Provenance
                                            │
                                            v
                                    Config.validate()
                                            │
                                            v
                                   Config.Mappings() ──> []*model.Mapping
```

`internal/config/resolve.go`

- `Resolve(path)` returns the merged tree **and** a `Provenance{HostPath, SourcePath, IncludePath}`. Exactly one of the two branches runs: a `source` key routes to `resolveSource`, anything else goes straight to `resolveInclude`.
- `resolveSource` requires `source` to be the only key — a pointer file has nothing else in it — expands `$VAR` then `~`, and rejects a chained source. It then calls `resolveInclude` with the **sourced file** as the base-directory anchor. That one argument is what makes the whole arrangement work: a repo-resident config can write `include = "dotsync.base.toml"` and get the sibling in the repo, not a file next to the pointer.
- `resolveInclude` resolves the include relative to whichever file it was anchored on, rejects a chained include, strips the `include` key from the overlay, and deep-merges.
- `deepMerge` merges tables recursively, **concatenates arrays base-first**, and overlays scalars. Array concatenation is why a machine overlay adds mappings to a shared base rather than replacing them.
- `normalizeMap` flattens BurntSushi's `[]map[string]any` arrays-of-tables into `[]any` so the merge and the accessors can treat every table and array uniformly.

`internal/config/config.go`

- `Load` expands the path, resolves, stores the provenance, and validates. `Path()` is the file dotsync was pointed at; `EffectivePath()` is the file a user edits — the sourced file when there is one. Renderers that mean "the config" want `EffectivePath`.
- `Mappings()` builds the direction's list: `[[push|pull|watch.mappings]]` first (literal `src`/`dest`), then `[[sync.mappings]]` (`local`/`remote` swapped by direction in `orient`), then the `[[sync.<type>]]` shorthands in the fixed `shorthandOrder`. The order is part of the contract — Go maps do not preserve insertion order, so the slice is explicit.

There is no on-disk cache. The Ruby original memoized the merged tree through `Marshal`; a compiled binary parses this TOML in sub-millisecond time, so the cache and its mtime/size/version invalidation bugs were dropped. `DOTSYNC_NO_CACHE` is still accepted as a no-op.

### The self-reference trap

`internal/config/selfref.go` answers one question per provenance file: *would applying this mapping move it?*

```
  for each file in Provenance.Files()      (host, sourced, included)
      for each VALID mapping
          inside Dest() and not filtered  -> Overwritten
          inside Src()  and not filtered  -> Propagated
```

Containment uses `paths.PathIsParentOrSame`, which is boundary-aware — `…/configs` does not contain `…/config`. The filter question reuses `model.Mapping.Skip`, which is sound on either side because a `Mapping` expands every `only` and `ignore` entry against both its source and its destination when it is built.

The two roles are different consequences, not two phrasings of one:

- **Overwritten** (the config is on the destination side, typically a pull): the run rewrites the configuration it was planned from. An incoming rule is delivered by a run governed by the *previous* rules, so it governs nothing until the run after that — and it cannot appear in the preview, because the plan was computed from the outgoing config.
- **Propagated** (the config is on the source side, typically a push): the run copies the live config outward over the far copy. An edit made there is reverted without ever being listed as a difference.

`internal/action/action.go` renders this as the *Config synced by this run* block, and `internal/action/tui.go` puts the same finding in the cockpit's Notices. The detection lives in the config layer precisely so the two renderers cannot drift.

**It reports; it does not refuse.** A directory mapping legitimately covers a tree that happens to contain the config, so refusing would break working setups. More importantly, changing which files get written would diverge from the Ruby oracle that the parity harness compares against — a divergence in filesystem outcomes is the one thing the migration constraint rules out. The way out is `source`, and the warning says so (except when the sourced file is itself in the payload, where the fix is the mapping).

## Failure modes

- **Config file missing** → `Load` fails before resolution with the `run dotsync setup` hint. Exit 1.
- **`source` combined with other keys** → refused in `resolveSource`; a pointer file has exactly one key.
- **`source` pointing nowhere** → `Source file not found: <expanded path>`. An unset `$VAR` expands to the empty string, so an unattended run with no shell profile produces a visibly wrong path rather than silently reading the wrong file. `dotsync setup --source` writes the path absolute to avoid this.
- **Chained `source` or `include`** → refused with the offending file named. Both are one level deep by design.
- **Include missing** → `Included file not found: <resolved path>`; note the path is resolved against the *sourced* file's directory when `source` is in play, which is the usual surprise.
- **No mappings for the direction** → `validate` fails: the direction section or `[sync]` must contribute at least one.
- **A mapping points at the live config** → reported, never refused. See above.

## See also

- [ADR 0002](decisions/0002-rewrite-in-go-as-a-single-binary.md) — the Go rewrite, the TOML choice, and the parity constraint that rules out refusing
- [Config Includes](../../README.md#config-includes) and [Config Source](../../README.md#config-source) — the user-facing reference
- [The TUI cockpit](tui-cockpit.md) — the other consumer of the resolved config
