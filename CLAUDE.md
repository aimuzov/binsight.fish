# CLAUDE.md — binsight.fish

## What this is

A fish plugin exposing one command, `bins`: it asks every package manager on the machine what it
installed, scans `PATH` for executables, links the two together, and shows the result in an `fzf`
picker searchable by description. Nothing is fetched over the network — descriptions come from
metadata already on disk.

It is the sibling of `keysight.fish` and follows the same shape: one file of functions, TSV between
stages, fixtures and stubs in the tests.

## Layout

```
functions/bins.fish     everything: sources, linking, descriptions, cache, preview
completions/bins.fish   option completions
tests/                  fishtape suites, fixtures per source, stubs for mise and go
docs/demo.tape          the README recording, replayable with vhs
docs/demo-profile/      the throwaway fish profile that recording runs in
```

`functions/bins.fish` defines several functions in one file. Fish autoloads it by the name of the
public one (`bins`) and the rest become available at the same time.

## Pipeline

```
_binsight_packages   →  source \t name \t version \t prefix \t description
_binsight_binaries   →  resolved path \t command name
_binsight_link       →  source \t name \t version \t provides \t description \t prefix
_binsight_describe   →  the same rows, with the description column filled in
_binsight_collect    →  index \t coloured, padded columns …
```

Linking is one rule, not one per manager: walk up from a binary's real path until a directory
matches a prefix some package claimed. Anything that never matches becomes a `path` row.

Descriptions are resolved in two passes — the package's own metadata first (a crate's `Cargo.toml`,
`package.json`, a `dist-info`, a `.gemspec`), the homebrew catalogue second. The order matters: the
catalogue's entry for termscp does not contain the word FTP, and the author's does.

## Conventions

- Target fish 4.0+. Code, comments and `--description` strings are in English.
- Comment only what the code cannot say by itself — mostly the traps below.
- No dependency without a strong reason. jq is optional; everything degrades rather than fails.
- Every path a source reads is overridable by a `binsight_*` variable, which is what keeps the
  tests off the machine they run on.

## Traps already hit (do not re-discover these)

- **`system` is an awk builtin.** Passing `-v system=…` makes awk run every row through `sh`; the
  symptom is a flood of `sh: path: command not found` and a run that never ends. The flag travels
  as `with_system`.
- **A command substitution does not inherit the function's stdin.** `set -f rows (cat)` inside a
  function reads nothing and then blocks on the terminal. Stages hand each other files instead.
- **`test -n (…)` with an empty substitution has no operand left**, and POSIX test answers a single
  `-n` argument with true. That made the cache look stale on every run. Quote through a variable.
- **fish collapses `\\` inside single quotes.** A literal backslash in an awk regex needs four of
  them in the fish source — the gemspec parser needs it to skip escaped quotes.
- **`version` is a special fish variable**, so a local named `version` fails to set. Use `ver`.
- **`string replace --regex '-…'` reads a leading dash as an option.** Put the pattern after `--`.
- **`read --line` and `--delimiter` cannot be combined.**
- **mise shims all resolve to the mise binary**, so scanning them credits the whole machine to one
  package. The shims directory is skipped.
- **`mktemp` here is GNU coreutils, not BSD.** Keep the `XXXXXX` in the template; that form works
  on both.
- **The displayed columns carry ANSI colouring and padding.** Strip both before copying or
  comparing.
- **A fish function cannot see the caller's local variables.** Tests overriding a `binsight_*` path
  must set it globally.
- **fzf rejoins the fields it displays with tabs**, which a terminal expands to the next tab stop
  and no column layout survives. The row is laid out into one field instead, and only that field is
  shown; the raw columns ride along behind it. `--no-hscroll` belongs with it — otherwise fzf
  scrolls each row to its match and the columns shear apart again.

## Testing

```fish
fish --no-config -n functions/*.fish completions/*.fish tests/*.fish
fishtape tests/*.test.fish
```

`tests/helpers.fish` points every source at `tests/fixtures/` and every scan at `binsight_path`, so
the machine's own packages never leak into the results. `tests/stubs/` holds the two managers that
must actually be executed — mise (for its JSON) and go (for `go version -m`); the rest are
redirected by variable.

The fixtures install `wireloop` twice, through mise and through cargo, on purpose: it is the case
where a package appears under two managers at once, and it keeps the tests honest about picking
rows by their full name.

The fzf UI itself cannot be tested this way. It can be exercised by putting stubs for `fzf` and
`pbcopy` early in `PATH` — an `fzf` stub that prints one line simulates a selection.
