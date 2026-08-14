# Shared setup for every suite: load the plugin out of this checkout and point every
# source at a fixture, so that the tests say the same thing on any machine.

set --global binsight_tests (realpath (status dirname))
set --global binsight_fixtures $binsight_tests/fixtures

source $binsight_tests/../functions/bins.fish

set --global binsight_brew_prefix $binsight_fixtures/brew
set --global binsight_npm_root $binsight_fixtures/npm/root
set --global binsight_gem_dir $binsight_fixtures/gem
set --global binsight_go_bin $binsight_fixtures/go/bin
set --global binsight_catalog $binsight_fixtures/catalog.tsv
set --global binsight_cache_dir (mktemp -d -t binsight-cache.XXXXXX)

# Only the fixture directories are scanned, so the machine running the tests cannot leak
# its own PATH into the results. The real PATH stays intact for awk, sort and friends.
set --global binsight_path \
    $binsight_fixtures/brew/Cellar/ripgrep/15.1.0/bin \
    $binsight_fixtures/mise/installs/cargo-wireloop/2.1.0/bin \
    $binsight_fixtures/mise/installs/aqua-burnt-sushi-ripgrep/15.1.0/bin \
    $binsight_fixtures/mise/shims \
    $binsight_fixtures/path/bin

set --global --export CARGO_HOME $binsight_fixtures/cargo
set --global --export BINSIGHT_FIXTURES $binsight_fixtures
# The stubs shadow the real mise and go; every other manager is redirected by variable
set --global --export PATH $binsight_tests/stubs $PATH

function _bt_field --description 'One tab separated field of a row'
    set -l fields (string split \t -- $argv[1])
    echo $fields[$argv[2]]
end

function _bt_named --description 'The row whose name column matches, out of the rows that follow'
    for row in $argv[2..]
        test (string trim -- (_bt_field $row 2)) = "$argv[1]"; and echo $row
    end
end

function _bt_column --description 'One field of every row that follows'
    for row in $argv[2..]
        _bt_field $row $argv[1]
    end
end

function _bt_has --description 'yes when the needle appears anywhere in the rest of the arguments'
    string match --quiet -- "*$argv[1]*" $argv[2..]; and echo yes; or echo no
end

function _bt_plain --description 'A displayed field without its colouring and padding'
    string trim -- (_binsight_strip $argv[1])
end

function _bt_shown --description 'One field of a displayed row, as the eye sees it'
    _bt_plain (_bt_field $argv[1] $argv[2])
end

# A displayed row carries the index first, so the name has moved a column to the right
function _bt_pick --description 'The displayed row whose name matches, out of the rows that follow'
    for row in $argv[2..]
        test (_bt_shown $row 3) = "$argv[1]"; and echo $row
    end
end
