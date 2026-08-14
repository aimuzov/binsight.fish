function bins --description 'Interactive inventory of installed packages, their binaries and what they do'
    argparse h/help l/list r/refresh u/unmanaged system 's/source=' -- $argv
    or return 22

    if set --query _flag_help
        _bins_help
        return
    end

    set -f self (status filename)
    set -f refresh (set --query _flag_refresh; and echo refresh; or echo '')
    set -f system (set --query _flag_system; and echo system; or echo '')
    set -f unmanaged (set --query _flag_unmanaged; and echo unmanaged; or echo '')
    set -f rows (_binsight_collect "$_flag_source" "$refresh" "$system" "$unmanaged")

    if test (count $rows) -eq 0
        echo "bins: nothing found for source '$_flag_source'" >&2
        echo "bins: known sources are brew, cask, mise, npm, cargo, gem, go, path" >&2
        return 1
    end

    if set --query _flag_list
        printf '%s\n' $rows
        return
    end

    if not command --query fzf
        printf '%s\n' $rows
        return
    end

    # fzf needs the rows on disk: the preview runs in a separate process and looks them up by index.
    # The template keeps its X's because GNU mktemp, which shadows the BSD one here, insists on them.
    set -f data (mktemp -t binsight.XXXXXX)
    or begin
        echo 'bins: could not create a temporary file' >&2
        return 1
    end

    printf '%s\n' $rows >$data

    set -f picked (
        fzf --ansi \
            --delimiter \t \
            --with-nth 2,3,4,5,6 \
            --prompt 'Installed> ' \
            --header 'enter: copy the name · ctrl-o: open the homepage · ctrl-w: print the paths' \
            --preview "fish --no-config --command 'source $self; _binsight_preview $data {1}'" \
            --preview-window 'right,52%,wrap,border-left' \
            --bind "ctrl-o:execute-silent(fish --no-config --command 'source $self; _binsight_open $data {1}')" \
            --bind "ctrl-w:execute(fish --no-config --command 'source $self; _binsight_paths $data {1}' | less --quit-if-one-screen)" \
            --query "$argv" <$data
    )

    command rm --force $data

    test -n "$picked"; or return 0

    # The visible column carries colouring and padding; neither belongs in the clipboard
    set -f name (string trim -- (_binsight_strip (string split \t -- $picked)[3]))

    if command --query pbcopy
        printf '%s' $name | pbcopy
        echo "copied: $name"
    else
        echo $name
    end
end

function _bins_help --description 'Usage text for the installed-package browser'
    echo 'bins — everything installed on this machine, browsable in one place.'
    echo
    echo 'Usage:'
    echo '  bins [query]            browse everything, optionally pre-filtered'
    echo '  bins --source mise      limit to one package manager'
    echo '  bins --unmanaged        only binaries in PATH that no package claims'
    echo '  bins --system           include /usr/bin and the other system directories'
    echo '  bins --list             dump raw TSV instead of opening fzf'
    echo '  bins --refresh          rebuild the caches'
    echo
    echo 'Sources: brew, cask, mise, npm, cargo, gem, go, path.'
    echo 'Descriptions come from local metadata only — nothing is fetched over the network.'
end

function _binsight_collect --description 'Gather packages, attach their binaries, describe them and index the result'
    set -f wanted $argv[1]
    set -f refresh $argv[2]
    set -f system $argv[3]
    set -f unmanaged $argv[4]

    set -f cache (_binsight_cache_dir)/packages.tsv
    set -f rows

    # The cache holds everything, including the system directories, so that --system and
    # --source only filter the output and never need a cache of their own.
    if test "$refresh" != refresh; and not _binsight_stale $cache
        set rows (cat $cache 2>/dev/null)
    else
        mkdir -p (dirname $cache)
        set rows (_binsight_build)
        printf '%s\n' $rows >$cache
    end

    test (count $rows) -gt 0; or return

    # `system` is an awk builtin: passing it as -v turns every row into a shell command,
    # so the flag travels under a name of its own
    printf '%s\n' $rows | awk -F'\t' -v OFS='\t' \
        -v wanted="$wanted" -v with_system="$system" -v unmanaged="$unmanaged" '
        function pad(s, w,   n) { n = length(s); return n >= w ? s : s sprintf("%" (w - n) "s", "") }

        wanted != "" && $1 != wanted { next }
        unmanaged == "unmanaged" && $1 != "path" { next }
        with_system != "system" && $1 == "path" && $6 ~ /^\/(usr\/(bin|sbin|libexec)|bin|sbin)\// { next }

        {
            printf "%d\t\033[38;5;245m%s\033[0m\t\033[1;36m%s\033[0m\t\033[38;5;245m%s\033[0m\t%s\t%s\t%s\n", \
                ++i, pad($1, 6), pad($2, 28), pad($3, 12), pad($4, 24), $5, $6
        }
    '
