source (status dirname)/helpers.fish

set -l packages (mktemp -t binsight-test-pkg.XXXXXX)
set -l found (mktemp -t binsight-test-bin.XXXXXX)
set -l linked (mktemp -t binsight-test-link.XXXXXX)

_binsight_packages >$packages
_binsight_binaries >$found
_binsight_link $packages $found >$linked

set -l rows (_binsight_describe $linked)

set -l row (_bt_named cargo:wireloop $rows)
@test "a crate is described by what its author wrote, not by the catalogue" \
    (_bt_field $row 5) = 'wireloop moves files over FTP, SFTP and WebDAV'

set -l row (_bt_named aqua:BurntSushi/ripgrep $rows)
@test "a tool with no metadata of its own falls back to the catalogue" \
    (_bt_field $row 5) = 'Search tool like grep and The Silver Searcher'

set -l row (_bt_named tinypkg $rows)
@test "a description the source already found is left alone" \
    (_bt_field $row 5) = 'Reads and writes tiny files'

set -l row (_bt_named loose-tool $rows)
@test "even an unowned binary is described when the catalogue knows the name" \
    (_bt_field $row 5) = 'Something the catalogue happens to know'

set -l row (_bt_named quiettool $rows)
@test "a package nothing knows about keeps an empty description" (_bt_field $row 5) = ''

@test "describing does not add or drop rows" \
    (count $rows) -eq (count (cat $linked))

command rm --force $packages $found $linked
