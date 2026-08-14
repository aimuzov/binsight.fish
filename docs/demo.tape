# The recording in the README. It runs against the machine it is recorded on, so the
# packages on screen are whatever the recorder actually has installed.
#
#   brew install vhs ttyd
#   cd docs && vhs demo.tape
#
# The first run of bins builds its caches, which takes a couple of seconds and would show
# up in the recording — the hidden warm-up below gets that out of the way.

Output demo.gif

Set Shell "bash"
Set FontFamily "JetBrainsMonoNL Nerd Font"
Set FontSize 15
Set Width 1900
Set Height 900
Set Padding 18
Set Theme "Catppuccin Mocha"
Set TypingSpeed 75ms
Set Framerate 24

# A fish profile of its own, and a cache built before the camera is on
Hide
Type "env XDG_CONFIG_HOME=$PWD/demo-profile XDG_CACHE_HOME=$PWD/demo-profile/cache fish -i"
Enter
Sleep 3s
Type "bins --list --refresh > /dev/null"
Enter
Sleep 8s
Type "clear"
Enter
Sleep 1s
Show

Sleep 1s
Type "bins"
Enter
Sleep 4s

# the question this was written for: something here speaks FTP, but what was it called
Type "ftp"
Sleep 4s
Down
Sleep 3s

# the other direction — a command in PATH, and the package it came from
Ctrl+U
Sleep 500ms
Type "rg"
Sleep 3s
Down
Sleep 2500ms

# enter copies the name
Enter
Sleep 3s
