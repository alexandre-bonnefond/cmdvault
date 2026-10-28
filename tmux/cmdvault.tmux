# cmdvault: prefix + ? searches the vault in a popup and pastes the filled command into the
# pane, without running it (replaces the default prefix + ? list-keys, still in :list-keys).
# Loaded from ~/.tmux.conf with: source-file -q ~/git/cmdvault/tmux/cmdvault.tmux
# The popup command is not format-expanded, so the target pane goes through @cmdvault-pane.

bind-key ? set-option -gF @cmdvault-pane "#{pane_id}" \; display-popup -E -w 90% -h 80% -T " cmdvault " -d "#{pane_current_path}" "~/.local/bin/cmdvault popup"
