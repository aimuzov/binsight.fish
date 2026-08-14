# binsight.fish

One command that shows everything installed on this machine — every package, every binary in
`PATH`, and what each of them is for — browsable in `fzf` and searchable by description, not just
by name.

```
bins
```

The list is built from the package managers themselves and from `PATH`, so it cannot drift away
from what is actually on disk.

## Why

You remember installing something that speaks FTP. You do not remember what it was called, and
neither `brew list` nor `mise ls` will tell you: they print names, and the name is exactly the part
you forgot. `bins ftp` finds it, because every row carries the package's own description — pulled
out of metadata that is already on the disk, with nothing fetched over the network.

The same list answers the other half of the question: which of the two thousand executables in your
`PATH` came from a package, which came from macOS, and where each one actually lives.

## Requirements

- [fish](https://fishshell.com) 4.0 or newer
- [fzf](https://github.com/junegunn/fzf) — optional, falls back to plain output
- [jq](https://jqlang.github.io/jq/) — optional, but without it mise tools lose their install paths
  and JSON metadata goes unread
- `awk`, `grep`, `sort`, `find`, `paste`, `mktemp` — any POSIX system has these

## Install

With [fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install aimuzov/binsight.fish
```

Manually — copy `functions/bins.fish` into `~/.config/fish/functions/`.

## Usage

```fish
bins                  # browse everything
bins ftp              # open with a starting query
bins --source mise    # limit to one package manager
bins --unmanaged      # only binaries no package claims
bins --system         # include /usr/bin and the other system directories
bins --list           # raw TSV instead of the fzf UI, for scripting
bins --refresh        # rebuild the caches
bins --help
```

Inside the picker:

| Key | Action |
| --- | --- |
| <kbd>Enter</kbd> | copy the package name to the clipboard |
| <kbd>Ctrl</kbd>+<kbd>O</kbd> | open its homepage |
| <kbd>Ctrl</kbd>+<kbd>W</kbd> | print the install directory and the paths of its binaries |

The left pane lists the manager, the name, the version, the commands the package provides and what
it does; the preview adds the homepage and the install directory.

## Sources

| Source | Read from | Notes |
| --- | --- | --- |
| brew | `$HOMEBREW_PREFIX/Cellar` | read as a directory: no ruby start-up, no complaints about untrusted taps |
| cask | `$HOMEBREW_PREFIX/Caskroom` | |
| mise | `mise ls --installed --json` | every backend: aqua, cargo, npm, pipx, github, http |
| npm | `npm root -g` | plain and scoped packages, description from `package.json` |
| cargo | `$CARGO_HOME/.crates.toml` | what `cargo install` put there, without starting cargo |
| gem | `gem env gemdir` | summary from the installed `.gemspec` |
| go | `go env GOBIN` or `$GOPATH/bin` | module path via `go version -m`; the toolchain itself is skipped |
| path | every directory in `PATH` | whatever no package claims |

Missing managers are skipped silently, so the plugin is useful with only one or two of them
installed.

## Where descriptions come from

Everything is local. In order of preference:

1. The package's own metadata — `Cargo.toml` from the cargo sources, `package.json`, a python
   `dist-info`, a `.gemspec`.
2. The homebrew catalogue in `~/Library/Caches/Homebrew/api`, matched by short name. It describes
   far more than homebrew installed, so it also covers the same tool under mise or in `PATH`.

The package's own words win, and that is deliberate: homebrew calls `termscp` a "feature rich
terminal file transfer and explorer", while its author mentions SCP, SFTP, FTP, S3 and WebDAV by
name — and that is what you will search for.

Anything neither source knows keeps an empty description rather than a guess.

## Notes and limitations

- **The list is cached.** Building it costs about two seconds; afterwards a run is roughly a third
  of a second. The cache lives in `$XDG_CACHE_HOME/binsight` and is rebuilt when any install
  directory changes, or on `bins --refresh`.
- **System binaries are hidden by default.** `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin` and
  `/usr/libexec` hold well over a thousand entries that drown everything else; `--system` brings
  them back.
- **mise shims are skipped.** Every shim resolves to the mise binary itself, which would credit the
  whole machine to one package. Tools are found through their real install paths instead.
- **A package can appear twice** when two managers installed it — that is a fact about the machine,
  not a bug, and seeing it is half the point.
- **Casks and GUI apps** are listed by name and version only; they rarely put anything in `PATH`.

## Configuration

Every path can be overridden, which is also how the tests keep themselves off the machine they run
on:

| Variable | Overrides |
| --- | --- |
| `binsight_cache_dir` | where the caches live |
| `binsight_path` | the directories scanned instead of `PATH` |
| `binsight_brew_prefix` | the homebrew prefix |
| `binsight_npm_root` | the global node modules directory |
| `binsight_gem_dir` | the gem directory |
| `binsight_go_bin` | the go binary directory |
| `binsight_catalog` | a ready-made name/description/homepage table |

## Adding a source

Each source is a single function printing tab-separated rows:

```
source <TAB> name <TAB> version <TAB> prefix <TAB> description
```

Write `_binsight_source_<name>`, return nothing when the manager is absent, and add `<name>` to the
loop in `_binsight_packages`. `prefix` is the directory the package owns — that is what links its
binaries to it — and `description` may be left empty for the later stages to fill in.

## Tests

```fish
fish --no-config -n functions/*.fish completions/*.fish tests/*.fish
fishtape tests/*.test.fish
```

The suite runs entirely against fixtures and stubbed managers, so it says the same thing on any
machine.

## License

[MIT](LICENSE)