end

function _binsight_build --description 'Collect every source, link binaries to packages, fill in descriptions'
    set -f packages (mktemp -t binsight-pkg.XXXXXX)
    set -f binaries (mktemp -t binsight-bin.XXXXXX)
    set -f linked (mktemp -t binsight-link.XXXXXX)

    _binsight_packages >$packages
    _binsight_binaries >$binaries

    # The stages hand each other files rather than a pipe: a command substitution inside
    # a fish function does not inherit the function's stdin, so `(cat)` would read nothing
    _binsight_link $packages $binaries >$linked
    _binsight_describe $linked | sort -t\t -k2,2 -f

    command rm --force $packages $binaries $linked
end

function _binsight_packages --description 'Every package manager in turn, as source/name/version/prefix/description rows'
    for source in brew cask mise npm cargo gem go
        _binsight_source_$source
    end
end

function _binsight_source_brew --description 'Formulae installed by homebrew'
    set -f cellar (_binsight_brew_dir Cellar)
    test -d "$cellar"; or return

    # The Cellar is read directly: `brew list` starts ruby and, with an untrusted tap
    # present, spends its stderr complaining instead of listing anything.
    for dir in $cellar/*/
        set -l name (path basename $dir)
        set -l versions (path basename (path filter -d $dir*/))
        test (count $versions) -gt 0; or continue

        printf 'brew\t%s\t%s\t%s\t\n' $name $versions[-1] (string trim --right --chars=/ -- $dir)
    end
end

function _binsight_source_cask --description 'Casks installed by homebrew'
    set -f caskroom (_binsight_brew_dir Caskroom)
    test -d "$caskroom"; or return

    for dir in $caskroom/*/
        set -l name (path basename $dir)
        set -l versions (path basename (path filter -d $dir*/))
        test (count $versions) -gt 0; or continue

        printf 'cask\t%s\t%s\t%s\t\n' $name $versions[-1] (string trim --right --chars=/ -- $dir)
    end
end

function _binsight_brew_dir --description 'Path to a homebrew directory, without paying for a brew start-up'
    if set --query binsight_brew_prefix
        echo $binsight_brew_prefix/$argv[1]
        return
    end

    if set --query HOMEBREW_PREFIX
        echo $HOMEBREW_PREFIX/$argv[1]
        return
    end

    command --query brew; or return
    echo (command brew --prefix 2>/dev/null)/$argv[1]
end

function _binsight_source_mise --description 'Tools installed by mise, across all of its backends'
    command --query mise; or return

    # install_path is what ties a tool to its binaries later on, and only the JSON output
    # carries it. Without jq the tools are still listed, just without that link.
    if command --query jq
        command mise ls --installed --json 2>/dev/null | jq -r '
            to_entries[] | .key as $tool | .value[] |
            select(.installed) | [$tool, .version, .install_path] | @tsv
        ' | while read --delimiter \t tool ver prefix
            printf 'mise\t%s\t%s\t%s\t\n' $tool $ver $prefix
        end
        return
    end

    command mise ls --installed 2>/dev/null | while read --line entry
        set -l fields (string split --no-empty ' ' -- (string replace --all --regex ' +' ' ' -- $entry))
        test (count $fields) -ge 2; or continue

        printf 'mise\t%s\t%s\t\t\n' $fields[1] $fields[2]
    end
end

function _binsight_source_npm --description 'Globally installed npm packages'
    set -f root (_binsight_npm_root)
    test -d "$root"; or return

    # Scoped packages live one level deeper, and their package.json is the only place
    # a description is kept locally.
    for manifest in $root/*/package.json $root/@*/*/package.json
        test -f $manifest; or continue

        set -l package (path dirname $manifest)
        printf 'npm\t%s\t%s\t%s\t%s\n' \
            (_binsight_json $manifest name) (_binsight_json $manifest version) \
            $package (_binsight_json $manifest description)
    end
end

function _binsight_npm_root --description 'Directory holding the global node modules'
    set --query binsight_npm_root; and echo $binsight_npm_root; and return

    command --query npm; or return
    command npm root -g 2>/dev/null
end

