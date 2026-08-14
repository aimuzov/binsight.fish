source (status dirname)/helpers.fish

# brew

set -l rows (_binsight_source_brew)

@test "brew lists what the Cellar holds" (count $rows) -eq 1
@test "brew reports the newest version installed" (_bt_field $rows[1] 3) = 15.1.0
@test "brew points at the directory that owns the binaries" \
    (_bt_field $rows[1] 4) = "$binsight_fixtures/brew/Cellar/ripgrep"

set -l rows (_binsight_source_cask)

@test "casks come from the Caskroom" (_bt_field $rows[1] 2) = kitty
@test "a cask carries its version too" (_bt_field $rows[1] 3) = 0.42.0

# mise

set -l rows (_binsight_source_mise)

@test "mise lists every installed tool" (count $rows) -eq 2

set -l row (_bt_named cargo:wireloop $rows)
@test "mise keeps the backend in the name" (_bt_field $row 2) = cargo:wireloop
@test "mise records the install path" \
    (_bt_field $row 4) = "$binsight_fixtures/mise/installs/cargo-wireloop/2.1.0"

# npm

set -l rows (_binsight_source_npm)

@test "npm finds both plain and scoped packages" (count $rows) -eq 2

set -l row (_bt_named tinypkg $rows)
@test "npm takes the description from package.json" (_bt_field $row 5) = 'Reads and writes tiny files'

set -l row (_bt_named @scope/scoped $rows)
@test "a scoped package keeps its scope" (_bt_field $row 3) = 0.2.1

# cargo

set -l rows (_binsight_source_cargo)

@test "cargo reads every entry of .crates.toml" (count $rows) -eq 2

set -l row (_bt_named wireloop $rows)
@test "cargo reports the installed version" (_bt_field $row 3) = 2.1.0

# gem

set -l rows (_binsight_source_gem)

@test "gem lists the installed specifications" (count $rows) -eq 1
@test "gem splits name and version apart" (_bt_field $rows[1] 2) = quoteful
@test "gem splits the version off the stem" (_bt_field $rows[1] 3) = 1.3.0
@test "a summary that quotes something survives intact" \
    (_bt_field $rows[1] 5) = '"Did you mean?" experience for gems'

# go

set -l rows (_binsight_source_go)

@test "go skips its own toolchain" (count $rows) -eq 1
@test "go names a package by its module path" (_bt_field $rows[1] 2) = example.invalid/gotool

# a missing manager is not an error.
# The override has to be global: a fish function cannot see the caller's local variables

set --global binsight_gem_dir $binsight_fixtures/nothing-here
@test "a source with nothing to read stays quiet" (count (_binsight_source_gem)) -eq 0
set --global binsight_gem_dir $binsight_fixtures/gem
