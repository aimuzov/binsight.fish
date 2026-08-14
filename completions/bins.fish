complete --command bins --no-files

complete --command bins --short-option h --long-option help --description 'Show usage'
complete --command bins --short-option l --long-option list --description 'Dump raw TSV instead of opening fzf'
complete --command bins --short-option r --long-option refresh --description 'Rebuild the caches'
complete --command bins --short-option u --long-option unmanaged --description 'Only binaries no package claims'
complete --command bins --long-option system --description 'Include the system directories'
complete --command bins --short-option s --long-option source --require-parameter --description 'Limit to one package manager' \
    --arguments 'brew cask mise npm cargo gem go path'