function _binsight_source_cargo --description 'Crates installed with cargo install'
    set -f home (set --query CARGO_HOME; and echo $CARGO_HOME; or echo ~/.cargo)
    set -f registry $home/.crates.toml
    test -s $registry; or return

    # .crates.toml records every `cargo install` as `name ver (source)` = ["bin", ...],
    # which is the whole inventory without starting cargo.
    awk -v home="$home" -F' ' '
        /^"/ {
            gsub(/^"|"$/, "", $1)
            split($0, part, " ")
            printf "cargo\t%s\t%s\t%s\t\n", part[1], part[2], home "/bin"
        }
    ' $registry | sort --unique
end

function _binsight_source_gem --description 'Installed ruby gems'
    set -f dir (_binsight_gem_dir)
    test -d "$dir/specifications"; or return

    for spec in $dir/specifications/*.gemspec
        set -l stem (string replace --regex -- '\.gemspec$' '' (path basename $spec))
        set -l name (string replace --regex -- '-[^-]+$' '' $stem)
        set -l ver (string replace --regex -- '^.*-' '' $stem)

        printf 'gem\t%s\t%s\t%s\t%s\n' $name $ver $dir/gems/$stem (_binsight_gemspec_summary $spec)
    end
end

function _binsight_gem_dir --description 'Directory holding the installed gems'
    set --query binsight_gem_dir; and echo $binsight_gem_dir; and return

    command --query gem; or return
    command gem env gemdir 2>/dev/null
end

function _binsight_gemspec_summary --description 'The summary line out of a gemspec'
    # Gemspecs spell the summary either as a plain string or as %q{...}, so both forms
    # are unwrapped here rather than fought with in fish quoting
    awk '
        /\.summary *=/ {
            if (match($0, /%q\{[^}]*\}/)) { summary = substr($0, RSTART + 3, RLENGTH - 4) }
            # A summary may quote something itself, so the string runs to the last
            # unescaped quote rather than to the first quote of any kind.
            # fish collapses \\ inside single quotes, so a literal backslash needs four
            else if (match($0, /"([^"\\\\]|\\\\.)*"/)) { summary = substr($0, RSTART + 1, RLENGTH - 2) }
            else next

            gsub(/\\\\"/, "\"", summary)
            print summary
            exit
        }
    ' $argv[1] 2>/dev/null
end

function _binsight_source_go --description 'Binaries installed with go install'
    set -f gobin (_binsight_go_bin)
    test -d "$gobin"; or return

    for binary in (path filter -fx $gobin/*)
        # The module path is the closest thing to a package name that go keeps in the binary
        set -l module (command go version -m $binary 2>/dev/null | string match --regex --groups-only '^\s+path\s+(\S+)' | head -1)
        test -n "$module"; or set module (path basename $binary)
        # mise points GOBIN at the toolchain's own bin, where go and gofmt sit next to
        # whatever `go install` put there; the toolchain already belongs to another source
        string match --quiet 'cmd/*' -- $module; and continue

        printf 'go\t%s\t-\t%s\t\n' $module $binary
    end
end

function _binsight_go_bin --description 'Directory holding go-installed binaries'
    set --query binsight_go_bin; and echo $binsight_go_bin; and return

    command --query go; or return
    set -f gobin (command go env GOBIN 2>/dev/null)
    test -n "$gobin"; and echo $gobin; and return

    echo (command go env GOPATH 2>/dev/null)/bin
end

function _binsight_binaries --description 'Every executable in PATH, paired with the file it really points at'
    set -f search $PATH
    set --query binsight_path; and set search $binsight_path

    set -f dirs
    for dir in $search
        # mise shims all resolve to the mise binary itself, which would credit every
        # command on the machine to a single package
        string match --quiet '*/shims' -- $dir; and continue
        test -d $dir; and set --append dirs $dir
    end

    test (count $dirs) -gt 0; or return

    set -f files (path filter -fx $dirs/*)
    test (count $files) -gt 0; or return

    # Resolved path and command name are collected in one vectorised call each and then
    # stitched together: doing it per file costs a fish loop over a couple of thousand entries.
    set -f resolved (mktemp -t binsight-res.XXXXXX)
    set -f names (mktemp -t binsight-nam.XXXXXX)

    printf '%s\n' (path resolve $files) >$resolved
    printf '%s\n' (path basename $files) >$names

    paste $resolved $names
    command rm --force $resolved $names
end

function _binsight_link --description 'Attach every binary to the package whose directory contains it'
    awk -F'\t' -v OFS='\t' -v packages="$argv[1]" '
        FILENAME == packages {
            n++
            source[n] = $1; name[n] = $2; version[n] = $3; prefix[n] = $4; description[n] = $5
            if ($4 != "") owner[$4] = n
            next
        }

        # Walk up from the real location until a directory is one a package claims.
        # Every manager installs under a prefix of its own, so one rule covers them all.
        {
            dir = $1
            while (length(dir) > 1) {
                sub(/\/[^\/]*$/, "", dir)
                if (dir in owner) {
                    i = owner[dir]
                    if (!seen[i, $2]++) provides[i] = provides[i] == "" ? $2 : provides[i] "," $2
                    next
                }
            }
            if (!unowned[$2]++) print "path", $2, "-", $2, "", $1
        }

        END {
            for (i = 1; i <= n; i++)
                print source[i], name[i], version[i], provides[i], description[i], prefix[i]
        }
    ' $argv[1] $argv[2]
end

function _binsight_describe --description 'Fill in missing descriptions from local metadata'
    set -f rows $argv[1]
    set -f found (mktemp -t binsight-desc.XXXXXX)

    # A package that ships its own metadata is asked first: what the author wrote about
    # termscp mentions FTP, while the homebrew catalogue entry for it does not. Only rows
    # with an install directory are worth the lookup — a bare binary in PATH has nothing.
    for entry in (awk -F'\t' '$5 == "" && $6 != "" && $1 != "path" { print NR "\t" $2 "\t" $6 }' $rows)
        set -l fields (string split \t -- $entry)
        set -l description (_binsight_metadata $fields[2] $fields[3])
        test -n "$description"; and printf '%s\t%s\n' $fields[1] "$description" >>$found
    end

    # The homebrew catalogue describes far more than homebrew installed: the same tool
    # under mise or in PATH usually carries the same name, so one join covers the rest.
    awk -F'\t' -v OFS='\t' -v catalog=(_binsight_catalog) -v found="$found" '
        BEGIN {
            while ((getline line < found) > 0) {
                split(line, f, "\t")
                own[f[1]] = f[2]
            }
            while ((getline line < catalog) > 0) {
                split(line, f, "\t")
                desc[f[1]] = f[2]
            }
        }
        NR in own { $5 = own[NR] }
        $5 == "" {
            short = $2
            sub(/^[^:]+:/, "", short)      # mise backends: aqua:BurntSushi/ripgrep
            sub(/^.*\//, "", short)        # owner/repo and scoped npm names
            if (short in desc) $5 = desc[short]
        }
        { print }
    ' $rows

    command rm --force $found
end

function _binsight_metadata --description 'Description for one package, dug out of its own install directory'
    set -f name $argv[1]
    set -f prefix $argv[2]
    set -f short (string replace --regex '^.*[:/]' '' -- $name)

    # A crate keeps its description in the sources cargo unpacked to build it
    set -f cargo_home (set --query CARGO_HOME; and echo $CARGO_HOME; or echo ~/.cargo)
    for manifest in $cargo_home/registry/src/*/$short-*/Cargo.toml
        set -l value (string replace --regex '^description *= *' '' -- \
            (grep --max-count=1 '^description *=' $manifest 2>/dev/null))
        test -n "$value"; and string trim --chars='"' -- $value; and return
    end

    test -n "$prefix"; or return

    # pipx-style layouts keep a python dist-info next to the virtualenv
    for meta in $prefix/*/lib/python*/site-packages/$short-*.dist-info/METADATA $prefix/lib/python*/site-packages/$short-*.dist-info/METADATA
        set -l value (string replace --regex '^Summary: *' '' -- \
            (grep --max-count=1 '^Summary:' $meta 2>/dev/null))
        test -n "$value"; and echo $value; and return
    end

    for manifest in $prefix/lib/node_modules/*/package.json $prefix/lib/node_modules/@*/*/package.json
        set -l value (_binsight_json $manifest description)
        test -n "$value"; and echo $value; and return
    end
end

function _binsight_catalog --description 'Name/description/homepage table built from the homebrew API cache'
    set -f cache (_binsight_cache_dir)/catalog.tsv
    set -f api ~/Library/Caches/Homebrew/api

    set --query binsight_catalog; and echo $binsight_catalog; and return

    if test -f $cache; and not _binsight_newer $cache $api/formula.jws.json
        echo $cache
        return
    end

    mkdir -p (dirname $cache)
    command touch $cache

    command --query jq; or begin
        echo $cache
        return
    end

    # The JSON is wrapped in a signed envelope, so the payload is a string that has to be
    # parsed a second time. Both files together describe about 15000 packages in under a second.
    begin
        test -f $api/formula.jws.json; and jq -r '
            .payload | fromjson | .[] | [.name, .desc // "", .homepage // ""] | @tsv
        ' $api/formula.jws.json 2>/dev/null

        test -f $api/cask.jws.json; and jq -r '
            .payload | fromjson | .[] | [.token, .desc // "", .homepage // ""] | @tsv
        ' $api/cask.jws.json 2>/dev/null
    end >$cache

    echo $cache
end

function _binsight_json --description 'One top level string field out of a JSON file'
    test -f "$argv[1]"; or return

    if command --query jq
        jq -r --arg field $argv[2] '.[$field] // ""' $argv[1] 2>/dev/null
        return
    end

    # Enough to read a package.json field when jq is missing; nested objects are not needed here
    string replace --regex '^.*"'$argv[2]'" *: *"((?:[^"\\\\]|\\\\.)*)".*$' '$1' -- \
        (string join ' ' <$argv[1]) | string match --regex --invert '^\{'
end

function _binsight_cache_dir --description 'Directory the caches live in'
    if set --query binsight_cache_dir
        echo $binsight_cache_dir
    else if set --query XDG_CACHE_HOME
        echo $XDG_CACHE_HOME/binsight
    else
        echo ~/.cache/binsight
    end
end

function _binsight_stale --description 'Whether the package cache is missing or older than what it describes'
    set -f cache $argv[1]
    test -f $cache; or return 0

    for dir in (_binsight_brew_dir Cellar) (_binsight_brew_dir Caskroom) \
        ~/.local/share/mise/installs (_binsight_npm_root) (_binsight_gem_dir)/specifications
        test -d "$dir"; or continue
        _binsight_newer $cache $dir; and return 0
    end

    return 1
end

function _binsight_newer --description 'Whether the second path was touched after the first'
    test -e "$argv[2]"; or return 1

    # The result is quoted through a variable: an unquoted empty substitution would leave
    # `test -n` with no operand at all, which POSIX test answers with true
    set -f changed (find $argv[2] -maxdepth 0 -newer $argv[1] 2>/dev/null)
    test -n "$changed"
end

function _binsight_preview --description 'Render the fzf preview card for one package'
    set -f row (_binsight_row $argv[1] $argv[2])
    test (count $row) -ge 6; or return

    set -f name (string trim -- (_binsight_strip $row[3]))
    set -f source (string trim -- (_binsight_strip $row[2]))
    set -f ver (string trim -- (_binsight_strip $row[4]))
    set -f provides (string trim -- $row[5])

    set_color --bold cyan
    echo $name
    set_color normal
    echo

    set_color --bold
    echo 'Does'
    set_color normal
    echo "  "(test -n "$row[6]"; and echo $row[6]; or echo 'no description in any local metadata')
    echo

    set_color --bold
    echo 'From'
    set_color normal
    echo "  $source"(test "$ver" = -; or echo " $ver")
    echo

    if test -n "$provides"
        set_color --bold
        echo 'Provides'
        set_color normal
        for binary in (string split ',' -- $provides)
            echo "  $binary"
        end
        echo
    end

    set -f homepage (_binsight_homepage $name)
    if test -n "$homepage"
        set_color --bold
        echo 'Homepage'
        set_color normal
        echo "  $homepage"
        echo
    end

    set_color --bold
    echo 'Installed in'
    set_color normal
    echo "  $row[7]"
end

function _binsight_homepage --description 'Homepage for a package, when the catalogue knows one'
    set -f catalog (_binsight_catalog)
    test -f "$catalog"; or return

    set -f short (string replace --regex '^.*[:/]' '' -- $argv[1])
    awk -F'\t' -v name="$short" '$1 == name { print $3; exit }' $catalog
end

function _binsight_open --description 'Open the homepage of a package'
    set -f row (_binsight_row $argv[1] $argv[2])
    set -f homepage (_binsight_homepage (string trim -- (_binsight_strip $row[3])))

    test -n "$homepage"; or return
    command --query open; and command open $homepage
end

function _binsight_paths --description 'Print where a package and its binaries live'
    set -f row (_binsight_row $argv[1] $argv[2])
    test (count $row) -ge 7; or return

    echo $row[7]
    for binary in (string split ',' -- (string trim -- $row[5]))
        test -n "$binary"; and command --search $binary 2>/dev/null
    end
end

function _binsight_row --description 'Read one indexed row back from the data file'
    test -f "$argv[1]"; or return
    string split \t -- (awk -F'\t' -v n="$argv[2]" 'NR == n' $argv[1])
end

function _binsight_strip --description 'Drop ANSI colouring from a field'
    string replace --all --regex '\e\[[0-9;]*m' '' -- $argv[1]
end
