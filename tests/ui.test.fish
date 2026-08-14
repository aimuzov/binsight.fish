source (status dirname)/helpers.fish

set -l rows (bins --list)

@test "the list is indexed from one" (_bt_field $rows[1] 1) = 1
@test "every row carries the full set of columns" (count (string split \t -- $rows[1])) -eq 7

# The fixtures deliberately install wireloop twice — once through mise, once through
# cargo itself — so the rows are picked by their full name rather than by the crate
set -l row (_bt_pick cargo:wireloop $rows)
@test "the name column is displayed without its colouring" (_bt_shown $row 3) = cargo:wireloop
@test "the row keeps the source it came from" (_bt_shown $row 2) = mise
@test "the row shows what the package provides" (_bt_shown $row 5) = wireloop

set -l sources (for row in (bins --list --source brew); _bt_shown $row 2; end)
@test "a filtered list only holds that source" (count $sources) -eq (count (string match brew $sources))
@test "an unknown source yields nothing" (count (bins --list --source nosuch 2>/dev/null)) -eq 0

set -l unmanaged (bins --list --unmanaged)
@test "--unmanaged keeps the binaries no package claims" (_bt_has loose-tool $unmanaged) = yes
@test "--unmanaged drops the packages" (_bt_has wireloop $unmanaged) = no

# The cache is what makes a second run cheap, and a stale one is what makes it wrong

set -l cache $binsight_cache_dir/packages.tsv
@test "the first run leaves a cache behind" -f $cache

echo 'path	planted	-	planted		/nowhere/planted' >>$cache
@test "a later run reads that cache instead of rebuilding" (_bt_has planted (bins --list)) = yes
@test "--refresh rebuilds it" (_bt_has planted (bins --list --refresh)) = no

# Actions on a selected row

set -l data (mktemp -t binsight-test-ui.XXXXXX)
bins --list >$data
set -l index (_bt_field (_bt_pick cargo:wireloop (cat $data)) 1)

set -l preview (_binsight_preview $data $index)
@test "the preview leads with the name" (_bt_plain $preview[1]) = cargo:wireloop
@test "the preview says what the package does" (_bt_has 'moves files over FTP' $preview) = yes
@test "the preview says where it is installed" \
    (_bt_has "$binsight_fixtures/mise/installs/cargo-wireloop" $preview) = yes

set -l paths (_binsight_paths $data $index)
@test "the paths action reports the install directory" \
    "$paths[1]" = "$binsight_fixtures/mise/installs/cargo-wireloop/2.1.0"

command rm --force $data
