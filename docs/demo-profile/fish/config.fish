# The fish profile the README recording runs in: none of the recorder's own prompt,
# bindings or fzf colours, but the real packages of the machine behind every source.

set -g fish_greeting

set -l here (dirname (status filename))

# bins is loaded straight out of this checkout, not from an installed copy
set -p fish_function_path (realpath $here/../../..)/functions
set -p fish_complete_path (realpath $here/../../..)/completions

# a clipboard that goes nowhere: the recording must not touch the real one
set -gx PATH (realpath $here/../bin) $PATH

set -gx FZF_DEFAULT_OPTS '--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 --color=border:#6c7086,label:#cdd6f4'

function fish_prompt
    set_color brblack
    echo -n '~ '
    set_color normal
end
