source (status dirname)/helpers.fish

set -l binaries (_binsight_binaries)

@test "every executable in the scanned directories is picked up" \
    (_bt_has loose-tool (_bt_column 2 $binaries)) = yes
@test "a shims directory is skipped, since its entries all resolve to one binary" \
    (_bt_has shimmed-tool (_bt_column 2 $binaries)) = no

set -l packages (mktemp -t binsight-test-pkg.XXXXXX)
set -l found (mktemp -t binsight-test-bin.XXXXXX)

_binsight_packages >$packages
_binsight_binaries >$found

set -l rows (_binsight_link $packages $found)

set -l row (_bt_named ripgrep $rows)
@test "a binary under a package directory is credited to that package" \
    (_bt_field $row 4) = rg
@test "linking keeps the package's own columns" (_bt_field $row 1) = brew

set -l row (_bt_named cargo:wireloop $rows)
@test "the walk up finds the owner through a nested bin directory" \
    (_bt_field $row 4) = wireloop

set -l row (_bt_named loose-tool $rows)
@test "a binary no package claims becomes a row of its own" (_bt_field $row 1) = path
@test "an unclaimed binary records where it was found" \
    (_bt_field $row 6) = "$binsight_fixtures/path/bin/loose-tool"
@test "an unclaimed binary provides itself" (_bt_field $row 4) = loose-tool

@test "a package with no binary in PATH still gets a row" \
    (_bt_has kitty (_bt_column 2 $rows)) = yes
@test "and that row provides nothing" (_bt_field (_bt_named kitty $rows) 4) = ''

command rm --force $packages $found
